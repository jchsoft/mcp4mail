---
title: Zoho Mail
provider: zoho
summary: Switch on IMAP access in Zoho Mail settings, create an app password in Zoho Accounts, and pick the server for your region.
imap_host: imap.zoho.eu
needs_app_password: true
order: 130
---

Zoho Mail needs two things before a mail client can connect: IMAP access
switched on for your mailbox, and an **app password** if your Zoho account uses
two-factor authentication. The server name also depends on where your account
is hosted.

## 1. Switch on IMAP access

1. Sign in to [Zoho Mail](https://mail.zoho.eu) and open **Settings**.
2. Go to **Mail Accounts** and click your address.
3. Under **IMAP**, tick **IMAP Access** and save.

## 2. Create an app password

App passwords live in Zoho Accounts, not in Mail settings. Open
[accounts.zoho.eu](https://accounts.zoho.eu) (or `accounts.zoho.com`), go to
**Security**, then **App Passwords**, and choose **Generate New Password**.
Name it `mcp4mail` and copy the password it shows.

## 3. Pick the server for your account

| Your account                                   | IMAP server        |
|------------------------------------------------|--------------------|
| Free account, EU (you sign in at `zoho.eu`)    | `imap.zoho.eu`     |
| Free account, elsewhere (`zoho.com`)           | `imap.zoho.com`    |
| Paid account on your own domain, EU            | `imappro.zoho.eu`  |
| Paid account on your own domain, elsewhere     | `imappro.zoho.com` |

The **IMAP** section from step 1 also shows the exact server for your account;
if it differs from the table, use that one.

## 4. The settings to use

| Setting     | Value                                        |
|-------------|----------------------------------------------|
| IMAP server | from step 3                                  |
| Port        | `993`                                        |
| Security    | SSL/TLS                                      |
| Username    | your **full** address, e.g. `jana@zoho.eu`   |
| Password    | the app password from step 2                 |

## If it still does not connect

- **"IMAP is disabled"** — IMAP access is still off; repeat step 1.
- **"Authentication failed"** — use the app password, and check the server
  matches your region and plan from step 3.
