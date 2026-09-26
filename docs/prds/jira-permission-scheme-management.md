# PRD: Safe Jira permission-scheme management and PAH isolation

| Field | Value |
| --- | --- |
| Status | Draft for review; implementation and permission changes pending |
| Documentation ticket | [GEN-730](https://doolin.atlassian.net/browse/GEN-730) |
| Owner | Ron — Security and Compliance |
| Repository | JiraTK |
| Location | `docs/prds/jira-permission-scheme-management.md` |
| Prepared | 2026-09-25 |
| Inspected baseline | `master` at `6472b32b`, including the COMMONS merge |

## 1. Purpose and decision requested

Extend JiraTK with reusable Ruby code for inspecting Jira permission schemes,
auditing effective permissions, and replacing broad grants through a reviewed,
verifiable sequence. The first operational use is to restrict the
`production-at-home` service account to ticket management in PAH.

This ticket delivers the PRD. Implementing the library, executing the initial
repair, and completing isolation are subsequent work. Reviewing this document
does not authorize permission mutations. Tests must pass and the operator must
see the concrete mutation plan before any live permission changes proceed.

## 2. Problem and motivation

The service account currently has ticket-management permissions outside PAH.
Restricting a CLI's accepted issue keys or JQL protects that interface, but does
not restrict what its underlying Jira credentials can access through another
client. Jira permissions must enforce the intended boundary.

Manual scripts established the API mechanics, but safely repeating the work
requires more than a successful POST or DELETE. PAH and GEN share a permission
scheme. Removing an application-wide grant without first establishing the PAH
role grant can revoke PAH access. This already happened with `ADD_COMMENTS`.

The product must make the intended changes reviewable, preserve replacement
access, reject unexpected live state, and report what the service account can
actually do after each stage.

## 3. Users and outcomes

- **Operator / Jira administrator:** inspect grants and affected projects;
  review exact additions and deletions; apply only a verified plan.
- **Ron:** maintain the reusable controls and evidence of their operation.
- **Production-at-home service account:** retain the six required permissions
  in PAH and have none of those permissions in other projects.
- **Human Jira users:** receive the explicitly intended replacement grants
  through `jira-project-users`.
- **Jira applications:** retain all `atlassian-addons-project-access` grants.

Success means the requested matrix is observed using the verified service
account identity over a complete, explicitly reported project inventory. A
completed API request or a correctly shaped grant alone is insufficient.

## 4. Operator-supplied baseline

The following is supplied context, not a fresh live audit. Every identifier and
grant used for a mutation must be revalidated when a plan is generated and
again when it is applied.

### 4.1 Entities

| Entity | Name | Identifier |
| --- | --- | --- |
| Service account | `production-at-home` | Immutable account ID to confirm |
| Service-account group | `pah-ticket-managers` | Immutable group ID to resolve |
| Project role | `Ticket Manager` | `10076` |
| Human-user group | `jira-project-users` | `fc8e7ac7-be76-4f1b-b481-6221f06b20a8` |
| Shared permission scheme | `GEN software permission scheme` | `10003` |
| Known associated projects | PAH and GEN | Resolve project IDs during discovery |
| Protected application role | `atlassian-addons-project-access` | Project-role ID `10003` |

The permission-scheme ID and protected project-role ID both happen to be
`10003`. They belong to different entity types and must never be conflated.
Discovery must check for additional projects sharing the scheme.

### 4.2 Permissions and display labels

| API permission | Matrix column |
| --- | --- |
| `BROWSE_PROJECTS` | BROWSE |
| `CREATE_ISSUES` | CREATE |
| `EDIT_ISSUES` | EDIT |
| `TRANSITION_ISSUES` | TRANSITION |
| `ADD_COMMENTS` | COMMENT |
| `ASSIGN_ISSUES` | ASSIGN |

All commands and reports use this fixed order.

### 4.3 Reported current matrix

| PROJECT | BROWSE | CREATE | EDIT | TRANSITION | COMMENT | ASSIGN |
| --- | --- | --- | --- | --- | --- | --- |
| ADMIN | true | true | true | true | true | true |
| BST | false | false | false | false | false | false |
| DS | false | false | false | false | false | false |
| FIN | false | false | false | false | false | false |
| GEN | false | false | false | false | false | true |
| PAH | true | true | true | true | true | true |
| PLANT | true | true | true | true | true | true |
| SCRUM | true | true | true | true | true | true |
| TASKLETS | true | true | true | true | true | true |

The final expectation is PAH all true and every other project all false.
The nine listed projects are mandatory initial controls, not a permanent
assumption that no other projects exist.

### 4.4 Known ASSIGN_ISSUES grants in scheme 10003

| Grant ID | Holder | Treatment |
| --- | --- | --- |
| `10532` | Project role `10003`, `atlassian-addons-project-access` | Always preserve |
| `10592` | `applicationRole`, reported as Any logged in user | Candidate removal after verification |
| Absent | Project role `10076`, Ticket Manager | Add before removing `10592` |

The presence of a human-group ASSIGN grant is not established by this snapshot.
Ensure it exists; do not blindly create another copy.

## 5. Scope

### 5.1 Included

1. Resolve a project's permission scheme and enumerate affected projects.
2. List grants and find them by permission, holder type, and holder identity.
3. Ensure group grants by immutable group ID and project-role grants by role ID.
4. Delete an individual grant by ID with explicit expected-state checks.
5. Audit the six permissions for a specified project set and render its matrix.
6. Generate a reviewable plan, default to dry-run, and require explicit apply.
7. Reconcile repeat runs without duplicate grants or unverified deletions.
8. Enforce add, verify, then delete ordering for broad-grant replacement.
9. Protect application grants and verify both positive and negative controls.
10. Produce credential-free plan and execution evidence, including failures.

### 5.2 Excluded from the first implementation

- Replacing an entire scheme's permission list, cloning schemes, or changing
  project-to-scheme assignments.
- Creating accounts, groups, roles, or changing their memberships automatically.
- Changing global permissions, application access, workflow restrictions,
  issue-security schemes, or team-managed project access settings.
- Refactoring the PAH issue commands or migrating `marisu_jira` credentials.
- Building a generic Jira administration framework or a web interface.
- Creating or modifying real issues as part of the permission audit.
- Claiming that the six checks establish isolation for every Jira capability.

If discovery reveals an access path requiring an excluded operation, report it
as unresolved and stop the affected mutation. It requires a separately reviewed
change; the tool must not widen its own scope.

## 6. Existing architecture and smallest proposed design

The inspected implementation has these relevant properties:

- `ApiHelper` wraps `rest-client`, supports GET and POST, and returns HTTP 4xx
  responses without raising. POST debug output defaults to printing the body.
- `AccountManager` reads existing administrator configuration; its project URL
  is hardcoded and its project listing handles only the first response page.
- `JiraTk::Pah::Client` accepts an injected API helper, disables POST debugging,
  and validates PAH keys. It currently uses the administrator credential root.
- `exe/marisu_jira` is a thin executable with explicit library requires.
- Specs use RSpec, doubles, VCR, and WebMock. New permission tests should use
  synthetic fixtures and mocked HTTP rather than record live administrator data.

Use the existing namespace and dependency-injection pattern:

| Component | Responsibility |
| --- | --- |
| `JiraTk::Permissions::Client` | HTTP operations, response validation, configuration, and identity/project/role/group discovery |
| `JiraTk::Permissions::Scheme` | Grant normalization, lookup, replacement requirements, and protected-holder rules |
| `JiraTk::Permissions::Auditor` | Identity-checked permission queries, matrix rendering, and expected-result comparison |
| `JiraTk::Permissions::Plan` | Ordered operations, expected state, dry-run rendering, apply checks, and execution results |
| `JiraTk::Permissions::Error` | Sanitized domain errors |
| `exe/jira_permissions` | Thin CLI with standard-library argument parsing |

The read-only implementation is delivered incrementally: GEN-732 provides
[discovery](../permission-discovery.md), GEN-734 provides
[auditing](../permission-audit.md), and GEN-735 provides
[planning and saved-plan revalidation](../permission-plans.md) for the initial
GEN/PAH ASSIGN repair. Execution and the executable remain later deliveries;
the complete behavior specified below is still the target.

Provide `lib/jiratk/permissions.rb` as the focused require entry point. Put
implementation files under `lib/jiratk/permissions/` and specs under the
corresponding `spec/lib/jiratk/permissions/` directory. Keep CLI behavior
testable independently of process exit and real credentials.

Extend `ApiHelper` only as needed for DELETE and explicit authentication options.
Keep existing callers compatible. The permissions client must independently
enforce strict status handling and disable raw debug output on every request.
Extend `AccountManager` with opt-in configuration while preserving its existing
default interface. Do not reuse its incomplete project inventory for isolation.

Avoid a second HTTP stack, a new CLI framework, or additional runtime
dependencies unless implementation demonstrates a specific need.

## 7. Credentials, identity, and transport

### 7.1 Administrator connection

Use the existing administrator configuration supplied privately by the
operator. Keep credential-root names, environment-variable names, endpoint
configuration, and values out of this PRD and its tracking ticket.

Resolve configuration from the environment at runtime. Reject absent or blank
required values before making a request. Do not substitute the administrator
identity when service-account configuration is missing.

### 7.2 Service-account connection

Inject a separate audit client. Structural inspection of `jira-test.sh` shows
Bearer authentication through the Atlassian API gateway. This establishes a
different authentication shape from the administrator scripts; it does not
establish the token's current availability. Keep the concrete configuration
names in the operator's private setup.

Support the confirmed service-account authentication shape explicitly. The
private configuration and immutable expected account ID remain to be confirmed.
Do not guess Basic authentication or reuse administrator credentials merely
because the current PAH client does so.

Validate the audit identity using `GET /rest/api/3/myself` and compare its account
ID to the expected service account. Match the administrator and audit clients
to the same Jira site, allowing a validated gateway cloud path where needed.
Fail on identity/site mismatch or inability to authenticate. The official
[current-user API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-myself/#api-rest-api-3-myself-get)
provides the identity response.

### 7.3 Secret handling

- Never print or persist credential values, Authorization headers, cookies,
  encoded credentials, or raw credential-bearing request objects.
- CLI arguments identify configuration names, never token values.
- Validate HTTPS endpoints; reject URL userinfo and unexpected query/fragment
  components. Do not forward credentials across unapproved redirects.
- Suppress underlying exception text that could contain a URL, header, or body.
  Report the operation, safe entity identifiers, status, and error category.
- Keep environment values and connection objects out of plan serialization,
  object inspection output, test snapshots, VCR recordings, and execution logs.
- Inject synthetic credentials in tests. Test failures must not dump real
  process environment values.

## 8. API and grant contracts

Use individual grant endpoints, not whole-scheme updates. Atlassian documents
the [grant operations and holder representations](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-permission-schemes/)
and the [project's assigned scheme endpoint](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-permission-schemes/#api-rest-api-3-project-project-key-or-id-permissionscheme-get).

| Operation | Endpoint relative to the configured API base | Expected status |
| --- | --- | --- |
| Resolve project scheme | `GET /rest/api/3/project/{projectKeyOrId}/permissionscheme` | 200 |
| List scheme grants | `GET /rest/api/3/permissionscheme/{schemeId}/permission` | 200 |
| Read one grant | `GET /rest/api/3/permissionscheme/{schemeId}/permission/{grantId}` | 200 |
| Add one grant | `POST /rest/api/3/permissionscheme/{schemeId}/permission` | 201 |
| Delete one grant | `DELETE /rest/api/3/permissionscheme/{schemeId}/permission/{grantId}` | 204 |
| Audit permissions | `GET /rest/api/3/mypermissions` with project and six permission keys | 200 |

Supporting discovery uses the project, group, user-membership, and project-role
APIs. Read every page where an endpoint is paginated. Validate required fields
and types before using a response. Treat truncation, incomplete pagination, or
unresolved holder identities as incomplete evidence.

### 8.1 Create payloads

Group grant example using the operator-supplied immutable ID:

```json
{
  "permission": "ASSIGN_ISSUES",
  "holder": {
    "type": "group",
    "value": "fc8e7ac7-be76-4f1b-b481-6221f06b20a8"
  }
}
```

Project-role grant example:

```json
{
  "permission": "ASSIGN_ISSUES",
  "holder": {
    "type": "projectRole",
    "value": "10076"
  }
}
```

Construct these payloads from validated domain fields. Never copy a GET holder
object into a POST. The operator observed HTTP 400 when both `parameter` and
`value` were supplied. Creation must send only `value`; GET may contain both.

### 8.2 Normalization and matching

Normalize numeric IDs to strings. For groups, match immutable group IDs; a GET
`parameter` can be a mutable name and is not interchangeable with a group ID.
Resolve older name-only representations before matching, or fail closed. For
project roles, normalize the role ID from `value` or `parameter` and reject
conflicting IDs.

Identify a removal candidate by scheme ID, grant ID, permission, holder type,
and normalized holder identity. Do not classify every `applicationRole` as
Any logged in user: capture and verify the exact live representation. Unknown
or conflicting representations block mutation rather than broadening a match.

All deletion entry points reject the protected application project role by
resolved identity, including its known ID and name. Snapshot its grants and
verify they remain unchanged after applying a plan.

## 9. Functional and safety requirements

### FR-1: Complete discovery and scope

Use administrator credentials to enumerate projects; the target account's
project listing can omit the very projects that must be negative controls.
Include the nine supplied projects and reconcile them with the discovered
inventory. Report new, missing, archived, deleted, or unsupported projects
explicitly. A partial audit can be useful but must not be labeled full isolation.

Resolve scheme associations for every affected project and group changes by
scheme so shared schemes are processed once. Show the full affected project
set. Unexpected associations invalidate the plan before writes.

### FR-2: Membership preconditions

Before replacing grants in a PAH-shared scheme, verify:

- Role `10076` resolves to Ticket Manager.
- The human-group ID resolves to `jira-project-users`.
- The target belongs to the intended service-account group and is not a member
  of `jira-project-users`.
- PAH's Ticket Manager actors give the target the expected role through the
  intended group; check direct account actors and all relevant group actors.
- The target does not receive Ticket Manager through direct or group membership
  in GEN or another negative-control project sharing an affected scheme.

Record the intended human replacement population for operator review. A group
grant proves structural access for that group; it does not prove that every
formerly authenticated user belongs to it. Unresolved membership evidence
blocks affected changes. This tool does not repair memberships automatically.

### FR-3: Reviewable plans and dry-run defaults

Every mutation entry point defaults to dry-run. A dry-run may perform reads but
must not send a mutation. Both the library execution boundary and CLI require
explicit apply intent; a public low-level method must not bypass that gate.

A plan includes:

- Plan schema version, creation time, and a digest of its normalized content.
- Non-secret site identity, expected audit account ID, and operation scope.
- Project inventory, expected project-to-scheme associations, and holder IDs.
- Expected grants and relevant role/group memberships.
- Ordered additions, verification checkpoints, exact deletions, and no-ops.
- Protected grants, expected final controls, and the pre-change matrix.

Use an allowlist of fields for machine-readable output. Do not serialize raw
API responses or connection configuration. Plans may be saved for review and
later execution, but a saved plan is not proof that live state is unchanged.

`--apply` must operate on the reviewed plan and validate its schema and scope.
It must not silently regenerate an expanded plan and apply new deletions.

### FR-4: Apply preflight and ordered execution

1. Validate credentials, both identities, site, full inventory, expected
   schemes, groups, role actors, grants, and protected grants before any write.
2. Reconcile already-satisfied operations and reject unrelated drift.
3. Add all missing replacement grants required by the plan.
4. Read the scheme back and verify each exact replacement grant exists.
5. Verify PAH's positive control and unchanged negative-control expectations
   before starting removals. Unexpected new access blocks further changes.
6. Immediately before each deletion, recheck that the scheme association,
   target grant, relevant membership state, and replacements still match.
7. Delete only the specified grant; verify absence and protected-grant retention.
8. Rerun the matrix after each deletion and at completion. Stop on a regression
   or a failed operation-specific expectation.

Each checkpoint declares its intermediate expectations. Previously true cells
awaiting a later planned repair remain visible; they must not be mistaken for
new regressions or for a successful final isolation result. Compare each final
scheme state with the plan's projected grants, including preservation of all
unrelated grants.

The API offers no assumed transaction spanning these requests. Checks narrow
the race window but cannot eliminate concurrent administration. Report this
limitation, keep changes serial, and detect drift at each boundary.

### FR-5: Idempotency and partial execution

An exact existing replacement is a no-op. A duplicate or ambiguous holder
representation must not trigger another add. An already-absent deletion target
is a no-op only after a successful, complete read of the expected scheme proves
absence and replacement/protection checks pass. A bare 404 is not that proof.

Permit resumption when live state matches an expected completed prefix of the
reviewed plan. A timeout after POST or DELETE is an uncertain outcome: reread
and reconcile before retrying. Never blindly replay writes.

On failure, stop further mutations and report completed, pending, failed, and
uncertain steps. Preserve verified replacement grants. Do not automatically
restore broad access or remove replacements to simulate a rollback. Recovery
requires a fresh inspection and a reviewed forward plan.

### FR-6: Audits, errors, and exit status

Authenticate as the expected service account, then request all six permission
keys in each project's context. Only explicit Boolean `havePermission` values
count as results. Missing keys, malformed JSON, authentication failures,
transport errors, and HTTP errors are unknown/error states, never false.

Render the six-column matrix in a stable order. Support structured JSON with
the account ID, project coverage, requested permissions, results, comparison,
and timestamp. Keep errors distinguishable from legitimate denials.

Proposed process statuses:

| Code | Meaning |
| --- | --- |
| 0 | Requested operation completed; any specified expectations passed |
| 1 | Complete audit found a permission mismatch |
| 2 | Usage, configuration, identity, precondition, or incomplete-audit failure |
| 3 | Apply failed or stopped after writes began; inspect execution evidence |

Use a bounded verification retry policy for delayed visibility, with a timeout
and sanitized results. A replacement must become visible before deletion;
expiration of the verification window is failure, not assumed success.

## 10. First operation: GEN/PAH ASSIGN repair

Generate this candidate only from fresh discovery; the supplied IDs are
expectations, not unconditional instructions:

1. Verify PAH and GEN still use scheme `10003`, its name matches, and every
   additional associated project is listed and included in review.
2. Verify grant `10532` is the protected ASSIGN grant and grant `10592` has the
   expected broad ASSIGN holder. Apply the membership preconditions above.
3. Inspect all six PAH role grants. Before deletion, Ticket Manager must hold
   all six explicitly in scheme `10003`. The known missing ASSIGN grant is
   handled below. If another role grant is missing, stop the ASSIGN-only plan
   and disclose the additional replacement in a revised plan for review; do
   not silently extend the repair or rely on broad access to protect PAH.
4. Ensure `ASSIGN_ISSUES` for project role `10076`.
5. Ensure `ASSIGN_ISSUES` for group
   `fc8e7ac7-be76-4f1b-b481-6221f06b20a8`.
6. Read back and verify both replacements, protected grant `10532`, the role
   memberships, and PAH's six true results.
7. Remove grant `10592` only after these checks pass.
8. Verify the broad grant is absent, replacements and protected grants remain,
   PAH still has all six permissions, and GEN has all six false.
9. Report the complete matrix, retaining visibility of other unresolved projects.

This stage is successful when its GEN/PAH expectations pass and unaffected
controls do not regress. ADMIN, PLANT, SCRUM, and TASKLETS are reported as
remaining isolation work if their supplied true results persist. Do not label
this stage full PAH isolation.

## 11. Full isolation operation

Build a separate, fully enumerated plan from the current matrix and scheme
inventory. For each unexpected true result, inspect the contributing grants
and memberships. A true matrix cell does not identify a grant by itself.

For each supported broad-grant replacement, ensure the intended human-group
grant before removing broad access. In any scheme shared with PAH, verify
explicit Ticket Manager grants for all six PAH permissions before any broad
grant is removed; include missing replacements in the reviewed plan. Never add
`pah-ticket-managers` directly to a shared scheme as a shortcut to project-scoped
access.

Show every affected scheme, associated project, permission, replacement holder,
and deletion ID. Unknown access paths or unsupported project models prevent a
claim of complete isolation; they do not authorize speculative removals.

After changes, rerun all six checks for PAH and every negative-control project.
Reconcile the final project inventory with the reviewed one. Success requires:

- PAH: all six true.
- Every other included project: all six false.
- All discovered in-scope projects accounted for, with no unknown/error cells.
- All replacement and protected grants verified intact.
- No unexpected change to project associations or relevant memberships.

An idempotent rerun produces no mutations and the same successful controls.

## 12. CLI workflow

The following is a proposed interface, not commands available in the current
repository. Exact option spelling may be refined without weakening the gates.

```text
bundle exec exe/jira_permissions scheme --project PAH
bundle exec exe/jira_permissions grants --scheme 10003 --permission ASSIGN_ISSUES
bundle exec exe/jira_permissions audit --projects ADMIN,BST,DS,FIN,GEN,PAH,PLANT,SCRUM,TASKLETS
bundle exec exe/jira_permissions plan --operation pah-assign-repair --output plan.json
bundle exec exe/jira_permissions plan --operation pah-isolation --output plan.json
bundle exec exe/jira_permissions execute --plan plan.json
bundle exec exe/jira_permissions execute --plan plan.json --apply
```

`execute` without `--apply` revalidates and displays the plan without writes.
The audit command supports an explicit expectation such as PAH-only and a
complete administrator-discovered inventory. Configuration selects the audit
identity without passing credentials on the command line.

Generic ensure-group, ensure-role, and delete-grant operations use the same
planning and execution path. A delete requires the expected permission/holder
and scheme context as well as the grant ID. Removing a broad grant requires
declared replacements and verification controls. There is no force option that
bypasses application-grant protection or failed preconditions.

## 13. Verification plan

Use classic RSpec style and named subjects where applicable. Do not use `let!`,
`allow_any_instance_of`, or `OpenStruct`. Use verifying doubles and synthetic
fixtures; block real network traffic in the new tests.

| Area | Required cases |
| --- | --- |
| Configuration and identity | Missing/blank variables; distinct admin/audit clients; wrong account; wrong site; safe error output |
| HTTP contracts | Exact methods/routes; GET 200; POST 201; DELETE 204; 400/401/403/404/429/5xx; invalid JSON; empty DELETE body; timeouts |
| Grant serialization | Group and role IDs in `value`; no POST `parameter`; GET with both; conflicting IDs; name-only group resolution |
| Discovery | Paginated projects/memberships; shared schemes processed once; unexpected associations; missing or unsupported project |
| Membership | Intended PAH actors; direct and group role paths; target in human group; unexpected target role in GEN |
| Dry-run | Zero mutations for every public mutation path without explicit apply; malformed or altered plans rejected |
| Ordering | Replacement POSTs precede readback and DELETE; failed add/readback prevents all dependent deletions |
| Protection | Protected role rejected through every delete path; numeric/string ID normalization; same number used as scheme and role ID |
| Matching | Do not delete by holder type alone; reject changed grant ID/permission/holder; reject ambiguous broad grants |
| Idempotency | Existing replacement; completed plan rerun; absent target with verified scheme; expected partial progress; uncertain write outcome |
| Audit | Six stable columns; explicit false; missing fields are errors; anonymous/wrong-user audit rejected; full inventory coverage |
| Controls | PAH ADD_COMMENTS regression; GEN ASSIGN remains true; another project unexpectedly gains access; final full-isolation matrix |
| Evidence | No credentials, headers, URLs from configuration, or raw transport bodies in output, saved plans, or failures |
| CLI | Help, invalid options, default dry-run, explicit apply, JSON output, and documented exit codes |

After implementation run:

```text
bundle exec rspec
bundle exec rubocop
```

These are implementation gates, not claims that the documentation task has
already validated code that does not exist. For this PRD, check Markdown
structure, local references, requirement coverage, and absence of secrets.

Live validation happens only after tests pass and the concrete plan has been
shown to the operator. It consists of read-only baseline discovery, plan
review, authorized staged apply, and read-only post-change verification.

## 14. Acceptance criteria

### 14.1 Documentation ticket

- [x] PRD exists under `docs/prds/` and links to its own GEN ticket.
- [x] Baseline facts, known IDs, six permissions, and target matrix are recorded.
- [x] Architecture, CLI workflow, safety invariants, failure behavior, and tests
  are concrete enough to implement and review.
- [x] Immediate ASSIGN repair and full isolation have separate success criteria.
- [x] Open configuration questions and limitations are explicit.
- [x] No library implementation, credential values, or permission mutations are
  included in this documentation deliverable.

### 14.2 Subsequent implementation and operation

- [ ] All capabilities in section 5.1 have library APIs and executable coverage.
- [ ] Every public mutation path is dry-run by default and protected by apply.
- [ ] A stale or unsafe plan stops before the next write; replacements precede
  removals and protected application grants survive.
- [ ] Synthetic regression tests cover the known PAH comment-loss failure and
  the GEN ASSIGN leak; the full RSpec suite and RuboCop pass.
- [ ] The operator sees the exact live mutation plan before permission changes.
- [ ] The ASSIGN repair meets section 10, with remaining isolation work visible.
- [ ] Full isolation meets section 11 across the complete reported inventory.
- [ ] A subsequent run is a verified no-op and evidence contains no credentials.

## 15. Delivery sequence

1. **PRD:** create the dedicated GEN documentation ticket, complete this
   document, and resolve review feedback.
2. **Read-only foundation:** implement configuration, identity checks, discovery,
   grant normalization, auditor, matrix output, and unit tests.
3. **Mutation planning:** implement plan serialization/revalidation, default
   dry-run, replacement ordering, protected deletes, and recovery behavior.
4. **Executable and documentation:** expose the workflow, add README usage,
   complete CLI tests, and run the required suite and lint commands.
5. **Initial operational repair:** present the current GEN/PAH ASSIGN plan;
   apply only within the operator-authorized scope; record controls.
6. **Remaining isolation:** inspect other schemes/access paths, present their
   explicit plan, and verify the full matrix after authorized changes.

Select implementation and operational tickets separately. Keep this PRD's
documentation scope clear in its ticket and any later PR description.

## 16. Limitations and open decisions

| Item | Required resolution / behavior |
| --- | --- |
| Service-account configuration | Confirm environment-variable names, Bearer/gateway setup, and immutable expected account ID without copying credential values |
| Group identity | Resolve the immutable ID of `pah-ticket-managers` and verify relevant memberships |
| Broad holder representation | Capture normalized non-secret live holder fields for `10592` and other proposed removals; never assume type alone |
| Other schemes and project types | Discover all associations and supported access paths; the supplied matrix does not explain why access exists |
| Human replacement coverage | Confirm `jira-project-users` represents the intended human population for each affected scheme |
| Delayed visibility | Choose a bounded retry interval/deadline during implementation; never bypass replacement readback |
| Concurrent administration | Revalidate between steps and stop on drift; multi-request changes are not assumed atomic |
| Coverage boundary | Report archived/unsupported/inaccessible inventory explicitly; never silently certify a subset as every project |
| PRD and implementation tickets | This ticket owns the specification; subsequent delivery work receives separate tracking |

Jira's project-context permission checks have issue-dependent semantics: a true
cell can describe permission applicable to some issues and does not prove that
every issue operation will succeed. Conversely, an HTTP error does not prove a
denial. Treat this matrix as the specified six-permission control, with its
scope visible. Workflow and issue-security behavior remain separate concerns.
See Atlassian's
[mypermissions contract](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-permissions/#api-rest-api-3-mypermissions-get).

## 17. Change and attribution conventions

Follow `COMMONS.md` where it overrides `AGENTS.md`. Keep the commons mirror
read-only. Work begins from master with the merged maintenance preserved.

The clean historical example is `539aa485` (GEN-724), rather than the recent
squash messages. Future documentation commits use one ticket, its Jira URL as
the first body line, an explanation of why, and Ron's attribution. Wrap body
prose to 55–65 characters; URLs and structured trailers may exceed that width.
Append a PR number only when it is known and appropriate for the merge.

```text
GEN-730 Document safe Jira permission management

https://doolin.atlassian.net/browse/GEN-730

Define the grant replacement and audit requirements before
changing shared schemes so PAH access remains protected.

Coauthored by Ron via Codex GPT-6
```

The existing manual scripts are reference material. This PRD records only
non-secret structure and operator-supplied facts; it does not execute, copy,
stage, or incorporate those scripts into the product.
