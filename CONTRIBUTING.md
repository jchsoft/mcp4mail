# Contributing to mcp4mail

Thanks for helping. mcp4mail is small on purpose, so issues and pull requests are read closely.

## Before you start

- For anything bigger than a bug fix, open an issue first so we can agree on the shape.
- The MCP endpoint is **read-only by design**. Tools that send, move, delete or re-flag mail will not be merged
  as ordinary tools; the tool registry refuses to boot with one. If you want write access, open an issue.

## Setup

```bash
bin/setup   # gems, database, dev server
bin/dev     # web server + Tailwind watcher
```

You need Ruby (see `.ruby-version`) and a running PostgreSQL that accepts your OS user over the local socket.

## `bin/ci` must pass

Every pull request is expected to pass `bin/ci` locally before review. It runs, in order:

- RuboCop (`bin/rubocop`)
- `bin/bundler-audit`, `bin/importmap audit` and Brakeman
- unit and integration tests (`bin/rails test`)
- system tests (`bin/rails test:system`, needs Chrome)
- seeds

A pull request with a red `bin/ci` is not reviewed. When `bin/ci` passes and the
[`gh-signoff`](https://github.com/basecamp/gh-signoff) extension is installed, it posts a signoff status to the
pull request.

## Guidelines

- Add tests with the change: a model or service test for logic, an integration test for a controller or MCP
  tool, a system test for a user-visible flow.
- Every MCP tool resolves data through the signed-in user's own mail accounts. Keep it that way.
- User-facing strings go through I18n, in both `en` and `cs`.
- Keep commits focused and write messages that say why.

## Secrets: never commit them

This repository is public. Never commit credentials, API keys, `config/master.key`, a filled-in `.env`, a real
mailbox host or username, or a database dump. Tests use fake servers on `127.0.0.1` and made-up addresses.
If you commit a secret by mistake, rotate it: removing it from a later commit does not remove it from history.

## Security issues

Do not open a public issue for a vulnerability. Report it privately through GitHub's
"Report a vulnerability" button on the repository's Security tab.

## License

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE).
