---
title: Yahoo Mail
provider: yahoo
summary: Yahoo refuses your normal password over IMAP. Create an app password in Account Security and use that.
imap_host: imap.mail.yahoo.com
needs_app_password: true
order: 140
---

Yahoo Mail does not let mail clients sign in with your normal password. You
need an **app password**.

## 1. Create an app password

1. Sign in to Yahoo and open your
   [Account Security](https://login.yahoo.com/account/security) page.
2. Under **External connections**, choose **Create app password**.
3. Name it `mcp4mail` and choose **Generate password**.
4. Copy the password it shows. Yahoo shows it only once.

## 2. The settings to use

| Setting     | Value                                        |
|-------------|----------------------------------------------|
| IMAP server | `imap.mail.yahoo.com`                        |
| Port        | `993`                                        |
| Security    | SSL/TLS                                      |
| Username    | your **full** address, e.g. `jana@yahoo.com` |
| Password    | the app password from step 1                 |

## If it still does not connect

- **"Authentication failed"** — you are probably using your normal Yahoo
  password. Create an app password as in step 1.
- **It worked and then stopped** — the app password may have been revoked in
  Account Security. Create a new one.
