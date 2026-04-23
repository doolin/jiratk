# Agent context for JiraTK

Guidance for AI agents working in this repo.

## Stack and layout

- **Language**: Ruby 3.2+ (see `.ruby-version`).
- **Project type**: Gem; `lib/jiratk/` is the library, `exe/` holds executables.
- **Config**: `jiratk.gemspec` for metadata and deps; `Gemfile` adds dev/test and optional groups (`:aws`, `:google`, `:test`). Runbook used for some automation (`Runbookfile`).

## Commands

| Task | Command |
|------|--------|
| Install deps | `bundle install` |
| Tests | `bundle exec rspec` or `rake` (default task is spec) |
| Lint | `bundle exec rubocop` |
| Run an exe | `bundle exec exe/<name>` (e.g. `bundle exec exe/provision_s3`)

## Conventions

- Use `# frozen_string_literal: true` at the top of new Ruby files (see existing lib/exe).
- Library code lives under `lib/jiratk/`; require via `require 'jiratk'` or `require 'jiratk/...'`.
- Executables are in `exe/`; they are run via `bundle exec` and are listed in the README.

## Where to look

- **Jira API / auth**: `lib/jiratk/api_helper.rb`, `lib/jiratk/oautherizer.rb`
- **Issues and tickets**: `lib/jiratk/issue.rb`, `lib/jiratk/jira_ticket.rb`, `lib/jiratk/assessment_ticket.rb`
- **Burndown**: `lib/jiratk/burndown_to_csv.rb`, `lib/jiratk/burndown_to_html.rb`
- **Templates**: `lib/jiratk/template_cloner.rb`; exe: `provision_templates`, `copy_from_template`
- **AWS**: `lib/jiratk/s3_tools.rb`, `lib/jiratk/athena_tools.rb`; exe: `provision_s3`, `athena`
- **Version**: `lib/jiratk/version.rb`

## Commit message template

Use this format for every commit. **The Jira link in the body is mandatory.**

```
GEN-<number> <Imperative summary> (#<PR> optional, add when merging PR)

https://doolin.atlassian.net/browse/GEN-<number>

<Optional: short explanation or bullet list>
```

- Subject: ticket key first (e.g. `GEN-709`), then imperative phrase. Append `(#NNN)` when commit is from a merged PR.
- Body line 1: **must** be the Jira URL for the ticket (do not omit).
- Body line 2: blank.
- Body line 3+: optional context, explanation, or bullets.
- **Line length**: wrap at ~72 characters; URLs are excepted (may stay on one line).

When suggesting or writing commit messages, read this section and include the Jira URL.

## Other

- CI: `.github/workflows/`; Semaphore config in `.semaphore/`.
- Specs use VCR/webmock (see `spec/cassettes/`). Keep API and env details out of committed secrets.
