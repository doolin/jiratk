# JiraTK

A Jira toolkit and specialist API wrapper for managing Jira issues: creating, querying, and syncing with spreadsheets and AWS.

## Features

- **Jira API**: Create and fetch issues via REST; OAuth support (`oautherizer`, `api_helper`).
- **Burndown**: Export burndown data to CSV and HTML (`burndown_to_csv`, `burndown_to_html`).
- **Templates**: Clone issues from templates and provision templates (`template_cloner`, `provision_templates`, `copy_from_template`).
- **Spreadsheets**: Copy to/from Google Sheets (`copy_to_new_spreadsheet`).
- **AWS**: S3 utilities and Athena tools (`s3_tools`, `athena_tools`); provisioning scripts (`provision_s3`, `athena`).

## Requirements

- Ruby >= 3.2

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
| `provision_s3` | Provision S3 resources |
| `provision_templates` | Provision Jira templates |

## Development

- Tests: `rspec`
- Linting: `rubocop`
- Runbook automation is used for some workflows (`Runbookfile`)

## License

See [LICENSE](LICENSE) for license terms.
