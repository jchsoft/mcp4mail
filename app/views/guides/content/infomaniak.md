---
title: Infomaniak
provider: infomaniak
summary: Generate a password for the mailbox in the Infomaniak Manager — your Infomaniak login will not work — and use mail.infomaniak.com.
imap_host: mail.infomaniak.com
needs_app_password: true
order: 160
---

Infomaniak keeps your account login separate from mailbox access. A mail
client like mcp4mail signs in with a **password generated for the mailbox**,
not with the password you use for the Infomaniak Manager.

## 1. Generate a mailbox password

Sign in to the [Infomaniak Manager](https://manager.infomaniak.com), open
**Mail Service** and select your address. In the mailbox settings, generate a
new password for a mail client, name it `mcp4mail` and copy it. Infomaniak
shows it only once.

## 2. The settings to use

| Setting     | Value                                        |
|-------------|----------------------------------------------|
| IMAP server | `mail.infomaniak.com`                        |
| Port        | `993`                                        |
| Security    | SSL/TLS                                      |
| Username    | your **full** address, e.g. `jana@firma.ch`  |
| Password    | the password generated in step 1             |

## If it still does not connect

- **"Authentication failed"** — you are probably using your Infomaniak login.
  Generate a mailbox password as in step 1.
- **You lost the generated password** — it cannot be shown again. Generate a
  new one and use that.
