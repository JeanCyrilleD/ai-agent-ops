#!/bin/bash
# Morning intelligence paper — scheduled LLM web-research collection + human-readable delivery.
# From the ai-agent-ops stack (sanitized). Requires: a web-research-capable LLM CLI, macOS (launchd/afplay/say optional).

#!/bin/bash
# poste_du_matin — LE PAPIER DU MATIN (pour Ahadi, français clair) + brief technique interne.
# Canal : Desktop PAPIER_DU_MATIN_$T.md + notification cliquable + chime/voix (A7 : jamais de fenêtre forcée).
# La collecte veille (Perplexity, preset fast, routine Art. 41 — scheduling testé) s'exécute dans cette passe.
set -u
BT="$HOME/.bionic-tools"; F="$BT/fleet"; OUT="$F/briefs"
mkdir -p "$OUT" "$F/logs"
T=$(date +%F)
PAPIER="$HOME/Desktop/PAPIER_DU_MATIN_$T.md"
TECH="$OUT/tech_$T.md"

# ── 1. Données brutes ──────────────────────────────────────────────
CARDS=$(find "$BT/inbox" -name 'card_*.md' -mtime -1 2>/dev/null | sort -r)
NCARDS=0; [ -n "$CARDS" ] && NCARDS=$(echo "$CARDS" | grep -c .)
NTEAMS=0
CARDS_NOM=""
while IFS= read -r c; do
  [ -n "$c" ] || continue
  t=$(grep -m1 '^#' "$c" 2>/dev/null | sed 's/^# *//' | head -c 90)
  case "$t" in "Activité Teams à vérifier"|"") NTEAMS=$((NTEAMS+1)); continue ;; esac
  CARDS_NOM="${CARDS_NOM}  · $t
"
done <<EOF2
$CARDS
EOF2
DUE=$(grep -B4 'status: DUE' "$BT/state/commitments_mirror.yaml" 2>/dev/null | grep -E 'what:|due:' | sed 's/^ *what: */· /; s/^ *due: */   échéance : /; s/"//g')
ND=$(grep -c 'status: DUE' "$BT/state/commitments_mirror.yaml" 2>/dev/null || echo 0)
ECH=$(grep -E 'date:|quoi:' "$F/PRIORITES.yaml" 2>/dev/null | sed 's/^ *- *date: */· /; s/^ *- *quoi: */   — /; s/^ *quoi: */   — /; s/"//g')

# ── 2. Collecte veille du matin (Perplexity, preset fast) ──────────
RAW="$OUT/veille_collecte_$T.md"
Q="Veille humanitaire-sécuritaire, fenêtre dernières 24 heures : uniquement les faits NOUVEAUX datés. Zones : Éthiopie/Corne (Tigré, Afar, Érythrée, accès humanitaire), Somalie (civils, santé, déplacements), Soudan (El Obeid, Darfour, accès, cessez-le-feu), Sahel/AES (Mali, Burkina Faso, Niger : attaques, déplacements, politique), financements (OCHA, WFP, UNICEF, CERF). Pour chaque fait : date précise, source nommée avec date de publication, chiffres, impact sur les populations civiles. Pas d'opinions. Contexte déjà connu (ne pas répéter comme neuf) : rupture diplomatique Éthiopie-Érythrée 01-02/10, frappes El Obeid 30/09-01/10, CERF 160M$ 02/10."
"$HOME/.bionic-tools/perplexity_ask.py" "$Q" fast > "$RAW" 2>"$OUT/veille_collecte_$T.err"
COLLECT_NOTE="Collecte du matin : Perplexity (fast)."
NEWS="(Collecte indisponible cette passe — échec signalé, aucune absence d'événement déduite.)"
if [ -s "$RAW" ]; then
  NEWS=$(sed '/--- SOURCES ---/,$d' "$RAW" | head -c 2600)
  SRCS=$(sed -n '/--- SOURCES ---/,$p' "$RAW" | grep '^-' | head -8)
  COLLECT_NOTE="Collecte veille : Perplexity (fast), fenêtre 24 h, sources datées en fin de section."
else
  COLLECT_NOTE="⚠ Collecte veille ÉCHOUÉE ce matin (trace : fleet/outbox/veille_collecte_$T.err)."
fi

# ── 3. LE PAPIER (pour Ahadi — français clair) ─────────────────────
JOUR=$(date '+%d/%m/%Y')
{
echo "# ☀️ PAPIER DU MATIN — $JOUR"
echo
echo "## À RETENIR"
echo "- Prochaine échéance : **14/10 — CAFU Café** (deck prêt — répéter) · puis 25/10 e-Visa · 26/10 Note 3 pages + revue 90j"
[ "${ND:-0}" -gt 0 ] 2>/dev/null && echo "- **Engagements DUE : $ND** (détail ci-dessous)"
[ "$NCARDS" -gt 0 ] && echo "- Inbox 24 h : $NCARDS cartes dont $NTEAMS messages Teams à trier"
echo "- $COLLECT_NOTE"
echo
echo "## NOUVELLES DES ZONES (dernières 24 h — sources datées)"
echo "$NEWS"
if [ -n "$SRCS" ]; then echo; echo "**Sources du matin :**"; echo "$SRCS"; fi
echo
echo "## CE QUI T'ATTEND"
echo "$ECH"
if [ -n "$DUE" ]; then echo; echo "## ENGAGEMENTS DUE"; echo "$DUE"; fi
if [ -n "$CARDS_NOM" ]; then echo; echo "## MESSAGES À NOM (hors Teams génériques)"; echo "$CARDS_NOM"; fi
echo
echo "---"
echo "*Papier automatique (poste du matin) · bulletin complet : _CAFU_Livrables_Cles/Veille_Afrique/ · technique interne : fleet/briefs/tech_$T.md*"
} > "$PAPIER"

# ── 4. Brief technique interne (archivage — pas pour Ahadi) ────────
{
echo "# TECH — $T $(date '+%H:%M')"
echo "- Disque : $(df -g / | awk 'NR==2{print $4}') Go · Swap : $(sysctl -n vm.swapusage | sed 's/.*used = //;s/M.*//;s/ .*//') Mo · RAM : $(memory_pressure 2>/dev/null | awk '/free percentage/{gsub("%","",$NF);print $NF}') %"
echo "- Flotte : missions $(ls "$F/missions" 2>/dev/null | grep -vc TEMPLATE) · outbox $(ls "$F/outbox" 2>/dev/null | grep -c '\.md$')"
curl -s -m 3 -o /dev/null http://127.0.0.1:9222/json/version && echo "- CDP 9222 ✓" || echo "- CDP 9222 ✗"
pgrep -qx Comet && echo "- Comet ✓" || echo "- Comet éteint"
} > "$TECH" 2>>"$F/logs/erreurs.log"

# ── 5. Notification + chime/voix (A7 : rien ne vole le focus) ──────
MSG="Papier du matin prêt — clique pour lire"
if [ -x "/Applications/terminal-notifier.app/Contents/MacOS/terminal-notifier" ]; then
  "/Applications/terminal-notifier.app/Contents/MacOS/terminal-notifier" -title "☀️ Papier du matin — $JOUR" -message "$MSG" -execute "open \"$PAPIER\"" -group "poste-matin" >/dev/null 2>&1
else
  osascript -e "display notification \"$MSG\" with title \"☀️ Papier du matin\"" >/dev/null 2>&1
fi
afplay /System/Library/Sounds/Ping.aif 2>/dev/null
say -v "Thomas" "Papier du matin prêt." 2>/dev/null &
echo "papier : $PAPIER"
