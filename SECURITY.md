# Security policy

mcp4mail stores IMAP credentials, so we take security reports seriously.

## Supported versions

Only `main` and the hosted service at [mcp4mail.online](https://mcp4mail.online) (which deploys from the
`production` branch) are supported. There are no versioned releases; if you self-host, run a current `main`.

## Reporting a vulnerability

Please report privately, not in a public issue or pull request:

1. Preferred: [GitHub private vulnerability reporting](https://github.com/jchsoft/mcp4mail/security/advisories/new)
   (the **Security** tab of this repository, then **Report a vulnerability**).
2. Or e-mail [support@mcptask.online](mailto:support@mcptask.online).

Please include:

- what you found and the impact you expect,
- the steps or a minimal proof of concept to reproduce it,
- the affected version (commit) or whether it is the hosted service,
- how you would like to be credited, if at all.

Do not include real mailbox hosts, usernames, passwords or message content; use made-up data. We answer as soon
as we can; we do not promise a response time. Please give us a reasonable chance to fix the problem before you
disclose it publicly.

## Security model

A short summary; the details are in the [README](README.md#mcp-endpoint-read-only-by-design) and the
[security notes of the self-hosting guide](docs/self-hosting.md#security-notes).

- **Passwords encrypted at rest.** Mailbox passwords are encrypted with Active Record Encryption before they are
  written to PostgreSQL. They are never shown in the UI, returned by an MCP tool, written to the audit log or
  logged. Use an app-specific password.
- **Read-only by default.** A mailbox can only be read and searched until its owner switches on "Allow the AI to
  make changes to this mailbox". Folders are opened with IMAP `EXAMINE`, so reading does not mark mail as seen.
- **Per-mailbox AI permissions.** Once changes are allowed, the owner ticks what the AI may do (flags, moves,
  drafts, send, trash). A tool whose box is unticked is refused, and the tool registry refuses to boot with a
  write tool that is not declared as one.
- **Sending needs a human.** `send_message` only prepares an email; it is sent after the owner approves it.
- **Scoping.** Every tool resolves data through the signed-in user's own mail accounts; another user's account
  id is refused before any tool code runs.
- **Rate limits.** Per user and client, plus one tool-call quota per user across all their clients.
- **Audit log.** Every MCP call is recorded (user, client, tool, account, outcome, rows, duration); arguments
  are not stored.
- **Search guard.** Result pages are capped, and each account has a budget of searches and returned rows.

What it does not do: an AI client you connect can read your mail whenever it asks, so connect only clients you
trust. A database backup contains the encrypted passwords; keep the encryption keys apart from it.

## Scope

In scope: this repository and the hosted service at mcp4mail.online. Out of scope: vulnerabilities in your own
IMAP provider or in the AI client you connect.
