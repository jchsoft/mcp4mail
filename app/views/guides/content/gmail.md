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
- **It worked and then stopped** — changing your Google Account password
  revokes every app password. Create a new one.

### "The setting you are looking for is not available for your account"

In Czech: *"Nastavení, které hledáte, pro váš účet není k dispozici."*

Google shows this on
[myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
when your account cannot have app passwords yet.

1. Most often 2-Step Verification is off. Open
   [myaccount.google.com/signinoptions/twosv](https://myaccount.google.com/signinoptions/twosv),
   turn it on, then go back to the app passwords page.
2. If 2-Step Verification is already on, you probably sign in only with
   passkeys or security keys, or your account is in Google's Advanced
   Protection Program. Such an account cannot have app passwords until you add
   another second step, for example the Google Authenticator app, on the same
   2-Step Verification page.

If the 2-Step Verification page itself says it is not allowed, read the next
section.

### "2-Step Verification is not allowed for this account"

In Czech: *"Dvoufázové ověření pro tento účet není povoleno – Dokud
administrátor nepovolí dvoufázové ověření, nebude možné ho zapnout."*

Your account belongs to an organisation on Google Workspace, and its
administrator has not allowed 2-Step Verification. You cannot turn it on
yourself; send these steps to your administrator.

**Is this a Workspace account?** Yes, if your address is on your own domain
(for example `jana@yourcompany.com`, not `@gmail.com`) and that mail is
hosted by Google.

### For the Google Workspace administrator

Allow 2-Step Verification:

1. Open
   [admin.google.com/ac/security/2sv](https://admin.google.com/ac/security/2sv)
   (**Security** → **Authentication** → **2-Step Verification**).
2. Select the whole organisation, or just the user's organisational unit.
3. Tick **Allow users to turn on 2-Step Verification**. **Enforcement** can
   stay **Off** and **Methods** can stay **Any**.
4. Choose **Save**. The change can take a few minutes to reach the user,
   sometimes longer.

Allow IMAP access:

1. In [admin.google.com](https://admin.google.com) open **Apps** →
   **Google Workspace** → **Gmail** → **End User Access**.
2. Select the user's organisational unit.
3. Under **POP and IMAP access**, tick **Enable IMAP access for all users**
   and allow any IMAP client. Restricting it to OAuth mail clients shuts out
   mcp4mail, which signs in with an app password.
4. Save.

Then the user turns on 2-Step Verification, creates an app password and
connects with the settings above.
