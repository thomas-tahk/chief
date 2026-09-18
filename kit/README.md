# Onboarding a repo

`install.sh <owner/repo>` does everything that can be automated: it opens a PR
adding the workflow, the seed files and the CLAUDE.md block, and it creates the
three labels.

What follows is everything it **cannot** do. Each item is a click in a web UI
with no API behind it that a script or a cloud run can reach. Step 0 proved each
of these the hard way, by failing on it.

## One-time, per account

- [ ] **Cloud environment → Network access → Custom**, add `*.vercel.app`
      (or whatever host serves your previews), with *"Also include default list
      of common package managers"* checked.
      Without this the quality gate cannot load a preview at all: the proxy
      returns `000 … connect_rejected`, and Playwright reports
      `net::ERR_TUNNEL_CONNECTION_FAILED`. Verified blocked 2026-09-18.

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

- [ ] **Previews must actually build.** If the repo has a `vercel.json` with an
      `ignoreCommand` that exits 0 on preview, previews are skipped entirely and
      there will be nothing for the gate to look at. priority-post is in exactly
      this state as of 2026-09-18.

## Then check it works

Open an issue, give it a done-gate, label it `build`. Within a minute the issue
should get a comment linking a live cloud session. If it does not, the workflow
run under the repo's Actions tab says why.
