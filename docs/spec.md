# chief — spec v1

Written 2026-09-17. Settled over four rounds of grilling. Nothing built yet.

## 1. What this is

One agent — the **chief** — that you talk to. You bring ideas and judgment. It
breaks work down, hands it to builder agents in the cloud, throws away the bad
output, and brings you back a working thing to look at and one button to press.

It runs on Anthropic's cloud infrastructure on your Claude subscription, so it
keeps working with your laptop closed. It works on any GitHub repo you own; repos
are added one at a time, the first time you want work done in one.

### What it fixes (your stated pain)

| Pain | How this answers it |
|---|---|
| (a) Babysitting sessions: prompts, nudges, questions | Cloud runs are autonomous. The chief answers small questions itself and only escalates what touches your vision |
| (b) Re-entering a cold repo | Every agent PR updates `STATUS.md`; the chief reads it before proposing anything |
| (c) Turning a vague idea into a buildable spec | `idea` label → the chief returns up to 7 real options on a small HTML page; you pick; it writes the issue |

### What foundry got wrong, and what changed

| foundry | chief |
|---|---|
| Agent picked the work; 3 of 4 proposals declined | You start work. Suggestions only on request, or as follow-ups on a finished PR |
| Custodial loops (survey, warn, nudge) | No scheduled scanning. Nothing runs unless you asked for something |
| ~12 repos, Discord, cross-app glue | GitHub only. One repo at a time. No Discord |
| Output capped by your review capacity | The chief filters before you see anything; you review running results, not diffs |
| Memory recorded "it's live", never yield | Memory records what shipped; a single check-in question at two weeks |

## 2. Roles

**You** — decide what gets built, judge UX/visuals/functionality, merge.

**The chief** — one agent definition, two modes:
- **Desk mode**: you talk to it (phone or terminal). It reads repo state and open
  issues, turns talk into issues, starts build jobs, and shows you what's waiting.
- **Run mode**: it runs inside each cloud build job. Splits the work, dispatches
  builders, verifies, rejects bad output, writes the PR.

**Builders** — subagents inside a run. Implementer + reviewer per task. Engine:
start with the superpowers `subagent-driven-development` skill, kept as a single
swappable line in the chief's prompt. Judge it on real tasks; replace if it drags.

## 3. The loop

```
idea (phone/terminal/issue)
  └─ chief: options page (1 if obvious, max 7) ─ you pick
       └─ chief writes the issue: intent, done-gate, decision line
            └─ label `build` → cloud run
                 └─ implementer + reviewer subagents
                      └─ gate: build+tests green · done-gate exercised
                        · reviewer approved · mocked/stubbed list
                        └─ pass → PR (mechanical: auto-merge; visible: `your-call`)
                        └─ fail → retry ×2 → "stuck" note with options
```

## 4. The decision line

**Brings to you:** anything a user sees (UX flow, visuals, wording, feature
scope); anything that costs money or adds an outside service; hard-to-undo data
or schema changes; auth and security; deleting features or data.

**Decides alone:** internal implementation, file layout, tests, refactors,
choosing between equivalent libraries, fixing its own bugs.

Each repo may adjust this line in its `CLAUDE.md`.

**Overruling:** reply on the PR ("undo decision 3, use X"). With the Claude
GitHub App installed, the PR's session picks up review comments (auto-fix) and
makes the change. Nothing extra to build.

## 5. The quality gate

Nothing reaches you until all four hold:

1. Build and tests pass
2. The issue's done-gate is actually exercised in the cloud (Playwright for UI)
3. A separate reviewer subagent approves
4. A list of everything still mocked, stubbed, or hardcoded on the gate path

Failure → 2 retries → a short "stuck" note with options. Never a broken PR.

## 6. Audit trail — one source of truth

`DECISIONS.md` at each repo root. Newest first. One line per entry:

```
2026-09-20 · Used server-side pagination over infinite scroll · list is unbounded · #42 · run
```

- The PR description **points at** the entry; it does not keep its own copy.
- The cloud session transcript is evidence the entry links to. Sessions can be
  archived or deleted, so git is the durable layer.
- **One line per entry, hard rule.** foundry's own lesson: append-only without a
  size limit turns into a swamp nobody reads.
- Chat is never the record. Anything settled in desk mode is written into the
  issue before work starts.

## 7. Surfaces

**Labels** (three): `idea` (return options), `build` (do it), `your-call`
(chief applies; waiting on you).

**Your queue**: saved GitHub search `is:open user:thomas-tahk label:your-call`.
Upgrade to a page only if that feels clunky.

**PR format**: 5-line summary · preview link · what's mocked · numbered decisions
(linking to the `DECISIONS.md` entries) · direct merge link · follow-up options.

**Merging**: mechanical PRs turn on GitHub auto-merge and land themselves once
checks pass. Visible PRs wait for your tap.

## 8. Infrastructure

| Piece | Choice |
|---|---|
| Compute | Claude Code cloud sessions — Anthropic-hosted VMs, subscription, laptop-off |
| Trigger | A tiny GitHub Action fires the routine endpoint when you apply `build`. No AI runs in Actions, so it costs nothing |
| Manual start | A pre-filled `claude.ai/code?prompt=…&repositories=…` link on every issue |
| Config in cloud | **Cloud runs see only what is committed.** `~/.claude` does not travel. The kit commits the chief and its skills to `.claude/skills/` in each repo |
| Concurrency | One job per repo (no merge conflicts), no overall cap |
| GitHub access | Claude GitHub App per repo (needed for auto-fix), or `/web-setup` token |

### Per-repo install kit

The chief opens a PR adding:
- `.claude/skills/` — the chief and the build engine
- `CLAUDE.md` section — decision line, done-gate style, how to run and preview
- `STATUS.md` seed and empty `DECISIONS.md`
- `.github/workflows/chief-fire.yml` — the label trigger
- the three labels
- preview config

One-time manual clicks (GitHub App install, cloud environment, secrets) come as a
`wizard` checklist.

## 9. Repo layout (`thomas-tahk/chief`)

```
chief/
├─ prompts/chief.md          # the chief: desk mode + run mode
├─ skills/                   # what gets vendored into target repos
├─ kit/                      # install templates (workflow, CLAUDE.md block, labels)
├─ install.sh                # onboard a repo → opens a PR
└─ docs/spec.md              # this file
```

## 10. Unknowns — Step 0 proves these before anything is built

Each is a yes/no experiment, done in an afternoon, with a written fallback.

| # | Question | Fallback if no |
|---|---|---|
| 1 | Can a cloud run merge a PR / turn on auto-merge? (`gh` is installed; the GitHub proxy may restrict it) | Every PR waits for your tap; mechanical ones get a one-tap link |
| 2 | Can a cloud session start another cloud job (fire the routine endpoint)? | Desk chief replies with a pre-filled "Build this" link you tap |
| 3 | Can a cloud run publish the HTML options page? | Commit the page to the branch and serve via GitHub Pages, or post options as a Markdown comment |
| 4 | What is the daily routine-run cap on this account? | If tight, drop the routine and use pre-filled links as the only trigger |
| 5 | Are Vercel previews login-protected? (priority-post previews were disabled in `991facb` to fix a red check, not for auth) | Screenshots and GIFs from the run, plus one-command local checkout |

## 11. Build order

**Step 0 — prove the unknowns.** Gate: a written yes/no plus fallback for all five.

**Step 1 — the build path, one repo.** Kit + chief run mode + the label trigger.
Gate: *I label an issue `build` from my phone, and a PR comes back that builds,
runs, and shows me a working preview — laptop off the whole time.*

**Step 2 — desk mode.** The chief you talk to; it writes issues and starts jobs.
Gate (v1 done-gate): *With my laptop off, I tell the chief an idea from my phone.
It files an issue, a cloud run builds it without me, and I get one link. I open
the preview, it works, and I tap merge.*

**Step 3 — the idea path.** `idea` → options page → pick → issue.
Gate: *I drop a vague idea and get back an options page I can pick from.*

**Step 4 — second repo, different stack.** Proves it is project-agnostic.
Gate: *Adding a repo takes one command plus a short checklist.*

## 12. Non-goals

Discord. priority-post integration. Scheduled suggestion loops. beads (revisit
only if a single epic outgrows GitHub sub-issues). Multi-repo parallel work in one
job. Agents merging visible changes. Numeric throughput targets.

## 13. Check-in

At two weeks the chief asks one question — *"Is this getting your backlog
built?"* — next to a plain list of what shipped and what got stuck. No targets.
Memory records what it produced, never that it is running.
