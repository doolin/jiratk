# AGENTS.md - JiraTK

Specialist Ruby gem for managing Jira issues via the Jira Cloud REST API.
Also integrates with AWS S3/Athena and Google Drive for issue storage,
querying, and template provisioning.

## Quick reference

- Ruby 4.0.1 (required >= 4.0)
- Bundler 4.0.3
- Test: `bundle exec rspec` (20 examples, 10 pending, 0 failures)
- Lint: `bundle exec rubocop --parallel` (1 pre-existing offense in `exe/provision_templates.rb`)
- Default rake task runs rspec: `bundle exec rake`

## Setup

```sh
bundle install
```

Environment variables needed for live API calls (not needed for tests):
- `DOOLIN_JIRA_ID` - Jira account email
- `DOOLIN_JIRA_API` - Jira API token
- `AWS_REGION` - AWS region (defaults to `us-west-1` in S3Tools)

## Project structure

```
lib/jiratk.rb              Entry point (requires 4 of 15 lib files)
lib/jiratk/
  api_helper.rb             REST client wrapper (GET/POST with basic auth)
  account_manager.rb        Jira credentials from env vars, project listing
  project.rb                Batch download/search issues (paginated, 50/page)
  jira_ticket.rb            Abstract base for ticket JSON payloads
  assessment_ticket.rb      Concrete subclass of JiraTicket
  issue.rb                  Near-duplicate of JiraTicket (legacy)
  s3_tools.rb               AWS S3 read/write wrapper
  athena_tools.rb           AWS Athena query execution
  template_cloner.rb        Google Drive template cloning
  oautherizer.rb            Google OAuth2 flow
  csv_writer.rb             Stub class (not implemented)
  burndown_to_csv.rb        Script: parses hardcoded burndown data to CSV
  burndown_to_html.rb       Script: converts CSV to HTML table
  version.rb                VERSION = '0.1.0'

exe/                        CLI scripts (athena, s3 provisioning, templates, gem updates)
bin/console                 IRB session with gem loaded
bin/setup                   Runs bundle install
spec/                       RSpec tests with VCR cassettes for HTTP recording
runbooks/                   Runbook definitions (used by exe/gem_update.rb)
```

## Architecture

All Jira API calls go through `ApiHelper` using `rest-client` with basic auth.
The base URL is `https://doolin.atlassian.net/rest/api/3/`.

`Project` handles bulk operations (issue listing, batch download).
`AccountManager` manages credentials and project discovery.
Ticket creation uses `JiraTicket` subclasses that build JSON payloads via `to_h`.

AWS and Google integrations are standalone wrappers with no shared base class.

## Testing patterns

- RSpec with `expect` syntax (monkey patching disabled)
- VCR + WebMock for HTTP recording/stubbing
- Cassettes stored in `spec/cassettes/`
- `spec_helper.rb` defines `remove_secrets` to redact auth headers from VCR recordings
- Tests requiring AWS credentials are skipped with `skip: 'requires AWS credentials'`
- Specs use `OpenStruct` for lightweight param objects
- Pending tests are declared as `it 'description'` with no block

## Conventions

- All files use `# frozen_string_literal: true`
- Commit messages: `GEN-<number> <description>` (enforced by PR title linter)
- RuboCop with `rubocop-rspec` plugin; config in `.rubocop.yml`
- `Metrics/MethodLength` counts hashes as one line
- `Naming/VariableNumber` symbol checking disabled (Jira field names like `customfield_10029`)

## CI/CD

- **Semaphore CI**: rspec, rubocop, flay (flay currently disabled)
- **GitHub Actions**: PR title linter requiring `GEN-\d+` prefix

## Known issues and technical debt

- `Issue` and `JiraTicket` are near-identical classes; only `JiraTicket` is subclassed
- `CsvWriter` is a stub with no implementation
- `burndown_to_csv.rb` and `burndown_to_html.rb` are procedural scripts, not classes
- `lib/jiratk.rb` only requires 4 of 15 lib files; others loaded ad hoc
- `google-api-client` gem is deprecated; migration to per-service gems pending
- `S3Tools` hardcodes AWS profile name `david_doolin`
- 10 pending specs need implementation
- Flay is disabled in CI ("flay isn't working")
- `exe/copy_to_new_spreadsheet.rb` is noted as not fully working

## Making changes

Run tests and lint after any change:
```sh
bundle exec rspec && bundle exec rubocop --parallel
```

When adding new lib files, decide whether they should be required in `lib/jiratk.rb`
or loaded on demand. Currently only `account_manager`, `api_helper`, `s3_tools`,
and `project` are auto-required.

New specs go in `spec/lib/jiratk/` mirroring the lib path. Use VCR cassettes
for any HTTP interactions and call `remove_secrets` in an `after` block when
recording new cassettes.
