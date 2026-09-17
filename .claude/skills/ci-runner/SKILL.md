---
name: ci-runner
description: Run local CI (bin/ci) and report what needs fixing. Use when user says "bin/ci", "run ci", "lokální CI", "spusť CI", "pusť CI", "ci check", or wants to run the full CI pipeline locally.
allowed-tools: Skill, Read
---

# CI Runner

Orchestrates `/ci-start` + `/ci-wait` to run local CI safely on a machine shared with other Claude agents. Preserves the global CI lock (`/tmp/claude_test_run.lock`) so two agents never run system tests at the same time.

You (the main agent) drive this state machine directly. Do NOT poll logs yourself. Do NOT use Monitor. Do NOT read `latest_ci-runner.log`. Your only tools here are the two sub-skills below.

`/ci-start` always runs `bin/ci` — that is the one command this family hard-codes, and it is a project convention rather than a framework's: whatever `bin/ci` shells out to is the project's own business. This skill therefore reads CI's output by its *shape*, never by the names of the tools underneath it.

## State machine

```
outer_iterations = 0
while outer_iterations < 10:
  outer_iterations += 1

  result = Skill(ci-start)
  parse result

  if result starts with "CI_LOCKED":
    # Another agent holds the lock. Wait for THEIR CI to finish,
    # then retry ci-start to acquire for ourselves.
    inner = 0
    while inner < 8:                       # 8 × 9min = 72min cap
      inner += 1
      w = Skill(ci-wait, args="other <OTHER_LOG>")
      if w starts with "NOT_FINISHED":
        continue
      if w starts with "FINISHED_OTHER":
        break                              # other agent done, go retry ci-start
      if w starts with "FAILED_EXTERNAL":
        report w to user, STOP
    else:
      report "Other agent's CI did not finish after 72 min. Lock may be stuck. Run ~/.claude/bin/test_lock status to inspect."
      STOP
    continue  # back to outer_iterations loop, retry ci-start

  if result starts with "CI_STARTED":
    # We launched. Wait for our own CI.
    max_waits = max(6, min(8, ceil(EXPECTED_SEC / 540) + 2))  # floor 6 → ≥54min; long suites run 30min+
    waits = 0
    while waits < max_waits:
      waits += 1
      w = Skill(ci-wait, args="self <CI_LOG>")
      if w starts with "NOT_FINISHED":
        # A NOT_FINISHED with an empty LAST= now carries a DIAG=/PROC= line.
        # PROC=dead means CI crashed producing no output — don't spin the full
        # cap; report the diagnostic and STOP. PROC=alive means it's just
        # silent (long build/setup step) — keep waiting.
        if w contains "PROC=dead":
          report "CI process died with no output. Log at CI_LOG. Diagnostic: <the DIAG=/PROC= lines>. Run ~/.claude/bin/test_lock kill to clean up." , STOP
        continue
      if w starts with "FINISHED_SELF":
        parse the ---BEGIN_LOG_TAIL---...---END_LOG_TAIL--- block and EXIT_CODE
        produce the structured report (see "Report format" below)
        save duration (see "After CI" below)
        STOP — DONE
      if w starts with "FAILED_EXTERNAL":
        report w, STOP
    report "Our CI did not finish after max_waits cycles. Log at CI_LOG. Run ~/.claude/bin/test_lock kill to clean up."
    STOP

  if result starts with "CI_ERROR":
    report the error and STOP

report "ci-start did not succeed after 10 outer iterations" and STOP
```

The 10-outer-iterations cap prevents infinite loops if the lock is pathologically stuck. In practice outer loop runs once (our CI) or twice (wait for other, then ours).

## The shape `bin/ci` prints

`bin/ci` is a convention, not one program: what it prints depends on what the
project built it out of. Two shapes are known, and a run matches one of them or
neither. Read whichever you are given rather than assuming the first.

### Shape A — one step block per step, closed by a summary block

Steps are delimited by a header line and closed by a verdict line:

```
--------------------------------------------------------------------------------
>> <step name>
--------------------------------------------------------------------------------
<the step's own output>

PASS (12.4s)
```

- `>> <step name>` opens a step. The name is whatever that project called it.
- `PASS (Ns)` / `FAIL (Ns)` closes it. `SKIP (<reason>)` replaces both when the step did not run.
- A failed step may be followed by a hint line and a note line, which are worth quoting verbatim — they are the author telling you how to fix it.

The run closes with a summary block:

```
================================================================================
CI SUMMARY
--------------------------------------------------------------------------------
  OK     <step name> (12.4s)
  FAIL   <step name> (3.1s)
  SKIP   <step name> - <reason>
================================================================================
N check(s) FAILED - do not merge
```

or, when nothing failed, `All checks passed - safe to merge` (with `(N skipped)` when some were).

### Shape B — one line per step, and no summary block anywhere

Some CI harnesses print no aggregation at all: no `CI SUMMARY`, no `>> `, no
`PASS (`. The whole machine-readable record is then one line per step, the emoji
at column 0:

```
✅ <step name> passed in 4.88s
❌ <step name> failed in 1m31.30s
✅ Continuous Integration passed in 8m6.64s
```

- The step name is whatever that project called it; the time is that step's own.
- The last line names the whole run rather than a step — it is the total, not an
  extra step. Do not count it in the step count.
- A failed run keeps running its remaining steps, so both spellings appear in
  one run. The step count is the `✅` lines minus that final aggregate; the
  failures are the `❌` lines.
- The step's own output sits above its line, not below it, and the run carries
  no per-step header to bound it. Take the failing tool's output from what
  precedes the `❌` line.

**Read the verdict from the words, not only from `EXIT_CODE`.** `bin/ci` is honest at both ends, but a status number that has travelled through a pipe is not — a run whose output says `FAILED - do not merge` is red no matter what exit code reached you.

**If you recognise no step markers at all, say so in the report.** An empty step list means this skill did not understand the output, which is a different thing from CI having reported nothing — and reporting the second when you mean the first is how a broken parser passes for a quiet CI. Quote the last few lines of what you did get and name what you were looking for (`>> `, `PASS (`, `CI SUMMARY`, `✅ … passed in`).

## Report format (on FINISHED_SELF)

`EXIT_CODE` is CI's exit code (0 = all green). On `EXIT_CODE=0`, `/ci-wait` emits `ALL_OK` with no log block — parent context stays clean. On non-zero, a `---BEGIN_LOG_TAIL---...---END_LOG_TAIL---` block follows containing a filtered tail (signal lines only; build chatter, deprecation warnings and dotted progress collapsed).

### On EXIT_CODE=0

`/ci-wait` emits an `ALL_OK` marker followed by the run's step record — the `CI SUMMARY` block (shape A) or the `✅ … passed in` lines (shape B) — and, when it recognises neither, the tail of the run with a `NO_SUMMARY_RECOGNISED` marker in front of it. Use those lines to fill the report; do NOT ask for the full log tail.

```
✅ CI passed — all steps green
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Steps: N passed (M skipped) | Time: Xm Ys
```

List the skipped steps by name and reason. A skipped step is not a passed one, and `bin/ci` prints the reason precisely so it can be repeated here. Shape B has no notion of a skipped step, so on those runs there are none to list; take `Time:` from its closing `Continuous Integration passed in <time>` line, and the step count from the `✅` lines that are not that one.

If `NO_SUMMARY_RECOGNISED` is present, report the run as green **and** say the summary could not be read, with the path to the log. Do not invent a step count.

### On EXIT_CODE != 0

Walk the tail for whichever shape the run printed — `>> <step>` headers and their `FAIL (Ns)` verdicts, or `❌ <step> failed in <time>` lines — then extract from each failed step's own output whatever it printed: a file and line, an offending rule or check name, a diff, a compiler message, a failing assertion. Which of those a step produces depends on the tool it ran, so take what is there rather than looking for a fixed shape. In shape B the step's output precedes its verdict line instead of following a header, so read upwards from the `❌`.

Emit:

```
❌ CI failed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[✅ or ❌ or ⏭] <step name>
   → <error detail, if failed>
...

🔧 To fix:
1. <concrete action>
2. <concrete action>
```

Be specific: file paths, line numbers, the actual failing assertion. Group similar errors. Quote the step's own hint line as the first fix when it printed one.

## After CI (FINISHED_SELF only)

Save the run's duration for next time's adaptive timeout. The log footer contains `Started: …` and `Finished: …` timestamps; compute the difference in milliseconds.

The cache path comes from `.claude/test-commands.json`'s `durations` key, defaulting to `.claude/test_durations.json`:

```bash
ruby -e '
require "json"
require "fileutils"
path = "REPLACE_DURATIONS"
FileUtils.mkdir_p(File.dirname(path))
data = File.exist?(path) ? JSON.parse(File.read(path)) : {}
# Replace with actual computed values:
data["ci"] = { "last_duration_ms" => <MS>, "last_run" => "<YYYY-MM-DD>" }
File.write(path, JSON.pretty_generate(data))
'
```

Skip this if `FINISHED_SELF` came with an `EXIT_CODE` that suggests the run was killed abnormally (e.g. 137 SIGKILL).

## Lock cleanup

You do NOT need to call `test_lock release`. `run_with_log` auto-releases the lock when `bin/ci` exits, via its internal `test_lock release_if_owner ci-runner` on-exit hook.

Only call `~/.claude/bin/test_lock kill` if the waiter loop exhausted its iteration cap without completion (runaway CI). Never bypass a valid lock held by another agent.

## Important

- **Never** poll the log file directly. Only the `/ci-wait` sub-skill does that, via `~/.claude/bin/ci_wait`.
- **Never** invoke Monitor for CI waits. `/ci-wait` already handles polling internally.
- **Never** read `~/.claude/logs/latest_ci-runner.log` — logs are now per-project at `~/.claude/logs/projects/<slug>/`. `/ci-start` returns the correct path; use it.
- **Never construct or guess the log path.** Always pass `CI_LOG=...` (from `/ci-start` output) or `OTHER_LOG=...` verbatim into `/ci-wait`. Project slugs are sha256 hashes, not human-readable names. Fabricated paths cause 9-minute NOT_FINISHED polling loops that spin until the iteration cap.
- **Never** report an empty step list as if CI had said nothing. See "The shape `bin/ci` prints".
- If `OTHER_LOG=unknown`, do NOT call `/ci-wait` with `"unknown"` — instead fall through to the outer retry loop and call `/ci-start` again after a brief delay; the other agent's log may have appeared by then.
- If `/ci-wait` returns `FAILED_EXTERNAL` with `REASON=log_missing` or `REASON=invalid_log_path`, STOP — do not retry. The path is wrong; user intervention needed.
- If you see `CI_LOCKED`, never try to kill or release the other agent's lock. Wait it out via `/ci-wait mode=other`.
