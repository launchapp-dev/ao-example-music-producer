# Music Album Production Pipeline

AI-powered album production pipeline — takes a creative brief from concept through release-ready package including lyrics, compositions, production specs, reference audio, artwork, liner notes, and marketing strategy.

## How It Works

```
config/album-brief.yaml
         │
         ▼
┌─────────────────────┐
│   develop-concept   │ creative-director (Opus)
│  album narrative,   │
│  mood arc, track    │
│  listing            │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│   review-concept    │ ── rework ──► develop-concept (×2)
│   [DECISION GATE]   │
└────────┬────────────┘
         │ approve
         ▼
┌─────────────────────┐
│    write-lyrics     │ lyricist (Sonnet)
│  full structured    │
│  lyrics per track   │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│   compose-tracks    │ composer (Sonnet)
│  chord progressions,│
│  melody, arrangement│
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│   produce-tracks    │ producer (Sonnet)
│  instrumentation,   │
│  sound design,      │
│  audio prompts      │
└────────┬────────────┘
         │
         ▼
┌──────────────────────────────┐
│  generate-reference-audio    │ [COMMAND] scripts/generate-audio.sh
│  Replicate API → .wav files  │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│      analyze-audio           │ [COMMAND] scripts/analyze-audio.sh
│  ffprobe → BPM, LUFS, peaks  │
└────────┬─────────────────────┘
         │
         ▼
┌─────────────────────┐
│  master-collection  │ producer (Sonnet)
│  EQ, compression,   │
│  loudness targets   │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  review-production  │ ── rework ──► produce-tracks (×2)
│   [DECISION GATE]   │
└────────┬────────────┘
         │ approve
         ▼
┌─────────────────────┐
│   design-artwork    │ art-director (Haiku)
│  visual concept,    │
│  color palette,     │
│  SD prompts         │
└────────┬────────────┘
         │
         ▼
┌──────────────────────────────┐
│    generate-artwork          │ [COMMAND] scripts/generate-artwork.sh
│  Replicate SDXL → 3 variants │
└────────┬─────────────────────┘
         │
         ▼
┌─────────────────────┐
│  write-liner-notes  │ creative-director (Opus)
│  artist statement,  │
│  track commentary   │
└────────┬────────────┘
         │
         ▼
┌──────────────────────────────┐
│   prepare-distribution       │ [COMMAND] scripts/prepare-metadata.sh
│  ISRC, UPC, metadata JSON    │
└────────┬─────────────────────┘
         │
         ▼
┌─────────────────────┐
│   plan-marketing    │ marketing-strategist (Haiku)
│  release timeline,  │
│  playlist pitching, │
│  press release      │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│    final-review     │ ── rework ──► plan-marketing (×1)
│   [DECISION GATE]   │
└────────┬────────────┘
         │ approve
         ▼
     ✅ DONE
   output/ ready
```

## Agents

| Agent | Model | Role |
|---|---|---|
| **creative-director** | claude-opus-4-6 | Album vision, concept development, liner notes, 3 decision gates |
| **lyricist** | claude-sonnet-4-6 | Full structured lyrics with syllable counts and rhyme schemes |
| **composer** | claude-sonnet-4-6 | Chord progressions, melody contours, arrangement sections |
| **producer** | claude-sonnet-4-6 | Instrumentation, sound design, mixing directives, mastering plan |
| **art-director** | claude-haiku-4-5 | Visual identity, color palette, artwork generation prompts |
| **marketing-strategist** | claude-haiku-4-5 | Release strategy, playlist pitching, press outreach |

## AO Features Demonstrated

| Feature | Where |
|---|---|
| **Multi-agent pipeline** | 6 specialized agents across creative, technical, and business domains |
| **Multi-model routing** | Opus for creative direction, Sonnet for production, Haiku for execution |
| **Decision gates with rework** | 3 gates: concept review, production review, final review |
| **Command phases** | 4 shell scripts: audio generation, audio analysis, artwork, metadata |
| **Sequential-thinking MCP** | Creative concept development, arrangement decisions, review reasoning |
| **Structured output contracts** | JSON schema for every agent phase (lyrics, compositions, production) |
| **Rework loops** | Concept reworks ×2, production reworks ×2, marketing reworks ×1 |
| **Post-success merge** | Auto-merge squash PR to main on approval |

## Quick Start

```bash
# 1. Navigate to example
cd examples/music-producer

# 2. Configure your album
edit config/album-brief.yaml   # Set artist name, genre, theme, track count

# 3. (Optional) Set Replicate API key for real audio + artwork generation
export REPLICATE_API_TOKEN=your_token_here

# 4. Start the AO daemon and run the workflow
ao daemon start
ao workflow run album-production

# 5. Watch it go
ao daemon stream --pretty
```

## Requirements

**Required:**
- `ao` CLI installed and configured
- Node.js 18+ (for MCP servers via npx)
- Python 3.8+ (for generation/analysis scripts)

**Optional (for real audio generation):**
- `REPLICATE_API_TOKEN` — Replicate API access for music and image generation
- `ffmpeg` — For audio analysis and placeholder WAV creation (install via `brew install ffmpeg`)
- Python `replicate` package: `pip install replicate`
- Python `pillow` package for placeholder images: `pip install Pillow`

Without a Replicate API token, all generation phases run in **placeholder mode** — they create silent WAV files and solid-color PNG placeholders so the pipeline can complete end-to-end.

## Project Layout

```
music-producer/
├── .ao/workflows/
│   ├── agents.yaml              # 6 agents: creative-director, lyricist, composer, producer, art-director, marketing-strategist
│   ├── phases.yaml              # 15 phases: develop through final-review
│   ├── workflows.yaml           # album-production workflow with rework loops
│   └── mcp-servers.yaml         # filesystem, sequential-thinking, fetch
├── config/
│   ├── album-brief.yaml         # EDIT THIS: artist, genre, theme, track count
│   ├── production-config.yaml   # Audio/artwork model settings
│   └── distribution-config.yaml # Platform and distributor settings
├── scripts/
│   ├── generate-audio.sh        # Replicate music generation
│   ├── analyze-audio.sh         # ffprobe audio analysis
│   ├── generate-artwork.sh      # Replicate SDXL artwork
│   └── prepare-metadata.sh      # Distribution metadata compiler
├── data/                        # Pipeline data (populated by agents)
│   ├── album-concept.json
│   ├── track-listing.json
│   ├── lyrics/track-{nn}-*.json
│   ├── compositions/track-{nn}-*.json
│   ├── production/track-{nn}-*.json
│   ├── audio-manifest.json
│   ├── audio-analysis.json
│   ├── mastering-plan.json
│   └── artwork-brief.json
└── output/                      # Final deliverables
    ├── audio/track-{nn}-*.wav   # Reference audio
    ├── artwork/cover-*.png      # Album cover variants
    ├── liner-notes.md           # Artist statement + track commentary
    ├── distribution-metadata.json
    ├── credits.txt
    ├── marketing-plan.md
    └── press-release.md
```

## Workflow Details

| # | Phase | Agent | Type |
|---|---|---|---|
| 1 | develop-concept | creative-director | Agent |
| 2 | review-concept | creative-director | Decision gate |
| 3 | write-lyrics | lyricist | Agent |
| 4 | compose-tracks | composer | Agent |
| 5 | produce-tracks | producer | Agent |
| 6 | generate-reference-audio | — | Command |
| 7 | analyze-audio | — | Command |
| 8 | master-collection | producer | Agent |
| 9 | review-production | creative-director | Decision gate |
| 10 | design-artwork | art-director | Agent |
| 11 | generate-artwork | — | Command |
| 12 | write-liner-notes | creative-director | Agent |
| 13 | prepare-distribution | — | Command |
| 14 | plan-marketing | marketing-strategist | Agent |
| 15 | final-review | creative-director | Decision gate |

## Customization

**Change genre:** Edit `config/album-brief.yaml` → `genre.primary` and `influences.artists`

**Change track count:** Edit `config/album-brief.yaml` → `track_count` (supports 5–20 tracks)

**Change audio model:** Edit `config/production-config.yaml` → `audio_generation.model`
  - `meta/musicgen:large` (default, mono)
  - `meta/musicgen:stereo-large` (stereo)

**Change artwork model:** Edit `config/production-config.yaml` → `artwork.model`

**Different artist name:** Edit `config/album-brief.yaml` → `artist_name`

## Sample Output

After a successful run, `output/` contains:

```
output/
├── audio/
│   ├── track-01-midnight-drive.wav
│   ├── track-02-glass-cities.wav
│   └── ... (10 tracks)
├── artwork/
│   ├── cover-primary.png       (main album cover)
│   ├── cover-atmospheric.png   (textural variant)
│   └── cover-minimalist.png    (clean typography variant)
├── liner-notes.md              (2,500+ word artist statement + track notes)
├── distribution-metadata.json  (DistroKid-ready track metadata)
├── credits.txt                 (formatted credits and ISRC placeholders)
├── marketing-plan.md           (8-week release calendar + playlist pitches)
└── press-release.md            (publication-ready press release)
```
