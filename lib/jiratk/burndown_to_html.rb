# frozen_string_literal: true

# This is straight from gpt-4o, dno't know if it
# works, saving it for later.

require 'csv'

# Read the CSV file
csv_file = 'jira_report.csv'
table_data = CSV.read(csv_file, headers: true)

# Generate the HTML content
html_content = <<~HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Jira Burndown Report</title>
      <style>
          table {
              width: 100%;
              border-collapse: collapse;
          }
          th, td {
              border: 1px solid black;
              padding: 8px;
              text-align: left;
          }
          th {
              background-color: #f2f2f2;
          }
      </style>
  </head>
  <body>
      <h1>Jira Burndown Report</h1>
      <table>
          <thead>
              <tr>
HTML

# Add table headers
table_data.headers.each do |header|
  html_content += "                <th>#{header}</th>\n"
end

html_content += <<-HTML
            </tr>
        </thead>
        <tbody>
HTML

# Add table rows
table_data.each do |row|
  html_content += "            <tr>\n"
  row.each do |value|
    html_content += "                <td>#{value}</td>\n"
  end
  html_content += "            </tr>\n"
end

html_content += <<~HTML
          </tbody>
      </table>
  </body>
  </html>
HTML

# Write the HTML content to a file
File.write('index.html', html_content)

puts 'HTML file created successfully!'
