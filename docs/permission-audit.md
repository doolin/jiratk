# Auditing service-account permissions

[GEN-734](https://doolin.atlassian.net/browse/GEN-734) adds a read-only library
audit to the [discovery API](permission-discovery.md). It verifies the
service-account identity, checks six permissions across the administrator's
project inventory, and compares PAH's positive control with the other
projects' negative controls.

## Library interface

Load the focused API without optional AWS or Google dependencies:

```ruby
require 'jiratk/permissions'

administrator = JiraTk::Permissions::Client.new(
  connection: JiraTk::Permissions::Connection.administrator
)
service = JiraTk::Permissions::Client.new(
  connection: JiraTk::Permissions::Connection.service_account(
    base_url: private_service_endpoint,
    token: private_service_token
  )
)
auditor = JiraTk::Permissions::Auditor.new(
  administrator: administrator,
  audit_client: service,
  expected_account_id: expected_service_account_id
)

report = auditor.audit
puts report.matrix
puts JSON.pretty_generate(report.to_h)
report.exit_status
```

Reports stay in memory until the caller writes them. This example prints
text and JSON to standard output; the library creates no audit-results file.

The administrator factory uses existing private runtime configuration.
The service endpoint, token, and expected immutable account ID come from
separate caller-supplied configuration. Keep credentials out of command
arguments, documentation, logs, and test recordings. The service client
never falls back to administrator credentials.

Each audit verifies the expected active service account, a distinct
administrator account, and matching site fingerprints before collecting
results. Administrator discovery requires the global Administer Jira
permission and complete pagination across live, archived, and deleted
projects. Identity, configuration, and inventory failures raise
`JiraTk::Permissions::Error`; they do not produce a passing report.

`service.my_permissions('PAH')` is also available as a low-level read. It
returns the six permission keys mapped to `value` and `error` fields.
Use `Auditor` for identity verification, inventory coverage, and comparison.

## Scope and controls

The default required controls are ADMIN, BST, DS, FIN, GEN, PAH, PLANT,
SCRUM, and TASKLETS. Discovery adds every other project; the required list
does not restrict discovery. Rows are sorted by project key. PAH must have
all six permissions, and every other audited project must have all six
denied. Missing required projects remain visible.

For an investigation, select projects explicitly:

```ruby
partial = auditor.audit(projects: %w[PAH GEN])
```

A subset always reports `incomplete`, even if every selected control
matches. The full inventory still appears, with unselected live projects
marked `not_selected`. This also applies when an explicit selection happens
to contain every discovered project.

For another deployment, callers can set `positive:` and
`required_projects:`. The positive project is always required, including
when omitted from the required list. These parameters change the control
definition; keep them consistent when comparing audit evidence.

| Project coverage | Treatment |
| --- | --- |
| `audited` | Live classic project; query all six permissions |
| `missing` | Required or requested key absent from discovery; unknown |
| `archived` / `deleted` | Explicit inventory state; unknown |
| `unsupported` | Live project with another style; unknown |
| `not_selected` | Supported live project outside an explicit subset; unknown |

Every coverage state other than `audited` prevents a complete result.
Projects absent from the required baseline have `new_project: true`.
Changed, missing, or unsupported projects require review; the auditor never
silently treats them as denied.

## Results and evidence

The matrix has a fixed column order:

```text
PROJECT  BROWSE  CREATE  EDIT  TRANSITION  COMMENT  ASSIGN
```

These map to `BROWSE_PROJECTS`, `CREATE_ISSUES`, `EDIT_ISSUES`,
`TRANSITION_ISSUES`, `ADD_COMMENTS`, and `ASSIGN_ISSUES`. Cells display
`true`, `false`, or `unknown`; the footer states the result and scope mode.

Only explicit Boolean `havePermission` values with matching permission
keys count as results. An invalid individual entry becomes unknown while
valid entries remain available. HTTP errors, transport failures, invalid
JSON, or a malformed whole response make that project's six cells unknown.
A 401, 403, or 404 is never interpreted as six denials.

| Status | Exit status | Meaning |
| --- | --- | --- |
| `passed` | 0 | Full inventory, all cells known, all controls match |
| `mismatch` | 1 | Complete audit with one or more failed controls |
| `incomplete` | 2 | Subset, coverage gap, or unknown cell, even if other controls fail |

`report.to_h` returns an independent, JSON-ready evidence snapshot:

- `identity`: verified account ID, active flag, and canonical site fingerprint.
- `timestamp`: UTC audit completion time.
- `permissions`: the six requested API keys in matrix order.
- `scope`: all/subset mode, requested and required keys, and positive project.
- `projects`: IDs, keys, project states, styles, coverage, new-project flags,
  expected values, and six `value`/`error` cells per row.
- `comparison`: status, mismatches with expected/actual values, unknown cells
  with error categories, and project coverage gaps.

Known mismatches remain in incomplete reports. Error categories are
`invalid_permission`, `request_failed`, or the project's coverage state.
Raw response bodies, headers, tokens, configured URLs, and unrelated API
metadata are excluded. Mutating returned data cannot alter the report.

## Limits and verification

Jira's [project-context permission checks](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-permissions/#api-rest-api-3-mypermissions-get)
can reflect permissions applicable to some issues. A passing matrix checks
the specified six controls; it does not prove that every issue operation
will succeed. Workflow and issue-security behavior require separate checks.

The audit spans multiple requests and is not a transactional snapshot.
Jira can change during collection. Evidence describes the observed results;
later mutation operations must rediscover and revalidate their preconditions.
This subtask provides no permission mutation methods or permission executable.
It does not modify issues to probe access.

Run `bundle exec rspec` and `bundle exec rubocop`. The tests exercise the real
library and HTTP boundaries with synthetic data, including the GEN assignment
leak, PAH comment regression, full and partial inventories, error states, and
report isolation. Every permission library file requires 100% line and branch
coverage. New code has no additional RuboCop exclusions.
