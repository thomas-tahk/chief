# Onboarding a repo

`install.sh <owner/repo>` does everything that can be automated: it opens a PR
adding the workflow, the seed files and the CLAUDE.md block, and it creates the
three labels.

What follows is everything it **cannot** do. Each item is a click in a web UI
with no API behind it that a script or a cloud run can reach. Step 0 proved each
of these the hard way, by failing on it.

## One-time, per account

- [ ] **Only if a repo's done-gate must be exercised against a *remote* host:**
      cloud environment → Network access → Custom, add `*.vercel.app` (or
      whatever host serves your previews), with *"Also include default list of
      common package managers"* checked.
      Egress is allowlisted and `*.vercel.app` is blocked by default: the proxy
      returns `000 … connect_rejected` and Playwright reports
      `net::ERR_TUNNEL_CONNECTION_FAILED`. Verified blocked 2026-09-18.
      **`localhost` is not proxied**, so a repo whose playable surface is a
      server the run starts itself needs none of this.

- [ ] **A routine at [claude.ai/code/routines](https://claude.ai/code/routines)**
      with the prompt from [`routine-prompt.md`](routine-prompt.md).
      Repositories: `thomas-tahk/chief` **and** the target repo — both, or the
      run has no chief to follow.

- [ ] **An API trigger on that routine** → *Generate token*.
      Edit → Select a trigger → Add another trigger → API.
      **The token is shown once and cannot be retrieved later.**

## One-time, per repo

- [ ] **Install the Claude GitHub App** on the repo —
      [github.com/apps/claude](https://github.com/apps/claude/installations/select_target).
      Without it a cloud run is read-only: every write path returns
      `403 Resource not accessible by integration`, including plain `git push`.
      This is a hard gate, not a nicety.

- [ ] **Settings → General → Pull Requests → Allow auto-merge.**
      There is no `mcp__github__update_repository`, so no run can set this.
      Without it, mechanical PRs pile up waiting for a tap they did not need.

- [ ] **Settings → Secrets and variables → Actions**, add two repository secrets:
      | Secret | Value |
      |---|---|
      | `CHIEF_ROUTINE_ID` | the routine id, `trig_01…` |
      | `CHIEF_ROUTINE_TOKEN` | the API-trigger token from above |

- [ ] **The gate needs something real to drive.** Either a server the run can
      start itself (pocket-draft: `cd server && go run .` on `localhost:8080`),
      or a preview that actually builds. A repo with a `vercel.json`
      `ignoreCommand` that exits 0 on preview skips previews entirely and leaves
      the gate nothing to look at — priority-post is in exactly that state as of
      2026-09-18.

## Then check it works

Open an issue, give it a done-gate, label it `build`. Within a minute the issue
should get a comment linking a live cloud session. If it does not, the workflow
run under the repo's Actions tab says why.
