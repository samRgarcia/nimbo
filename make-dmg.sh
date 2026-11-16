#!/bin/bash
# Crea el instalador de Nimbo: un archivo .dmg con la app y un acceso a Aplicaciones.
# Creates the Nimbo installer: a .dmg file with the app and a shortcut to Applications.
#
# Sin cuenta de desarrollador (macOS avisará al abrirlo en otro equipo):
# Without a developer account (macOS will warn when it is opened on another Mac):
#   bash make-dmg.sh
#
# Firmado y notarizado (se abre sin avisos) / Signed and notarized (opens with no warnings):
#   SIGN_ID="Developer ID Application: Tu Nombre (TEAMID)" NOTARY_PROFILE="nimbo" bash make-dmg.sh
#
# NOTARY_PROFILE es un perfil guardado una sola vez con / is a profile saved once with:
#   xcrun notarytool store-credentials "nimbo" --apple-id TU_CORREO --team-id TEAMID --password CONTRASEÑA_DE_APP
set -euo pipefail
cd "$(dirname "$0")"

SIGN_ID="${SIGN_ID:--}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
APP="build/Nimbo.app"
DMG="build/Nimbo-$VERSION.dmg"

# 1. Compila para Apple silicon e Intel, sin abrir la app.
UNIVERSAL=1 NO_OPEN=1 SIGN_ID="$SIGN_ID" bash build-app.sh

# 2. Arma el contenido del instalador: la app y un acceso directo a Aplicaciones.
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# 3. Crea el .dmg comprimido.
hdiutil create -volname "Nimbo" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

# 4. Firma y notariza, si se indicó una identidad de Developer ID.
if [ "$SIGN_ID" != "-" ]; then
    codesign --force --sign "$SIGN_ID" --timestamp "$DMG"
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$DMG"
        echo "Instalador firmado y notarizado: $DMG"
    else
        echo "Instalador firmado, pero SIN notarizar (falta NOTARY_PROFILE): $DMG"
    fi
else
    echo "Instalador sin firma de desarrollador: $DMG"
    echo "En otros equipos macOS lo bloqueará hasta que el usuario lo autorice a mano."
fi

echo "Para publicarlo en GitHub Releases: bash release.sh"
