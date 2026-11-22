#!/bin/sh
# Galaxy 55 (offline): compila el juego y el servidor del multijugador para este equipo desde el codigo C (HashLink/C) del
# paquete de macOS (carpeta hlc). Hace falta en los Mac con procesador Apple (M1 y siguientes): ahi HashLink no tiene la
# maquina virtual hl, solo HashLink/C. Sirve igual en un Mac Intel o en Linux.
#   macOS: sh compilar.sh   (instala hashlink con Homebrew si falta; Xcode Command Line Tools: xcode-select --install)
#   otro:  HASHLINK=/ruta/de/hashlink sh compilar.sh   (con include/hl.h, hlc.h, hlc_main.c y lib/libhl + *.hdll)
# Crea galaxy55 (el juego) y galaxy55-serveur (el servidor dedicado) en esta carpeta y, en macOS, la aplicacion
# "Galaxy 55.app" (doble clic; se puede mover a Aplicaciones), con el juego, sus recursos y el icono.
set -e
APPVER="__VERSION__"
cd "$(dirname "$0")"
if [ -z "$HASHLINK" ]; then
	if ! command -v brew > /dev/null 2>&1; then
		echo "Falta Homebrew (https://brew.sh) / Homebrew is missing / Homebrew manque."
		exit 1
	fi
	brew list hashlink > /dev/null 2>&1 || brew install hashlink
	HASHLINK="$(brew --prefix hashlink)"
	BREWHL=1
fi
INC="$HASHLINK/include"
LIB="$HASHLINK/lib"
[ -d "$LIB" ] || LIB="$HASHLINK"
CC="${CC:-cc}"
# el hashlink ya compilado de Homebrew puede venir roto: su fmt.hdll se enlazo cuando libturbojpeg aun daba adler32 y la de
# ahora no ("Symbol not found: _adler32" al abrir el juego). Se comprueba que sus hdll cargan; si no, se compila desde el codigo
hdllcheck() {
	cat > /tmp/g55_hdllcheck.c << 'C'
#include <dlfcn.h>
#include <stdio.h>
int main( int c, char **v ) {
	int ok = 1;
	for( int i = 1; i < c; i++ ) if( !dlopen(v[i], RTLD_NOW) ) { printf("%s\n", dlerror()); ok = 0; }
	return ok ? 0 : 1;
}
C
	$CC /tmp/g55_hdllcheck.c -o /tmp/g55_hdllcheck -ldl 2> /dev/null || $CC /tmp/g55_hdllcheck.c -o /tmp/g55_hdllcheck || return 0
	/tmp/g55_hdllcheck "$LIB/fmt.hdll" "$LIB/sdl.hdll" "$LIB/openal.hdll" "$LIB/ssl.hdll" "$LIB/uv.hdll" "$LIB/sqlite.hdll" "$LIB/ui.hdll"
}
if [ -n "$BREWHL" ] && ! hdllcheck; then
	echo "== hashlink de Homebrew roto: se compila desde el codigo / broken: building it from source / casse : compilation depuis les sources"
	brew reinstall --build-from-source hashlink
	hdllcheck || { echo "hashlink sigue sin cargar / still broken / toujours casse"; exit 1; }
fi
# -ffp-contract=off: sin multiplicaciones-sumas fusionadas (FMA, que clang usa en los procesadores ARM), los calculos del
# generador de planetas dan lo mismo que en Windows y Linux; si no, el terreno del juego y el del servidor podrian diferir
CFLAGS="-O2 -std=c11 -ffp-contract=off -w"
OS="$(uname -s)"
# algunas funciones de uv.hdll son las de libuv tal cual (uv_default_loop, uv_run...): el juego se enlaza tambien con libuv
# (la de Homebrew, que hashlink ya instala)
SYSLIB=""
if command -v brew > /dev/null 2>&1; then SYSLIB="-L$(brew --prefix)/lib"; fi
# openal.hdll solo tiene alc_reopen_device_soft con OpenAL Soft 1.22 o mas nuevo (el de Homebrew si); heaps la usa al
# cambiar de salida de audio: si falta, una que no hace nada
if [ "$OS" = "Darwin" ]; then NM="nm -g"; else NM="nm -D"; fi
GAMEEXTRA="-luv"
if ! $NM "$LIB/openal.hdll" 2> /dev/null | grep -q "openal_alc_reopen_device_soft"; then
	printf '#include <hl.h>\nHL_PRIM bool openal_alc_reopen_device_soft( void *d, vbyte *n, vbyte *a ) { return false; }\n' > hlc/openal_stub.c
	GAMEEXTRA="hlc/openal_stub.c $GAMEEXTRA"
fi
build() {
	dir=$1; main=$2; out=$3; extra=$4; shift 4
	libs=""
	for l in "$@"; do
		if [ "$OS" = "Darwin" ]; then libs="$libs $LIB/$l.hdll"; else libs="$libs -l:$l.hdll"; fi
	done
	echo "== $out: compilando $dir (unos minutos) / compiling (a few minutes) / compilation (quelques minutes)"
	$CC $CFLAGS -I "$dir" -I "$INC" "$dir/$main" -o "$out" -L "$LIB" -lhl $libs $SYSLIB $extra -lm -Wl,-rpath,"$LIB"
}
build hlc/game galaxy55.c galaxy55 "$GAMEEXTRA" fmt sdl openal ssl ui uv sqlite
build hlc/server server.c galaxy55-serveur "" fmt ssl sqlite

# la aplicacion de macOS: el ejecutable de la app es un script que entra en Resources (donde estan el juego y "res", que el
# juego busca en la carpeta actual) y lo abre. Hecha en este Mac, no lleva la marca de cuarentena de lo descargado: se abre
# sin el aviso de Gatekeeper. Necesita el hashlink de Homebrew que ha usado la compilacion (no desinstalarlo).
mkapp() {
	app="Galaxy 55.app"
	rm -rf "$app"
	mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
	cp galaxy55 "$app/Contents/Resources/galaxy55"
	cp -R res "$app/Contents/Resources/res"
	printf '#!/bin/sh\ncd "$(dirname "$0")/../Resources" && exec ./galaxy55 "$@"\n' > "$app/Contents/MacOS/Galaxy55"
	chmod +x "$app/Contents/MacOS/Galaxy55" "$app/Contents/Resources/galaxy55"
	short="${APPVER%%-*}"
	cat > "$app/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Galaxy 55</string>
	<key>CFBundleDisplayName</key><string>Galaxy 55</string>
	<key>CFBundleIdentifier</key><string>local.galaxy55-offline.game</string>
	<key>CFBundleExecutable</key><string>Galaxy55</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$short</string>
	<key>CFBundleVersion</key><string>$APPVER</string>
	<key>CFBundleIconFile</key><string>galaxy55</string>
	<key>LSMinimumSystemVersion</key><string>11.0</string>
</dict>
</plist>
PLIST
	# icono: icon.png del paquete (256x256) a galaxy55.icns con las herramientas de macOS; sin ellas, la app sin icono
	if [ -f icon.png ] && command -v sips > /dev/null 2>&1 && command -v iconutil > /dev/null 2>&1; then
		iconset="$(mktemp -d)/galaxy55.iconset"
		mkdir -p "$iconset"
		for s in 16 32 128 256; do
			sips -z $s $s icon.png --out "$iconset/icon_${s}x${s}.png" > /dev/null 2>&1 || true
			d=$((s * 2))
			sips -z $d $d icon.png --out "$iconset/icon_${s}x${s}@2x.png" > /dev/null 2>&1 || true
		done
		iconutil -c icns "$iconset" -o "$app/Contents/Resources/galaxy55.icns" > /dev/null 2>&1 || echo "(sin icono / no icon / sans icone)"
	fi
	echo "== $app"
}
if [ "$OS" = "Darwin" ] || [ -n "$MAKEAPP" ]; then mkapp; fi
if [ "$OS" = "Darwin" ]; then
	echo "OK: Galaxy 55.app (doble clic / double-click / double-clic) - ./jugar.sh"
else
	echo "OK: ./jugar.sh"
fi
