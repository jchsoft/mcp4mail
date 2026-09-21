---
title: OVHcloud
provider: ovh
summary: MX Plan mailboxes use ssl0.ovh.net with your full address and mailbox password. Email Pro uses a numbered server.
imap_host: ssl0.ovh.net
needs_app_password: false
order: 150
---

OVHcloud mailboxes work over IMAP without anything to switch on and without an
app password. Which server you use depends on your email product.

## 1. Check which email product you have

In the OVHcloud Control Panel, open **Web Cloud**, then **Emails**. The product
name is shown with your domain:

- **MX Plan** (the mailboxes that come with web hosting) — the server is
  `ssl0.ovh.net`.
- **Email Pro** — the server is numbered, like `pro1.mail.ovh.net`. The exact
  name is on the product's **General information** tab.

## 2. Have your mailbox password ready

Use the password of the mailbox, not the one for your OVHcloud account. You can
set a new one on the mailbox in the Control Panel.

## 3. The settings to use

| Setting     | Value                                                  |
|-------------|--------------------------------------------------------|
| IMAP server | `ssl0.ovh.net` (MX Plan) or your `pro….mail.ovh.net`   |
| Port        | `993`                                                  |
| Security    | SSL/TLS                                                |
| Username    | your **full** address, e.g. `jana@firma.fr`            |
| Password    | your mailbox password                                  |

## If it still does not connect

- **"Authentication failed"** — check the username is the whole address and
  the password is the mailbox one.
- **Email Pro and `ssl0.ovh.net` does not answer** — use the numbered server
  from step 1 instead.
