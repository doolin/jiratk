#!/usr/bin/env ruby
# frozen-string-literal: true

# The result is {:query_execution_id=>"05dfecae-4aec-4f3f-ba7c-c02f51bdac70"}
# Do the following:
# - [X] Find the Dec 14 result in the S3 bucket, verify CSV, it is.
# - [X] download that result via S3 and write to /tmp
# - [X] check to see if downloaded matches known good results and is csv
#
# - [ ] Determine what that lag time is for running Athena queries. That is,
#       does the API call return an execution_id immediately, or does it
#       return the execution_id after the query is run?
# - [ ] Determine how failed queries are handled.
# - [ ] Does the crawler need to be run after every update to the data?
# - [ ] How many concurrent connections can I make to S3?
# - [ ] How many concurrent connections can I make to Jira?
# - [X] Implement an exponential backoff to wait for query results

# From stackoverflow https://stackoverflow.com/questions/61412424/aws-athena-too-slow-for-an-api

ATHENA_EXPLANATION = <<~DOC
  Athena is indeed not a low latency data store. You will very rarely see response
  times below one second, and often they will be considerably longer. In the general
  case Athena is not suitable as a backend for an API, but of course that depends on
  what kind of an API it is. If it's some kind of analytics service, perhaps users don't
  expect sub second response times? I have built APIs that use Athena that work really well,
  but those were services where response times in seconds were expected (and even considered fast),
  and I got help from the Athena team to tune our account to our workload.

  To understand why Athena is "slow", we can dissect what happens when you submit a query to Athena:

  1. Your code starts a query by using the StartQueryExecution API call
  2. The Athena service receives the query, and puts it on a queue. If you're unlucky your query will sit in the queue for a while
  3. When there is available capacity the Athena service takes your query from the queue and makes a query plan
  4. The query plan requires loading table metadata from the Glue catalog, including the list of partitions, for all tables included in the query
  5. Athena also lists all the locations on S3 it got from the tables and partitions to produce a full list of files that will be processed
  6. The plan is then executed in parallel, and depending on its complexity, in multiple steps
  7. The results of the parallel executions are combined and a result is serialized as CSV and written to S3
  8. Meanwhile your code checks if the query has completed using the GetQueryExecution API call, until it gets a response that says that the execution has succeeded, failed, or been cancelled
  9. If the execution succeeded your code uses the GetQueryResults API call to retrieve the first page of results
  10. To respond to that API call, Athena reads the result CSV from S3, deserializes it, and serializes it as JSON for the API response
  11. If there are more than 1000 rows the last steps will be repeated

  A Presto expert could probably give more detail about steps 4-6, even though they are probably a bit
  modified in Athena's version of Presto. The details aren't very important for this discussion though.

  If you run a query over a lot of data, tens of gigabytes or more, the total execution time will be dominated by step 6. If the result is also big, 7 will be a factor.

  If your data set is small, and/or involves thousands of files on S3, then 4-5 will instead dominate.

  Here are some reasons why Athena queries can never be fast, even if they wouldn't touch S3 (for example SELECT NOW()):

  - There will at least be three API calls before you get the response, a StartQueryExecution, a GetQueryExecution, and a GetQueryResults, just their round trip time (RTT) would add up to more than 100ms.
  - You will most likely have to call GetQueryExecution multiple times, and the delay between calls will puts a bound on how quickly you can discover that the query has succeeded, e.g. if you call it every 100ms you will on average add half of 100ms + RTT to the total time because on average you'll miss the actual completion time by this much.
  - Athena will writes the results to S3 before it marks the execution as succeeded, and since it produces a single CSV file this is not done in parallel. A big response takes time to write.
  - The GetQueryResults must read the CSV from S3, parse it and serialize it as JSON. Subsequent pages must skip ahead in the CSV, and may be even slower.
  - Athena is a multi tenant service, all customers are competing for resources, and your queries will get queued when there aren't enough resources available.

  If you want to know what affects the performance of your queries you can use the ListQueryExecutions API call to list recent query execution IDs (I think you can go back 90 days at the most), and then use GetQueryExecution to get query statistics (see the documentation for QueryExecution.Statistics for what each property means). With this information you can figure out if your slow queries are because of queueing, execution, or the overhead of making the API calls (if it's not the first two, it's likely the last).

  There are some things you can do to cut some of the delays, but these tips are unlikely to get you down to sub second latencies:

  - If you query a lot of data use file formats that are optimized for that kind of thing, Parquet is almost always the answer – and also make sure your file sizes are optimal, around 100 MB.
  - Avoid lots of files, and avoid deep hierarchies. Ideally have just one or a few files per partition, and don't organize files in "subdirectories" (S3 prefixes with slashes) except for those corresponding to partitions.
  - Avoid running queries at the top of the hour, this is when everyone else's scheduled jobs run, there's significant contention for resources the first minutes of every hour.
  - Skip GetQueryExecution, download the CSV from S3 directly. The GetQueryExecution call is convenient if you want to know the data types of the columns, but if you already know, or don't care, reading the data directly can save you some precious tens of milliseconds. If you need the column data types you can get the ….csv.metadata file that is written alongside the result CSV, it's undocumented Protobuf data, see here and here for more information.
  - Ask the Athena service team to tune your account. This might not be something you can get without higher
    tiers of support, I don't really know the politics of this and you need to start by talking to your account manager.

  share improve this answer follow
  edited Apr 27 at 10:12
  answered Apr 27 at 10:05
  Theo
  124k1717 gold badges134134 silver badges176176 bronze badges
DOC

require 'pry'

require_relative '../lib/jiratk/athena_tools'
require_relative '../lib/jiratk/s3_tools'

if ENV['AWS_REGION'].nil?
  puts 'set AWS region'
  exit
end

COUNT_BY_DAY_OF_WEEK = <<~SQL
  select day_of_week(from_iso8601_timestamp(fields.created)) as day,
        count(*) as count
    from jiratickets.jirainventium_jira
    where fields.project.key = 'TASKLETS'
    and
    fields.created < '2020-10-01'
    group by 1
    order by day asc;
SQL

def query_string
  <<~SQL
    select key, fields.issuetype.name as type, fields.summary as summary
      from jiratickets.jirainventium_jira
      where fields.issuetype.name = 'Epic'
  SQL
end

execution_id = AthenaTools.new.execute(COUNT_BY_DAY_OF_WEEK)

puts "Execution id: #{execution_id}"

# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#get_object-instance_method
options = {
  response_target: "/tmp/#{execution_id}.csv",
  bucket: 'inventium-testem',
  key: "#{execution_id}.csv"
}

# This is going to fail if executed right away, as it takes a bit of time for the
# query to run on Athena.

retries = 0
max_retries = 5
begin
  puts "Retries: #{retries}"
  _response = S3Tools.new.get_object(options)
# rescue Aws::S3::Errors::NoSuchKey => e
rescue RuntimeError => e
  raise "Timeout: #{e.message}" unless retries <= max_retries

  retries += 1
  value = 2**retries
  puts "Sleep: #{value}"
  sleep(value)
  retry
end

puts "Retries: #{retries}"
