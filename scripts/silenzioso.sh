# Da includere con "source": esegue un comando senza mostrare il suo output.
#
# Questo repository è PUBBLICO, quindi i suoi log lo sono. I sorgenti no:
# gli errori di compilazione (Cython, PyInstaller) possono citare righe di
# codice. Perciò l'output dei passi che toccano i sorgenti va in un file, e
# se il passo fallisce il file viene caricato nella release PRIVATA
# dell'altro repository, non stampato qui.
#
# Uso:  silenzioso NOME comando arg...
# Serve SORGENTI (es. FMJones/ai-lab) e GH_TOKEN con accesso a quel repo.
silenzioso() {
  local nome="$1"; shift
  local log="${RUNNER_TEMP:-/tmp}/${nome}.log" rc=0
  "$@" >"$log" 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "[$nome] ok"
    return 0
  fi
  local asset="log-${RUNNER_OS:-locale}-${nome}.txt"
  echo "[$nome] FALLITO (codice $rc). Log completo nella release privata prova-installer: $asset"
  cp "$log" "$asset"
  gh release view prova-installer --repo "$SORGENTI" >/dev/null 2>&1 \
    || gh release create prova-installer --repo "$SORGENTI" --prerelease \
         --title "AI-Lab — build di prova" --notes "Ultima build di prova." || true
  gh release upload prova-installer "$asset" --repo "$SORGENTI" --clobber || true
  return "$rc"
}
