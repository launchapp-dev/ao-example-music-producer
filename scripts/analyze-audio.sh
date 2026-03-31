#!/usr/bin/env bash
# analyze-audio.sh — Analyze generated audio files using ffprobe
# Reads: data/audio-manifest.json, output/audio/*.wav
# Writes: data/audio-analysis.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AUDIO_DIR="$PROJECT_ROOT/output/audio"
MANIFEST_FILE="$PROJECT_ROOT/data/audio-manifest.json"
ANALYSIS_FILE="$PROJECT_ROOT/data/audio-analysis.json"

echo "=== Music Producer: Audio Analysis Phase ==="

# Check for ffprobe
if ! command -v ffprobe &>/dev/null; then
  echo "WARNING: ffprobe not found (install ffmpeg). Running in fallback mode."
  FFPROBE_AVAILABLE=false
else
  FFPROBE_AVAILABLE=true
  echo "ffprobe found: $(ffprobe -version 2>&1 | head -1)"
fi

# Read manifest to get track list
if [ ! -f "$MANIFEST_FILE" ]; then
  echo "ERROR: $MANIFEST_FILE not found. Run generate-audio phase first."
  exit 1
fi

python3 - <<PYEOF
import json
import subprocess
import os
import sys

project_root = "$PROJECT_ROOT"
audio_dir = "$AUDIO_DIR"
manifest_path = "$MANIFEST_FILE"
analysis_path = "$ANALYSIS_FILE"
ffprobe_available = "$FFPROBE_AVAILABLE" == "true"

with open(manifest_path) as f:
    manifest = json.load(f)

track_analyses = []

for track in manifest.get("tracks", []):
    audio_path = os.path.join(project_root, track["path"])
    track_num = track["track_number"]
    title = track["title"]

    print(f"\nAnalyzing: Track {track_num} — {title}")

    if not os.path.exists(audio_path):
        print(f"  WARNING: File not found: {audio_path}")
        track_analyses.append({
            "track_number": track_num,
            "title": title,
            "status": "file_not_found",
            "path": track["path"]
        })
        continue

    analysis = {
        "track_number": track_num,
        "title": title,
        "path": track["path"],
        "status": "analyzed"
    }

    if ffprobe_available:
        try:
            # Get format/stream info
            result = subprocess.run(
                [
                    "ffprobe", "-v", "quiet",
                    "-print_format", "json",
                    "-show_format",
                    "-show_streams",
                    audio_path
                ],
                capture_output=True, text=True, timeout=30
            )
            probe = json.loads(result.stdout)

            fmt = probe.get("format", {})
            streams = probe.get("streams", [{}])
            audio_stream = next(
                (s for s in streams if s.get("codec_type") == "audio"), {}
            )

            analysis.update({
                "duration_secs": float(fmt.get("duration", track.get("duration_secs", 0))),
                "size_bytes": int(fmt.get("size", 0)),
                "sample_rate": int(audio_stream.get("sample_rate", 44100)),
                "channels": audio_stream.get("channels", 2),
                "codec": audio_stream.get("codec_name", "unknown"),
                "bit_rate": int(fmt.get("bit_rate", 0))
            })

            # Get loudness/amplitude via volumedetect filter
            vol_result = subprocess.run(
                [
                    "ffmpeg", "-i", audio_path,
                    "-af", "volumedetect",
                    "-f", "null", "-"
                ],
                capture_output=True, text=True, timeout=60
            )
            vol_output = vol_result.stderr

            # Parse volumedetect output
            for line in vol_output.split("\n"):
                if "mean_volume" in line:
                    analysis["mean_volume_db"] = float(line.split(":")[1].strip().replace(" dB", ""))
                elif "max_volume" in line:
                    analysis["peak_volume_db"] = float(line.split(":")[1].strip().replace(" dB", ""))

            print(f"  Duration: {analysis.get('duration_secs', '?'):.1f}s | "
                  f"Rate: {analysis.get('sample_rate', '?')}Hz | "
                  f"Peak: {analysis.get('peak_volume_db', '?')} dB")

        except Exception as e:
            print(f"  WARNING: ffprobe analysis failed: {e}")
            analysis["status"] = "analysis_error"
            analysis["error"] = str(e)
            analysis["duration_secs"] = track.get("duration_secs", 0)
    else:
        # Fallback: read WAV header with Python wave module
        try:
            import wave
            with wave.open(audio_path) as wf:
                frames = wf.getnframes()
                rate = wf.getframerate()
                duration = frames / float(rate)
                analysis.update({
                    "duration_secs": duration,
                    "sample_rate": rate,
                    "channels": wf.getnchannels(),
                    "codec": "pcm",
                    "mean_volume_db": None,
                    "peak_volume_db": None,
                    "note": "ffprobe not available — limited analysis"
                })
                print(f"  Duration: {duration:.1f}s | Rate: {rate}Hz (WAV header only)")
        except Exception as e:
            print(f"  WARNING: Could not read WAV file: {e}")
            analysis["status"] = "read_error"
            analysis["duration_secs"] = track.get("duration_secs", 0)

    # Validation checks
    duration = analysis.get("duration_secs", 0)
    validation = []
    if duration < 2:
        validation.append("WARN: Very short duration (<2s)")
    if duration > 600:
        validation.append("WARN: Very long duration (>10min)")
    peak = analysis.get("peak_volume_db")
    if peak is not None and peak > 0:
        validation.append("WARN: Clipping detected (peak > 0 dBFS)")
    analysis["validation_warnings"] = validation

    track_analyses.append(analysis)

# Write analysis file
output = {
    "analyzed_at": subprocess.run(
        ["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"],
        capture_output=True, text=True
    ).stdout.strip(),
    "total_tracks": len(track_analyses),
    "total_duration_secs": sum(
        t.get("duration_secs", 0) for t in track_analyses
    ),
    "tracks": track_analyses
}

with open(analysis_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"\n=== Audio analysis complete ===")
print(f"Total tracks: {len(track_analyses)}")
total_min = output['total_duration_secs'] / 60
print(f"Total duration: {total_min:.1f} minutes")
print(f"Analysis written to: {analysis_path}")

# Report any warnings
warnings = [
    (t["title"], w)
    for t in track_analyses
    for w in t.get("validation_warnings", [])
]
if warnings:
    print("\nValidation warnings:")
    for title, warning in warnings:
        print(f"  {title}: {warning}")
PYEOF
