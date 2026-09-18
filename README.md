# chief

One agent you talk to. It breaks work down, hands it to builder agents in the
cloud, throws away the bad output, and brings back a working thing and one
button to press.

Runs on Anthropic's cloud on your Claude subscription, so it keeps working with
the laptop closed. Repos are onboarded one at a time.

Design: [`docs/spec.md`](docs/spec.md) ([rendered](docs/spec.html)).
What was proven before building: [`docs/step0-results.md`](docs/step0-results.md)
([rendered](docs/step0-results.html)).

## How a build happens

```
you label an issue `build`, from anywhere
  └─ .github/workflows/chief-fire.yml  (in the target repo)
       └─ POST /v1/claude_code/routines/{id}/fire   ·  text: repo + issue
            └─ cloud run: clones the target repo AND this one
                 └─ follows prompts/chief-run.md
                      └─ implementer + reviewer subagents
                           └─ quality gate: build green · done-gate actually
                             exercised · reviewer approved · mocked list written
                                └─ PR — auto-merge if mechanical,
                                        `your-call` if you'd see it
```

The label bridge exists because Claude Code's native GitHub triggers cover only
`pull_request` and `release`. There is no issue-labeled event, so the Action
catches the label and calls the routine's API trigger instead.

## Why the chief is not vendored into each repo

The routine clones **two** repositories: the target, and this one. So
`prompts/chief-run.md` is read from here at run time. Changing the chief is one
PR against this repo and every onboarded repo gets it, instead of a vendored
copy per repo drifting out of date.

## Layout

```
chief/
├─ prompts/chief-run.md   the chief in run mode — procedure, gate, PR format
├─ kit/                   what gets installed into a target repo
│  ├─ README.md           the one-time clicks no script can do
│  ├─ routine-prompt.md   what to paste into the routine
│  ├─ workflows/          chief-fire.yml, the label trigger
│  ├─ CLAUDE.md.block     decision line + how to run and preview
│  ├─ STATUS.md           seed
│  ├─ DECISIONS.md        seed
│  └─ labels.json         idea · build · your-call
├─ install.sh             onboard a repo → opens a PR
└─ docs/
```

## Onboarding a repo

```sh
./install.sh thomas-tahk/knowflow
```

Then finish [`kit/README.md`](kit/README.md). The trigger stays inert until you
do — and two of those items are hard gates, not polish: without the Claude
GitHub App every write from a run is a 403, and without `*.vercel.app` on the
environment's allowlist the quality gate cannot see a preview at all.
