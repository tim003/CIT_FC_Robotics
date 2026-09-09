#!/usr/bin/env bash
# Mechanical consistency checks for the wiring documentation.
# The netlist is the source of truth; these checks stop the other
# documents from drifting away from it.
#
# Scope note: only the *deliverable* docs are checked. docs/superpowers/
# holds specs and plans, which legitimately discuss placeholders and
# rejected pin assignments, and would trip these rules by design.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }
ok()  { echo "  ok: $*"; }
# Only report a check as ok if it did not raise an error itself.
mark() { before=$fail; }
done_ok() { [ "$fail" -eq "$before" ] && ok "$*"; }

DOCS=$(find docs/wiring docs/upstream hardware -name '*.md' 2>/dev/null
       ls ARCHITECTURE.md AGENTS.md 2>/dev/null)
[ -n "$DOCS" ] || { echo "no deliverable docs found yet"; exit 0; }

# 1. No placeholders anywhere.
if grep -rniE '\b(TBD|TODO|FIXME|XXX)\b' $DOCS >/dev/null 2>&1; then
  err "placeholder markers found:"
  grep -rniE '\b(TBD|TODO|FIXME|XXX)\b' $DOCS >&2
else
  ok "no placeholders"
fi

# 2. Forbidden GPIOs must never be assigned a function.
#    Only flagged inside tables (lines starting with '|').
#    GPIO3 is deliberately absent from this list: it is a strapping pin,
#    but it strapping-selects the JTAG source only, gated by the
#    STRAP_JTAG_SEL eFuse which ships unburned. It carries our I2C SCL.
#    See docs/wiring/pin-map.md for the reasoning and the datasheet cite.
mark
for pin in 0 19 20 43 44 45 46 47 48; do
  if grep -rnE "^\|.*GPIO ?${pin}\b" $DOCS 2>/dev/null \
     | grep -viE 'reserved|do not use|forbidden|never|strapping|boot|USB|UART|RGB' >/dev/null; then
    err "forbidden GPIO${pin} appears as an assignment"
  fi
done
done_ok "no forbidden GPIO assignments"

# 3. I2C addresses must be exactly these two.
addrs=$(grep -rhoE '0x[0-9A-Fa-f]{2}' $DOCS | sort -u | tr '\n' ' ')
if [ "$(echo $addrs)" != "0x3C 0x40" ]; then
  err "unexpected I2C addresses: $addrs (expected '0x3C 0x40')"
else
  ok "I2C addresses correct"
fi

# 4. The dual-supply invariant must be restated wherever V+ appears.
# File-level, not line-level: the distinction is often stated across a
# sentence that wraps, so requiring VCC and 3V3 on one line is too brittle.
for f in $(grep -rlE 'V\+' docs/wiring 2>/dev/null | grep '\.md$'); do
  { grep -qi 'VCC' "$f" && grep -qiE '3[.V]?3' "$f"; } \
    || echo "WARN: $f mentions V+ without restating the VCC/V+ distinction" >&2
done
ok "dual-supply invariant checked"

# 5. RSTn must always carry the open-drain warning.
mark
for f in $(grep -rl 'RSTn' $DOCS 2>/dev/null); do
  grep -qiE 'open.?drain' "$f" || err "$f mentions RSTn without the open-drain warning"
done
done_ok "RSTn warning present wherever RSTn appears"

# 6. Internal links must resolve.
# Skip external schemes explicitly rather than by first letter: excluding
# anything starting with 'h' to dodge http also silently skipped every
# relative link under hardware/.
mark
for f in $DOCS; do
  d=$(dirname "$f")
  for l in $(grep -oE '\]\([^)#]+' "$f" 2>/dev/null | sed -E 's/^\]\(//'); do
    [ -z "$l" ] && continue
    case "$l" in http:*|https:*|mailto:*) continue;; esac
    fs_l=${l//%20/ }
    [ -e "$d/$fs_l" ] || [ -e "$fs_l" ] || err "$f: dead link -> $l"
  done
done
done_ok "internal links resolve"

# 7. Every GPIO used in the netlist must be declared in the pin map.
#    This is the cross-document check that keeps the netlist and the pin
#    map from disagreeing about what a pin is for.
if [ -f docs/wiring/netlist.md ] && [ -f docs/wiring/pin-map.md ]; then
  missing=$(comm -23 \
    <(grep -oE 'GPIO ?[0-9]+' docs/wiring/netlist.md | tr -d ' ' | sort -u) \
    <(grep -oE 'GPIO ?[0-9]+' docs/wiring/pin-map.md | tr -d ' ' | sort -u))
  if [ -n "$missing" ]; then
    err "netlist references GPIOs absent from the pin map: $(echo $missing)"
  else
    ok "every netlist GPIO is declared in the pin map"
  fi
fi

# 8. Netlist row numbers must be unique and match the stated total.
if [ -f docs/wiring/netlist.md ]; then
  dupes=$(grep -oE '^\| [0-9]+ ' docs/wiring/netlist.md | tr -d '| ' | sort -n | uniq -d)
  [ -n "$dupes" ] && err "duplicate netlist row numbers: $(echo $dupes)"
  count=$(grep -cE '^\| [0-9]+ ' docs/wiring/netlist.md)
  stated=$(grep -oE 'total of \*\*[0-9]+\*\* connections' docs/wiring/netlist.md \
           | grep -oE '[0-9]+' | head -1)
  if [ -n "$stated" ] && [ "$stated" != "$count" ]; then
    err "netlist states $stated connections but has $count rows"
  else
    ok "netlist row numbering consistent ($count rows)"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "consistency checks FAILED" >&2
  exit 1
fi
echo "all consistency checks passed"
