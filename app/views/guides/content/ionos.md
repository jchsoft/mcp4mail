---
title: IONOS
provider: ionos
summary: Use the IMAP server for your IONOS country, your full address and the mailbox password — not the IONOS account password.
imap_host: imap.ionos.com
needs_app_password: false
order: 170
---

IONOS runs a separate mail server for each country it sells in. There is no
app password, but the password you need is the **mailbox** one, not the one
for your IONOS customer account.

## 1. Pick the server for your IONOS country

| You signed up at | IMAP server        |
|------------------|--------------------|
| `ionos.com` (US) | `imap.ionos.com`   |
| `ionos.de`       | `imap.ionos.de`    |
| `ionos.co.uk`    | `imap.ionos.co.uk` |
| another country  | `imap.ionos.` followed by that site's ending, e.g. `imap.ionos.es` |

## 2. Have your mailbox password ready

Use the password you set for the mailbox. If you do not know it, open
**Email** in your IONOS account, choose the mailbox and set a new password.

## 3. The settings to use

| Setting     | Value                                        |
|-------------|----------------------------------------------|
| IMAP server | from step 1                                  |
| Port        | `993`                                        |
| Security    | SSL/TLS                                      |
| Username    | your **full** address, e.g. `jana@firma.de`  |
| Password    | your mailbox password                        |

## If it still does not connect

- **"Authentication failed"** — you are probably using the IONOS account
  password. Use the mailbox password from step 2.
- **Nothing answers on the server** — check the server ending matches the
  IONOS site where you bought the mailbox.
