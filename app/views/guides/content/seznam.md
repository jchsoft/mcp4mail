---
title: Seznam.cz (Email.cz)
provider: seznam
summary: IMAP is off by default. Switch it on in Seznam settings, then sign in with your full address.
imap_host: imap.seznam.cz
needs_app_password: false
order: 10
---

Seznam Email keeps IMAP **switched off** until you turn it on. Until you do,
every mail client — mcp4mail included — is refused with a login error, even
with the right password. It takes a minute.

## 1. Switch on IMAP in Seznam

1. Sign in at [email.seznam.cz](https://email.seznam.cz).
2. Open **Settings** (the gear icon, top right).
3. Go to **Email clients** (*Poštovní klienti*, also labelled POP3/IMAP).
4. Turn on **IMAP access** and save.

## 2. Check whether you need an app password

If your Seznam account uses **two-step verification**, your normal password
will not work for IMAP. Create an app password in your Seznam account security
settings (*Hesla pro aplikace*) and use that instead. Without two-step
verification, your normal Seznam password is fine.

## 3. The settings to use

| Setting    | Value                                        |
|------------|----------------------------------------------|
| IMAP server | `imap.seznam.cz`                            |
| Port       | `993`                                        |
| Security   | SSL/TLS                                      |
| Username   | your **full** address, e.g. `jana@seznam.cz` |
| Password   | your Seznam password, or the app password    |

The username is the whole address, including `@seznam.cz` (or `@email.cz`,
`@post.cz`, `@spoluzaci.cz`) — just the part before the `@` is refused.

## If it still does not connect

- **"Authentication failed" right after switching IMAP on** — Seznam can take a
  few minutes to apply the change. Wait, then try again.
- **It worked and then stopped** — you may have switched on two-step
  verification since; create an app password as in step 2.
- **You use your own domain on Seznam** — the server is still
  `imap.seznam.cz`, and the username is still your full address on your domain.
