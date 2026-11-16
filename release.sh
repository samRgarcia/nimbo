#!/bin/bash
# Publica una versión de Nimbo en GitHub Releases.
#
# Uso:   bash release.sh
#
# Toma la versión de Support/Info.plist, genera el instalador y lo sube como:
#   Nimbo.dmg            nombre fijo, para un enlace de descarga que no cambia
#   Nimbo-<versión>.dmg  copia con el número de versión
# Si la versión ya existe en GitHub, reemplaza sus archivos.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
TAG="v$VERSION"

if ! command -v gh >/dev/null 2>&1; then
    echo "Falta la herramienta de GitHub (gh). Instálala y entra a tu cuenta:"
    echo "  brew install gh && gh auth login"
    exit 1
fi

# La versión se etiqueta sobre lo que ya está en GitHub: avisa si hay trabajo sin subir.
if [ -n "$(git status --porcelain)" ]; then
    echo "Aviso: hay cambios sin commit. La versión $TAG se publicará sin ellos."
fi
if [ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}' 2>/dev/null || echo none)" ]; then
    echo "Aviso: hay commits sin subir (git push). La etiqueta $TAG apuntará a lo último que esté en GitHub."
fi

bash make-dmg.sh
cp -f "build/Nimbo-$VERSION.dmg" build/Nimbo.dmg

if [ "${SIGN_ID:--}" != "-" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
    GATEKEEPER_ES="Esta versión está firmada y notarizada por Apple."
    GATEKEEPER_EN="This build is signed and notarized by Apple."
else
    GATEKEEPER_ES="Esta versión no está notarizada: si macOS la bloquea, ve a Ajustes del Sistema › Privacidad y seguridad y pulsa \"Abrir igualmente\"."
    GATEKEEPER_EN="This build is not notarized: if macOS blocks it, go to System Settings › Privacy & Security and click \"Open Anyway\"."
fi

NOTES="$(mktemp)"
cat > "$NOTES" <<NOTES_EOF
## Nimbo $VERSION

Descarga \`Nimbo.dmg\` aquí abajo, ábrelo y arrastra Nimbo a Aplicaciones.
Download \`Nimbo.dmg\` below, open it and drag Nimbo into Applications.

Requiere macOS 14 o posterior (Apple silicon o Intel). / Requires macOS 14 or later (Apple silicon or Intel).

$GATEKEEPER_ES
$GATEKEEPER_EN

Datos del clima / Weather data: [Open-Meteo](https://open-meteo.com/) (CC BY 4.0).
NOTES_EOF

if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" build/Nimbo.dmg "build/Nimbo-$VERSION.dmg" --clobber
    echo "Versión $TAG actualizada."
else
    gh release create "$TAG" build/Nimbo.dmg "build/Nimbo-$VERSION.dmg" --title "Nimbo $VERSION" --notes-file "$NOTES"
    echo "Versión $TAG publicada."
fi
rm -f "$NOTES"

echo "Descarga directa: $(gh repo view --json url -q .url)/releases/latest/download/Nimbo.dmg"
