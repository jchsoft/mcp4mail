---
title: WEDOS
provider: wedos
summary: The IMAP server name depends on your webhosting server. Copy it from the WEDOS administration, then sign in with your full address.
imap_host: wesX-imap.wedos.net
needs_app_password: false
order: 20
---

WEDOS webhosting has no single shared IMAP server. Each webhosting runs on a
numbered server, and the IMAP address carries that number — for example
`wes1-imap.wedos.net`. There is no app password; your normal mailbox password
works.

## 1. Find your IMAP server in the WEDOS administration

Sign in to the WEDOS customer administration, open your **webhosting** and look
at its detail. The mail server names are listed there, in the form
`wesX-imap.wedos.net`, where `X` is your server number. Copy the IMAP one.

## 2. Have your mailbox password ready

Use the password of the mailbox itself, the one you set when you created the
mailbox — not the password of your WEDOS customer account. If you do not know
it, set a new one on the mailbox in the administration.

## 3. The settings to use

| Setting     | Value                                          |
|-------------|------------------------------------------------|
| IMAP server | `wesX-imap.wedos.net` (your number instead of `X`) |
| Port        | `993`                                          |
| Security    | SSL/TLS                                        |
| Username    | your **full** address, e.g. `jana@firma.cz`    |
| Password    | your mailbox password                          |

## If it still does not connect

- **"Server not found"** — the server number is wrong. Copy the name again
  from the webhosting detail, character by character.
- **"Authentication failed"** — you are probably using the customer account
  password. Use the mailbox password, or set a new one on the mailbox.
