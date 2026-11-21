#!/bin/sh
# Galaxy 55 (offline): compila el juego y el servidor del multijugador para este equipo desde el codigo C (HashLink/C) del
# paquete de macOS (carpeta hlc). Hace falta en los Mac con procesador Apple (M1 y siguientes): ahi HashLink no tiene la
# maquina virtual hl, solo HashLink/C. Sirve igual en un Mac Intel o en Linux.
#   macOS: sh compilar.sh   (instala hashlink con Homebrew si falta; Xcode Command Line Tools: xcode-select --install)
#   otro:  HASHLINK=/ruta/de/hashlink sh compilar.sh   (con include/hl.h, hlc.h, hlc_main.c y lib/libhl + *.hdll)
# Crea galaxy55 (el juego) y galaxy55-serveur (el servidor dedicado) en esta carpeta.
set -e
cd "$(dirname "$0")"
if [ -z "$HASHLINK" ]; then
	if ! command -v brew > /dev/null 2>&1; then
		echo "Falta Homebrew (https://brew.sh) / Homebrew is missing / Homebrew manque."
		exit 1
	fi
	brew list hashlink > /dev/null 2>&1 || brew install hashlink
	HASHLINK="$(brew --prefix hashlink)"
fi
INC="$HASHLINK/include"
LIB="$HASHLINK/lib"
[ -d "$LIB" ] || LIB="$HASHLINK"
CC="${CC:-cc}"
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
echo "OK: ./jugar.sh"
