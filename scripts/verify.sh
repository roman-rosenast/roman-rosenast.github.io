#!/usr/bin/env bash
# scripts/verify.sh
# Verifies that ../knitting/projects.md is valid for site generation.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNITTING_DIR="$(cd "$SCRIPT_DIR/../knitting" && pwd 2>/dev/null)" || {
  echo "ERROR: ../knitting directory not found (expected at: $SCRIPT_DIR/../knitting)"
  exit 1
}
PROJECTS_FILE="$KNITTING_DIR/projects.md"
SUPPORTED_EXTS="jpg jpeg png gif webp"

errors=0
warnings=0
block_num=0
seen_titles=""

# ── File existence ────────────────────────────────────────────────────────────
if [[ ! -f "$PROJECTS_FILE" ]]; then
  echo "ERROR: projects.md not found at: $PROJECTS_FILE"
  exit 1
fi

# ── Split into blocks on '---' and process each ───────────────────────────────

while IFS= read -r block; do
  [[ -z "$(echo "$block" | tr -d '[:space:]')" ]] && continue
  block_num=$((block_num + 1))
  block_errors=0
  echo ""
  echo "Block $block_num:"

  # Title
  title=$(echo "$block" | grep -m1 '^## ' | sed 's/^## *//' | xargs) || title=""
  if [[ -z "$title" ]]; then
    echo "  x Missing ## heading (project title)."
    block_errors=$((block_errors + 1))
    errors=$((errors + 1))
  else
    title_lower=$(echo "$title" | tr '[:upper:]' '[:lower:]')
    if echo "$seen_titles" | grep -qxF "$title_lower" 2>/dev/null; then
      echo "  x Duplicate title: \"$title\""
      block_errors=$((block_errors + 1))
      errors=$((errors + 1))
    else
      seen_titles="${seen_titles}"$'\n'"${title_lower}"
      echo "  Title   : $title"
    fi
  fi

  # Disallow non-H2 headings
  bad_headings=$(echo "$block" | grep -E '^#[^#]|^#{3,}' || true)
  if [[ -n "$bad_headings" ]]; then
    echo "  x Contains non-H2 headings (only ## is allowed)."
    block_errors=$((block_errors + 1))
    errors=$((errors + 1))
  fi

  # Description
  desc=$(echo "$block" | grep -m1 '^description:' | sed 's/^description: *//' | xargs) || desc=""
  if [[ -z "$desc" ]]; then
    echo "  x Missing or empty \"description:\" field."
    block_errors=$((block_errors + 1))
    errors=$((errors + 1))
  else
    # Truncate for display without bash 4 substring (use awk instead)
    short_desc=$(echo "$desc" | awk '{if(length($0)>60) print substr($0,1,60)"..."; else print}')
    echo "  Desc    : $short_desc"
  fi

  # Images path
  img_path=$(echo "$block" | grep -m1 '^images:' | sed 's/^images: *//' | xargs) || img_path=""
  if [[ -z "$img_path" ]]; then
    echo "  x Missing \"images:\" field."
    block_errors=$((block_errors + 1))
    errors=$((errors + 1))
  else
    abs_path="$KNITTING_DIR/$img_path"
    if [[ ! -d "$abs_path" ]]; then
      echo "  x images: folder does not exist: $abs_path"
      block_errors=$((block_errors + 1))
      errors=$((errors + 1))
    else
      img_count=0
      for ext in $SUPPORTED_EXTS; do
        count=$(find "$abs_path" -maxdepth 1 -iname "*.${ext}" | wc -l | tr -d ' ')
        img_count=$((img_count + count))
      done
      if [[ $img_count -eq 0 ]]; then
        echo "  ! images: folder exists but contains no supported images (jpg/jpeg/png/gif/webp)"
        echo "            $abs_path"
        warnings=$((warnings + 1))
      else
        suffix="s"; [ "$img_count" -eq 1 ] && suffix=""
        echo "  Images  : $img_path ($img_count image${suffix})"
      fi
    fi
  fi

  if [[ $block_errors -eq 0 ]]; then
    echo "  ok"
  fi

done < <(awk 'BEGIN{b=""} /^---$/{print b; b=""; next} {b=b"\n"$0} END{if(b~/[^[:space:]]/) print b}' "$PROJECTS_FILE")

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "--------------------------------"
echo "Blocks found : $block_num"

if [[ $errors -gt 0 ]]; then
  err_suffix="s"; [ "$errors" -eq 1 ] && err_suffix=""
  echo ""
  echo "Verification FAILED ($errors error${err_suffix})"
  exit 1
else
  if [[ $warnings -gt 0 ]]; then
    echo "Warnings     : $warnings"
  fi
  echo ""
  echo "Verification PASSED"
  exit 0
fi
