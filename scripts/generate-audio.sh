#!/usr/bin/env bash
# generate-audio.sh — Generate reference audio for all tracks via Replicate API
# Reads: data/production/track-*.json, config/production-config.yaml
# Writes: output/audio/track-{nn}-{title}.wav, data/audio-manifest.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PRODUCTION_DIR="$PROJECT_ROOT/data/production"
OUTPUT_DIR="$PROJECT_ROOT/output/audio"
MANIFEST_FILE="$PROJECT_ROOT/data/audio-manifest.json"

mkdir -p "$OUTPUT_DIR"

echo "=== Music Producer: Audio Generation Phase ==="
echo "Production files: $PRODUCTION_DIR"
echo "Output directory: $OUTPUT_DIR"

# Check if Replicate API key is available
if [ -z "${REPLICATE_API_TOKEN:-}" ]; then
  echo "REPLICATE_API_TOKEN not set — running in placeholder mode"
  PLACEHOLDER_MODE=true
else
  PLACEHOLDER_MODE=false
  echo "Replicate API token found — generating real audio"
fi

# Find all production JSON files
PRODUCTION_FILES=($(ls "$PRODUCTION_DIR"/track-*.json 2>/dev/null || true))

if [ ${#PRODUCTION_FILES[@]} -eq 0 ]; then
  echo "ERROR: No production JSON files found in $PRODUCTION_DIR"
  echo "Run the produce-tracks phase first."
  exit 1
fi

echo "Found ${#PRODUCTION_FILES[@]} track(s) to process"

# Build manifest entries
MANIFEST_ENTRIES="[]"

for PROD_FILE in "${PRODUCTION_FILES[@]}"; do
  FILENAME=$(basename "$PROD_FILE" .json)
  echo ""
  echo "Processing: $FILENAME"

  # Extract track info from production JSON
  TRACK_NUM=$(python3 -c "import json,sys; d=json.load(open('$PROD_FILE')); print(d.get('track_number', 0))")
  TRACK_TITLE=$(python3 -c "import json,sys; d=json.load(open('$PROD_FILE')); print(d.get('title', 'unknown'))")
  AUDIO_PROMPT=$(python3 -c "import json,sys; d=json.load(open('$PROD_FILE')); print(d.get('audio_generation_prompt', 'instrumental ambient electronic music'))")

  # Zero-pad track number
  PADDED_NUM=$(printf "%02d" "$TRACK_NUM")
  SAFE_TITLE=$(echo "$TRACK_TITLE" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
  OUTPUT_FILE="$OUTPUT_DIR/track-${PADDED_NUM}-${SAFE_TITLE}.wav"

  if [ "$PLACEHOLDER_MODE" = true ]; then
    # Create a placeholder WAV file with ffmpeg (silent audio with metadata)
    if command -v ffmpeg &>/dev/null; then
      ffmpeg -f lavfi -i "sine=frequency=440:duration=5" \
        -metadata title="$TRACK_TITLE (placeholder)" \
        -metadata artist="Nova Dusk" \
        -ar 44100 -ac 2 -sample_fmt s16 \
        "$OUTPUT_FILE" -y -loglevel quiet
      echo "  Created placeholder WAV: $(basename "$OUTPUT_FILE")"
    else
      # Create minimal valid WAV header if ffmpeg not available
      python3 - <<PYEOF
import struct, wave, math

output_path = "$OUTPUT_FILE"
duration = 5  # seconds
sample_rate = 44100
num_channels = 2
num_frames = duration * sample_rate

with wave.open(output_path, 'w') as wf:
    wf.setnchannels(num_channels)
    wf.setsampwidth(2)  # 16-bit
    wf.setframerate(sample_rate)
    # Silent audio
    wf.writeframes(b'\x00' * num_frames * num_channels * 2)

print(f"  Created placeholder WAV: {output_path}")
PYEOF
    fi
    DURATION=5
    GENERATION_MODE="placeholder"
  else
    # Generate real audio via Replicate Python SDK
    python3 - <<PYEOF
import replicate
import urllib.request
import json
import sys

prompt = """$AUDIO_PROMPT"""
output_path = "$OUTPUT_FILE"

print(f"  Generating audio with prompt: {prompt[:80]}...")

try:
    output = replicate.run(
        "meta/musicgen:671ac645ce5e552cc63a54a2bbff63fcf798043055d2dac5fc9e36a837eedcfb",
        input={
            "prompt": prompt,
            "model_version": "large",
            "output_format": "wav",
            "normalization_strategy": "peak",
            "duration": 30
        }
    )

    if isinstance(output, str):
        audio_url = output
    elif hasattr(output, '__iter__'):
        audio_url = next(iter(output))
    else:
        audio_url = str(output)

    print(f"  Downloading from: {audio_url[:60]}...")
    urllib.request.urlretrieve(audio_url, output_path)
    print(f"  Saved to: {output_path}")

except Exception as e:
    print(f"  ERROR generating audio: {e}", file=sys.stderr)
    print(f"  Creating placeholder instead...")
    import wave
    with wave.open(output_path, 'w') as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(44100)
        wf.writeframes(b'\x00' * 44100 * 2 * 2 * 5)
PYEOF
    DURATION=30
    GENERATION_MODE="replicate"
  fi

  # Append to manifest
  MANIFEST_ENTRIES=$(python3 - <<PYEOF
import json

entries = $MANIFEST_ENTRIES
entries.append({
    "track_number": $TRACK_NUM,
    "title": "$TRACK_TITLE",
    "filename": "$(basename "$OUTPUT_FILE")",
    "path": "output/audio/$(basename "$OUTPUT_FILE")",
    "duration_secs": $DURATION,
    "generation_mode": "$GENERATION_MODE",
    "prompt_used": """$AUDIO_PROMPT"""[:200]
})
print(json.dumps(entries, indent=2))
PYEOF
  )
done

# Write final manifest
python3 - <<PYEOF
import json

manifest = {
    "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "total_tracks": ${#PRODUCTION_FILES[@]},
    "output_directory": "output/audio",
    "tracks": $MANIFEST_ENTRIES
}

with open("$MANIFEST_FILE", "w") as f:
    json.dump(manifest, f, indent=2)

print(f"\nManifest written to: $MANIFEST_FILE")
PYEOF

echo ""
echo "=== Audio generation complete ==="
echo "Generated: ${#PRODUCTION_FILES[@]} tracks"
echo "Manifest: $MANIFEST_FILE"
