#!/usr/bin/env bash
# Tests next-release.sh against throwaway repositories.
# Usage: .github/scripts/next-release_test.sh
set -euo pipefail

script=$(cd "$(dirname "$0")" && pwd)/next-release.sh
failures=0

# Creates a repository whose history has the tags of this one, the
# four-part v0.17.0.1 included, with v0.19.0 on its last commit.
setup() {
  repo=$(mktemp -d)
  cd "$repo"
  git init -q
  git config user.email test@example.com
  git config user.name test
  for tag in v0.14.0 v0.14.0.1 v0.17.0 v0.17.0.1 v0.18.0 v0.19.0; do
    echo "$tag" > Dockerfile
    git add -A
    git commit -qm "$tag"
    git tag "$tag"
  done
}

commit() {
  mkdir -p "$(dirname "$1")"
  echo change >> "$1"
  git add -A
  git commit -qm "change $1"
}

renovate='renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>'
responder='fraction-vuln-responder[bot] <348762456+fraction-vuln-responder[bot]@users.noreply.github.com>'
person='O. Yuanying <yuanying@fraction.jp>'

# Commits a change to the file as the author, "Name <email>".
commit_as() {
  local name=${1% <*} email=${1##*<}
  GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=${email%>} commit "$2"
}

# Runs the script with the options before the paths, e.g. --bots-only.
expect() {
  local name=$1 want=$2 got
  shift 2
  got=$("$script" "$@" Dockerfile smartmon.sh) || got="exit $?"
  if [[ $got == "$want" ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    echo "  want: ${want//$'\n'/ }"
    echo "  got:  ${got//$'\n'/ }"
    failures=$((failures + 1))
  fi
  cd /
  rm -rf "$repo"
}

setup
expect "no change since the latest tag" "release=false"

setup
commit .github/workflows/docker.yml
commit renovate.json
commit README.md
expect "only workflows, renovate.json and docs changed" "release=false"

setup
commit Dockerfile
expect "Dockerfile changed" $'release=true\ntag=v0.19.1'

setup
commit smartmon.sh
expect "smartmon.sh changed" $'release=true\ntag=v0.19.1'

setup
git tag v0.19.0.1
git tag v0.9.9
commit smartmon.sh
expect "four-part and lower tags are not taken as the latest" $'release=true\ntag=v0.19.1'

setup
git tag v0.19.10
commit Dockerfile
expect "versions compare as numbers, not as text" $'release=true\ntag=v0.19.11'

setup
git tag --list | xargs git tag -d > /dev/null
commit Dockerfile
expect "no vX.Y.Z tag" "exit 1"

# --bots-only: the release on the merge of a vulnerability fix.

setup
commit_as "$renovate" Dockerfile
expect "bots only: Renovate's change" $'release=true\ntag=v0.19.1' --bots-only

setup
commit_as "$responder" Dockerfile
expect "bots only: vuln-responder's change" $'release=true\ntag=v0.19.1' --bots-only

setup
commit_as "$renovate" Dockerfile
commit_as "$responder" smartmon.sh
expect "bots only: Renovate's and vuln-responder's changes" $'release=true\ntag=v0.19.1' --bots-only

setup
git checkout -qb vuln-responder/fix
commit_as "$responder" Dockerfile
git checkout -q -
GIT_AUTHOR_NAME='O. Yuanying' GIT_AUTHOR_EMAIL=yuanying@fraction.jp \
  git merge -q --no-ff -m "Merge pull request #9" vuln-responder/fix
expect "bots only: the merge commit a person made is not counted" $'release=true\ntag=v0.19.1' --bots-only

setup
commit_as "$person" README.md
human=$(git rev-parse HEAD)
commit_as "$responder" Dockerfile
expect "bots only: a person's commit stops the release" "release=false"$'\n'"blocked=$human" --bots-only

setup
commit_as "$person" smartmon.sh
first=$(git rev-parse HEAD)
commit_as "$renovate" Dockerfile
commit_as "$person" .github/workflows/release.yml
second=$(git rev-parse HEAD)
expect "bots only: every commit of a person is listed, oldest first" "release=false"$'\n'"blocked=$first $second" --bots-only

setup
commit_as 'renovate[bot] <someone@example.com>' Dockerfile
fake=$(git rev-parse HEAD)
expect "bots only: the name alone is not a bot" "release=false"$'\n'"blocked=$fake" --bots-only

setup
commit_as "$responder" README.md
expect "bots only: nothing the image is built from changed" "release=false" --bots-only

setup
commit_as "$person" smartmon.sh
commit_as "$responder" Dockerfile
expect "weekly: a person's commit is released as before" $'release=true\ntag=v0.19.1'

if ((failures > 0)); then
  echo "$failures failed"
  exit 1
fi
