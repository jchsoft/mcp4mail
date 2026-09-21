---
title: Active24
provider: active24
summary: Active24 mail now runs on the Websupport platform. Use imap.websupport.cz with your full address and mailbox password.
imap_host: imap.websupport.cz
needs_app_password: false
order: 40
---

Active24 in the Czech Republic has moved its mail to the Websupport platform,
so the IMAP server carries the Websupport name even though you still sign in to
Active24. There is no app password; the mailbox password works.

## 1. Have your mailbox password ready

Use the password of the mailbox, not the one for the Active24 customer centre.
If you do not know it, open your domain's **Email** section in the Active24
customer centre and set a new password on the mailbox.

## 2. Check the server name in your administration

The mailbox detail in the customer centre shows the settings for email
clients. For most accounts the IMAP server is `imap.websupport.cz`. Some older
accounts still show `email.active24.com` — if yours does, use that one.

## 3. The settings to use

| Setting     | Value                                        |
|-------------|----------------------------------------------|
| IMAP server | `imap.websupport.cz`                         |
| Port        | `993`                                        |
| Security    | SSL/TLS                                      |
| Username    | your **full** address, e.g. `jana@firma.cz`  |
| Password    | your mailbox password                        |

## If it still does not connect

- **"Authentication failed"** — make sure the username is the whole address
  and the password is the mailbox one, not the customer centre login.
- **Nothing answers on the server** — try the server name shown in your
  mailbox detail instead of the one above.
