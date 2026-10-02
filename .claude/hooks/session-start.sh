#!/bin/bash
# SessionStart hook per le sessioni cloud di Claude Code (mai sul PC):
# prepara Flutter, Deno e un Postgres di prova per i test SQL
# (supabase/tests/*.sql). Idempotente: se qualcosa c'è già, lo salta.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FLUTTER_VERSION="3.47.5"
FLUTTER_DIR="/opt/flutter-sdk/flutter"
DENO_DIR_BIN="/opt/deno"
PG_BIN="/usr/lib/postgresql/16/bin"
PG_DIR="/var/tmp/ecora-pg"
PG_PORT="54329"

# Flutter usa git sul proprio SDK (proprietario diverso dall'utente).
git config --global --add safe.directory '*' >/dev/null 2>&1 || true

# --- Flutter -------------------------------------------------------------------
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  mkdir -p /opt/flutter-sdk
  curl -fsSL -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar -xf /tmp/flutter.tar.xz -C /opt/flutter-sdk
  rm -f /tmp/flutter.tar.xz
fi
"$FLUTTER_DIR/bin/flutter" --disable-analytics >/dev/null 2>&1 || true

# pub get. L'SDK più nuovo di quello del PC riscrive analysis_options.yaml e
# pubspec.lock: si ripristinano, ma solo se prima non c'erano modifiche.
cd "$PROJECT_DIR"
clean_before=true
git diff --quiet -- analysis_options.yaml pubspec.lock 2>/dev/null || clean_before=false
"$FLUTTER_DIR/bin/flutter" pub get >/dev/null
if [ "$clean_before" = true ]; then
  git checkout -- analysis_options.yaml pubspec.lock 2>/dev/null || true
fi

# --- Deno (controllo delle Edge Function) ----------------------------------------
if [ ! -x "$DENO_DIR_BIN/deno" ]; then
  mkdir -p "$DENO_DIR_BIN"
  curl -fsSL -o /tmp/deno.zip \
    https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip
  python3 -c "import zipfile; zipfile.ZipFile('/tmp/deno.zip').extractall('$DENO_DIR_BIN')"
  chmod +x "$DENO_DIR_BIN/deno"
  rm -f /tmp/deno.zip
fi

# --- Postgres di prova (dati inventati, mai dati veri) ----------------------------
# In /var/tmp e non nella scratchpad: /tmp/claude-0 torna a permessi 700 e il
# server, che gira come utente postgres, andrebbe in PANIC.
if [ -x "$PG_BIN/initdb" ]; then
  if [ ! -f "$PG_DIR/data/PG_VERSION" ]; then
    rm -rf "$PG_DIR"
    mkdir -p "$PG_DIR"
    chown postgres "$PG_DIR"
    su postgres -c "$PG_BIN/initdb -D $PG_DIR/data -A trust" >/dev/null
  fi
  if ! su postgres -c "$PG_BIN/pg_ctl -D $PG_DIR/data status" >/dev/null 2>&1; then
    su postgres -c "$PG_BIN/pg_ctl -D $PG_DIR/data -l $PG_DIR/log \
      -o '-k $PG_DIR -p $PG_PORT -c listen_addresses=' start" >/dev/null
  fi
fi

# --- Variabili per la sessione ----------------------------------------------------
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PATH=\"$FLUTTER_DIR/bin:$DENO_DIR_BIN:\$PATH\""
    echo "export DENO_CERT=/root/.ccr/ca-bundle.crt"
    echo "export PGHOST=$PG_DIR PGPORT=$PG_PORT PGUSER=postgres"
  } >> "$CLAUDE_ENV_FILE"
fi
