# Connecting an MCP client

mcp4mail is a remote MCP server. You give your AI client one URL, sign in to mcp4mail in the browser window
the client opens, approve access, and the client can read and search the mailboxes you connected.

| You use | The URL |
| --- | --- |
| The hosted service | `https://mcp4mail.online/mcp` |
| Your own instance | `https://<your host>/mcp`, exactly the value of `HITCH_RESOURCE_URI` (see the [self-hosting guide](self-hosting.md#hitch_resource_uri-must-match-your-public-url-exactly)) |

Connect at least one mailbox in the mcp4mail web app first; otherwise the client connects but finds nothing.

## What the sign-in looks like

Every client below uses the same OAuth 2.1 flow, so the part on your side is always the same:

1. The client opens a browser window on mcp4mail. Sign in if you are not signed in already.
2. A "Connect &lt;client&gt;" screen names the client asking for access and what it asks for: to search and
   read the mail in the mailboxes you connected. Press **Approve access** (or **Deny access**).
3. The browser hands you back to the client, which now lists the mcp4mail tools.

The client never sees your mailbox passwords, only a token for mcp4mail. Every mailbox stays read-only unless
you switch on "Allow the AI to make changes to this mailbox" for it in mcp4mail.

The client steps below come from each client's own documentation, linked in every section. Clients change their
menus often; if what you see differs, the linked page is the one to trust.

## Claude (claude.ai and Claude Desktop)

Source: [Getting started with custom connectors using remote MCP](https://support.claude.com/en/articles/11175166-getting-started-with-custom-connectors-using-remote-mcp)

Custom connectors are added to your Claude account, so one connector works on claude.ai and in Claude Desktop.
They are available on the Free (one custom connector), Pro, Max, Team and Enterprise plans.

1. Go to **Customize > Connectors**.
2. Click **+ Add**, then **Add custom connector**.
3. Enter a name (for example `mcp4mail`) and the URL from the table above, then click **Continue**.
4. Review the detected authentication settings and click **Continue**. Under **Authentication** choose
   **Sign in now** (or **Sign in when needed**), then click **Add**.
5. Approve access on the mcp4mail screen when it opens.

To use it in a chat, click **+** at the lower left of the chat, then **Connectors**, and switch mcp4mail on.

On Team and Enterprise plans only owners (and on Enterprise, custom roles allowed to manage connectors) add
custom connectors, under **Organization settings > Connectors**; members then find it under
**Customize > Connectors** and click **Connect** to sign in with their own mcp4mail account.

Claude's servers make the connection, not your computer, so a self-hosted instance must be reachable from the
internet.

## Claude Code

Source: [Connect Claude Code to tools via MCP](https://code.claude.com/docs/en/mcp)

```bash
claude mcp add --transport http mcp4mail https://mcp4mail.online/mcp
```

Add `--scope user` to have it in all your projects instead of only the current one. Then sign in, either by
running `/mcp` inside Claude Code and following the steps in your browser, or from your shell:

```bash
claude mcp login mcp4mail
```

`claude mcp logout mcp4mail` clears the stored sign-in.

## ChatGPT

Source: [Connect from ChatGPT](https://developers.openai.com/apps-sdk/deploy/connect-chatgpt)

OpenAI's documentation currently describes adding a remote MCP server as a plugin:

1. Open [chatgpt.com/plugins](https://chatgpt.com/plugins).
2. Select the plus button, then **Add custom MCP server**.
3. Enter a name and description, and under **Connection** the URL from the table above, including `/mcp`.
4. Set up authentication (OAuth), read the risk warning and confirm, then select **Create as a plugin**.
5. Review the tools ChatGPT found, install the plugin and approve access on the mcp4mail screen.

In a new conversation, type `@` in the prompt box and select the plugin.

OpenAI has renamed this feature several times (developer mode, connectors, apps, plugins), and whether you can
add a custom MCP server depends on your plan and, on business plans, on your workspace's policy. Their
documentation does not give one consistent list of plans or menu paths; check the linked page for yours.

## Cursor

Source: [Model Context Protocol (MCP)](https://cursor.com/docs/context/mcp)

Add mcp4mail to `~/.cursor/mcp.json` (all projects) or `.cursor/mcp.json` in a project:

```json
{
  "mcpServers": {
    "mcp4mail": {
      "url": "https://mcp4mail.online/mcp"
    }
  }
}
```

Cursor supports OAuth for remote servers and discovers the sign-in from the server, so no client ID or
secret goes into the file. Enable or manage the server under **Customize** in the sidebar. Cursor's page does
not describe the sign-in step itself; expect the mcp4mail approval screen in your browser when Cursor first
connects.

## VS Code

Sources: [Add and manage MCP servers in VS Code](https://code.visualstudio.com/docs/copilot/customization/mcp-servers),
[MCP configuration reference](https://code.visualstudio.com/docs/copilot/reference/mcp-configuration)

Run **MCP: Add Server** from the Command Palette, choose **HTTP** and enter the URL from the table above. Or
add it to `.vscode/mcp.json` in a workspace, or to your user `mcp.json` (**MCP: Open User Configuration**):

```json
{
  "servers": {
    "mcp4mail": {
      "type": "http",
      "url": "https://mcp4mail.online/mcp"
    }
  }
}
```

Confirm that you trust the server when VS Code asks. VS Code's reference says a browser window opens for
authorization on the first connection; approve access on the mcp4mail screen. Then use the tools from the Chat
view; **Configure Tools** in the chat input turns individual tools on or off. Workspace servers do not start
in restricted mode (an untrusted workspace).

## Troubleshooting

- **Use the exact URL.** For the hosted service it is `https://mcp4mail.online/mcp`: `https`, the `/mcp` path,
  no trailing slash. A different spelling of the URL is a different server to the client.
- **Self-hosted and the client fails during or right after sign-in:** check `HITCH_RESOURCE_URI` first. It must
  match the URL you gave the client exactly (scheme, host, port and path), and the client compares it with the
  server's metadata. The app and its web UI work normally when it is wrong; only MCP clients fail. See
  [the self-hosting guide](self-hosting.md#hitch_resource_uri-must-match-your-public-url-exactly).
- **https is required.** Plain http is accepted only for `localhost` in development; put the app behind a
  TLS-terminating proxy.
- **Moved your instance to a new domain?** Update `HITCH_RESOURCE_URI`, then remove mcp4mail from every client
  and add it again with the new URL.
- **A message you just received is not found.** Search runs on mcp4mail's own index of your mail headers,
  refreshed about every 15 minutes, so mail newer than that is not searchable yet. `list_mail_accounts` shows
  `indexed_at` (when the index was last refreshed) and `sync_errors` (folders that failed to sync).
- **Connected, but no accounts.** Connect a mailbox in the mcp4mail web app; the client sees only the mailboxes
  of the mcp4mail account you approved access for.
- **A write tool is refused.** That mailbox is read-only. Its owner switches on "Allow the AI to make changes to
  this mailbox" in mcp4mail and ticks what the AI may do.
