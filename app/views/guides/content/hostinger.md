---
title: Hostinger
provider: hostinger
summary: Nothing to switch on. Use imap.hostinger.com with your full address and the mailbox password.
imap_host: imap.hostinger.com
needs_app_password: false
order: 180
---

Hostinger Email mailboxes accept IMAP from the start. You need the mailbox
password — not the password of your Hostinger account.

## 1. Have your mailbox password ready

In hPanel, open **Emails**, choose your domain and then the mailbox. If you do
not know its password, change it there.

## 2. The settings to use

| Setting     | Value                                        |
|-------------|----------------------------------------------|
| IMAP server | `imap.hostinger.com`                         |
| Port        | `993`                                        |
| Security    | SSL/TLS                                      |
| Username    | your **full** address, e.g. `jana@firma.com` |
| Password    | your mailbox password                        |

hPanel also lists these under **Connect apps & devices** for the mailbox, if
you want to double-check.

## If it still does not connect

- **"Authentication failed"** — check the username is the whole address and
  the password is the mailbox one, not your Hostinger login.
- **You just created the mailbox** — give it a few minutes, then try again.
