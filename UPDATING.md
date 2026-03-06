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
- CI:
  - GitHub Actions currently only runs a PR title linter workflow and
    does not depend on a specific Ruby version.
  - Semaphore CI runs on `ubuntu2004` and installs gems with `bundle`
    but does not pin a Ruby version; ensure the Semaphore agents are
    updated to provide Ruby 4.0.1 (or compatible 4.x) before relying
    on this update in main.
- Once GEN-710 is complete, update this section with the final Ruby
  version, any gem constraints, CI details, and links to relevant Jira
  tickets.

