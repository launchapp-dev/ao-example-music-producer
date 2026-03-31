# Music Album Production Pipeline — Agent Context

## What This Project Does

This is an AI-powered music album production pipeline. It takes a creative brief
(`config/album-brief.yaml`) and produces a complete, release-ready album package:
lyrics, compositions, production specs, reference audio, artwork, liner notes,
distribution metadata, and a marketing plan.

## Your Role as an Agent

When you are invoked in this project, you are one of several specialized agents
in a 15-phase pipeline. Read your phase directive carefully — it specifies exactly
what to read, what to produce, and what JSON structure to write.

## Critical Conventions

### File Naming
- Track files use zero-padded numbers: `track-01-title.json`, `track-02-title.json`
- Titles in filenames use lowercase with hyphens: `track-03-midnight-drive.json`
- Do NOT use spaces in filenames

### JSON Structure
- All data files must be valid JSON — no trailing commas, no comments
- Agent-written JSON must match the schemas specified in the phase directive exactly
- Missing required fields will cause downstream phases to fail

### Track Numbering
- Tracks are numbered starting from 1
- The final order may differ from the working order (set by the mastering plan)
- Always use `track_number` field in JSON to identify tracks, not filename position

### Decision Phases
When you are in a decision phase (review-concept, review-production, final-review),
your output MUST end with a JSON object on its own line:
```json
{"verdict": "approve", "reasoning": "..."}
```
or:
```json
{"verdict": "rework", "reasoning": "Specific issues: 1) ... 2) ..."}
```

### Working with MCP Servers

**filesystem** — Use for all file reads and writes in this project directory.
Read config files before starting your phase. Write all output files as specified.

**sequential-thinking** — Use for complex creative or analytical decisions:
- Album concept development (creative-director, develop-concept)
- Harmonic analysis across tracks (composer, compose-tracks)
- Production review reasoning (creative-director, review-production)

**fetch** — Use to research external information:
- Genre trends and recent releases
- Streaming platform editorial guidelines
- Music media outlets for press outreach

## Project Data Flow

```
config/album-brief.yaml ──► develop-concept
                              │
                         album-concept.json
                         track-listing.json
                              │
                         write-lyrics
                              │
                         data/lyrics/*.json
                         lyrics-summary.json
                              │
                         compose-tracks
                              │
                         data/compositions/*.json
                         compositions-summary.json
                              │
                         produce-tracks
                              │
                         data/production/*.json
                         production-summary.json
                              │
                         [scripts] → output/audio/*.wav
                                   → data/audio-manifest.json
                                   → data/audio-analysis.json
                              │
                         master-collection
                              │
                         data/mastering-plan.json
                              │
                         design-artwork
                              │
                         data/artwork-brief.json
                              │
                         [scripts] → output/artwork/*.png
                                   → data/artwork-manifest.json
                              │
                         write-liner-notes ──► output/liner-notes.md
                              │
                         [scripts] → output/distribution-metadata.json
                                   → output/credits.txt
                              │
                         plan-marketing ──► output/marketing-plan.md
                                         ──► output/press-release.md
```

## Config Files (Read These First)

`config/album-brief.yaml` — Artist name, genre, theme, track count, influences, release date.
This is the primary source of truth for the entire project.

`config/production-config.yaml` — Audio generation model, mastering targets, artwork settings.
Read this in command phases and production phases.

`config/distribution-config.yaml` — Distributor, platforms, copyright holder, territory.
Read this in prepare-distribution and plan-marketing phases.

## Quality Bar

Every deliverable in this pipeline must be:
- **Complete** — no placeholders, no TODOs, no "fill in later"
- **Specific** — concrete details, not generic descriptions
- **Consistent** — aligned with the album concept established in develop-concept
- **Structured** — valid JSON matching the schema in the phase directive

The creative-director's decision gates will catch and reject incomplete work.
Write as if a real artist will use these deliverables to release a real album.

## Genre Context

The default album brief is configured for **indie electronic / dream pop**.
Key aesthetic references: Bon Iver, Lana Del Rey, James Blake, Washed Out.
Sonic palette: warm analog synths, spacious reverb, intimate vocals, melancholic chord progressions.

If `config/album-brief.yaml` has been edited to a different genre, adapt all
creative decisions (chord progressions, production approach, marketing outlets)
to that genre instead.
