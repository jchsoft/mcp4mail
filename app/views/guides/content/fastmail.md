---
title: Fastmail
provider: fastmail
summary: Fastmail only accepts app passwords over IMAP. Create one under Privacy & Security, then sign in with your full address.
imap_host: imap.fastmail.com
needs_app_password: true
order: 120
---

Fastmail never lets a mail client sign in with your normal password. You need
an **app password** with IMAP access.

## 1. Create an app password

1. Sign in to [Fastmail](https://app.fastmail.com) and open **Settings**.
2. Go to **Privacy & Security**, then **Connected apps & API tokens**.
3. Choose **Manage app passwords and access**, then **New app password**.
4. Name it `mcp4mail` and give it access to **Mail (IMAP/POP/SMTP)**.
5. Copy the password it shows. Fastmail shows it only once.

## 2. The settings to use

| Setting     | Value                                           |
|-------------|-------------------------------------------------|
| IMAP server | `imap.fastmail.com`                             |
| Port        | `993`                                           |
| Security    | SSL/TLS                                         |
| Username    | your **full** address, e.g. `jana@fastmail.com` |
| Password    | the app password from step 1                    |

## If it still does not connect

- **"Authentication failed"** — check that the app password has IMAP access,
  and that you did not paste your normal Fastmail password.
- **You use your own domain on Fastmail** — the server is still
  `imap.fastmail.com`; the username is your Fastmail login address.
