# frozen_string_literal: true

require 'csv'

data = <<~TEXT
  Date	Event Type	Issue	Completed Work	Work scope
  1/Jun/24 5:31 AM

  Sprint started
  FIN-369 Smog check
  FIN-555 LinkedIn recommendation Andrew Grieser
  FIN-569 Step 1 Set up a Job Search Council
  FIN-599 Repot h. bhutanica
  FIN-646 HPPR 6 Introducing Database Views
  FIN-659 Nguyen Hue pages 26-27
  FIN-661 Github sales tax configuration :(
  FIN-662 Olli: Prompt Engineering & more due diligence
  FIN-666 Add Skills to hired.com profile
  FIN-667 Draft charter for JSC
  FIN-668 Huntress interview Wed June 5
  FIN-670 undefined
  FIN-671 Outline SIEM architecture

  0

  25
  1/Jun/24 5:31 AM

  Issue completed
  FIN-569 Step 1 Set up a Job Search Council

  0 → 3

  25
  1/Jun/24 7:47 AM

  Issue completed
  FIN-659 Nguyen Hue pages 26-27

  3 → 4

  25
  1/Jun/24 10:15 AM

  Issue completed
  FIN-599 Repot h. bhutanica

  4 → 5

  25
  2/Jun/24 5:01 AM

  Issue completed
  FIN-555 LinkedIn recommendation Andrew Grieser

  5 → 7

  25
  2/Jun/24 5:09 AM

  Issue completed
  FIN-666 Add Skills to hired.com profile

  7 → 8

  25
  2/Jun/24 8:07 AM

  Issue completed
  FIN-661 Github sales tax configuration :(

  8 → 9

  25
  2/Jun/24 11:45 AM

  Estimate updated
  FIN-662 Olli: Prompt Engineering & more due diligence

  9

  25 → 29
  2/Jun/24 12:54 PM

  Added to sprint
  FIN-676 Spring Health interview Tuesday June 4 9:30 am

  9

  29 → 31
  2/Jun/24 12:58 PM

  Estimate updated
  FIN-662 Olli: Prompt Engineering & more due diligence

  9

  31 → 32
  3/Jun/24 5:51 AM

  Issue completed
  FIN-646 HPPR 6 Introducing Database Views

  9 → 10

  32
  3/Jun/24 2:11 PM

  Issue completed
  FIN-667 Draft charter for JSC

  10 → 12

  32
  4/Jun/24 12:57 PM

  Issue completed
  FIN-676 Spring Health interview Tuesday June 4 9:30 am

  12 → 14

  32
  5/Jun/24 8:31 AM

  Issue completed
  FIN-671 Outline SIEM architecture

  14 → 17

  32
  5/Jun/24 9:34 AM

  Issue completed
  FIN-662 Olli: Prompt Engineering & more due diligence

  17 → 23

  32
  5/Jun/24 1:10 PM

  Removed from sprint
  FIN-670 undefined

  23

  32 → 31
  5/Jun/24 3:03 PM

  Issue completed
  FIN-668 Huntress interview Wed June 5

  23 → 26

  31
  6/Jun/24 5:52 AM

  Added to sprint
  FIN-685 Read Chapter 4 - list likes and dislikes

  26

  31 → 33
  6/Jun/24 5:59 AM

  Added to sprint
  FIN-686 Download Mnookin two pager

  26

  33 → 34
  6/Jun/24 8:27 AM

  Estimate updated
  FIN-685 Read Chapter 4 - list likes and dislikes

  26

  34 → 33
  6/Jun/24 8:33 AM

  Issue completed
  FIN-685 Read Chapter 4 - list likes and dislikes

  26 → 27

  33
  6/Jun/24 8:43 AM

  Issue completed
  FIN-686 Download Mnookin two pager

  27 → 28

  33
TEXT

parsed_data = []
lines = data.strip.split("\n")

date = nil
event_type = nil
completed_work = nil
issue = nil
work_scope = nil
in_sprint_started = false

lines.each do |line|
  line.strip!
  next if line.empty?

  case line
  when %r{\d+/\w+/\d+ \d+:\d+ (AM|PM)}
    date = line
    in_sprint_started = false
  when /Sprint started/
    event_type = line
    in_sprint_started = true
  when /Issue completed|Estimate updated|Added to sprint|Removed from sprint/
    event_type = line
  # elsif line.match(/^FIN-/)
  #   puts "Issue: #{line}"
  #   issue = line
  when /\d+ → \d+/
    completed_work = line
  when /\d+/
    work_scope = line
  else
    issue = line
    parsed_data << [date, event_type, issue, completed_work, work_scope]
    completed_work = nil
    work_scope = nil
  end

  parsed_data << [date, event_type, line, nil, nil] if in_sprint_started && line.match(/^FIN-/)
end

CSV.open('jira_report.csv', 'w') do |csv|
  csv << ['Date', 'Event Type', 'Issue', 'Completed Work', 'Work Scope']
  parsed_data.each do |row|
    csv << row
  end
end

puts 'CSV file created successfully!'
