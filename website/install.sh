#!/bin/bash
# Nimbo installer for the Terminal / Instalador de Nimbo para la Terminal.
# Usage / Uso:  curl -fsSL https://nimbo.samdev.space/install.sh | bash
#
# What it does: downloads Nimbo.dmg from GitHub Releases, copies Nimbo.app to Applications and opens it.
# It asks for no password and installs nothing else.
# Qué hace: descarga Nimbo.dmg desde GitHub Releases, copia Nimbo.app a Aplicaciones y la abre.
# No pide contraseña ni instala nada más.
set -euo pipefail

# The installer comes from the latest GitHub release (override with NIMBO_DMG_URL).
# El instalador viene de la última versión publicada en GitHub.
DMG_URL="${NIMBO_DMG_URL:-https://github.com/samRgarcia/nimbo/releases/latest/download/Nimbo.dmg}"

# Messages in Spanish when the system is in Spanish, English otherwise.
# Mensajes en español si el sistema está en español; en inglés en otro caso.
LOCALE="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
if [ -z "$LOCALE" ] && command -v defaults >/dev/null 2>&1; then
    LOCALE="$(defaults read -g AppleLocale 2>/dev/null || true)"
fi
case "$LOCALE" in
    es*) ES=1 ;;
    *) ES=0 ;;
esac
say() {
    if [ "$ES" = "1" ]; then echo "$1"; else echo "$2"; fi
}

if [ "$(uname -s)" != "Darwin" ]; then
    say "Nimbo solo funciona en macOS." "Nimbo only runs on macOS." >&2
    exit 1
fi
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MAJOR" -lt 14 ]; then
    say "Nimbo necesita macOS 14 o posterior (tienes $(sw_vers -productVersion))." \
        "Nimbo needs macOS 14 or later (you have $(sw_vers -productVersion))." >&2
    exit 1
fi

# Aplicaciones del sistema si se puede escribir ahí; si no, la carpeta Aplicaciones del usuario.
# The system Applications folder when it is writable; otherwise the user's own Applications folder.
DEST="/Applications"
if [ ! -w "$DEST" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
fi

TMP="$(mktemp -d)"
cleanup() {
    hdiutil detach "$TMP/mnt" -quiet 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

say "Descargando Nimbo…" "Downloading Nimbo…"
curl -fL --progress-bar "$DMG_URL" -o "$TMP/Nimbo.dmg"

say "Instalando en $DEST…" "Installing to $DEST…"
mkdir "$TMP/mnt"
hdiutil attach "$TMP/Nimbo.dmg" -nobrowse -quiet -mountpoint "$TMP/mnt"
pkill -x Nimbo 2>/dev/null || true
rm -rf "$DEST/Nimbo.app"
cp -R "$TMP/mnt/Nimbo.app" "$DEST/"
# Por si la copia heredó la marca de descarga de internet. / In case the copy kept the downloaded-from-internet flag.
xattr -dr com.apple.quarantine "$DEST/Nimbo.app" 2>/dev/null || true

say "Listo. Abriendo Nimbo… Búscala en la barra de menús." "Done. Opening Nimbo… Look for it in the menu bar."
open "$DEST/Nimbo.app"
