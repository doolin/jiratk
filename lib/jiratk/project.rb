# frozen-string-literal: true

# Projects are composed of issues, components, and other
# items.
class Project
  STEP = 50

  def self.search_url
    @search_url ||= 'https://doolin.atlassian.net/rest/api/3/search'
  end

  # `startAt` works in reverse order: it indexes the latest
  # ticket at 0, and works backwards from that.
  def self.get_issues_for(project, start_at)
    query = {
      jql: "project = \"#{project}\"",
      startAt: start_at.to_s,
      maxResults: STEP
    }

    api_helper = ApiHelper.new(search_url)

    response = api_helper.get(query)
    response_json = JSON.parse(response)
    response_json['issues']
  end

  # setting maxResults: 0 returns just metadata which will
  # contain `total`, the number of issues in a project.
  def self.issue_count_for(project)
    query = {
      jql: "project = \"#{project}\"",
      startAt: 0,
      maxResults: 0
    }

    api_helper = ApiHelper.new(search_url)

    response = api_helper.get(query)
    response_json = JSON.parse(response)
    response_json['total']
  end

  def self.file_writer(issue, path = '/tmp')
    File.open("#{path}/jira/#{issue['key']}.json", 'w') do |f|
      f.write(issue)
    end
  end

  def self.batch_download_for(project, writer = method(:file_writer))
    total = issue_count_for(project)

    (0..total).step(STEP).each do |start_at|
      issues = get_issues_for(project, start_at)

      issues.each do |issue|
        puts issue['key']
        writer.call(issue)
      end
    end
  end
end
