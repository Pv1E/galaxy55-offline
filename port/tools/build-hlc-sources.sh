#!/bin/sh
# Codigo C (HashLink/C) del juego y del servidor para el zip de macOS (port/tools/package.ps1 -Hlc port/out/hlc.zip).
# Se genera en Linux: Haxe nombra algunos tipos internos con un contador de mayusculas y minusculas (_std/_sP.h y _std/_sp.h)
# y en Windows, que no las distingue, un archivo pisa al otro y el C no compila. Corre en la imagen oficial de Haxe, con las
# librerias de tools-portable sin haxelib (sus rutas "dev" son de Windows). Uso, desde la raiz del repo en WSL o Linux:
#   docker run --rm -v "$PWD:/repo:ro" -v "$PWD/../tools-portable:/tp:ro" -v "$PWD/port/out:/out" haxe:4.3.7 \
#     sh /repo/port/tools/build-hlc-sources.sh
# Deja /out/hlc.zip con hlc/game (galaxy55.c) y hlc/server (server.c).
set -e
cd /repo
libs() {
	# heaps trae format, como "haxelib path heaps"
	sed -e 's#^-lib heaps$#-cp /tp/src/heaps\n-D heaps=2.1.0\n-cp /tp/haxelib/format/3,8,0\n-D format=3.8.0#' \
		-e 's#^-lib format$#-cp /tp/haxelib/format/3,8,0\n-D format=3.8.0#' \
		-e 's#^-lib hlopenal$#-cp /tp/src/hashlink/libs/openal\n-D hlopenal=1.16.0#' \
		-e 's#^-lib hlsdl$#-cp /tp/src/hashlink/libs/sdl\n-D hlsdl=1.16.0#' \
		-e '/^-hl /d' "$1"
}
# el generador de C pide la libreria "hashlink" a haxelib: un repositorio con solo ella, en tools-portable
mkdir -p /tmp/haxelib/hashlink && echo /tp/src/hashlink/other/haxelib > /tmp/haxelib/hashlink/.dev
export HAXELIB_PATH=/tmp/haxelib
rm -rf /tmp/hlc && mkdir -p /tmp/hlc
libs port/game.hxml > /tmp/game_c.hxml && echo "-hl /tmp/hlc/hlc/game/galaxy55.c" >> /tmp/game_c.hxml
libs port/server.hxml > /tmp/server_c.hxml && echo "-hl /tmp/hlc/hlc/server/server.c" >> /tmp/server_c.hxml
if grep -q '^-lib ' /tmp/game_c.hxml /tmp/server_c.hxml; then echo "libreria sin ruta:"; grep '^-lib ' /tmp/*_c.hxml; exit 1; fi
haxe /tmp/game_c.hxml
haxe /tmp/server_c.hxml
cd /tmp/hlc
if command -v python3 > /dev/null; then
	python3 -c "import os, zipfile
z = zipfile.ZipFile('/tmp/hlc.zip', 'w', zipfile.ZIP_DEFLATED)
for d, _, fs in os.walk('hlc'):
	for f in sorted(fs): z.write(os.path.join(d, f))
z.close()"
else
	(apt-get update -qq && apt-get install -y -qq zip) > /dev/null 2>&1
	zip -qr /tmp/hlc.zip hlc
fi
cp /tmp/hlc.zip /out/hlc.zip
echo "hlc.zip: $(find hlc -type f | wc -l) archivos"
