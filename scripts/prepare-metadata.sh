#!/usr/bin/env bash
# prepare-metadata.sh — Compile distribution-ready metadata from all pipeline data
# Reads: data/*.json, config/distribution-config.yaml, config/album-brief.yaml
# Writes: output/distribution-metadata.json, output/credits.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Music Producer: Prepare Distribution Metadata ==="

python3 - <<PYEOF
import json
import os
import sys
import re

project_root = "$PROJECT_ROOT"
data_dir = os.path.join(project_root, "data")
config_dir = os.path.join(project_root, "config")
output_dir = os.path.join(project_root, "output")

os.makedirs(output_dir, exist_ok=True)

def load_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"  WARNING: Could not load {path}: {e}")
        return default or {}

def load_yaml_simple(path):
    """Minimal YAML loader for simple key: value and list structures."""
    try:
        try:
            import yaml
            with open(path) as f:
                return yaml.safe_load(f)
        except ImportError:
            pass
        # Fallback: parse simple YAML manually
        result = {}
        with open(path) as f:
            content = f.read()
        # Just extract key-value pairs (good enough for our configs)
        for line in content.split("\n"):
            line = line.strip()
            if line and not line.startswith("#") and ":" in line:
                key, _, val = line.partition(":")
                val = val.strip().strip('"').strip("'")
                if val:
                    result[key.strip()] = val
        return result
    except Exception as e:
        print(f"  WARNING: Could not load {path}: {e}")
        return {}

# Load all data files
print("Loading data files...")
album_concept = load_json(os.path.join(data_dir, "album-concept.json"))
track_listing = load_json(os.path.join(data_dir, "track-listing.json"))
lyrics_summary = load_json(os.path.join(data_dir, "lyrics-summary.json"))
audio_manifest = load_json(os.path.join(data_dir, "audio-manifest.json"))
audio_analysis = load_json(os.path.join(data_dir, "audio-analysis.json"))
production_summary = load_json(os.path.join(data_dir, "production-summary.json"))
mastering_plan = load_json(os.path.join(data_dir, "mastering-plan.json"))

# Load configs
album_brief = load_yaml_simple(os.path.join(config_dir, "album-brief.yaml"))
dist_config = load_yaml_simple(os.path.join(config_dir, "distribution-config.yaml"))

print("Building distribution metadata...")

# Get ordered tracks
tracks = track_listing.get("tracks", [])
final_order = mastering_plan.get("final_track_order", [t["number"] for t in tracks])

# Build track metadata
track_metadata = []
isrc_counter = 1

for track_num in final_order:
    # Find track in listing
    track = next((t for t in tracks if t.get("number") == track_num), None)
    if not track:
        continue

    # Get duration from audio analysis
    analysis_track = next(
        (t for t in audio_analysis.get("tracks", []) if t.get("track_number") == track_num),
        {}
    )
    duration_secs = analysis_track.get("duration_secs", 0)
    duration_formatted = f"{int(duration_secs // 60)}:{int(duration_secs % 60):02d}"

    # Get lyrics summary
    lyrics_track = next(
        (t for t in lyrics_summary.get("tracks", []) if t.get("number") == track_num),
        {}
    )

    track_metadata.append({
        "position": len(track_metadata) + 1,
        "title": track.get("title", track.get("working_title", f"Track {track_num}")),
        "track_number": track_num,
        "duration_secs": duration_secs,
        "duration_formatted": duration_formatted,
        "bpm": track.get("bpm_range", [0, 0])[0],
        "key": track.get("suggested_key", ""),
        "mood": track.get("mood", ""),
        "primary_theme": lyrics_track.get("primary_theme", ""),
        "isrc": f"PLACEHOLDER-{isrc_counter:04d}",
        "explicit": False,
        "language": "en"
    })
    isrc_counter += 1

# Calculate total album duration
total_duration = sum(t.get("duration_secs", 0) for t in track_metadata)
total_duration_formatted = f"{int(total_duration // 60)}:{int(total_duration % 60):02d}"

# Build distribution metadata
artist_name = album_brief.get("artist_name", "Unknown Artist")
album_title = album_concept.get("album_title", album_brief.get("album_title", "Untitled Album"))
if album_title in ("TBD", ""):
    album_title = "Untitled Album (Title TBD)"

distribution_metadata = {
    "schema_version": "1.0",
    "generated_at": __import__("subprocess").run(
        ["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"],
        capture_output=True, text=True
    ).stdout.strip(),
    "artist": {
        "name": artist_name,
        "upc": dist_config.get("upc", "PLACEHOLDER"),
        "isrc_prefix": dist_config.get("isrc_prefix", "PLACEHOLDER")
    },
    "album": {
        "title": album_title,
        "genre_primary": dist_config.get("primary", album_brief.get("primary", "Electronic")),
        "genre_secondary": dist_config.get("secondary", "Indie Pop"),
        "total_tracks": len(track_metadata),
        "total_duration_secs": total_duration,
        "total_duration_formatted": total_duration_formatted,
        "release_date": album_brief.get("target_release_date", "TBD"),
        "label": dist_config.get("label_name", "Self-released"),
        "copyright_holder": dist_config.get("copyright_holder", artist_name),
        "copyright_year": "2026",
        "territory": dist_config.get("territory", "Worldwide"),
        "language": dist_config.get("language", "English"),
        "parental_advisory": False,
        "concept_statement": album_concept.get("concept_statement", "")
    },
    "tracks": track_metadata,
    "platforms": [
        "Spotify", "Apple Music", "YouTube Music",
        "Amazon Music", "Tidal", "Bandcamp"
    ],
    "sonic_palette": album_concept.get("sonic_palette", []),
    "thematic_motifs": album_concept.get("thematic_motifs", [])
}

# Write distribution metadata
metadata_path = os.path.join(output_dir, "distribution-metadata.json")
with open(metadata_path, "w") as f:
    json.dump(distribution_metadata, f, indent=2)
print(f"  Written: distribution-metadata.json")

# Build credits.txt
print("Building credits.txt...")

credits_lines = [
    f"{artist_name.upper()}",
    "=" * len(artist_name),
    f"{album_title}",
    "",
    "RELEASE INFORMATION",
    "-" * 40,
    f"Release Date: {distribution_metadata['album']['release_date']}",
    f"Label: {distribution_metadata['album']['label']}",
    f"Copyright: ℗ & © 2026 {distribution_metadata['album']['copyright_holder']}",
    f"UPC: {distribution_metadata['artist']['upc']}",
    "",
    "TRACK LISTING",
    "-" * 40
]

for track in track_metadata:
    credits_lines.append(
        f"{track['position']:2d}. {track['title']:<30} {track['duration_formatted']:>6}  ISRC: {track['isrc']}"
    )

credits_lines += [
    "",
    f"Total Duration: {total_duration_formatted}",
    "",
    "PRODUCTION CREDITS",
    "-" * 40,
    f"Written, Produced & Performed by: {artist_name}",
    f"Additional Production: AI Music Production Pipeline",
    f"Mixed by: {artist_name}",
    f"Mastered by: {artist_name}",
    f"Artwork by: {artist_name}",
    "",
    "PUBLISHING",
    "-" * 40,
    f"All songs written by {artist_name}",
    f"Publishing: {artist_name} / Self-Published",
    "",
    "DISTRIBUTION",
    "-" * 40,
    "Distributed by: DistroKid",
    "Territory: Worldwide",
    "",
    f"All rights reserved. {artist_name} 2026.",
    "Unauthorized duplication is a violation of applicable laws."
]

credits_path = os.path.join(output_dir, "credits.txt")
with open(credits_path, "w") as f:
    f.write("\n".join(credits_lines))
print(f"  Written: credits.txt")

print(f"\n=== Distribution metadata complete ===")
print(f"Total tracks: {len(track_metadata)}")
print(f"Total duration: {total_duration_formatted}")
print(f"Files written to: {output_dir}")
PYEOF
