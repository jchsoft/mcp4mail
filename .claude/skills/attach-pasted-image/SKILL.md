---
name: attach-pasted-image
description: Attach an image the user pasted into this Claude Code chat (a screenshot, an annotated mockup) to an mcptask.online task or story as a file. The model sees a pasted image only as pixels, never as bytes, so this skill recovers the real file from the session transcript. Use when the user says "přilož obrázek k úkolu", "přidej screenshot k tasku", "přilož to k úkolu #N", "připoj screenshot", "attach this screenshot to task #N", "attach the image I pasted", "add this image to the piece", or pastes an image and asks for it to be saved on a piece.
allowed-tools: Bash, Read
---

# Attach a pasted image to an mcptask.online piece

An image pasted into the chat reaches you as pixels. You cannot base64 it into
`AddAttachmentTool` and you have no file to give `CreateUploadUrlTool`. Claude
Code does keep every pasted image on disk, inside this session's transcript, and
`mcptask_runner pasted-images` writes it out as a real file.

Never type or reproduce base64 by hand: the image is not in your context as text,
and a guessed payload is a corrupt attachment.

## 1. Get the file

```bash
mcptask_runner pasted-images --last N
```

`N` is how many of the most recent pastes the user means (default 1). Only images
the user pasted count; a screenshot a tool returned does not. It prints one JSON
line per file, oldest first:

```json
{"path":"/tmp/claude-pasted-images/<session>/screenshot-20261109-170000-1.png","file_name":"screenshot-20261109-170000-1.png","byte_size":123456,"checksum":"<base64 md5>","content_type":"image/png","pasted_at":"2026-11-09T16:00:00Z"}
```

A non-zero exit says what is missing: `CLAUDE_CODE_SESSION_ID` unset (not inside a
Claude Code session), no transcript on disk, or no pasted image in it. Tell the
user that; do not look for the image elsewhere.

## 2. Upload each file

`mcp__mcptask-online__CreateUploadUrlTool` with `file_name`, `byte_size`,
`checksum` and `content_type` exactly as printed, plus the piece's account code
and relative id. It returns a signed upload URL and the headers to send. Then:

```bash
curl -X PUT --data-binary @<path> -H "<each returned header>" "<upload url>"
```

Expect HTTP 204. Anything else: report it, do not retry with different bytes.

(The claude.ai mcptask connector, in the desktop app, takes the same three steps.)

## 3. Attach it

- To attach the file alone: `mcp__mcptask-online__AddAttachmentTool` with the
  returned `signed_blob_id`.
- When the user said what the image shows: `mcp__mcptask-online__AddMessageTool`
  with that text as `content` and the `signed_blob_id`, so the picture arrives
  with its explanation.
- A user who cannot edit the piece (Tester, Client, Brigadier) cannot use
  `AddAttachmentTool`; use `AddMessageTool` for them.

Finish by telling the user which piece got which file.
