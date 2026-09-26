# JiraTK

A Jira toolkit and specialist API wrapper for managing Jira issues: creating, querying, and syncing with spreadsheets and AWS.

## Features

- **Jira API**: Create and fetch issues via REST; OAuth support (`oautherizer`, `api_helper`).
- **Burndown**: Export burndown data to CSV and HTML (`burndown_to_csv`, `burndown_to_html`).
- **Templates**: Clone issues from templates and provision templates (`template_cloner`, `provision_templates`, `copy_from_template`).
- **Spreadsheets**: Copy to/from Google Sheets (`copy_to_new_spreadsheet`).
- **AWS**: S3 utilities and Athena tools (`s3_tools`, `athena_tools`); provisioning scripts (`provision_s3`, `athena`).

## Requirements

- Ruby >= 4.0

## Installation

```bash
bundle install
```

Or install the gem:

```bash
gem install jiratk
```

## Executables

From the project root (or via `bundle exec`):

| Command | Purpose |
|--------|---------|
| `athena` | AWS Athena integration |
| `copy_from_template` | Copy issues from a template |
| `copy_to_new_spreadsheet` | Copy data to a new Google Sheet |
| `gem_update` | Update gem dependencies |
| `jira_ticket` | Read tickets, create Tasks, and safely append description sections |
| `provision_s3` | Provision S3 resources |
| `marisu_jira` | PAH-only Jira reads for Marisu agent |
| `provision_templates` | Provision Jira templates |

### Ticket descriptions

Use the existing administrator environment configuration. Run from the
repository root; the command loads only its Jira dependencies.

```sh
bundle exec exe/jira_ticket get GEN-123
bundle exec exe/jira_ticket append-description GEN-123 --heading "Testing" --file section.txt
bundle exec exe/jira_ticket append-description GEN-123 --heading "Testing" --file section.txt --apply
```

The UTF-8 file contains plain text with blank lines between paragraphs.
Appending previews the resulting description by default. `--apply` rereads
the ticket to detect intervening edits, updates only its description, and
verifies the saved result. Existing rich-text nodes are preserved. An exact
existing section is a no-op; duplicate headings or different section content
stop the operation. Errors return exit status 1 without raw HTTP diagnostics.

Jira's [edit issue API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-put)
does not provide a transaction spanning these reads and the write. A concurrent
edit can still occur after the last check. After an uncertain write, inspect
the ticket before rerunning; the command does not automatically retry writes.

The PAH-only `marisu_jira` command retains its project restriction.

### Create a Task

```sh
bundle exec exe/jira_ticket create-task GEN --summary "Improve ticket tooling" --label jiratk-ticket-tooling --file task.txt
bundle exec exe/jira_ticket create-task GEN --summary "Improve ticket tooling" --label jiratk-ticket-tooling --file task.txt --apply
```

Creation uses the existing `JiraTicket` payload builder and POST helper.
It previews by default, creates only a standard Task, and reads it back to
verify its project, type, summary, label and description. Choose a unique
label for the work: a matching existing Task is a no-op; conflicting results
or an incomplete label search stop creation.

The label check is not a transaction or uniqueness constraint. Jira search
can lag behind recent writes, and concurrent creators can race. After an
uncertain POST, inspect Jira before retrying; do not treat an empty search
as proof that creation failed. No writes are automatically retried.

## Development

- Tests: `rspec`
- Linting: `rubocop`
- Runbook automation is used for some workflows (`Runbookfile`)

`bundle exec rspec` starts [SimpleCov](https://github.com/simplecov-ruby/simplecov/tree/v0.22.0)
before loading application code and writes an ignored report to
`coverage/index.html`. It tracks all library files, including files not loaded
by tests. Each file under `lib/jiratk/tickets/` and `lib/jiratk/permissions/`
must have 100% line and branch coverage in the current run. Legacy coverage
remains visible without making its existing gaps a gate for new work. The
existing pending examples remain reported by RSpec.

## License

See [LICENSE](LICENSE) for license terms.
