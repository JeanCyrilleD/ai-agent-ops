# ai-agent-ops

AI agent operations stack: a six-atelier multi-agent LLM fleet run by a single operator, governed by a
ratified 45-article operating constitution, with background-only automation and an automated daily
intelligence pipeline.

## What's here
- `scripts/morning_intel_paper.sh` — scheduled LLM web-research collection that composes a sourced,
  plain-language daily brief and delivers it to the desktop with a clickable notification, sound and voice.
  Includes hallucination guards (facts filtered against a known-events register) and explicit
  "could not confirm" statements when a collection fails.
- `scripts/fleet_dispatch.sh` — mission dispatcher for multi-vendor LLM channels, injecting the operating
  constitution into every stateless-channel call (governance by protocol, not by promise).
- `docs/operating-principles.md` — ten operating rules distilled from production incidents.

## Why
Most agent demos show what AI can do. This repo is about the other half: keeping agent systems alive —
incident forensics, credential hygiene, background operations that never disturb the operator, and
governance that survives contact with reality.

## Notes
Scripts are sanitized (no personal paths, no secrets, no client content). They assume macOS + a
web-research-capable LLM CLI. See `docs/operating-principles.md` before adapting them.
