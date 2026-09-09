#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

fail=0
IMAGE='hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png'
README='hardware/circuit layout/README.md'

if [ ! -f "$IMAGE" ]; then
  echo "FAIL: missing verified wiring-table image: $IMAGE"
  fail=1
elif ! file "$IMAGE" | grep -q 'PNG image data'; then
  echo "FAIL: verified wiring-table file is not PNG image data"
  fail=1
fi

if [ -e docs/wiring/diagrams ]; then
  echo 'FAIL: retired docs/wiring/diagrams directory still exists'
  fail=1
fi

if [ -e tests/test_wiring_diagrams.py ]; then
  echo 'FAIL: retired SVG generator test still exists'
  fail=1
fi

if rg -q '^```mermaid' docs/wiring/README.md; then
  echo 'FAIL: unverified wiring Mermaid still exists'
  fail=1
fi

for text in \
  '2026-09-07-stage1-verified-wiring-table.png' \
  '20260901_CircuitBoardDesign_002_Fixed.jpg' \
  'power-up, I2C on GPIO2/GPIO3, and movement of three servos' \
  'does not verify all eight servos' \
  'Wi-Fi in the photographed stacked placement'; do
  if ! grep -Fq "$text" "$README"; then
    echo "FAIL: Stage 1 README missing: $text"
    fail=1
  fi
done

ACTIVE_DOCS=(ARCHITECTURE.md AGENTS.md docs/wiring docs/upstream hardware)

if rg -n 'docs/wiring/diagrams|diagrams/README|[12][ab]-(no-uwb|uwb)-' \
  "${ACTIVE_DOCS[@]}" --glob '*.md'; then
  echo 'FAIL: active documentation still references retired wiring diagrams'
  fail=1
fi

for file in ARCHITECTURE.md AGENTS.md docs/wiring/expansion.md hardware/bom.md; do
  if ! grep -Fq 'Makerfabs ESP32 UWB DW3000 WROOM' "$file"; then
    echo "FAIL: $file does not name the selected Makerfabs WROOM board"
    fail=1
  fi
  if ! grep -Fq 'delivered-board verification' "$file"; then
    echo "FAIL: $file does not preserve the delivered-board verification gate"
    fail=1
  fi
done

if ! grep -Fq 'two evaluation boards' hardware/bom.md; then
  echo 'FAIL: BOM does not record the two evaluation boards'
  fail=1
fi

if ! grep -Fq 'exact UART GPIOs' docs/wiring/expansion.md; then
  echo 'FAIL: expansion guide does not gate exact UART GPIOs'
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo 'Stage 1 evidence checks passed'
