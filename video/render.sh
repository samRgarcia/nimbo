#!/bin/bash
# Genera el video en español y en inglés y lo deja en website/media.
# Renders the video in Spanish and English into website/media.
#
# Uso / Usage:   bash render.sh
# Requiere / Requires: Node 22+, FFmpeg, Python 3.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p ../website/media
for LANG_CODE in es en; do
    python3 gen.py "$LANG_CODE"
    npx --yes hyperframes@0.9.52 render . -o "../website/media/nimbo-$LANG_CODE.mp4" --crf 23
done
# Deja index.html en español para la vista previa (npm run dev).
python3 gen.py es
echo "Listo / Done: website/media/nimbo-es.mp4, website/media/nimbo-en.mp4"
