#!/usr/bin/env bash
# Tests smartmon.sh against the smartctl outputs in test/cases, served by
# test/fake-smartctl, and compares what it prints with test/expected.
# Usage: test/smartmon_test.sh
#        UPDATE_EXPECTED=1 test/smartmon_test.sh   (rewrites test/expected)
set -euo pipefail

dir=$(cd "$(dirname "$0")" && pwd)
script=$dir/../smartmon.sh
failures=0

# expect NAME CASE [VAR=VALUE...]: runs smartmon.sh on the case with the
# environment given, and compares with test/expected/NAME.prom.
expect() {
  local name=$1 case=$2 want=$dir/expected/$1.prom got
  shift 2
  got=$(env -u SMARTMON_USB_TYPES LC_ALL=C \
    SMARTCTL="$dir/fake-smartctl" \
    SMARTMON_SYSFS="$dir/cases/$case/sys" \
    FAKE_SMARTCTL_FIXTURES="$dir/cases/$case" \
    "$@" bash "$script" 2>&1 |
    sed -E 's/^(smartmon_smartctl_run\{[^}]*\}) [0-9]+$/\1 NOW/') || true
  if [[ ${UPDATE_EXPECTED:-} ]]; then
    printf '%s\n' "$got" > "$want"
  fi
  if diff -u "$want" <(printf '%s\n' "$got"); then
    echo "ok   $name"
  else
    echo "FAIL $name"
    failures=$((failures + 1))
  fi
}

# braque: the SATA SSD in --scan-open, and four USB bays behind a bridge
# smartctl does not know: sdb active, sdc spun down, sdd answering only
# as sat,12, sde empty. sdf is a disk not on USB.
expect usb usb SMARTMON_USB_TYPES='sat sat,12'
expect usb-default-types usb
expect usb-off usb SMARTMON_USB_TYPES=
expect nvme nvme

echo "${failures} failure(s)"
exit $((failures > 0))
