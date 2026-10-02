#!/usr/bin/env bash
# ============================================================================
# Staging locale: catena completa delle migrazioni + prove SQL.
# Solo sul Postgres di prova del container (dati inventati), mai su Supabase.
#
#   1. database nuovo: supporto_supabase.sql + 0000 -> ultima migrazione;
#   2. confronto della struttura con catalogo_produzione.txt: le differenze
#      devono essere esattamente quelle di catalogo_differenze_attese.txt;
#   3. ogni supabase/tests/*_test.sql su un database nuovo con la catena,
#      fino alla migrazione scritta nella sua riga "-- catena-fino-a: NNNN"
#      (senza la riga: catena completa). Così la prova carica i suoi dati e
#      applica da sé la migrazione che prova, su tabelle già piene.
# Alla fine elimina database e ruoli (sono globali al cluster).
#
# Uso: supabase/tests/run_chain.sh
# Connessione: PGHOST/PGPORT/PGUSER, predefiniti quelli del Postgres di prova
# avviato da .claude/hooks/session-start.sh.
# ============================================================================
set -euo pipefail

export PGHOST="${PGHOST:-/var/tmp/ecora-pg}"
export PGPORT="${PGPORT:-54329}"
export PGUSER="${PGUSER:-postgres}"
export LC_ALL=C
# Solo avvisi ed errori; le prove rialzano il livello per contare i "ok".
export PGOPTIONS="-c client_min_messages=warning"

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
MIGRATIONS_DIR="$(cd "$TESTS_DIR/../migrations" && pwd)"
PREFIX="ecora_catena"
PSQL=(psql -X -q -v ON_ERROR_STOP=1)
TMP="$(mktemp -d)"

drop_all() {
  for db in $("${PSQL[@]}" -d postgres -Atc \
      "select datname from pg_database where datname like '${PREFIX}_%'"); do
    "${PSQL[@]}" -d postgres -c "drop database if exists \"$db\"" >/dev/null
  done
  "${PSQL[@]}" -d postgres -c \
    "drop role if exists anon; drop role if exists authenticated; drop role if exists service_role;" \
    >/dev/null 2>&1 \
    || echo "attenzione: ruoli anon/authenticated/service_role ancora usati da un altro database del cluster" >&2
}
trap 'drop_all; rm -rf "$TMP"' EXIT
drop_all

# Crea il database $1 e ci applica supporto + catena fino alla migrazione
# $2 compresa (predefinito: tutte).
apply_chain() {
  local db="$1" fino_a="${2:-9999}"
  "${PSQL[@]}" -d postgres -c "create database \"$db\"" >/dev/null
  # (l'avviso sul wal_level della publication è normale in locale)
  "${PSQL[@]}" -d "$db" -f "$TESTS_DIR/supporto_supabase.sql" >/dev/null 2>"$TMP/errore" || {
    cat "$TMP/errore" >&2; exit 1; }
  for m in "$MIGRATIONS_DIR"/[0-9][0-9][0-9][0-9]_*.sql; do
    local n; n="$(basename "$m")"; n="${n:0:4}"
    [ "$((10#$n))" -le "$((10#$fino_a))" ] || break
    "${PSQL[@]}" -d "$db" -f "$m" >/dev/null 2>"$TMP/errore" || {
      echo "ERRORE applicando $(basename "$m"):" >&2
      cat "$TMP/errore" >&2
      rm -f "$TMP/errore"
      exit 1
    }
  done
  rm -f "$TMP/errore"
}

# --- 1. Catena -----------------------------------------------------------------
echo "== Catena: supporto + $(ls "$MIGRATIONS_DIR"/[0-9][0-9][0-9][0-9]_*.sql | wc -l) migrazioni"
apply_chain "${PREFIX}_struttura"
# Niente seconda passata dell'intera catena: 0001 e 0003 creano policy senza
# cancellarle prima e non si possono rieseguire (annotato in PIANO_LAVORO).
# La 0000 sì, e così le migrazioni che le prove rieseguono da sé.
"${PSQL[@]}" -d "${PREFIX}_struttura" -f "$MIGRATIONS_DIR/0000_schema_base.sql" >/dev/null
echo "ok  catena applicata, 0000 rieseguita sopra la catena"

# --- 2. Confronto con la produzione ------------------------------------------------
staging="$("${PSQL[@]}" -d "${PREFIX}_struttura" -At -f "$TESTS_DIR/catalogo.sql" | sort)"
produzione="$(grep -v '^#' "$TESTS_DIR/catalogo_produzione.txt" | sed '/^$/d' | sort)"
trovate="$( { comm -23 <(echo "$produzione") <(echo "$staging") | sed 's/^/solo produzione: /'
             comm -13 <(echo "$produzione") <(echo "$staging") | sed 's/^/solo staging: /'; } | sort)"
attese="$(grep -v '^#' "$TESTS_DIR/catalogo_differenze_attese.txt" | sed '/^$/d' | sort)"
if [ "$trovate" != "$attese" ]; then
  echo "FALLITA: la struttura dello staging non corrisponde alla produzione." >&2
  echo "Differenze nuove (+) o non più presenti (-) rispetto a catalogo_differenze_attese.txt:" >&2
  diff <(echo "$attese") <(echo "$trovate") | grep '^[<>]' | sed 's/^</-/; s/^>/+/' >&2 || true
  exit 1
fi
echo "ok  struttura uguale alla produzione, salvo $(echo "$attese" | sed '/^$/d' | wc -l) differenze attese"

# --- 3. Prove ------------------------------------------------------------------------
for t in "$TESTS_DIR"/*_test.sql; do
  name="$(basename "$t" .sql)"
  fino_a="$(sed -n 's/^-- catena-fino-a: *\([0-9]\{4\}\).*/\1/p' "$t" | head -1)"
  echo "== $name (catena fino a ${fino_a:-ultima})"
  apply_chain "${PREFIX}_${name}" "${fino_a:-9999}"
  out="$TMP/uscita"
  if ! PGOPTIONS="-c client_min_messages=notice" \
      "${PSQL[@]}" -d "${PREFIX}_${name}" -f "$t" >"$out" 2>&1; then
    cat "$out" >&2
    rm -f "$out"
    exit 1
  fi
  grep -c '^psql:.*NOTICE:  ok\|^NOTICE:  ok' "$out" | sed 's/^/ok  verifiche superate: /'
  grep 'SUPERATE' "$out" || { echo "FALLITA: $name non è arrivata in fondo" >&2; exit 1; }
  rm -f "$out"
done
echo "TUTTA LA CATENA E TUTTE LE PROVE SUPERATE"
