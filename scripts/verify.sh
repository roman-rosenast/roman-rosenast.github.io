#!/usr/bin/env bash
# scripts/verify.sh
# Verifies that ../knitting/projects.md is valid for site generation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNITTING_DIR="$(cd "$SCRIPT_DIR/../../knitting" && pwd 2>/dev/null)" || {
  echo "ERROR: ../knitting directory not found (expected at: $SCRIPT_DIR/../../knitting)"
  exit 1
}
PROJECTS_FILE="$KNITTING_DIR/projects.md"
SUPPORTED_EXTS="jpg jpeg png gif webp"

errors=0
warnings=0
block_num=0

# ── File existence ────────────────────────────────────────────────────────────
if [[ ! -f "$PROJECTS_FILE" ]]; then
  echo "ERROR: projects.md not found at: $PROJECTS_FILE"
  exit 1
fi

# ── Split into blocks on '---' and process each ───────────────────────────────
# Collect all titles to detect duplicates
declare -A seen_titles

while IFS= read -r block; do
  [[ -z "$block" ]] && continue
  block_num=$((block_num + 1))
  block_errors=0
  echo ""
  echo "Block $block_num:"

  # Title
  title=$(echo "$block" | grep -m1 '^## ' | sed 's/^## *//' | xargs)
  if [[ -z "$title" ]]; then
    echo "  ✗ Missing ## heading (project title)."
    block_errors=$((block_errors + 1))
    errors=$((errors + 1))
  else
    title_lower=$(echo "$title" | tr '[:upper:]' '[:lower:]')
    if [[ -n "${seen_titles[$title_lower]+_}" ]]; then
      echo "  ✗ Duplicate title: \"$title\""
      block_errors=$((block_errors + 1))
      errors=$((errors + 1))
    else
      seen_titles[$title_lower]=1
      echo "  Title    : $title"
    fi
  fi

  # Disallow non-H2 headings
  bad_headings=$(echo "$block" | grep -E '^#[^#]|^#{3,}' || true)
  if [[ -n "$bad_headings" ]]; then
    echo "  ✗ Contains non-H2 headings (only ## is allowed)."
    block_errors=$((block_errors + 1))
    errors=$((errors + 1))
  fi

  # Description
  desc=$(echo "$block" | grep -m1 '^description:' | sed 's/^description: *//' | xargs)
  if [[ -z "$desc" ]]; then
    echo "  ✗ Missing or empty \"description:\" field."
    block_errors=$((block_errors + 1))
    errors=$((errors + 1))
  else
    short_desc="${desc:0:60}"
    [[ ${#desc} -gt 60 ]] && short_desc="$short_desc…"
    echo "  Desc     : $short_desc"
  fi

  # Images path
  img_path=$(echo "$block" | grep -m1 '^images:' | sed 's/^images: *//' | xargs)
  if [[ -z "$img_path" ]]; then
    echo "  ✗ Missing \"images:\" field."
    block_errors=$((block_errors + 1))
    errors=$((errors + 1))
  else
    abs_path="$KNITTING_DIR/$img_path"
    if [[ ! -d "$abs_path" ]]; then
      echo "  ✗ images: folder does not exist: $abs_path"
      block_errors=$((block_errors + 1))
      errors=$((errors + 1))
    else
      img_count=0
      for ext in $SUPPORTED_EXTS; do
        count=$(find "$abs_path" -maxdepth 1 -iname "*.${ext}" | wc -l | xargs)
        img_count=$((img_count + count))
      done
      if [[ $img_count -eq 0 ]]; then
        echo "  ⚠ images: folder exists but contains no supported images (jpg/jpeg/png/gif/webp): $abs_path"
        warnings=$((warnings + 1))
      else
        echo "  Images   : $img_path ($img_count image$([ "$img_count" -eq 1 ] && echo "" || echo "s"))"
      fi
    fi
  fi

  if [[ $block_errors -eq 0 ]]; then
    echo "  ✓ valid"
  fi

done < <(awk 'BEGIN{b=""} /^---$/{print b; b=""; next} {b=b"\n"$0} END{if(b~/[^[:space:]]/) print b}' "$PROJECTS_FILE")

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────"
echo "Blocks found : $block_num"

if [[ $errors -gt 0 ]]; then
  echo ""
  echo "Verification FAILED ($errors error$([ "$errors" -eq 1 ] && echo "" || echo "s"))"
  exit 1
else
  if [[ $warnings -gt 0 ]]; then
    echo "Warnings     : $warnings"
  fi
  echo ""
  echo "Verification PASSED ✓"
  exit 0
fi
