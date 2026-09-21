---
title: Forpsi
provider: forpsi
summary: No app password and nothing to switch on. Use imap.forpsi.com with your full address and mailbox password.
imap_host: imap.forpsi.com
needs_app_password: false
order: 30
---

Forpsi mailboxes are ready for IMAP from the start. You only need the mailbox
password — not an app password, and not the password of your Forpsi customer
account.

## 1. Have your mailbox password ready

Use the password you set for the mailbox itself. If you do not know it, sign in
to the Forpsi administration, open **Email** for your domain and set a new
password on the mailbox.

## 2. The settings to use

| Setting     | Value                                        |
|-------------|----------------------------------------------|
| IMAP server | `imap.forpsi.com`                            |
| Port        | `993`                                        |
| Security    | SSL/TLS                                      |
| Username    | your **full** address, e.g. `jana@firma.cz`  |
| Password    | your mailbox password                        |

The server is `imap.forpsi.com` whatever your domain is.

## If it still does not connect

- **"Authentication failed"** — check that the username is the whole address,
  including the domain, and that you are using the mailbox password.
- **You just created the mailbox** — give Forpsi a few minutes to set it up,
  then try again.
