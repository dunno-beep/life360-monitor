#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export GH_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
REPO="${REPO:-life360-monitor}"
command -v gh >/dev/null || { echo "pkg install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web

git add -A && git commit -qm "fix: config, perms, ids, urls" || true
git branch -M main
if ! git remote get-url origin >/dev/null 2>&1; then
  gh repo create "$REPO" --public --source=. --push
else
  git push -q -u origin main
fi

if gh api -X POST "repos/{owner}/{repo}/pages" \
     -f "source[branch]=main" -f "source[path]=/docs" >/dev/null 2>&1; then
  echo "pages enabled"
else
  echo "! enable Pages by hand: Settings > Pages > main > /docs"
fi

gh workflow run ios.yml; gh workflow run android.yml
while :; do
  n=$(gh run list --limit 20 --json status --jq '[.[]|select(.status!="completed")]|length')
  [ "$n" -eq 0 ] && break; echo "  $n running"; sleep 20
done

mkdir -p ~/dl && cd ~/dl
for wf in ios.yml android.yml; do
  id=$(gh run list --workflow="$wf" --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run download "$id" || echo "  (nothing for $wf)"
done
find ~/dl \( -name '*.ipa' -o -name '*.apk' \) | sort
