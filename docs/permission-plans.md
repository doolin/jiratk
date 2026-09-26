# Reviewable permission repair plans

[GEN-735](https://doolin.atlassian.net/browse/GEN-735) adds read-only planning
for the initial GEN/PAH `ASSIGN_ISSUES` repair from the
[permission-management PRD](prds/jira-permission-scheme-management.md).
It produces data for review and can compare a saved plan against fresh
discovery. No permission-writing methods or apply path are exposed.

## Prepare and review

Using the separately configured administrator and service clients from
[permission auditing](permission-audit.md):

```ruby
require 'jiratk/permissions'

planner = JiraTk::Permissions::Planner.new(
  administrator: administrator,
  audit_client: service
)
plan = planner.pah_assign_repair(
  account_id: expected_service_account_id,
  service_group_id: verified_service_group_id,
  broad_holder_id: verified_application_role_identity
)

puts plan.dump
```

All three arguments are required. The application-role identity must come
from inspection of the normalized grant: `nil`, an empty string, and a
named role are distinct expectations. The planner never infers “Any logged
in user” from the holder type alone.

This first operation has fixed expectations for scheme `10003`, its name,
Ticket Manager role `10076`, the named human replacement group, broad grant
`10592`, and protected addon grant `10532`. These expectations are checked
against fresh reads. The service-group ID is caller-supplied and must resolve
to `pah-ticket-managers`; the account must be its active member and must not
belong to `jira-project-users`.

The default shared-project expectation is GEN and PAH. If discovery finds
another project using the scheme, planning stops. After reviewing that
association, explicitly include it in `projects:`; GEN and PAH must remain
present. The planner checks every declared shared project's role actors and
relevant group members. The target must have the intended service-group role
path in PAH and no direct or group Ticket Manager path in shared negative
projects. Account and group membership endpoints must agree.

## Preconditions and steps

Planning verifies the expected active account and site through the existing
audit API, followed by complete administrator inventory and membership reads.
All baseline projects and any newly discovered projects must have complete,
known six-permission results. This initial planner conservatively rejects
archived, deleted, unsupported, missing, or otherwise incomplete coverage.
Audit and scheme-discovery inventories must agree on project IDs and keys.

PAH must already have all six permissions. GEN must have its other five
permissions denied. Ticket Manager must explicitly hold the other five PAH
permissions in the shared scheme; a missing `ADD_COMMENTS` role grant stops
the ASSIGN-only plan even if broad access currently makes PAH's audit pass.
Missing or ambiguous grant evidence, unexpected identities, and duplicate
replacement candidates also stop planning.

The generated steps are ordered:

1. Verify the captured preconditions before additions.
2. Add Ticket Manager's ASSIGN grant, or verify the existing exact grant as a no-op.
3. Add the human group's ASSIGN grant, or verify its existing exact grant as a no-op.
4. Verify both replacements.
5. Verify the before-deletion permission controls.
6. Recheck preconditions immediately before deletion.
7. Delete only the captured broad grant, or verify its already-absent state.
8. Verify projected grants, preserving all protected and unrelated grants.
9. Verify the after-deletion permission controls.

Create payloads use immutable IDs in `holder.value` alone. Deletion includes
the expected scheme, grant ID, permission, holder type, and holder identity.
The intermediate grant projection retains the broad grant until removal.
New grant IDs are `null` in projections because only a future write and
readback can establish them.

An absent broad grant is a no-op only when a complete scheme read proves
absence, both replacements already exist, and final controls already match.
An equivalent broad grant with a different ID is an identity mismatch, not
permission to retarget the deletion.

Before deletion, controls preserve all observed results. After deletion,
PAH stays all true and each shared negative project's ASSIGN must be false;
other results retain their observed values. This requires GEN all false.
Existing access in unrelated projects remains visible. A successful repair
does not establish full PAH isolation.

## Serialization and revalidation

`plan.to_h` returns independent structured data; `plan.dump` returns JSON.
The caller chooses where to save that JSON. The versioned document includes:

- Fixed operation expectations and explicitly reviewed shared-project scope.
- Capture and creation timestamps, account identity, and site fingerprint.
- Complete project inventory and scheme associations.
- Normalized scheme grants, roles, role actors, relevant group populations,
  account-group membership, and the pre-change permission matrix.
- Ordered steps, protected grants, intermediate and final grant projections,
  and operation-specific controls.
- A SHA-256 digest of canonical content, excluding the digest field itself.

Only allowlisted evidence is serialized. Credentials, configured endpoints,
headers, raw responses, and connection objects are excluded. Grant and
membership ordering from Jira does not alter canonical evidence ordering.

```ruby
reviewed = JiraTk::Permissions::Plan.load(saved_json)
planner.revalidate(reviewed)
```

Loading reconstructs the request, validates evidence and repair policy, and
derives the steps and projections again. It rejects unsupported versions,
unknown or duplicate fields, malformed evidence, altered steps, and a differing digest.
A recomputed digest cannot legitimize inconsistent steps or protected-grant
substitutions. The digest is an integrity check, not a signature or operator
authorization; loading a file does not establish current Jira state.

Revalidation captures fresh evidence using the saved scope, then compares
every recorded precondition except the audit capture timestamp. It returns
the original plan on success and raises `JiraTk::Permissions::Error` on drift.
It never expands the reviewed scope or substitutes a newly generated plan.
Membership changes, unrelated grants in the affected scheme, changed controls,
identity changes, and project association changes invalidate the old plan.

All reads span multiple requests; Jira can change between them. Revalidation
narrows that uncertainty but supplies no lock or transaction. Execution must
recheck at each write boundary. Partial-write reconciliation, resumption,
bounded verification retries, the apply gate, and general isolation planning
remain later work. The Markdown audit-persistence requirement is queued for
the CLI/integration child.

## Verification

Run `bundle exec rspec`, `bundle exec rubocop`, and the dependency audit.
Tests use real library components and synthetic HTTP responses, exercise
the known control regressions and drift cases, and assert that planning and
revalidation send no POST, PUT, or DELETE requests. Every new permission
library file requires 100% line and branch coverage, with no new lint exclusions.
