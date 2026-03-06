#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

total=0
missing_count=0

while IFS= read -r -d '' f; do
  total=$((total + 1))
  fm=$(awk '
    BEGIN { infm=0 }
    /^---[[:space:]]*$/ {
      if (infm == 0) { infm=1; next }
      else { exit }
    }
    infm==1 { print }
  ' "$f")

  title=$(printf '%s\n' "$fm" | sed -n 's/^title:[[:space:]]*//p' | head -n1)
  description=$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n1)
  datev=$(printf '%s\n' "$fm" | sed -n 's/^date:[[:space:]]*//p' | head -n1)

  missing=()
  [[ -z "${title// /}" ]] && missing+=(title)
  [[ -z "${description// /}" ]] && missing+=(description)
  [[ -z "${datev// /}" ]] && missing+=(date)

  if ((${#missing[@]} > 0)); then
    missing_count=$((missing_count + 1))
    echo "MISSING | $f | ${missing[*]}"
  fi
done < <(rg -0 -l '^draft:\s*false' content --glob '**/*.md' | sort -z)

echo "SUMMARY | published=$total | missing=$missing_count"

if ((missing_count > 0)); then
  exit 1
fi
