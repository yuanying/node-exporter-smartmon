#!/usr/bin/env bash
# Decides whether the weekly release cuts a new patch version.
#
# Usage: next-release.sh [--bots-only] <path>...
#
# The paths are the files the image is built from. When any of them
# changed between the latest vX.Y.Z tag and HEAD, prints
# "release=true" and the next tag as "tag=vX.Y.(Z+1)"; otherwise
# prints "release=false". The output is meant for $GITHUB_OUTPUT.
# Tags of any other form, such as v0.17.0.1, are not versions here.
#
# --bots-only is the release on the merge of a vulnerability fix: it
# also requires every commit since the tag, merge commits aside, to be
# authored by Renovate or vuln-responder. Otherwise it prints
# "release=false" and the commits that stopped it as "blocked=<sha>...",
# oldest first, and the release is left to a person.
set -euo pipefail

# The authors, by the email GitHub gives the commits of an app.
BOTS=(
  '29139614+renovate[bot]@users.noreply.github.com'
  '348762456+fraction-vuln-responder[bot]@users.noreply.github.com'
)

bots_only=false
if [[ ${1:-} == --bots-only ]]; then
  bots_only=true
  shift
fi

latest=$(git tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)
if [[ -z $latest ]]; then
  echo "no vX.Y.Z tag to release after" >&2
  exit 1
fi

if git diff --quiet "$latest" HEAD -- "$@"; then
  echo "nothing changed since $latest" >&2
  echo "release=false"
  exit 0
fi

if $bots_only; then
  blocked=()
  while read -r sha email; do
    bot=false
    for b in "${BOTS[@]}"; do
      [[ $email == "$b" ]] && bot=true
    done
    $bot || blocked+=("$sha")
  done < <(git log --reverse --no-merges --format='%H %ae' "$latest..HEAD")
  if ((${#blocked[@]} > 0)); then
    echo "commits since $latest other than Renovate's and vuln-responder's:" >&2
    git show --no-patch --format='%h %an <%ae> %s' "${blocked[@]}" >&2
    echo "release=false"
    echo "blocked=${blocked[*]}"
    exit 0
  fi
fi

IFS=. read -r major minor patch <<< "${latest#v}"
echo "changed since $latest:" >&2
git diff --stat "$latest" HEAD -- "$@" >&2
echo "release=true"
echo "tag=v${major}.${minor}.$((patch + 1))"
