#!/bin/bash
# Toma las capturas del README: abre Nimbo en cada escena y guarda la pantalla principal.
# Takes the README screenshots: opens Nimbo in each scene and saves the main display.
#
# Uso / Usage:   bash capture.sh
#
# Las capturas quedan en docs/screenshots/<escena>.jpg y muestran TODO lo que haya en pantalla.
# Screenshots are saved to docs/screenshots/<scene>.jpg and show EVERYTHING on screen.
#
# La Terminal necesita permiso en Ajustes del Sistema › Privacidad y seguridad › Grabación de pantalla.
# Terminal needs permission in System Settings › Privacy & Security › Screen Recording.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Nimbo.app"
OUT="docs/screenshots"

if [ ! -d "$APP" ]; then
    echo "Falta $APP. Compila primero con: ./build-app.sh"
    exit 1
fi
mkdir -p "$OUT"

echo "Estas capturas se publicarán en GitHub y muestran todo lo que haya en tu pantalla."
echo "Antes de seguir:"
echo "  1. Cierra o esconde lo que no quieras publicar (correo, chats, pestañas, notificaciones)."
echo "  2. Deja dos o tres ventanas sencillas abiertas (por ejemplo Finder) para que la nieve se junte encima."
echo "  3. No muevas el ratón ni las ventanas mientras corre; tarda unos 2 minutos."
read -r -p "Pulsa Enter para empezar, o Ctrl+C para cancelar. " _

# Abre Nimbo en una escena fija (sin tocar tus ajustes guardados), espera y captura.
shot() {
    local scene="$1" wait="$2"
    pkill -x Nimbo 2>/dev/null || true
    sleep 0.8
    open -n "$APP" --args -scene "$scene" -auto NO -paused NO -intensity 1.2 -cabin YES
    echo "  ${scene}..."
    sleep "$wait"
    screencapture -x -m "$OUT/$scene.png"
    sips -s format jpeg -s formatOptions 82 -Z 1800 "$OUT/$scene.png" --out "$OUT/$scene.jpg" >/dev/null
    rm -f "$OUT/$scene.png"
}

# La nieve necesita más tiempo para que se vean los montones.
shot snow 45
shot rain 7
shot storm 7
shot petals 9
shot leaves 9
shot fireflies 7
shot meteors 7
shot cloud 7
shot mist 7
shot clear 7

# Vuelve a abrir Nimbo con tus ajustes normales.
pkill -x Nimbo 2>/dev/null || true
sleep 0.8
open "$APP"

echo "Listo: revisa las imágenes en $OUT antes de subirlas."
echo "  open $OUT"
