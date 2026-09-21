#!/usr/bin/env bash
# Toglie la roba vecchia da GitHub, così niente si accumula fino alla quota.
#
#   scripts/pulizia.sh --prova     mostra cosa toglierebbe, senza toccare niente
#   scripts/pulizia.sh             toglie davvero
#
# Cosa fa, sul repository dei sorgenti (privato) e su questo:
#   - cancella le esecuzioni di Actions vecchie (restano le ultime $TIENI_RUN);
#   - cancella tutti gli Artifacts e le cache (la CI non ne usa: se ci sono, sono avanzi);
#   - sulle release "vX.Y.Z" tiene i pacchetti delle ultime $TIENI_VERSIONI versioni
#     e svuota i pacchetti delle più vecchie (la release, il tag e le note restano);
#     le bozze vecchie fuori da quelle versioni si cancellano per intero.
# "prova-installer" non si tocca: si riscrive da sé a ogni build.
#
# Nell'esecuzione automatica i token arrivano da TOKEN_SORGENTI e TOKEN_BUILD;
# dal Mac, senza variabili, si usa l'account di "gh".
set -euo pipefail

SORGENTI="${SORGENTI:-FMJones/ai-lab}"
BUILD="${BUILD:-FMJones/ai-lab-build}"
TIENI_RUN="${TIENI_RUN:-15}"
TIENI_VERSIONI="${TIENI_VERSIONI:-2}"
PROVA=0
[ "${1:-}" = "--prova" ] && PROVA=1

# gh con il token giusto per il repository giusto.
g() {
  local repo="$1"; shift
  if [ "$repo" = "$SORGENTI" ] && [ -n "${TOKEN_SORGENTI:-}" ]; then
    GH_TOKEN="$TOKEN_SORGENTI" gh "$@"
  elif [ "$repo" = "$BUILD" ] && [ -n "${TOKEN_BUILD:-}" ]; then
    GH_TOKEN="$TOKEN_BUILD" gh "$@"
  else
    gh "$@"
  fi
}

# Esegue la cancellazione (o la descrive, con --prova).
cancella() {  # descrizione repo percorso-api
  if [ "$PROVA" -eq 1 ]; then
    echo "  [prova] $1"
  else
    g "$2" api -X DELETE "$3" >/dev/null 2>&1 && echo "  cancellato: $1" || echo "  NON riuscito: $1"
  fi
}

for REPO in "$SORGENTI" "$BUILD"; do
  echo "== $REPO =="

  # Esecuzioni concluse, dalla più recente: si salta le prime TIENI_RUN.
  echo "Esecuzioni vecchie:"
  g "$REPO" api --paginate "repos/$REPO/actions/runs?per_page=100" \
      --jq '.workflow_runs[] | select(.status=="completed") | [.id, .name, .created_at] | @tsv' \
    | tail -n +"$((TIENI_RUN + 1))" \
    | while IFS=$'\t' read -r ID NOME QUANDO; do
        cancella "esecuzione $ID ($NOME, $QUANDO)" "$REPO" "repos/$REPO/actions/runs/$ID"
      done

  echo "Artifacts:"
  g "$REPO" api --paginate "repos/$REPO/actions/artifacts?per_page=100" \
      --jq '.artifacts[] | [.id, .name] | @tsv' \
    | while IFS=$'\t' read -r ID NOME; do
        cancella "artifact $ID ($NOME)" "$REPO" "repos/$REPO/actions/artifacts/$ID"
      done

  echo "Cache:"
  g "$REPO" api --paginate "repos/$REPO/actions/caches?per_page=100" \
      --jq '.actions_caches[] | [.id, .key] | @tsv' \
    | while IFS=$'\t' read -r ID CHIAVE; do
        cancella "cache $ID ($CHIAVE)" "$REPO" "repos/$REPO/actions/caches/$ID"
      done
done

echo "== Release di $SORGENTI =="
# Le release "vX.Y.Z" dalla versione più alta: le prime TIENI_VERSIONI tengono i pacchetti.
POS=0
while IFS=$'\t' read -r TAG BOZZA; do
  POS=$((POS + 1))
  if [ "$POS" -le "$TIENI_VERSIONI" ]; then
    echo "$TAG: tenuta con i suoi pacchetti"
    continue
  fi
  if [ "$BOZZA" = "true" ]; then
    ID=$(g "$SORGENTI" api "repos/$SORGENTI/releases?per_page=100" --jq ".[] | select(.tag_name==\"$TAG\") | .id")
    cancella "bozza $TAG per intero" "$SORGENTI" "repos/$SORGENTI/releases/$ID"
    continue
  fi
  echo "$TAG: svuoto i pacchetti (release e note restano)"
  g "$SORGENTI" api "repos/$SORGENTI/releases?per_page=100" \
      --jq ".[] | select(.tag_name==\"$TAG\") | .assets[] | [.id, .name, .size] | @tsv" \
    | while IFS=$'\t' read -r ID NOME DIM; do
        cancella "pacchetto $NOME ($((DIM / 1048576)) MB)" "$SORGENTI" "repos/$SORGENTI/releases/assets/$ID"
      done
done < <(g "$SORGENTI" api --paginate "repos/$SORGENTI/releases?per_page=100" \
           --jq '.[] | select(.tag_name | test("^v[0-9]")) | [.tag_name, .draft] | @tsv' \
         | sort -t$'\t' -k1,1 -V -r)

echo "Fatto."
