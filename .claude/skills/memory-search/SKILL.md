---
name: memory-search
description: "Search LLM Memory Notes and return compact, filtered summary. Use when CLAUDE.md instructs to search memory notes before coding, or when user says 'search memory', 'hledej v paměti', 'co víme o X'."
context: fork
allowed-tools: ToolSearch, mcp__llmmn-production__SearchNotesTool, mcp__llmmn-production__RateNoteTool
---

# Memory Search Skill

Search LLM Memory Notes and return a compact, relevant summary.
This skill exists to prevent verbose memory note results from bloating the main session context.

## ⛔ HARD RULES — read first

1. **You ARE the forked context.** Never return "I'm an agent without MCP access" or delegate the search back to the parent — that defeats the whole point of the fork. Either the search succeeds, or you return the error block at the bottom.
2. **Search with the MCP tool `mcp__llmmn-production__SearchNotesTool`, not with `ReadMcpResourceTool` and not with `curl`.** MCP *tools* propagate into forked subagents (the built-in resource reader does not), and the tool returns the same results as the REST endpoint plus each note's ID. If its schema is only named and not loaded, `ToolSearch(query: "select:mcp__llmmn-production__SearchNotesTool,mcp__llmmn-production__RateNoteTool")` loads it first.

## In a run driven by mcptask_runner

A headless run may not reach this skill: a forked skill is one more thing that has
to start before the search does, and when it does not, the child is left with an
instruction it cannot follow. A project that wants its agents to search before
every task says so in `work_steps.before` of `config/mcptask_runner.yml` and names
the `SearchNotesTool` call there — the runner relays the text into every prompt
and adds nothing to it.

## Input

The user message contains:
- **query**: what to search for (task topic, architecture concept, pattern name)
- **memory_identifier**: which memory to search (e.g., `projektoid_ii`, `wv-runner`)

If memory_identifier is not specified, check the project's CLAUDE.md for the identifier.

## Step 1: Search Memory Notes

Run up to 2 searches (task-specific + architecture if needed):

```
mcp__llmmn-production__SearchNotesTool(identifier: "MEMORY_ID", query: "QUERY", limit: 3)
```

**Always use `limit: 3`** to reduce noise. Each result has `id`, `title`, `content`,
`score` (similarity, higher = closer), `rating`, `updated_at`, and when present
`supersedes` and `rating_reasons` (the latest -1 votes with their reasons). Hidden
notes (superseded, or rated -3 or lower) are not returned; do not pass
`include_hidden`.

## Step 2: Filter and Summarize

For each returned note, evaluate relevance to the query:
- **Relevant** (high): directly relates to the task/topic being searched
- **Marginally relevant** (medium): same area of codebase but different feature
- **Irrelevant**: completely unrelated → discard from output

A note with `rating_reasons` is a warning: weigh the reasons before relying on it.

### Rating — after the summary, for the notes you actually used

Rating is how wrong and superseded notes leave the search, so do it every time:

- A note you **used** for the answer and found right → `mcp__llmmn-production__RateNoteTool(identifier: "MEMORY_ID", note_id: ID, rating: 1)`.
- A note that is **wrong or outdated** (contradicted by the code, by another note, or by what the caller told you) → `rating: -1` with a short `reason` (required, shown to everyone who reads the note). Add `superseded_by_note_id` only when a better note in the same memory already replaces it.
- A note you did **not** use (irrelevant, or only marginal and left out) gets **no rating**.

One counted vote per note per day; a second vote the same day replaces the first.
Never invent an ID: use only an `id` from this search's results.

## Step 3: Return Compact Output

Return ONLY this structured format:

```
## Memory Search: "QUERY" (MEMORY_ID)

### [Note Title] (relevance: high/medium) — note #ID, rating R, updated YYYY-MM-DD
- **Pattern**: [key pattern or approach used, 1-2 lines]
- **Files**: [key file paths, max 5]
- **Gotchas**: [important pitfalls or decisions, 1-2 lines]

### [Next Note Title] (relevance: high/medium) — note #ID, rating R, updated YYYY-MM-DD
...

### Rated
- #ID +1 / #ID -1 (reason) — or "none used"


### No relevant notes found
(if nothing matched)
```

## Rules

- **MAX 150 words per note summary** — strip PR numbers, test counts, full locale structures, verbose implementation details
- **DISCARD irrelevant notes entirely** — do not include them in output
- **Focus on PATTERNS and DECISIONS** — what approach was used, what file structure to follow, what pitfalls to avoid
- **Include file paths** — these are the most actionable piece of information
- **Never include**: full code blocks, test output, PR descriptions, CI results, locale YAML structures

## Error handling

If the tool is unavailable, errors, or returns empty `results`, return the exact error — do not fall back to another route and do not fabricate notes:

```
## Memory search error
- Tool: mcp__llmmn-production__SearchNotesTool
- Memory: MEMORY_ID
- Query: QUERY
- Error: <exact tool error or response>
```
