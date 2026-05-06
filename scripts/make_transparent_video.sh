#!/bin/bash
# Generates transparent video for all browsers:
#   - animation.webm  → Chrome, Firefox, Edge
#   - animation.mov   → Safari (HEVC with alpha)
# Requirements: ffmpeg with HEVC support (brew install ffmpeg)

INPUT_DIR="/Users/romanrosenast/Downloads/walking-animation"

# --- WebM (VP9) for Chrome, Firefox, Edge ---
ffmpeg -framerate 12 \
  -i "$INPUT_DIR/frame_%04d.png" \
  -c:v libvpx-vp9 \
  -pix_fmt yuva420p \
  -auto-alt-ref 0 \
  -b:v 0 \
  -crf 15 \
  -loop 0 \
  "$INPUT_DIR/walking-animation.webm"

echo "✓ WebM done"

# --- HEVC with alpha for Safari ---
ffmpeg -framerate 12 \
  -i "$INPUT_DIR/frame_%04d.png" \
  -c:v prores_ks \
  -profile:v 4444 \
  -pix_fmt yuva444p10le \
  -vendor apl0 \
  "$INPUT_DIR/walking-animation.mov"

echo "✓ ProRes 4444 MOV done — no alpha compression artifacts"
echo ""
echo "Both files saved to: $INPUT_DIR"
