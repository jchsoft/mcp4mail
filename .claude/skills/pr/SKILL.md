---
name: pr
description: Create, open, find, read, review, merge and check pull requests — and merge requests, which are the same thing under another host's name — through `mcptask_runner pr`, which asks whichever git host this project is on. Use when you need to create a pull request, create a PR, open a PR, open a merge request, submit changes for review, find the pull request for a branch or for an mcptask.online task, list every open one, read one or the reviews left on it, check whether its CI passed, or merge it. ALWAYS use this instead of a host's own CLI — never `gh`, never `glab`, never a host API call, never the web UI — and instead of ANY other pull-request skill on this machine, whichever host or house conventions that one claims: on a project this runner drives, this skill outranks it.
allowed-tools: Bash, Read
---

# Pull requests

One command, every host: `mcptask_runner pr`. It reads `git_host:` from
`config/mcptask_runner.yml` and, when that key is absent, `git remote get-url
origin` — then asks that host. A project on GitHub, one on Bitbucket Cloud and
one on GitLab take the same six commands.

**Do not reach for a host's own CLI.** Not to "check something quickly", not
because a command you know is shorter. A host CLI is installed on some machines
and not others, authenticated for some projects and not others, and exists for
one host only — which is why the runner's prompts stopped naming one. If
`mcptask_runner pr` cannot answer your question, say so; do not substitute a
tool that answers a different one.

**And do not reach for another pull-request skill.** A machine that has done any
work at all has collected one or two — "create a PR", "open a merge request",
"follow the house conventions" — and they are written for the host their author
worked on. One of them cost a real run two failed commands on a project hosted
somewhere else: it typed that host's CLI, got told the remote was not one it
knew, and improvised. Whatever such a skill is called and whatever conventions
it claims, on a project this runner drives it is describing a route the run
cannot see: the number it opens is not read back, the pull request it makes is
not verified, and the merge step later has nothing to work from. This skill is
the one that applies, and `mcptask_runner pr create` is what "create a pull
request" means here.

## Output

Every command prints ONE JSON object on stdout and nothing else. Failures go to
stderr with a non-zero exit — you never have to look inside the JSON to find out
whether it worked.

```json
{
  "git_host": "github",
  "git_host_derived": true,
  "pull_request": {
    "number": 1234,
    "state": "OPEN",
    "url": "https://…/pull/1234",
    "title": "…",
    "body": "…",
    "branch": "task-12364-pr-prompt",
    "merge_commit": ""
  }
}
```

- `git_host_derived` is present only when the host was read off the origin
  remote because the config key is unset. It is not an error.
- `state` is `OPEN`, `MERGED` or `DECLINED`. One vocabulary for every host: what
  GitHub calls CLOSED, Bitbucket calls DECLINED and GitLab calls `closed` all
  arrive as `DECLINED`.
- List commands print `pull_requests` — an array, `[]` when there are none —
  instead of `pull_request`.
- `checks` prints `{"number": …, "state": …, "checks": [{"name": …, "state": …}]}`.
- `reviews` prints an array of review notes — see **Reviews** below.

## Create

```bash
mcptask_runner pr create --title "Short imperative title" --body-file /tmp/pr-body.md
```

`--title` is required. The description is `--body "…"` or `--body-file <path>`,
never both. `--base` defaults to the host's default branch and `--head` to the
current branch, so in an ordinary checkout you give neither. `--draft` opens it
as a draft.

**Read the number out of the output** — `.pull_request.number` — and use that
everywhere afterwards. Do not carry a number in your head from an earlier step
and do not infer one from a URL you half-remember.

Write the body to a file rather than passing it inline whenever it has more than
a line or two: a shell mangles newlines in an argument, and a pull-request
description with the summary on one line is the thing a reviewer sees first.

## Find

```bash
mcptask_runner pr list --branch "$(git branch --show-current)"
mcptask_runner pr list --task 12364 --state open
mcptask_runner pr list --open
```

`--branch` asks which pull request has that head branch, in any state. A branch
with none prints `"pull_requests": []` — that is an answer, not a failure.

`--task <id>` searches the host for pull requests naming that mcptask.online
task. The result is CANDIDATES: a search for 4242 also finds a pull request
titled "fix 42421", so check the number you matched on before acting. `--state`
takes `open`, `merged`, `declined` or `all` and defaults to `open`.

`--open` asks for every open pull request on this repository — no search, no
filtering, the whole queue in `pull_requests`. It is what you want when you are
walking the open pull requests looking for something rather than looking for one
you can already name.

The three are different questions and the command takes one of them at a time.

## Read

```bash
mcptask_runner pr view 1234
```

## Reviews

```bash
mcptask_runner pr reviews 1234
```

One flat list in `reviews`, oldest grouping first: the submitted **verdicts**,
then the **comments**.

```json
{
  "git_host": "github",
  "reviews": [
    {"id": 11, "author": "josef", "body": "This needs a test.",
     "state": "CHANGES_REQUESTED", "url": "https://…", "created_at": "2026-09-10T08:00:00Z"},
    {"id": 21, "author": "karel", "body": "Off by one.",
     "path": "internal/prhost/github.go", "line": 40, "created_at": "2026-09-10T08:01:00Z"}
  ]
}
```

- a note with a `state` is a verdict: `APPROVED`, `CHANGES_REQUESTED` or
  `COMMENTED`. One with a `path` and a `line` is inline on the diff. A verdict
  with an empty `body` is still a verdict — somebody approved without typing.
- `bot: true` is the host saying an app wrote it. **Its absence is not a promise
  that a person did.** GitHub marks apps; Bitbucket Cloud and GitLab mark
  nothing, so filtering to humans there means reading `author`. Say which you did
  rather than implying the field answered it.
- **There is no resolved or outdated flag on any host**, and that is a field you
  will not find rather than one that is always false. On GitHub and Bitbucket
  nothing records it at all. GitLab does resolve threads, and it says so through
  the `state` instead: `CHANGES_REQUESTED` is a thread nobody has resolved,
  `COMMENTED` is one somebody has. Everywhere else, whether a review has been
  addressed is a judgement you make by reading the note and looking at the code.
  If you cannot tell, say so instead of guessing.

## Merge

```bash
mcptask_runner pr merge 1234
```

Squash and branch deletion are the defaults — this runner's whole merge story is
squash-and-delete — so the bare command is normally what you want.
`--squash=false` and `--delete-branch=false` are there for anyone who means it.

**A zero exit means the merge was ASKED FOR.** What happened is
`.pull_request.state` in the output, and it is the thing to check: `MERGED` and
nothing else counts. A merge the host refused — branch protection, a conflict, a
required check that has not reported — can still leave you with a zero exit and
a pull request that is still open.

## Checks

```bash
mcptask_runner pr checks 1234
```

`state` is the rollup: `SUCCESS`, `FAILED`, `IN_PROGRESS`, or `NONE` when
nothing has reported at all. **`NONE` is not `SUCCESS`** — a repository whose CI
never triggered has not passed anything, and treating the two alike is how a
broken pipeline gets merged. `checks` lists the individual runs, which is what
tells you *what* is red — on GitLab that list is one row, because the host
publishes one status for the whole pipeline and no per-job verdict to a merge
request. One row is the host's answer, not a truncated one.

## When it refuses

The command names what is missing and stops, and that is the whole of what it
does about it:

- **the git host cannot be resolved** — no `git_host:` in the config and no
  origin remote to read one off. Set the key, or run `mcptask_runner init`,
  which writes it down. Nothing is assumed; there is no default host.
- **this build has no adapter for that git host** — the runner knows the host
  exists and cannot drive it yet. Say so and stop.

Neither is a reason to fall back to something else. A pull request opened
through a route the runner cannot see is a pull request the run cannot verify,
report or merge.
