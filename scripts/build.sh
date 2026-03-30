#!/usr/bin/env bash
# scripts/build.sh
# Parses ../knitting/projects.md and regenerates ./index.html

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KNITTING_DIR="$(cd "$SCRIPT_DIR/../knitting" && pwd 2>/dev/null)" || {
  echo "ERROR: ../knitting directory not found"
  exit 1
}
PROJECTS_FILE="$KNITTING_DIR/projects.md"
OUTPUT_FILE="$SITE_ROOT/index.html"
SUPPORTED_EXTS="jpg jpeg png gif webp"

if [[ ! -f "$PROJECTS_FILE" ]]; then
  echo "ERROR: projects.md not found at $PROJECTS_FILE"
  exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

html_escape() {
  echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

# macOS-compatible relative path: relative_path <target> <base>
relative_path() {
  python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$1" "$2"
}

# ── Split projects.md into per-block temp files ───────────────────────────────
# Use awk to write each block to a numbered temp file, then process them one
# by one. This avoids the "while read -r reads lines not blocks" problem.

TMPDIR_BLOCKS="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BLOCKS"' EXIT

awk '
  BEGIN { block=1 }
  /^---$/ { block++; next }
  { print >> ("'"$TMPDIR_BLOCKS"'/" block ".txt") }
' "$PROJECTS_FILE"

# ── Parse each block file and build project HTML ──────────────────────────────

projects_html=""
project_count=0

for block_file in $(ls "$TMPDIR_BLOCKS"/*.txt 2>/dev/null | sort -t/ -k3 -n); do
  block_num=$(basename "$block_file" .txt)

  # Skip blank blocks
  content=$(tr -d '[:space:]' < "$block_file")
  [[ -z "$content" ]] && continue

  title=$(grep -m1 '^## '          "$block_file" | sed 's/^## *//'          | xargs) || title=""
  desc=$(grep -m1  '^description:' "$block_file" | sed 's/^description: *//' | xargs) || desc=""
  img_path=$(grep -m1 '^images:'   "$block_file" | sed 's/^images: *//'      | xargs) || img_path=""

  if [[ -z "$title" || -z "$img_path" ]]; then
    echo "ERROR: Block $block_num is missing required fields (## title, images:)."
    exit 1
  fi

  id=$(slugify "$title")
  safe_title=$(html_escape "$title")
  safe_desc=$(html_escape "$desc")
  abs_img="$KNITTING_DIR/$img_path"

  # Build image cards
  img_cards=""
  if [[ -d "$abs_img" ]]; then
    while IFS= read -r imgfile; do
      [[ -z "$imgfile" ]] && continue
      rel=$(relative_path "$imgfile" "$SITE_ROOT") || rel="$imgfile"
      img_cards+="        <div class=\"img-card\">"$'\n'
      img_cards+="          <img src=\"$rel\" alt=\"$safe_title\" loading=\"lazy\" />"$'\n'
      img_cards+="        </div>"$'\n'
    done < <(
      for ext in $SUPPORTED_EXTS; do
        find "$abs_img" -maxdepth 1 -iname "*.${ext}" 2>/dev/null || true
      done | sort
    )
  fi

  if [[ -z "$img_cards" ]]; then
    img_cards='        <div class="img-card img-empty">No images found</div>'$'\n'
    echo "WARN: No images found for \"$title\" in $abs_img"
  fi

  projects_html+="  <section class=\"project\" id=\"$id\">"$'\n'
  projects_html+="    <div class=\"project-header\">"$'\n'
  projects_html+="      <h2>$safe_title</h2>"$'\n'
  [[ -n "$desc" ]] && projects_html+="      <p class=\"desc\">$safe_desc</p>"$'\n'
  projects_html+="    </div>"$'\n'
  projects_html+="    <div class=\"scroll-track\" role=\"list\" aria-label=\"$safe_title photos\">"$'\n'
  projects_html+="${img_cards}"
  projects_html+="    </div>"$'\n'
  projects_html+="  </section>"$'\n'$'\n'
  project_count=$((project_count + 1))
done

YEAR=$(date +%Y)

# ── Write index.html ──────────────────────────────────────────────────────────

cat > "$OUTPUT_FILE" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Knitting Projects</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,600;1,400&family=Source+Serif+4:ital,opsz,wght@0,8..60,300;0,8..60,400;1,8..60,300&display=swap" rel="stylesheet" />
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --cream:  #f5f0e8;
      --warm:   #ede6d6;
      --sand:   #c9b99a;
      --ink:    #2c2318;
      --muted:  #7a6a58;
      --accent: #7a3e2a;
      --card-r: 12px;
      --gap:    1.5rem;
    }

    html { scroll-behavior: smooth; }

    body {
      background: var(--cream);
      color: var(--ink);
      font-family: 'Source Serif 4', Georgia, serif;
      font-weight: 300;
      line-height: 1.65;
      min-height: 100vh;
    }

    header {
      padding: 4rem 2rem 2.5rem;
      text-align: center;
      border-bottom: 1px solid var(--sand);
      background: var(--warm);
    }
    header h1 {
      font-family: 'Playfair Display', serif;
      font-size: clamp(2.2rem, 5vw, 3.8rem);
      font-weight: 600;
      letter-spacing: -0.01em;
      color: var(--ink);
      margin-bottom: 0.4rem;
    }
    header .tagline {
      font-style: italic;
      color: var(--muted);
      font-size: 1.05rem;
    }

    main {
      max-width: 1200px;
      margin: 0 auto;
      padding: 3rem 2rem 5rem;
      display: flex;
      flex-direction: column;
      gap: 4rem;
    }

    .project-header {
      margin-bottom: 1.2rem;
      padding-bottom: 0.8rem;
      border-bottom: 1px solid var(--sand);
    }
    .project-header h2 {
      font-family: 'Playfair Display', serif;
      font-size: clamp(1.4rem, 3vw, 2rem);
      font-weight: 600;
      color: var(--accent);
      margin-bottom: 0.25rem;
    }
    .project-header .desc {
      color: var(--muted);
      font-size: 0.95rem;
      max-width: 65ch;
    }

    .scroll-track {
      display: flex;
      gap: var(--gap);
      overflow-x: auto;
      overflow-y: hidden;
      padding-bottom: 0.75rem;
      scroll-snap-type: x mandatory;
      -webkit-overflow-scrolling: touch;
      cursor: grab;
    }
    .scroll-track:active { cursor: grabbing; }
    .scroll-track::-webkit-scrollbar { height: 5px; }
    .scroll-track::-webkit-scrollbar-track { background: var(--warm); border-radius: 99px; }
    .scroll-track::-webkit-scrollbar-thumb { background: var(--sand); border-radius: 99px; }

    .img-card {
      flex: 0 0 auto;
      width: 280px;
      height: 340px;
      border-radius: var(--card-r);
      overflow: hidden;
      scroll-snap-align: start;
      background: var(--warm);
      border: 1px solid var(--sand);
      transition: transform 0.2s ease, box-shadow 0.2s ease;
    }
    .img-card:hover {
      transform: translateY(-3px);
      box-shadow: 0 8px 24px rgba(44,35,24,0.12);
    }
    .img-card img { width: 100%; height: 100%; object-fit: cover; display: block; cursor: zoom-in; }
    .img-empty {
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--muted);
      font-style: italic;
      font-size: 0.9rem;
    }


    @media (max-width: 600px) {
      main { padding: 2rem 1rem 4rem; gap: 3rem; }
      .img-card { width: 220px; height: 270px; }
    }
    /* ── Lightbox ────────────────────────────────────── */
    #lightbox {
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(20,14,8,0.92);
      z-index: 100;
      align-items: center;
      justify-content: center;
      padding: 1.5rem;
    }
    #lightbox.open { display: flex; }
    #lightbox img {
      max-width: 100%;
      max-height: 100%;
      object-fit: contain;
      border-radius: 6px;
      box-shadow: 0 24px 80px rgba(0,0,0,0.6);
      animation: lb-in 0.18s ease;
    }
    @keyframes lb-in {
      from { opacity: 0; transform: scale(0.95); }
      to   { opacity: 1; transform: scale(1); }
    }
    #lightbox-close {
      position: fixed;
      top: 1rem;
      right: 1.25rem;
      background: none;
      border: none;
      color: #fff;
      font-size: 2rem;
      line-height: 1;
      cursor: pointer;
      opacity: 0.7;
    }
    #lightbox-close:hover { opacity: 1; }
  </style>
</head>
<body>

<header>
  <h1>Knitting Projects</h1>
  <p class="tagline">A collection of things made with yarn &amp; patience</p>
</header>

<main>
${projects_html}</main>


<div id="lightbox" role="dialog" aria-modal="true" aria-label="Image preview">
  <button id="lightbox-close" aria-label="Close">&times;</button>
  <img id="lightbox-img" src="" alt="" />
</div>

<script>
  // Lightbox
  const lightbox = document.getElementById('lightbox');
  const lbImg    = document.getElementById('lightbox-img');
  const lbClose  = document.getElementById('lightbox-close');

  function openLightbox(src, alt) {
    lbImg.src = src;
    lbImg.alt = alt;
    lightbox.classList.add('open');
    document.body.style.overflow = 'hidden';
  }
  function closeLightbox() {
    lightbox.classList.remove('open');
    document.body.style.overflow = '';
    lbImg.src = '';
  }

  document.querySelectorAll('.img-card img').forEach(img => {
    img.addEventListener('click', () => openLightbox(img.src, img.alt));
  });
  lbClose.addEventListener('click', closeLightbox);
  lightbox.addEventListener('click', e => { if (e.target === lightbox) closeLightbox(); });
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closeLightbox(); });

  document.querySelectorAll('.scroll-track').forEach(track => {
    let isDown = false, startX, scrollLeft;
    track.addEventListener('mousedown', e => {
      isDown = true;
      startX = e.pageX - track.offsetLeft;
      scrollLeft = track.scrollLeft;
    });
    document.addEventListener('mouseup', () => { isDown = false; });
    track.addEventListener('mousemove', e => {
      if (!isDown) return;
      e.preventDefault();
      const x = e.pageX - track.offsetLeft;
      track.scrollLeft = scrollLeft - (x - startX);
    });
  });
</script>

</body>
</html>
HTMLEOF

echo "Built $project_count project$([ "$project_count" -eq 1 ] && echo "" || echo "s") -> $OUTPUT_FILE"
