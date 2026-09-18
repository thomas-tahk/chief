# chief — Step 0 results

Run 2026-09-18. Gate for Step 0 was: *a written yes/no plus fallback for all five unknowns.*

Evidence comes from one cloud routine run ([session_01CNm2Z51wa7YWo1hpKdprjr](https://claude.ai/code/session_01CNm2Z51wa7YWo1hpKdprjr), routine `trig_01DhRVVaVgjJsWNXMbRnBdsj`) against the throwaway repo [thomas-tahk/chief-probe](https://github.com/thomas-tahk/chief-probe), plus the [routines documentation](https://code.claude.com/docs/en/routines) and local inspection of priority-post.

## Answers

| # | Question | Answer |
|---|---|---|
| 1 | Can a cloud run merge a PR / turn on auto-merge? | **YES, direct merge** — proven end to end. Auto-merge arming is one setting short of proven |
| 2 | Can a cloud session start another cloud job? | **YES** — proven, a child session ran to completion |
| 3 | Can a cloud run publish the HTML options page? | **YES** — the Artifact tool is available in-session and published a live page |
| 4 | What is the daily routine-run cap? | **Cap exists; the number is account-only.** One-off runs are exempt |
| 5 | Are Vercel previews login-protected? | **Moot as configured** — previews are not built at all. Protection status still unverified |

---

## 1. Merging a PR — YES (direct merge)

Answered on the second attempt, after installing the Claude GitHub App on the repo
([session_01QE7DREKLNwUiMqrsEr2oJ9](https://claude.ai/code/session_01QE7DREKLNwUiMqrsEr2oJ9), 272s).

A cloud run opened its own PR and merged it into `main`, unattended:

```json
mcp__github__merge_pull_request(pullNumber=2, merge_method="squash")
→ {"sha":"e9f3a8ed74d783eee5b85cf90056651331f36f32","merged":true,
   "message":"Pull Request successfully merged"}
```

Verified on the remote, not just claimed:

```
cad9729..e9f3a8e  main -> origin/main
e9f3a8e Probe B: set counter to 2 (#2)
cad9729 Seed scratch repo for chief Step 0 experiments
```

Everything on the path works: `git push` of a `claude/`-prefixed branch (no complaint, no
branch-name rejection), `mcp__github__create_pull_request` (PRs #1, #2, #3), and
`mcp__github__add_issue_comment` for PR comments. No rate-limit or quota message anywhere in the run.

### Auto-merge — the tool exists, the arming path is untested

`mcp__github__enable_pr_auto_merge` **is available** in a cloud run and is GraphQL-backed, so
the earlier worry — that auto-merge is GraphQL-only and therefore unreachable — is wrong. Calling
it returned:

```
Auto-merge is not enabled for this repository.
Enable it in repository Settings → General → Pull Requests → Allow auto-merge.
```

That is a repo setting, not a capability limit. I have since turned it on for `chief-probe`
(`allow_auto_merge=true`). Two things remain unproven, and they are worth stating precisely:

- **No cloud-run tool can flip that setting.** There is no `mcp__github__update_repository`.
  So *"Allow auto-merge"* joins the GitHub App install as a one-time manual click in the §8 install kit.
- **Arming was never exercised.** GitHub refuses to arm auto-merge on a PR that is already
  mergeable — there must be something to wait for (a required check or a required review).
  `chief-probe` has neither, and adding branch protection to create the condition was blocked by
  the local permission classifier.

**I am deliberately not chasing this further.** The condition auto-merge needs — a PR held up by
a required check — is exactly what a real repo with CI provides by itself. Testing it on a
synthetic repo with a fake required check would prove less than testing it in Step 1 on
priority-post, where the checks are real. Carried forward as a Step 1 verification, not a Step 0 hole.

**Fallback if arming turns out to fail:** direct merge already works, so a mechanical PR can be
merged outright once the run has seen its checks pass, or it waits for your tap. The spec's written
fallback — *"every PR waits for your tap"* — is the floor, and we are above it.

### What the first attempt established

The first run failed every write path on one upstream cause — the Claude GitHub App was not
installed on the repo:

```
remote: Claude doesn't have GitHub access to thomas-tahk/chief-probe for your organization.
An org admin can install the Claude GitHub App at
https://github.com/apps/claude/installations/select_target
fatal: unable to access 'https://github.com/thomas-tahk/chief-probe/': The requested URL returned error: 403
```

Four independent attempts, all 403:

| Path | Result |
|---|---|
| `git push` | 403, with the App-install message above |
| `mcp__github__create_branch` | `403 Resource not accessible by integration` |
| `mcp__github__push_files` | `403 Resource not accessible by integration` |
| `mcp__github__create_or_update_file` | `403 Resource not accessible by integration` |

Reads worked fine (`mcp__github__get_me`, `list_branches`), confirming the token is live and scoped read-only for this repo.

**Repo onboarding is a hard gate, not a nicety.** A repo with no App install is read-only to cloud runs. Spec §8 already lists this as a one-time manual click; Step 0 confirms nothing works without it.

### Correction to the spec

Spec §10 unknown 1 says *"`gh` is installed"*. **It is not.**

```
/bin/bash: line 1: gh: command not found
```

GitHub access in a cloud run is through `mcp__github__*` tools and plain `git`, not the `gh` CLI. Anything in the kit or the chief's run-mode prompt that shells out to `gh` will fail. This affects the PR-writing and label-reading steps throughout §3 and §7.

## 2. Starting another cloud job — YES

This was the load-bearing unknown, and the docs pointed the wrong way (*"You are inside a cloud session → manage routines from the web UI instead"*). That restriction applies to the `/schedule` command, not to the underlying capability.

A cloud session has a `Claude_Code_Remote` MCP connector exposing:

```
mcp__Claude_Code_Remote__create_session
mcp__Claude_Code_Remote__fire_trigger
mcp__Claude_Code_Remote__create_trigger
mcp__Claude_Code_Remote__list_sessions
mcp__Claude_Code_Remote__get_session
```

The probe called `create_session` and it was accepted:

```json
{"id":"session_01RjvkwPrmLiusKqAh7h13Ct","title":"chief-probe-b-test",
 "session_status":"SESSION_STATUS_PENDING","origin":"claude_code_mcp_seed"}
```

The child session ran and printed `CHIEF PROBE B OK`, verified through `get_session`. Separately, the `Agent` tool in a cloud session exposes `isolation: "remote"` as a second path to the same thing.

**Consequence for the design:** desk mode can dispatch build jobs itself. The spec's fallback — *"Desk chief replies with a pre-filled 'Build this' link you tap"* — is not needed.

It also makes spec §8's GitHub Action questionable. That Action existed only to bridge label→run because nothing else could fire a job. Two things now complicate it:

- GitHub triggers are native, but cover only `pull_request` and `release` events. **There is no issue-labeled event**, so `build` on an issue still has no native path.
- A long-lived desk chief could poll or be told directly, dispatching via `create_session`.

The Action is still the only way to make labeling an issue from a phone start a run with nothing else awake. Keep it, but it is now one option among several rather than the only mechanism.

## 3. Publishing the options page — YES

The Artifact tool is available inside a cloud run and published a live page:

**https://claude.ai/artifact/5nAghj8aaTHnZ1kQUXfEvp**

The `idea` → options-page flow needs no GitHub Pages fallback and no Markdown-comment degradation. The run can hand back a real URL.

The Pages fallback was not testable on the first run — enabling Pages is a write, and writes were 403. Untested, and now unnecessary. PR comments are confirmed available (`mcp__github__add_issue_comment`), so the second fallback channel exists too.

## 4. Daily routine cap — exists, number is account-only

From the [routines docs](https://code.claude.com/docs/en/routines):

> routines have a daily cap on how many runs can start per account

The number is not published; it is shown at [claude.ai/code/routines](https://claude.ai/code/routines) and [claude.ai/settings/usage](https://claude.ai/settings/usage). **Still to be read off the account.**

Three things soften this:

- **One-off runs do not count against the cap.** A one-off schedule fires once at a timestamp, then auto-disables.
- Sessions started by `create_session` from inside a run carry `origin: claude_code_mcp_seed`, not a routine fire — whether those count against the routine cap is **unverified**, and worth knowing, because it decides whether the chief's own dispatches are metered.
- With usage credits on, runs past the cap continue on metered overage instead of being rejected.

**Fallback if tight** (unchanged from the spec): drop the routine and use pre-filled links as the trigger. Now joined by a better one: dispatch via `create_session` from a desk chief.

## 5. Vercel preview protection — moot as configured

priority-post does not build previews at all. From `vercel.json`:

```json
{"ignoreCommand": "if [ \"$VERCEL_ENV\" = \"preview\" ]; then exit 0; else exit 1; fi"}
```

Exit 0 skips the build, so every preview deploy is skipped. This was done in `991facb` to clear a red check, not for auth — the memory on this was right.

So there is currently no preview URL to be protected. Whether Vercel Authentication would gate one if previews were re-enabled is **unverified** (needs the Vercel dashboard, or a throwaway branch with `ignoreCommand` flipped).

**This matters less than expected**, because of what Step 0 found instead — see below.

---

## New findings the spec did not anticipate

### Playwright is preinstalled, with browsers

```
Version 1.56.1
chromium  chromium-1194  chromium_headless_shell-1194  ffmpeg-1011
```

Spec §5's quality gate — *"the issue's done-gate is actually exercised in the cloud (Playwright for UI)"* — needs no setup script. This is the single best news in Step 0 for the gate's feasibility.

### Network egress is restricted — and `*.vercel.app` is blocked

**Answered 2026-09-18 by a follow-up probe**
([session_01DJEoSBs4U9QnJ5zS7BKDts](https://claude.ai/code/session_01DJEoSBs4U9QnJ5zS7BKDts), 101s).
The risk flagged below turned out to be real. Vercel is not on the Trusted allowlist:

| URL | Code | |
|---|---|---|
| `https://priority-post.vercel.app` | `000` | **BLOCKED** |
| `https://knowflow.vercel.app` | `000` | **BLOCKED** |
| `https://vercel.com` | `000` | **BLOCKED** |
| `https://github.com` | `400` | reachable |
| `https://api.github.com` | `200` | reachable |
| `https://registry.npmjs.org` | `200` | reachable |
| `https://example.com` | `000` | **BLOCKED** — the control, so the policy is unchanged and the result is trustworthy |

Playwright reports the same denial as `net::ERR_TUNNEL_CONNECTION_FAILED`:

```
Launching chromium... Chromium launched successfully.
Navigating to https://priority-post.vercel.app ...
Navigation error: page.goto: net::ERR_TUNNEL_CONNECTION_FAILED
Element counts: 0 <button>, 0 <a>
```

**The gate's machinery is fine; only its reach is not.** Chromium launched, drove,
and wrote a 27 KB screenshot — the failure is purely the proxy.

**Fix (one manual click, no code):** the environment's **Network access** →
**Custom** → add `*.vercel.app`, with *"Also include default list of common package
managers"* checked. That is a cloud-environment setting; no tool inside a run can
change it, so it joins the one-time-clicks checklist.

**Second gotcha, found the same way:** Playwright is installed **globally**, so
`import { chromium } from 'playwright'` fails with `ERR_MODULE_NOT_FOUND`. Use
`createRequire(import.meta.url)('/opt/node22/lib/node_modules/playwright')` or set
`NODE_PATH=/opt/node22/lib/node_modules`. Any quality-gate script that does the
obvious thing will fail on this first.

### The original finding



`example.com` was **denied**:

```
000 [agent-proxy] example.com:443 — connect_rejected
(the egress proxy denied the CONNECT (organization policy) or could not reach the destination)
```

`api.anthropic.com` was reachable (HTTP 404 from Cloudflare — a response, not a rejection).

The Default environment uses **Trusted** network access: a fixed allowlist of package registries and common dev domains. ~~Whether `*.vercel.app` is on that allowlist is unverified.~~ **It is not — see above.**

This supersedes unknown 5 in importance. Preview *reachability from the run* is the binding constraint; preview *auth* is downstream of it. Unknown 5 cannot even be asked until the allowlist is widened.

### Runtime versions

`node v22.22.2` · `python 3.11.15` · `git 2.43.0` · no `gh`

---

## Step 0 gate: met

All five have a written answer and a fallback. Nothing here blocks Step 1.

Two answers are partial, and neither is worth more Step 0 effort:

- **Auto-merge arming** (unknown 1) needs a PR held up by a real required check to test honestly.
  priority-post has real checks; a scratch repo does not. Better tested in Step 1.
- **The exact daily cap number** (unknown 4) is still unread. It matters much less now that
  unknown 2 came back YES — the chief can dispatch via `create_session` instead of firing routines,
  and one-off runs are exempt from the cap anyway.

### Carry into Step 1

- Purge `gh` from the kit and the chief's run-mode prompt; use `mcp__github__*`
- Add **"Allow auto-merge"** to the §8 one-time-clicks checklist, next to the GitHub App install —
  no cloud-run tool can set it
- ~~Verify `*.vercel.app` egress before trusting the done-gate.~~ **Done — it is blocked.**
  Add `*.vercel.app` to the environment's allowed domains; until then the gate cannot see a preview
- Arm auto-merge on a real PR with real checks, and confirm it lands
- Check whether `create_session` children count against the routine cap

### Cleanup owed

- `thomas-tahk/chief-step0` — wedged mid-visibility-change, abandoned. Needs deleting *(the local token lacks `delete_repo`)*
- `thomas-tahk/chief-probe` — unknown 1 is closed, so this can go too. PR #3 holds the run's own writeup if you want to read it before deleting
- Routine `trig_01DhRVVaVgjJsWNXMbRnBdsj` — delete; Step 0 is done with it
- Routine `trig_01CQbE2BFnw6wYixzgasDkbo` (*Weekly cross-project activity report*) — unrelated leftover, already disabled, last fired 2026-06-26. Superseded by the GitHub Actions version. Its prompt opens *"the gh CLI is authenticated"*, which Step 0 disproves — the likely reason it stopped working. Safe to delete
