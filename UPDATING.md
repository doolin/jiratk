# Updating JiraTK

This document records how dependency and runtime updates are performed,
starting with **GEN-710 Update gems and Ruby**.

## GEN-710: Update Ruby and gems

### 1. Update to latest Ruby (4.0.1)

As of early 2026, the latest stable Ruby is **4.0.1** ([ruby-lang.org](https://www.ruby-lang.org/en/downloads/releases/)).

- **.ruby-version**
  - Change from `ruby-3.2.2` to `ruby-4.0.1`.
- **gemspec**
  - Update `spec.required_ruby_version` to `'>= 4.0'` (or a narrower
    constraint once we know which 4.x versions we support in CI).
- **Local setup**
  - Install Ruby 4.0.1 via `rvm`.
  - Update Bundler if needed, e.g. `gem install bundler` or
    `bundle update --bundler`.
  - Run `bundle install` to resolve gems for Ruby 4.0.1.
- **Sanity checks**
  - Run `bundle exec rspec` (or `rake`) and ensure the suite passes.
  - Run `bundle exec rubocop`.
  - Manually run the key executables (`exe/provision_s3`, `exe/athena`,
    template and spreadsheet scripts) in a safe environment and confirm
    no Ruby-version-related regressions.

Record any issues, workarounds, or required code changes below as the
update proceeds.

#### Progress

- `Gemfile.lock` had `BUNDLED WITH 2.2.22` and `RUBY VERSION ruby
  3.2.2p53`. Bundler 2.2.22 crashes under Ruby 4.0 due to removed
  `DidYouMean::SPELL_CHECKERS` constant. Fixed by updating the
  lockfile to `BUNDLED WITH 4.0.3` and `RUBY VERSION ruby 4.0.1`
  before running `bundle install`.
- `bundle install` succeeded: 117 gems, no errors.
- Ruby 4.0 removed several gems from the default set. Added to
  Gemfile: `cgi` (needed by VCR), `csv` (needed by
  burndown_to_csv), `pstore` (needed by yaml/store), `tsort`
  (needed by RuboCop).
- Updated RuboCop from 1.78.0 to 1.85.1 (1.78 did not recognize
  Ruby 4.0). rubocop-rspec updated from 3.6.0 to 3.9.0.
- `bundle exec rspec`: 20 examples, 0 failures (10 pending,
  pre-existing).
- `bundle exec rubocop`: 1 pre-existing offense
  (`Style/OneClassPerFile` in `exe/provision_templates.rb`),
  no new offenses.
- `google-api-client` gem is deprecated upstream; recommends
  per-service gems (e.g. `google-apis-drive_v3`). Address in a
  follow-up ticket.

### 2. Reorganize Gemfile and update dev/test gems

Reorganized the Gemfile into clear groups so that development and
test gems can be updated independently of runtime dependencies.

- **Default group** (runtime): `awesome_print`, `cgi`, `csv`,
  `pstore`, `rest-client`, `runbook`, `tsort`, `tty-prompt`, plus
  `:aws` (`aws-sdk-athena`, `aws-sdk-s3`) and `:google`
  (`google-api-client`).
- **`:development`**: `debug`, `flay`, `rubocop`, `rubocop-rspec`.
- **`:test`**: `rspec`, `vcr`, `webmock`.

Ran `bundle update --group development test`. Notable updates:

| Gem | From | To |
|-----|------|----|
| debug | 1.11.0 | 1.11.1 |
| flay | 2.13.3 | 2.14.2 |
| rspec | 3.13.1 | 3.13.2 |
| rspec-core | 3.13.5 | 3.13.6 |
| rspec-mocks | 3.13.5 | 3.13.8 |
| rspec-support | 3.13.4 | 3.13.7 |
| vcr | 6.3.1 | 6.4.0 |
| webmock | 3.25.1 | 3.26.1 |

RuboCop (1.85.1) and rubocop-rspec (3.9.0) were already at latest.

Sanity checks after update:
- `bundle exec rspec`: 20 examples, 0 failures (10 pending).
- `bundle exec rubocop`: 1 pre-existing offense, no new offenses.

To update these groups in the future:
- `bundle update --group development`
- `bundle update --group test`
- `bundle update --group development test`

### 3. Update runtime gems

Ran `bundle update --group default aws google`. Notable updates:

| Gem | From | To |
|-----|------|----|
| aws-partitions | 1.1131.0 | 1.1222.0 |
| aws-sdk-athena | 1.105.0 | 1.117.0 |
| aws-sdk-core | 3.226.3 | 3.243.0 |
| aws-sdk-kms | 1.106.0 | 1.122.0 |
| aws-sdk-s3 | 1.193.0 | 1.215.0 |
| activesupport | 8.0.2 | 8.1.2 |
| concurrent-ruby | 1.3.5 | 1.3.6 |
| faraday | 2.13.2 | 2.14.1 |
| googleauth | 1.14.0 | 1.16.2 |
| jwt | 2.10.2 | 3.1.2 |
| signet | 0.20.0 | 0.21.0 |
| sshkit | 1.24.0 | 1.25.0 |
| thor | 1.4.0 | 1.5.0 |

Already at latest (no change): `awesome_print`, `cgi`, `csv`,
`pstore`, `rest-client`, `tsort`, `tty-prompt`, `google-api-client`.

Sanity checks after update:
- `bundle exec rspec`: 20 examples, 0 failures (10 pending).
- `bundle exec rubocop`: 1 pre-existing offense, no new offenses.

#### Notes

- If Ruby 4.0.1 introduces incompatibilities with specific gems, prefer
  to update or replace those gems rather than pinning Ruby back, unless
  there is a strong reason to stay on the 3.x series.
- CI: GitHub Actions PR title linter only. Semaphore removed (May 2026).
- Once GEN-710 is complete, update this section with the final Ruby
  version, any gem constraints, CI details, and links to relevant Jira
  tickets.

### 4. Maintenance round (May 2026)

Routine dependency refresh on Ruby 4.0.1 ([GEN-720](https://doolin.atlassian.net/browse/GEN-720)).

```bash
bundle update
bundle exec rspec
bundle exec rubocop
```

Notable direct/transitive updates:

| Gem | From | To |
|-----|------|----|
| activesupport | 8.1.2 | 8.1.3 |
| addressable | 2.8.9 | 2.9.0 |
| aws-partitions | 1.1222.0 | 1.1249.0 |
| aws-sdk-athena | 1.117.0 | 1.119.0 |
| aws-sdk-core | 3.243.0 | 3.247.0 |
| aws-sdk-kms | 1.122.0 | 1.125.0 |
| aws-sdk-s3 | 1.215.0 | 1.222.0 |
| bigdecimal | 4.0.1 | 4.1.2 |
| faraday | 2.14.1 | 2.14.2 |
| flay | 2.14.2 | 2.14.4 |
| http-cookie | 1.1.0 | 1.1.6 |
| irb | 1.17.0 | 1.18.0 |
| json | 2.19.0 | 2.19.5 |
| jwt | 3.1.2 | 3.2.0 |
| minitest | 6.0.2 | 6.0.6 |
| parallel | 1.27.0 | 2.1.0 |
| parser | 3.3.10.2 | 3.3.11.1 |
| regexp_parser | 2.11.3 | 2.12.0 |
| rubocop | 1.85.1 | 1.86.2 |
| webmock | 3.26.1 | 3.26.2 |

Left at constrained/latest-compatible versions (transitive pins):

- `diff-lcs` 1.6.2 (rspec; latest 2.0.0)
- `google-apis-core` 0.18.0 (google-api-client; latest 1.0.2)
- `wisper` 2.0.1 (runbook; latest 3.0.0)
- `unicode-display_width` 2.6.0 (rubocop; latest 3.2.0)

Other changes:

- Fixed `ApiHelper#post` error path: `res` → `result` (undefined
  local on non-2xx responses).
- `AGENTS.md`: Ruby requirement note updated to 4.0+.

Sanity checks:

- `bundle exec rspec`: 20 examples, 0 failures (10 pending).
- `bundle exec rubocop`: 34 files, no offenses.

Follow-ups (out of scope for this ticket):

- Dedicated agent Jira project + local tooling (separate accounts/email
  when management toil warrants it).
- Migrate off deprecated `google-api-client`.
- CI: re-enable Semaphore or expand GitHub Actions when needed.

## GEN-729: Patch gems for bundle audit (September 2026)

[GEN-729](https://doolin.atlassian.net/browse/GEN-729) covers this dependency
maintenance pass. The CI audit on the GEN-730 documentation PR reported five
advisories in the existing `concurrent-ruby`, `faraday`, and `json` versions.
This pass updates 42 gems and clears those findings without changing the Ruby
version or the Runbook Git revision.

### Update method

Used the shared `gem-update` skill for the version report and verification
gauntlet. At the operator's direction, related minor and major updates were
batched instead of processed individually:

1. Patch releases, using `bundle update --patch --strict --conservative` with
   the reported patch candidates and an explicit JSON security patch.
2. AWS SDK and partition dependencies.
3. Google client and authentication dependencies.
4. Development tooling and remaining compatible runtime dependencies.

The later batches used named `bundle update --conservative` targets. JSON first
moved to 2.19.9 in the security batch, then to 3.0.2 after the RuboCop upgrade
removed its previous JSON 2.x constraint. RDoc moved to 8.0.0 in the tooling
batch. Existing upstream dependency bounds were preserved.

### Compatibility and lint handling

The Google/authentication updates removed the transitive `multi_json`
dependencies supplied by `googleauth` and `signet`. The existing Google
client still loads Representable's JSON adapter, which requires `multi_json`.
The first suite run after that batch caught the missing dependency while
loading `spec_helper`. Added `multi_json` explicitly in the Google group and
verified Google Drive and Sheets object serialization with JSON 3.0.2, without
making API calls.

RuboCop 1.91.0 introduced six `Style/DirectiveScope` violations. Per the
operator's instruction, `.rubocop.yml` now inherits `.rubocop_todo.yml`, which
excludes only the six affected files for that cop. Application and spec code
were not rewritten to fix these violations. The exclusions remain cleanup
work; other cops and files remain checked.

### Version changes

| Gem | From | To |
| --- | --- | --- |
| activesupport | 8.1.3 | 8.1.4 |
| airbrussh | 1.6.1 | 1.6.2 |
| aws-partitions | 1.1249.0 | 1.1290.0 |
| aws-sdk-athena | 1.119.0 | 1.125.0 |
| aws-sdk-core | 3.247.0 | 3.257.0 |
| aws-sdk-kms | 1.125.0 | 1.132.0 |
| aws-sdk-s3 | 1.222.0 | 1.232.1 |
| bigdecimal | 4.1.2 | 4.1.3 |
| cgi | 0.5.1 | 0.5.2 |
| concurrent-ruby | 1.3.6 | 1.3.8 |
| csv | 3.3.5 | 3.3.6 |
| domain_name | 0.6.20240107 | 0.6.20260921 |
| erb | 6.0.4 | 6.0.7 |
| faraday | 2.14.2 | 2.14.4 |
| faraday-net_http | 3.4.2 | 3.4.4 |
| google-apis-discovery_v1 | 0.20.0 | 0.21.0 |
| google-apis-generator | 0.18.0 | 0.19.0 |
| google-cloud-env | 2.3.1 | 2.4.0 |
| googleauth | 1.16.2 | 1.17.4 |
| i18n | 1.14.8 | 1.15.2 |
| io-console | 0.8.2 | 0.9.4 |
| json | 2.19.5 | 3.0.2 |
| jwt | 3.2.0 | 3.3.0 |
| language_server-protocol | 3.17.0.5 | 3.17.0.6 |
| mime-types-data | 3.2026.0414 | 3.2026.0922 |
| multi_json | 1.21.1 | 1.21.2 |
| net-ssh | 7.3.2 | 7.3.3 |
| parallel | 2.1.0 | 2.2.0 |
| parser | 3.3.11.1 | 3.3.12.0 |
| pp | 0.6.3 | 0.6.4 |
| rdoc | 7.2.0 | 8.0.0 |
| regexp_parser | 2.12.0 | 2.13.0 |
| reline | 0.6.3 | 0.7.0 |
| representable | 3.2.0 | 3.3.0 |
| retriable | 3.4.1 | 3.8.0 |
| rubocop | 1.86.2 | 1.91.0 |
| rubocop-ast | 1.49.1 | 1.50.0 |
| rubocop-rspec | 3.9.0 | 3.10.2 |
| sexp_processor | 4.17.5 | 4.17.6 |
| signet | 0.21.0 | 0.22.0 |
| sshkit | 1.25.0 | 1.25.1 |
| webmock | 3.26.2 | 3.26.4 |

RDoc's dependency graph now adds `rbs` 4.2.0 and no longer includes `date`,
`psych`, or `stringio` in the lockfile. The resolved bundle contains 118 gems.

### Remaining upstream constraints

The final report found no remaining patch or minor candidates. These seven
newer major versions cannot be selected under the current upstream bounds:

| Gem | Retained | Reported latest | Blocking dependency |
| --- | --- | --- | --- |
| diff-lcs | 1.6.2 | 2.0.0 | RSpec expectations/mocks require `< 2.0` |
| gems | 1.3.0 | 2.0.0 | google-apis-generator requires `~> 1.2` |
| google-apis-core | 0.18.0 | 1.2.5 | google-api-client requires `~> 0.1` |
| http-accept | 1.7.0 | 2.2.2 | rest-client requires `< 2.0` |
| retriable | 3.8.0 | 5.0.1 | google-apis-core requires `< 4.a` |
| unicode-display_width | 2.6.0 | 3.3.0 | tty-progressbar requires `< 3.0` |
| wisper | 2.0.1 | 3.0.0 | tty-reader requires `~> 2.0` |

Changing those constraints requires upstream releases or a separate migration
of the dependency that imposes them, including the already-recorded migration
away from `google-api-client`. No constraints were bypassed in this pass.

### Verification

- Bundler audit with the refreshed advisory database: no vulnerabilities.
  Database commit: `fb34fedf8a96f99e54bcfb9306519996a70baa25`.
- RSpec: 48 examples, 0 failures, 10 existing pending examples.
- RuboCop: 42 files inspected, no offenses with the six todo exclusions.
- Google Drive and Sheets JSON serialization: passed without API calls.
- The patch and AWS batches passed the gauntlet individually; the complete
  updated bundle passed after the Google dependency and lint todo adjustments.
- Jira credential variables were removed from the verification process.
- Brakeman is not bundled in this gem repository and was not run.

The automated suite has limited integration coverage. This pass did not make
live Jira, Google, or AWS requests to exercise application functionality.
