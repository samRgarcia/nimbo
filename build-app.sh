#!/bin/bash
# Compila Nimbo y arma build/Nimbo.app.
#
# Variables opcionales:
#   UNIVERSAL=1   compila para Apple silicon e Intel a la vez (para distribuir)
#   SIGN_ID="Developer ID Application: Tu Nombre (TEAMID)"   firma para distribuir
#   NO_OPEN=1     no abre la app al terminar
set -euo pipefail
cd "$(dirname "$0")"

SIGN_ID="${SIGN_ID:--}"
ARCH_FLAGS=""
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS="--arch arm64 --arch x86_64"
fi

# El resultado de la compilación también queda en build/build.log.
mkdir -p build
# shellcheck disable=SC2086
swift build -c release $ARCH_FLAGS 2>&1 | tee build/build.log
# shellcheck disable=SC2086
BIN_DIR="$(swift build -c release $ARCH_FLAGS --show-bin-path)"

APP="build/Nimbo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f "$BIN_DIR/Nimbo" "$APP/Contents/MacOS/Nimbo"
cp -f Support/Info.plist "$APP/Contents/Info.plist"
if [ -f Support/AppIcon.icns ]; then
    cp -f Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Firma local ("-") para uso propio, o con Developer ID para distribuir.
if [ "$SIGN_ID" = "-" ]; then
    codesign --force --sign - "$APP"
else
    codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$APP"
fi
touch "$APP"

echo "Listo: $APP"
if [ "${NO_OPEN:-0}" != "1" ]; then
    pkill -x Nimbo 2>/dev/null || true
    sleep 0.5
    open "$APP"
fi
