#!/usr/bin/env bash
# generate-artwork.sh — Generate album cover artwork via Replicate API
# Reads: data/artwork-brief.json, config/production-config.yaml
# Writes: output/artwork/cover-variant-{n}.png, data/artwork-manifest.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ARTWORK_DIR="$PROJECT_ROOT/output/artwork"
ARTWORK_BRIEF="$PROJECT_ROOT/data/artwork-brief.json"
MANIFEST_FILE="$PROJECT_ROOT/data/artwork-manifest.json"

mkdir -p "$ARTWORK_DIR"

echo "=== Music Producer: Artwork Generation Phase ==="

if [ ! -f "$ARTWORK_BRIEF" ]; then
  echo "ERROR: $ARTWORK_BRIEF not found. Run design-artwork phase first."
  exit 1
fi

# Check for Replicate API key
if [ -z "${REPLICATE_API_TOKEN:-}" ]; then
  echo "REPLICATE_API_TOKEN not set — running in placeholder mode"
  PLACEHOLDER_MODE=true
else
  PLACEHOLDER_MODE=false
  echo "Replicate API token found — generating real artwork"
fi

python3 - <<PYEOF
import json
import os
import sys

project_root = "$PROJECT_ROOT"
artwork_dir = "$ARTWORK_DIR"
brief_path = "$ARTWORK_BRIEF"
manifest_path = "$MANIFEST_FILE"
placeholder_mode = "$PLACEHOLDER_MODE" == "true"

with open(brief_path) as f:
    brief = json.load(f)

prompts = brief.get("cover_prompts", [])
if not prompts:
    print("ERROR: No cover_prompts found in artwork-brief.json")
    sys.exit(1)

print(f"Found {len(prompts)} cover variant(s) to generate")

manifest_entries = []

for i, variant_def in enumerate(prompts):
    variant_name = variant_def.get("variant", f"variant-{i+1}")
    prompt = variant_def.get("prompt", "album cover art, professional photography")
    neg_prompt = variant_def.get("negative_prompt", "text, blurry, low quality, watermark")
    output_path = os.path.join(artwork_dir, f"cover-{variant_name}.png")

    print(f"\nGenerating variant: {variant_name}")
    print(f"  Prompt: {prompt[:80]}...")

    if placeholder_mode:
        # Create a placeholder PNG using Python (simple colored rectangle)
        try:
            # Try with Pillow if available
            from PIL import Image, ImageDraw, ImageFont
            colors = [(26, 26, 46), (15, 52, 96), (52, 31, 151)]
            color = colors[i % len(colors)]
            img = Image.new("RGB", (1024, 1024), color=color)
            draw = ImageDraw.Draw(img)
            draw.rectangle([100, 100, 924, 924], outline=(255, 255, 255, 100), width=3)
            draw.text((200, 480), f"[{variant_name.upper()}]", fill=(200, 200, 200))
            draw.text((200, 520), "Placeholder Artwork", fill=(150, 150, 150))
            img.save(output_path, "PNG")
        except ImportError:
            # Fallback: create minimal valid PNG using struct
            import struct
            import zlib

            def create_minimal_png(path, width=100, height=100, color=(26, 26, 46)):
                def png_chunk(chunk_type, data):
                    chunk_len = len(data)
                    chunk_data = chunk_type + data
                    checksum = zlib.crc32(chunk_data) & 0xFFFFFFFF
                    return struct.pack(">I", chunk_len) + chunk_data + struct.pack(">I", checksum)

                header = b'\x89PNG\r\n\x1a\n'
                ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
                ihdr = png_chunk(b'IHDR', ihdr_data)

                # Create raw pixel data (RGB)
                raw_rows = []
                for _ in range(height):
                    row = b'\x00' + bytes(color) * width
                    raw_rows.append(row)
                compressed = zlib.compress(b''.join(raw_rows))
                idat = png_chunk(b'IDAT', compressed)
                iend = png_chunk(b'IEND', b'')

                with open(path, 'wb') as f:
                    f.write(header + ihdr + idat + iend)

            create_minimal_png(output_path, 100, 100)

        print(f"  Created placeholder: {os.path.basename(output_path)}")
        generation_mode = "placeholder"
        width, height = 1024, 1024

    else:
        # Generate via Replicate API
        try:
            import replicate
            import urllib.request

            output = replicate.run(
                "stability-ai/sdxl:39ed52f2319f9c8fe5bc7df3c8e5a6a74f3fcb0e5d1d3c6e4f8a9b2c1d0e7f6a",
                input={
                    "prompt": prompt,
                    "negative_prompt": neg_prompt,
                    "width": 1024,
                    "height": 1024,
                    "num_inference_steps": 50,
                    "guidance_scale": 7.5,
                    "num_outputs": 1
                }
            )

            if isinstance(output, list) and output:
                image_url = output[0]
            elif isinstance(output, str):
                image_url = output
            else:
                image_url = str(output)

            print(f"  Downloading from Replicate...")
            urllib.request.urlretrieve(image_url, output_path)
            print(f"  Saved: {os.path.basename(output_path)}")
            generation_mode = "replicate"
            width, height = 1024, 1024

        except Exception as e:
            print(f"  ERROR: {e}")
            print(f"  Falling back to placeholder...")
            # Create minimal placeholder
            import struct, zlib
            header = b'\x89PNG\r\n\x1a\n'
            def png_chunk(t, d):
                c = t + d
                return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
            ihdr = png_chunk(b'IHDR', struct.pack(">IIBBBBB", 100, 100, 8, 2, 0, 0, 0))
            row = b'\x00' + b'\x1a\x1a\x2e' * 100
            idat = png_chunk(b'IDAT', zlib.compress(row * 100))
            iend = png_chunk(b'IEND', b'')
            with open(output_path, 'wb') as f:
                f.write(header + ihdr + idat + iend)
            generation_mode = "placeholder_fallback"
            width, height = 100, 100

    manifest_entries.append({
        "variant": variant_name,
        "filename": os.path.basename(output_path),
        "path": f"output/artwork/{os.path.basename(output_path)}",
        "width": width,
        "height": height,
        "generation_mode": generation_mode,
        "prompt": prompt
    })

# Write manifest
import subprocess
manifest = {
    "generated_at": subprocess.run(
        ["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"],
        capture_output=True, text=True
    ).stdout.strip(),
    "total_variants": len(manifest_entries),
    "output_directory": "output/artwork",
    "variants": manifest_entries
}

with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)

print(f"\n=== Artwork generation complete ===")
print(f"Generated: {len(manifest_entries)} variant(s)")
print(f"Manifest: {manifest_path}")
PYEOF
