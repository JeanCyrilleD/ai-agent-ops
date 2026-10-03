#!/bin/bash
# Fleet mission dispatcher with charter injection for stateless LLM channels.
# From the ai-agent-ops stack (sanitized).

#!/bin/bash
# fleet_dispatch — exécute une mission sur un atelier. Usage :
#   dispatch.sh perplexity "question" [fast|low|medium|high]   → outbox/
#   dispatch.sh status
set -u
F="$HOME/.bionic-tools/fleet"; OUT="$F/outbox"; mkdir -p "$OUT"
TS=$(date +%Y%m%d_%H%M%S)
CHARTER_DIGEST=$(cat "$HOME/.lmstudio/skills/charte-agents/SKILL.md" 2>/dev/null || echo "charte indisponible")
case "${1:-}" in
  perplexity)
    Q="${2:?question manquante}"; P="${3:-fast}"
    echo ">> dispatch perplexity ($P)…" >&2
    if "$HOME/.bionic-tools/perplexity_ask.py" "[CHARTE OBLIGATOIRE — v1.1 ratifiée. Applique ces règles à ta réponse :]
$CHARTER_DIGEST
---
MISSION : $Q" "$P" >"$OUT/perplexity_$TS.md" 2>"$OUT/perplexity_$TS.err"; then
      echo "✓ outbox/perplexity_$TS.md ($(wc -c <"$OUT/perplexity_$TS.md" | tr -d ' ') octets)"
    else
      echo "✗ échec — voir outbox/perplexity_$TS.err"; exit 1
    fi ;;
  status)
    M=$(ls "$F/missions" 2>/dev/null | grep -vc TEMPLATE)
    O=$(ls "$OUT" 2>/dev/null | grep -c '\.md$')
    echo "missions en attente: ${M} · sorties en outbox: ${O}" ;;
  *) grep '^#' "$0" | head -4; exit 1 ;;
esac
