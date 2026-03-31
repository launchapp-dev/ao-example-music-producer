# Music Album Production Pipeline — Build Plan

## Overview

A complete music album production pipeline that takes an album from concept through
release-ready. The pipeline develops the creative vision, writes lyrics per track,
designs compositions (chord progressions, melody notes, arrangement plans), produces
reference audio via Replicate's music generation models, masters the collection,
generates album artwork, writes liner notes, and prepares a full marketing/release plan.

All tools are real and available today: filesystem MCP for all data and config,
sequential-thinking MCP for creative concept development and arrangement decisions,
fetch MCP for researching genre trends and release strategies, and command phases
with Python scripts for audio analysis, BPM/key detection, and metadata formatting.

---

## Agents

| Agent | Model | Role |
|---|---|---|
| **creative-director** | claude-opus-4-6 | Oversees album vision — concept, mood, track listing, final approval at each gate |
| **lyricist** | claude-sonnet-4-6 | Writes lyrics per track — themes, verse/chorus/bridge structure, rhyme schemes |
| **composer** | claude-sonnet-4-6 | Designs musical compositions — chord progressions, melody contours, tempo, key, arrangement |
| **producer** | claude-sonnet-4-6 | Produces tracks — instrumentation choices, sound design notes, mixing directives, reference audio generation |
| **art-director** | claude-haiku-4-5 | Designs album artwork concept, color palette, typography, and visual identity |
| **marketing-strategist** | claude-haiku-4-5 | Plans release strategy — platform distribution, social media rollout, playlist pitching, press kit |

---

## Workflows

### Workflow 1: `album-production` (default)

The full album production pipeline from concept to release-ready package.

**Phases:**

1. **develop-concept** (agent: creative-director)
   - Read `config/album-brief.yaml` for artist name, genre, influences, theme direction, track count
   - Use sequential-thinking to develop album concept: overarching narrative, mood arc, sonic palette
   - Define track listing with working titles, BPM range, key suggestions, mood per track
   - Write `data/album-concept.json` (concept statement, mood board keywords, sonic references)
   - Write `data/track-listing.json` (ordered tracks with metadata)

2. **review-concept** (agent: creative-director, DECISION)
   - Review album concept for coherence, originality, and alignment with brief
   - Verify track listing flows well (energy arc, key relationships, tempo variety)
   - Decision: `approve` → continue | `rework` → back to develop-concept
   - Max 2 rework attempts

3. **write-lyrics** (agent: lyricist)
   - Read `data/album-concept.json` and `data/track-listing.json`
   - For each track: write full lyrics with verse/chorus/bridge/outro structure
   - Match lyrical tone to track mood (from concept)
   - Include syllable counts and stress patterns for melody alignment
   - Write `data/lyrics/track-{nn}-{title}.json` per track (structured lyrics with sections)
   - Write `data/lyrics-summary.json` (overview of all tracks' lyrical themes)

4. **compose-tracks** (agent: composer)
   - Read track listing, album concept, and lyrics
   - For each track: design chord progression (with Roman numeral and actual chords in key)
   - Write melody contour (pitch direction, rhythm pattern, intervals)
   - Define arrangement sections: intro, verse, pre-chorus, chorus, bridge, outro
   - Specify tempo (BPM), time signature, key signature
   - Write `data/compositions/track-{nn}-{title}.json` per track
   - Write `data/compositions-summary.json` (harmonic overview, key relationships between tracks)

5. **produce-tracks** (agent: producer)
   - Read compositions, lyrics, and album concept
   - For each track: specify instrumentation (drums, bass, synths, guitars, vocals, FX)
   - Write sound design notes: synth patches, drum kit choices, effects chain
   - Create mixing directives: levels, panning, reverb/delay settings, compression
   - Write reference prompt for audio generation (detailed text description for AI music model)
   - Write `data/production/track-{nn}-{title}.json` per track
   - Write `data/production-summary.json` (production approach, sonic cohesion notes)

6. **generate-reference-audio** (command: `scripts/generate-audio.sh`)
   - Python script reads `data/production/` track files
   - For each track, constructs a prompt from: genre, mood, BPM, key, instrumentation, arrangement
   - Calls Replicate API (`meta/musicgen:large` or similar) via `replicate` npm/Python package
   - Downloads generated audio clips to `output/audio/track-{nn}-{title}.wav`
   - Writes `data/audio-manifest.json` with file paths, durations, generation params

7. **analyze-audio** (command: `scripts/analyze-audio.sh`)
   - Python script reads generated audio files
   - Uses `librosa` or `ffprobe` for: actual BPM detection, duration, peak levels, spectral analysis
   - Validates: BPM matches target (±5%), duration reasonable (2-5 min), no clipping
   - Writes `data/audio-analysis.json` with per-track technical metrics

8. **master-collection** (agent: producer)
   - Read audio analysis and production notes
   - Write mastering directives per track: EQ adjustments, compression, limiting, stereo width
   - Ensure consistent loudness across album (LUFS targets)
   - Define track ordering, gaps between tracks, crossfades
   - Write `data/mastering-plan.json`

9. **review-production** (agent: creative-director, DECISION)
   - Review entire production: lyrics, compositions, production notes, audio analysis, mastering plan
   - Verify album cohesion, quality, and alignment with original concept
   - Decision: `approve` → continue | `rework` → back to produce-tracks
   - Max 2 rework attempts

10. **design-artwork** (agent: art-director)
    - Read album concept, track listing, and lyrics summary
    - Design album cover concept: visual style, color palette, typography, imagery
    - Design track-specific visual motifs for potential singles artwork
    - Write image generation prompts for cover art (for Replicate/SDXL)
    - Write `data/artwork-brief.json` (visual concept, prompts, color codes, font suggestions)

11. **generate-artwork** (command: `scripts/generate-artwork.sh`)
    - Python script reads `data/artwork-brief.json`
    - Calls Replicate API (stability-ai/sdxl or similar) for album cover generation
    - Generates 3 cover variants
    - Downloads to `output/artwork/cover-variant-{n}.png`
    - Writes `data/artwork-manifest.json`

12. **write-liner-notes** (agent: creative-director)
    - Read all album data: concept, lyrics, compositions, production notes
    - Write liner notes: artist statement, track-by-track commentary, credits, thank-yous
    - Write `output/liner-notes.md`

13. **prepare-distribution** (command: `scripts/prepare-metadata.sh`)
    - Python script compiles distribution metadata from all data files
    - Formats for digital distributors: ISRC placeholders, UPC placeholder, track metadata
    - Generates `output/distribution-metadata.json` (title, artist, tracks, durations, genres, credits)
    - Generates `output/credits.txt` (formatted credits file)

14. **plan-marketing** (agent: marketing-strategist)
    - Read album concept, track listing, artwork brief, distribution metadata
    - Plan release strategy: single selections, release timeline, platform priorities
    - Write playlist pitching strategy (Spotify editorial, Apple Music, genre-specific)
    - Plan social media rollout: teaser schedule, behind-the-scenes content ideas
    - Draft press release and EPK (electronic press kit) outline
    - Write `output/marketing-plan.md`
    - Write `output/press-release.md`

15. **final-review** (agent: creative-director, DECISION)
    - Review complete package: audio, artwork, liner notes, metadata, marketing plan
    - Verify everything is consistent and release-ready
    - Decision: `approve` → done | `rework` → back to plan-marketing
    - Max 1 rework attempt

**Routing:**
```
develop-concept → review-concept
                    ↓ approve → write-lyrics → compose-tracks → produce-tracks
                    ↓ rework → develop-concept (max 2)
                                              
produce-tracks → generate-reference-audio → analyze-audio → master-collection
  → review-production
      ↓ approve → design-artwork → generate-artwork → write-liner-notes
      ↓ rework → produce-tracks (max 2)

write-liner-notes → prepare-distribution → plan-marketing → final-review
                                                              ↓ approve → ✅ done
                                                              ↓ rework → plan-marketing (max 1)
```

---

## MCP Servers

| Server | Package | Purpose |
|---|---|---|
| filesystem | `@modelcontextprotocol/server-filesystem` | Read/write all config, data, and output files |
| sequential-thinking | `@modelcontextprotocol/server-sequential-thinking` | Creative concept development, arrangement decisions, review reasoning |
| fetch | `@modelcontextprotocol/server-fetch` | Research genre trends, streaming platform guidelines, competitor releases |

---

## Config Files

### `config/album-brief.yaml`
- Artist name, genre(s), subgenre influences
- Album title (or "TBD" for agent to decide)
- Theme/concept direction (e.g., "coming of age", "dystopian noir", "summer road trip")
- Track count (default: 10)
- Target BPM range, preferred keys
- Reference artists/albums for sonic direction
- Target audience, mood keywords
- Release timeline (target date, singles schedule)

### `config/production-config.yaml`
- Default audio generation model (e.g., `meta/musicgen:large`)
- Audio format preferences (WAV, 44.1kHz, 16-bit)
- Mastering loudness target (e.g., -14 LUFS for streaming)
- Artwork generation model (e.g., `stability-ai/sdxl`)
- Artwork dimensions (3000x3000 for album cover)

### `config/distribution-config.yaml`
- Primary distributor (DistroKid, TuneCore, etc.)
- Platform priorities (Spotify, Apple Music, YouTube Music, etc.)
- Genre/subgenre classification for stores
- Language, copyright holder, label name
- Territory (worldwide vs specific regions)

---

## Data Files (populated by pipeline)

| File | Written By | Contains |
|---|---|---|
| `data/album-concept.json` | develop-concept | Concept statement, mood board, sonic references |
| `data/track-listing.json` | develop-concept | Ordered tracks with BPM, key, mood, working titles |
| `data/lyrics/track-{nn}-*.json` | write-lyrics | Per-track structured lyrics with sections |
| `data/lyrics-summary.json` | write-lyrics | Lyrical themes overview |
| `data/compositions/track-{nn}-*.json` | compose-tracks | Per-track chords, melody, arrangement |
| `data/compositions-summary.json` | compose-tracks | Harmonic overview, key relationships |
| `data/production/track-{nn}-*.json` | produce-tracks | Per-track instrumentation, mixing, audio prompts |
| `data/production-summary.json` | produce-tracks | Production approach, sonic cohesion |
| `data/audio-manifest.json` | generate-reference-audio | Generated audio file paths, durations, params |
| `data/audio-analysis.json` | analyze-audio | BPM, duration, levels, spectral data per track |
| `data/mastering-plan.json` | master-collection | Per-track mastering directives, album-level consistency |
| `data/artwork-brief.json` | design-artwork | Visual concept, prompts, colors, typography |
| `data/artwork-manifest.json` | generate-artwork | Generated artwork file paths |
| `output/audio/track-{nn}-*.wav` | generate-reference-audio | AI-generated reference audio |
| `output/artwork/cover-variant-*.png` | generate-artwork | AI-generated album cover variants |
| `output/liner-notes.md` | write-liner-notes | Artist statement, track commentary, credits |
| `output/distribution-metadata.json` | prepare-distribution | Formatted metadata for distributors |
| `output/credits.txt` | prepare-distribution | Formatted credits |
| `output/marketing-plan.md` | plan-marketing | Release strategy, playlist pitching, social plan |
| `output/press-release.md` | plan-marketing | Draft press release and EPK outline |

---

## Scripts

### `scripts/generate-audio.sh`
- Wraps Python script that reads production JSON files
- Constructs detailed prompts from track metadata (genre, BPM, key, mood, instruments)
- Calls Replicate API via `python3 -c "import replicate; ..."` or `replicate` CLI
- Falls back to creating placeholder `.wav` files with metadata if no API key
- Downloads results to `output/audio/`

### `scripts/analyze-audio.sh`
- Python script using `ffprobe` (from ffmpeg) for audio analysis
- Extracts: duration, sample rate, bit depth, peak amplitude
- Estimates BPM from audio characteristics
- Validates against target specs from track listing
- Writes structured analysis JSON

### `scripts/generate-artwork.sh`
- Python script calling Replicate API for image generation
- Reads prompts from `data/artwork-brief.json`
- Generates multiple variants at 3000x3000
- Falls back to creating placeholder images if no API key
- Downloads to `output/artwork/`

### `scripts/prepare-metadata.sh`
- Python script that aggregates all data files into distribution format
- Compiles track listing with durations, credits, ISRC placeholders
- Formats for common distributor CSV/JSON schemas
- Generates credits.txt from all contributor data

---

## Schedules

None — album production is a one-shot workflow triggered per project.

---

## README Outline

1. Title + one-line description
2. How It Works — ASCII flow diagram of the 15-phase pipeline
3. Agents table (6 agents across 3 models)
4. AO Features Demonstrated
   - Multi-agent pipeline (creative + technical + business agents)
   - Phase routing with decision gates (concept review, production review, final review)
   - Command phases (audio generation, audio analysis, artwork generation, metadata prep)
   - Multi-model routing (Opus for creative direction, Sonnet for production, Haiku for support)
   - Sequential-thinking for creative concept development
   - Output contracts (structured JSON for every phase)
5. Quick Start (edit album-brief.yaml, run workflow)
6. Requirements (Node.js, Python 3, AO CLI, optional: Replicate API key, ffmpeg)
7. Project Layout tree
8. Workflow Details — all 15 phases explained
9. Customization (change genre, track count, models, target platforms)
10. Sample Output (example album concept, track listing, marketing plan)
