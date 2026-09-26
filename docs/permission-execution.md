# Execute a reviewed permission plan

[GEN-737](https://doolin.atlassian.net/browse/GEN-737) adds library execution
of the initial GEN/PAH assignment repair. Prepare and review a plan using
[permission planning](permission-plans.md), then supply that same plan to
the executor. The CLI and audit-result persistence are later work.

```ruby
require 'jiratk/permissions'

connection = JiraTk::Permissions::Connection.administrator
executor = JiraTk::Permissions::Executor.new(
  administrator_connection: connection,
  audit_client: service # Separately authenticated client from permission-audit.md
)
reviewed = JiraTk::Permissions::Plan.load(saved_plan_json)

preview = executor.execute(reviewed)
puts preview.dump

# After reviewing the concrete plan and authorizing its application:
result = executor.execute(reviewed, apply: true)
puts result.dump
```

Both calls collect fresh evidence. Only Boolean `true` enables writes;
omitting `apply` or passing a string leaves execution read-only. The executor
loads and validates the plan again, including its derived steps and digest.
It never regenerates a wider plan. Administrator reads and writes use the
same injected connection. Discovery still verifies administrator privileges,
the expected distinct service account, and the common Jira site.

## Verification and ordering

Before any write, execution verifies the complete project inventory,
scheme associations, role and group identities, relevant memberships,
all scheme grants, and the six-permission matrix. Every recorded field
except the audit timestamp must match the reviewed evidence, allowing only
the planned grant additions and deletion and the corresponding final controls.

Execution recognizes these ordered prefixes: original state; first required
addition; both required additions; exact broad-grant removal. Replacements
already present in the original plan remain mandatory, with their original
IDs. If only one addition was planned, only that addition precedes deletion.
An out-of-order partial repair, duplicate candidate, changed membership,
changed association, or unrelated grant change stops execution.

New IDs are initially unknown in the plan. The executor binds them to exact,
unique observed grants and validates creation acknowledgements against the
reviewed payload. Once learned, an ID cannot be substituted or reused for
another grant. Protected addon grants and every unrelated original grant
must remain intact.

Each write has its own fresh preflight. Role and human-group replacements
are added serially and read back before the broad grant can be deleted.
The complete snapshot immediately before deletion verifies replacements,
membership, associations, the exact target, and before-deletion controls.
Deletion targets only the reviewed scheme and grant ID. Complete subsequent
reads must prove the projected grants and the final controls; a 404 alone
never proves absence.

PAH must retain all six permissions. GEN must end with all six denied.
Every additional shared negative project's ASSIGN permission must also be
denied, while other observed results stay unchanged. Access still present
in unrelated projects remains visible. Successful execution of this narrow
repair does not establish full PAH isolation.

## Readback and uncertain writes

Readback makes at most three complete capture attempts by default, with
one second between attempts. Configure `verification_attempts:` (1–5),
`verification_interval:` (0–5 seconds), and an optional callable `sleeper:`
when constructing the executor. These bounds govern capture attempts and
delays; each capture comprises multiple requests with its own timeouts.

Read failures and expected propagation delays can consume those attempts.
Unexpected drift stops immediately. After deletion, controls may move from
their exact before values toward their exact planned after values while
verification waits. A PAH regression or unrelated control change is drift.
If GEN assignment access persists, execution reports failure.

The transport requires POST 201 and DELETE 204, disables debug output and
redirects, and accepts an empty DELETE response. Mutation requests disable
Net::HTTP's implicit retries as well as application-level retries. There is
no automatic POST or DELETE replay and no rollback to broad access.

A timeout, malformed acknowledgement, unexpected status, or failed readback
stops further mutations. The executor still attempts bounded readback to
reconcile what happened. Even if it observes the attempted operation
completed, a failed write response is reported as a failed run. Successful
replacements remain in place. Recovery uses an inspected, explicit forward
attempt rather than compensating deletions or restoring the broad grant.

## Results and resumption

`ExecutionResult#to_h` returns independent data; `#dump` renders JSON.
The result contains the plan digest, grant ID bindings, observed prefix,
write attempts, and mutation-step outcomes. Step numbers refer to the
original nine-step plan: 2 and 3 are replacements; 7 is the broad grant.
Checkpoint evidence is represented by `last_observation`, which includes
the complete allowlisted snapshot and whether its controls were verified.
It is the last accepted observation, not a claim about the current live site.

Mutation statuses are `completed`, `pending`, `failed`, or `uncertain`.
`completed` means reconciled with live evidence; it does not claim that this
invocation performed a historical operation. `write_attempts` distinguishes
writes attempted by this invocation. A verified HTTP rejection can be
reported as `failed`; an unresolved write remains `uncertain`.

| Run status | Exit status | Meaning |
| --- | --- | --- |
| `dry-run` | 0 | Fresh preflight passed; remaining operations were previewed. |
| `applied` | 0 | All required operations and final verification completed. |
| `unchanged` | 0 | Fresh evidence proves the repair is already complete. |
| `failed` | 2 | This invocation stopped before attempting a write. |
| `failed` | 3 | A write was attempted and the run did not complete successfully. |

Invalid plan objects or verification configuration raise a sanitized
`JiraTk::Permissions::Error`. Operational failures return an execution result
with a fixed error category, optional HTTP status, and verification outcome.
Raw responses, transport exception text, credentials, and configuration are
excluded from results and inspection of connection-bearing objects.

The same executor automatically retains the latest result for each plan.
When constructing another executor in the same process, pass the previous
result explicitly:

```ruby
next_result = another_executor.execute(reviewed, apply: true, previous: result)
```

The previous result must refer to the same plan digest. Known grant IDs and
observed progress cannot regress. A previously uncertain step must become
observable as completed before execution can continue; another blocked
attempt retains that uncertainty. A known rejected write may be attempted
again only in a new explicit apply invocation after fresh preflight.

Without a previous result, a fresh executor can recognize completed prefixes
from the saved plan and current complete evidence. It cannot know an earlier
unobserved write or an ID absent from that plan. After losing process state,
inspect and resolve uncertain outcomes before applying again; an apparently
absent addition is not proof that a timed-out request failed. Result JSON is
evidence for review; loading execution receipts is not implemented here.

Jira supplies no transaction or lock spanning these reads and writes.
Concurrent administration can still race after a check. Keep repairs serial,
retain execution evidence, and review a new plan for unrelated drift.
