#!/usr/bin/env bash
# Decides whether the weekly release cuts a new patch version.
#
# Usage: next-release.sh <path>...
#
# The paths are the files the image is built from. When any of them
# changed between the latest vX.Y.Z tag and HEAD, prints
# "release=true" and the next tag as "tag=vX.Y.(Z+1)"; otherwise
# prints "release=false". The output is meant for $GITHUB_OUTPUT.
# Tags of any other form, such as v0.17.0.1, are not versions here.
set -euo pipefail

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

IFS=. read -r major minor patch <<< "${latest#v}"
echo "changed since $latest:" >&2
git diff --stat "$latest" HEAD -- "$@" >&2
echo "release=true"
echo "tag=v${major}.${minor}.$((patch + 1))"
