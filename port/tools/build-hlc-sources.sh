#!/bin/sh
# Codigo C (HashLink/C) del juego y del servidor para el zip de macOS (port/tools/package.ps1 -Hlc port/out/hlc.zip) y para la
# app de macOS de GitHub Actions (.github/workflows/mac.yml). Se genera en Linux: Haxe nombra algunos tipos internos con un
# contador de mayusculas y minusculas (_std/_sP.h y _std/_sp.h) y en Windows, que no las distingue, un archivo pisa al otro.
# Corre en la imagen oficial de Haxe, con las librerias de tools-portable sin haxelib (sus rutas "dev" son de Windows).
# Uso, desde la raiz del repo en WSL o Linux:
#   docker run --rm -v "$PWD:/repo:ro" -v "$PWD/../tools-portable:/tp:ro" -v "$PWD/port/out:/out" haxe:4.3.7 \
#     sh /repo/port/tools/build-hlc-sources.sh
# Deja /out/hlc.zip con hlc/game (galaxy55.c) y hlc/server (server.c); con GEN=1 (-e GEN=1), tambien /out/hlc-gen.zip con
# hlc/gen (gen.c, el comprobador de planetas de port/headless/gen_ref.txt).
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
# hxml, carpeta y archivo principal de cada programa
gen() {
	libs "$1" > /tmp/c.hxml && echo "-hl /tmp/hlc/hlc/$2/$3" >> /tmp/c.hxml
	if grep -q '^-lib ' /tmp/c.hxml; then echo "libreria sin ruta en $1:"; grep '^-lib ' /tmp/c.hxml; exit 1; fi
	haxe /tmp/c.hxml
}
gen port/game.hxml game galaxy55.c
gen port/server.hxml server server.c
[ -n "$GEN" ] && gen port/headless.hxml gen gen.c
cd /tmp/hlc
# el disco de un Mac (APFS) tampoco distingue mayusculas por defecto: al descomprimir, _std/_sp.h pisaba a _std/_sP.h y el
# juego no compilaba ($_sp desconocido). Los archivos cuyo nombre solo cambia en mayusculas se renombran (_sp__ci1.h) y
# se corrigen sus #include
for prog in hlc/*; do
	n=0
	(cd "$prog" && find . -type f | sed 's#^\./##') | awk '{ print tolower($0) "\t" $0 }' | LC_ALL=C sort \
		| awk -F'\t' '$1 == prev { print $2 } { prev = $1 }' > /tmp/dups
	while IFS= read -r f; do
		n=$((n + 1))
		nf="${f%.*}__ci$n.${f##*.}"
		old=$(printf '%s' "$f" | sed 's/[.[*^$]/\\&/g')
		grep -rlF "<$f>" "$prog" | while IFS= read -r g; do sed -i "s#<$old>#<$nf>#g" "$g"; done
		mv "$prog/$f" "$prog/$nf"
		echo "renombrado (mayusculas): $prog/$f -> $nf"
	done < /tmp/dups
done
# zip $1 con las carpetas $2...
pack() {
	z=$1; shift
	rm -f "$z"
	if command -v python3 > /dev/null; then
		python3 -c "import os, sys, zipfile
z = zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED)
for top in sys.argv[2:]:
	for d, _, fs in os.walk(top):
		for f in sorted(fs): z.write(os.path.join(d, f))
z.close()" "$z" "$@"
	else
		command -v zip > /dev/null || (apt-get update -qq && apt-get install -y -qq zip) > /dev/null 2>&1
		zip -qr "$z" "$@"
	fi
	cp "$z" "/out/$(basename "$z")"
	echo "$(basename "$z"): $(find "$@" -type f | wc -l) archivos"
}
pack /tmp/hlc.zip hlc/game hlc/server
if [ -d hlc/gen ]; then pack /tmp/hlc-gen.zip hlc/gen; fi
