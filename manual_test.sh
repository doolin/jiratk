# Temporary script for manual testing.
# Uncomment each of the following to manually test.

# Check whether files are updated on S3, then
# check the various method results from Project
# which need to be done by uncommenting.
# ./exe/provision_s3.rb

# Make a copy of the software_estimation_template and
# rename it in the same folder:
# ./exe/copy_from_template.rb

# This one doesn't really work, skip it for now.
# ./exe/copy_to_new_spreadsheet.rb

# Test ticket creation
# https://doolin.atlassian.net/secure/RapidBoard.jspa?projectKey=SCRUM&rapidView=1&view=planning.nodetail
# ./exe/gem_update.rb

# This is a big one, copies templates and renames them.
# $ ./exe/provision_templates.rb
#
# The results should look like this:
# RESPONSE: 201
# RESPONSE BODY: {"id":"10373","key":"SCRUM-82","self":"https://doolin.atlassian.net/rest/api/2/issue/10373"}
# https://docs.google.com/spreadsheets/d/1ZfXxxvJot4adkUEG5Jfzvr9usVE2Kny1DuA9Mt_kOFc/edit#gid=0
# RESPONSE: 201
# RESPONSE BODY: {"id":"10374","key":"SCRUM-83","self":"https://doolin.atlassian.net/rest/api/2/issue/10374"}
# https://docs.google.com/spreadsheets/d/1yBmlm9TLkt-N8ggmKAV6kYEop-ue4M-rRRyGtgTRE5Y/edit#gid=0
# RESPONSE: 201
# RESPONSE BODY: {"id":"10375","key":"SCRUM-84","self":"https://doolin.atlassian.net/rest/api/2/issue/10375"}
# https://docs.google.com/spreadsheets/d/1otJV3xBSk0w6NGGCVL3ufrjsvVbBrxathKKBy-BHcJo/edit#gid=0
#
# Cleaning up:
# 1. remove the tickets from the SCRUM board: https://doolin.atlassian.net/secure/RapidBoard.jspa?rapidView=1&projectKey=SCRUM&view=planning.nodetail&issueLimit=100
# 2. remove the files from drive: https://drive.google.com/drive/u/2/recent
