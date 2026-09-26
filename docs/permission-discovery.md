# Read-only permission discovery

GEN-732 provides the foundation for the
[permission management PRD](prds/jira-permission-scheme-management.md).
It exposes reads only. Auditing the six-permission matrix, constructing
mutation plans, and applying grants belong to subsequent subtasks.

Load this API independently of optional AWS and Google dependencies:

```ruby
require 'jiratk/permissions'

admin = JiraTk::Permissions::Client.new(
  connection: JiraTk::Permissions::Connection.administrator
)
scheme = admin.project_scheme('PAH')
scheme.id
scheme.grants
scheme.find(permission: 'ASSIGN_ISSUES', holder_type: 'projectRole', holder_id: '10076')
```

The administrator factory uses JiraTK's existing private runtime
configuration. It rejects missing or blank configuration. Supply service
account credentials separately from private configuration; never place
them in command arguments, documents, logs, or recorded test cassettes.

```ruby
audit = JiraTk::Permissions::Client.new(
  connection: JiraTk::Permissions::Connection.service_account(
    base_url: private_service_endpoint,
    token: private_service_token
  )
)
admin.verify_audit_identity(
  audit_client: audit,
  expected_account_id: expected_service_account_id
)
```

Both direct HTTPS site origins and Atlassian's HTTPS cloud gateway are
supported. Redirects are disabled and requests have bounded timeouts.
The service factory never falls back to administrator authentication.
`identity` reads the authenticated account and server metadata. Its output
contains only the account ID, active flag, and a SHA-256 fingerprint of the
canonical site origin. Verification requires the expected active service
account, a different administrator account, and matching site fingerprints.
It does not establish authorization for a future mutation.

## Discovery API

| Method | Result |
| --- | --- |
| `client.projects` | Administrator inventory across live, archived, and deleted projects |
| `client.inventory` | Inventory with scheme associations and explicit coverage per project |
| `client.project_scheme(key)` | `Scheme` with string `id`, `name`, and fresh `grants` reads |
| `scheme.find(permission:, holder_type:, holder_id:)` | All exact matches, retaining duplicate grants with different IDs |
| `client.grants(scheme_id)` | Normalized scheme grants |
| `client.grant(scheme_id, grant_id)` | One grant, with its identity verified |
| `client.group(id:)` / `client.group(name:)` | Immutable group ID and current name |
| `client.group_members(group_id)` | Every member's account ID and active flag, including inactive accounts |
| `client.account_groups(account_id)` | Group IDs and names from the complete array endpoint |
| `client.role(role_id)` | Verified role ID and name |
| `client.role_actors(project_key, role_id)` | Role with direct user and group actors |

Project discovery first checks the global Administer Jira permission.
It reads all status inventories and rejects duplicate project IDs or keys.
Inventory resolves schemes for classic projects, including archived
projects, and groups their keys by scheme ID. Deleted projects and other
project styles remain visible with `coverage: unsupported` and a null
scheme ID. Consumers must reconcile these entries before claiming complete
isolation; absence of a scheme is not evidence of denied access.

Paginated endpoints require integer offsets, page limits and totals, an
explicit last-page flag, forward progress, and a stable total. Changed or
incomplete pagination fails. Server-provided next-page URLs are ignored;
requests use the configured endpoint and calculated offsets. Discovery is
not a transactional snapshot: Jira can change between reads even when
counts remain stable. Later apply operations must rediscover preconditions.

Grant IDs and numeric role/scheme IDs are normalized to strings. Group
holders resolve to immutable IDs; a name alone is resolved, and a name/ID
conflict fails. Project-role `parameter` and `value` must agree. Protected
addon roles are marked by their known ID or resolved name. A scheme ID
matching a role ID does not make the scheme itself a protected role.

Application-role identities retain absent, empty, and named values
distinctly. No blanket classification as “Any logged in user” is made.
Other holder types remain visible with `supported: false` for explicit
review. A supported holder representation is not permission to delete it.
Unknown role actor types, name-only actors without immutable IDs, malformed
payloads, mismatched identities, and unsuccessful HTTP responses raise
`JiraTk::Permissions::Error`. Errors omit credentials and response bodies;
transport and JSON exceptions do not retain their original exception cause.

## Validation

Run `bundle exec rspec` and `bundle exec rubocop`. Tests use synthetic
configuration and HTTP stubs with the real client and transport. No live
administrator recordings or permission mutations are involved. SimpleCov
requires full line and branch coverage for each new permission library
file. New code must pass RuboCop without additional exclusions; the existing
`.rubocop_todo.yml` tracks previously deferred work.

Endpoint contracts follow Atlassian's documentation for
[permission schemes](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-permission-schemes/),
[project scheme assignments](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-permission-schemes/),
[projects](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/),
[groups](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-groups/),
[users](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/),
[project roles](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-roles/),
and [server metadata](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-server-info/).
