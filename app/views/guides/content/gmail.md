---
title: Gmail
provider: gmail
summary: Gmail refuses your Google password over IMAP. Turn on 2-Step Verification, create an app password and use that.
imap_host: imap.gmail.com
needs_app_password: true
order: 100
---

Gmail never accepts your Google Account password from a mail client like
mcp4mail. You need an **app password**, and Google only lets you create one
once **2-Step Verification** is on.

## 1. Turn on 2-Step Verification

Open
[myaccount.google.com/signinoptions/twosv](https://myaccount.google.com/signinoptions/twosv),
sign in if Google asks, and follow the steps to switch 2-Step Verification on.

Skip this if it is already on.

## 2. Create an app password

1. Open
   [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords).
2. Name it `mcp4mail` and choose **Create**.
3. Copy the 16-letter password it shows. Google shows it only once; the
   spaces do not matter.

Use these two links rather than the menus: Google renames its account pages
often, and the "App passwords" entry is no longer listed on the Security page.

## 3. The settings to use

| Setting     | Value                                       |
|-------------|---------------------------------------------|
| IMAP server | `imap.gmail.com`                            |
| Port        | `993`                                       |
| Security    | SSL/TLS                                     |
| Username    | your full Gmail address, e.g. `jana@gmail.com` |
| Password    | the app password from step 2                |

## If it still does not connect

- **"Invalid credentials"** — you are most likely using your Google Account
  password. Create an app password as in step 2.
- **There is no "App passwords" page** — 2-Step Verification is off, or you
  sign in only with a security key under Advanced Protection, which does not
  allow app passwords.
- **A work or school account (Google Workspace)** — your administrator can
  switch off IMAP or app passwords for the whole organisation. If either is
  off, only they can turn it back on; ask them to allow IMAP access and app
  passwords for your account.
- **It worked and then stopped** — changing your Google Account password
  revokes every app password. Create a new one.
