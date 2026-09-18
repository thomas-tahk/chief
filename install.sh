#!/usr/bin/env bash
# Onboard a repo to the chief: open a PR with the kit, and create the labels.
#
# Runs on your laptop, where `gh` exists. (It does not exist in cloud runs.)
# Everything this cannot automate is listed in kit/README.md — read it after.
#
#   ./install.sh thomas-tahk/pocket-draft

set -euo pipefail

REPO="${1:-}"
[ -n "$REPO" ] || { echo "usage: $0 <owner/repo>" >&2; exit 1; }

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit"
BRANCH="chief/install"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v gh >/dev/null || { echo "gh is required" >&2; exit 1; }
gh repo view "$REPO" >/dev/null || exit 1

create_labels() {
  jq -c '.[]' "$KIT/labels.json" | while read -r label; do
    name=$(jq -r .name <<<"$label")
    gh label create "$name" --repo "$REPO" \
      --color "$(jq -r .color <<<"$label")" \
      --description "$(jq -r .description <<<"$label")" \
      --force >/dev/null
    echo "  label: $name"
  done
}

seed_if_absent() {
  local src="$1" dest="$2"
  [ -e "$dest" ] && { echo "  kept existing $(basename "$dest")"; return; }
  cp "$src" "$dest"
  echo "  seeded $(basename "$dest")"
}

append_claude_block() {
  if [ -f CLAUDE.md ] && grep -q 'chief:begin' CLAUDE.md; then
    echo "  CLAUDE.md already has a chief block — left alone"
    return
  fi
  printf '\n' >> CLAUDE.md
  cat "$KIT/CLAUDE.md.block" >> CLAUDE.md
  echo "  appended the chief block to CLAUDE.md"
}

echo "Onboarding $REPO"
create_labels

gh repo clone "$REPO" "$WORK/repo" -- --depth 1 >/dev/null 2>&1
cd "$WORK/repo"
git checkout -b "$BRANCH" >/dev/null

mkdir -p .github/workflows
cp "$KIT/workflows/chief-fire.yml" .github/workflows/chief-fire.yml
echo "  added .github/workflows/chief-fire.yml"
seed_if_absent "$KIT/STATUS.md" STATUS.md
seed_if_absent "$KIT/DECISIONS.md" DECISIONS.md
append_claude_block

git add -A
git -c commit.gpgsign=false commit -q -m "Install the chief: label trigger, status and decision log

Adds the chief-fire workflow so labelling an issue 'build' starts a cloud
run, plus the STATUS.md and DECISIONS.md the run reads and updates.

Needs two repository secrets before it will fire: CHIEF_ROUTINE_ID and
CHIEF_ROUTINE_TOKEN. See the checklist in the PR body."

git push -q -u origin "$BRANCH"

gh pr create --repo "$REPO" --head "$BRANCH" \
  --title "Install the chief" \
  --body "$(cat <<'BODY'
Onboards this repo so an issue labelled `build` starts an autonomous cloud run
that opens a PR back here.

**This PR does nothing on its own.** It needs the one-time clicks below, none of
which have an API a script or a cloud run can reach.

- [ ] Install the [Claude GitHub App](https://github.com/apps/claude/installations/select_target) on this repo — without it every write from a run is a 403
- [ ] Settings → General → Pull Requests → **Allow auto-merge**
- [ ] Settings → Secrets and variables → Actions → add `CHIEF_ROUTINE_ID` and `CHIEF_ROUTINE_TOKEN`
- [ ] Confirm the run can reach whatever the done-gate must be exercised against — a server it starts itself on `localhost` works out of the box; a remote preview host needs adding to the environment's network allowlist, and must not be skipped by a `vercel.json` `ignoreCommand`
- [ ] Fill in the run/preview commands in the `CLAUDE.md` block, and adjust the decision line for this repo

Full detail: [`kit/README.md`](https://github.com/thomas-tahk/chief/blob/main/kit/README.md)
BODY
)"

echo
echo "PR opened. Finish the checklist in kit/README.md — the trigger stays inert until then."
