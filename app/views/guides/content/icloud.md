---
title: iCloud Mail
provider: icloud
summary: iCloud refuses your Apple Account password over IMAP. Create an app-specific password and use that.
imap_host: imap.mail.me.com
needs_app_password: true
order: 110
---

iCloud Mail never accepts your Apple Account password from a mail client like
mcp4mail. You need an **app-specific password**, and to create one your Apple
Account must have two-factor authentication switched on (most already do).

## 1. Create an app-specific password

1. Sign in at [account.apple.com](https://account.apple.com).
2. Open **Sign-In and Security**, then **App-Specific Passwords**.
3. Choose **Generate an app-specific password**, name it `mcp4mail` and
   confirm.
4. Copy the password it shows. Apple shows it only once.

## 2. The settings to use

| Setting     | Value                                           |
|-------------|-------------------------------------------------|
| IMAP server | `imap.mail.me.com`                              |
| Port        | `993`                                           |
| Security    | SSL/TLS                                         |
| Username    | your iCloud address, e.g. `jana@icloud.com`     |
| Password    | the app-specific password from step 1           |

If the full address is refused, try just the part before the `@`
(`jana`) — Apple accepts either for most accounts.

## If it still does not connect

- **"Authentication failed"** — you are most likely using your Apple Account
  password. Create an app-specific password as in step 1.
- **It worked and then stopped** — changing your Apple Account password
  revokes every app-specific password. Create a new one.
- **You use a custom domain with iCloud+** — the server is still
  `imap.mail.me.com`; sign in with your `@icloud.com` address.
