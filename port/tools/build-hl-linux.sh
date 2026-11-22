#!/bin/bash
# HashLink 1.16 para Linux x86-64, para la carpeta hashlink del zip de Linux (port/tools/package.ps1 -LinuxHashLink).
# Se construye en ubuntu:22.04 (glibc 2.35: sirve en las distribuciones de 2022 o posteriores) con SDL 3.4.12 compilada aqui
# (su huella se compara con la de GitHub) y mbedtls de las fuentes de HashLink (SSL_STATIC); lleva tambien las bibliotecas
# que no todas las distribuciones tienen en la misma version. Uso, desde la raiz del repo en WSL o Linux:
#   docker run --rm -v "$PWD/../tools-portable/src/hashlink:/src/hashlink:ro" -v "<carpeta de salida>:/out" ubuntu:22.04 #     bash /dev/stdin < port/tools/build-hl-linux.sh
# Deja en /out/hashlink: hl, libhl.so, los hdll, libSDL3.so.0 y las bibliotecas; en /out/include, las cabeceras de HashLink/C.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends build-essential cmake ninja-build pkg-config curl ca-certificates python3 patchelf file \
  libpng-dev libturbojpeg0-dev libvorbis-dev libopenal-dev libuv1-dev libsqlite3-dev zlib1g-dev \
  libgl-dev libegl-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxss-dev libxtst-dev \
  libxkbcommon-dev libwayland-dev wayland-protocols libdecor-0-dev libdrm-dev libgbm-dev libpulse-dev libasound2-dev \
  libpipewire-0.3-dev libudev-dev libdbus-1-dev > /dev/null
echo "== paquets installes"

SDL_VER=3.4.12
cd /tmp
curl -fsSL -o sdl.tar.gz "https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VER/SDL3-$SDL_VER.tar.gz"
want=$(curl -fsSL "https://api.github.com/repos/libsdl-org/SDL/releases/tags/release-$SDL_VER" \
  | python3 -c "import json,sys; a=[x for x in json.load(sys.stdin)['assets'] if x['name']=='SDL3-$SDL_VER.tar.gz'][0]; print(a.get('digest',''))")
got="sha256:$(sha256sum sdl.tar.gz | cut -d' ' -f1)"
echo "SDL3 $SDL_VER digest GitHub=$want calcule=$got"
[ -n "$want" ] && [ "$want" = "$got" ] || { echo "EMPREINTE SDL3 DIFFERENTE"; exit 1; }
tar xzf sdl.tar.gz
cmake -S "SDL3-$SDL_VER" -B sdlbuild -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/sdl3 \
  -DCMAKE_INSTALL_LIBDIR=lib -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DSDL_STATIC=OFF > /tmp/sdl_cmake.log
cmake --build sdlbuild > /tmp/sdl_build.log
cmake --install sdlbuild > /dev/null
echo "== SDL3 construite"

export PKG_CONFIG_PATH=/opt/sdl3/lib/pkgconfig
cp -r /src/hashlink /tmp/hl
cd /tmp/hl
make clean > /dev/null 2>&1 || true
make -j"$(nproc)" SSL_STATIC=1 PREFIX=/opt/hl hl libhl.so fmt.hdll sdl.hdll ssl.hdll openal.hdll ui.hdll uv.hdll sqlite.hdll heaps.hdll > /tmp/hl_build.log 2>&1 \
  || { tail -40 /tmp/hl_build.log; exit 1; }
echo "== HashLink construit"

rm -rf /out/hashlink && mkdir -p /out/hashlink
cp hl libhl.so fmt.hdll sdl.hdll ssl.hdll openal.hdll ui.hdll uv.hdll sqlite.hdll heaps.hdll /out/hashlink/
cp -L /opt/sdl3/lib/libSDL3.so.0 /out/hashlink/
# bibliotecas que no todas las distribuciones tienen en la misma version (las de glibc, libstdc++, zlib, ALSA y OpenGL, si)
for l in libopenal.so.1 libsndio.so.7 libbsd.so.0 libmd.so.0 libturbojpeg.so.0 libuv.so.1 libvorbisfile.so.3 libvorbis.so.0 	libogg.so.0 libpng16.so.16 libsqlite3.so.0; do
	cp -L "/lib/x86_64-linux-gnu/$l" /out/hashlink/
done
mkdir -p /out/include && cp src/hl.h src/hl_ffi.h src/hlc.h src/hlc_main.c /out/include/
echo "== dependances (ldd)"
cd /out/hashlink
LD_LIBRARY_PATH=/out/hashlink ldd hl libhl.so *.hdll libSDL3.so.0 | grep "=>" | awk '{print $1" "$3}' | sort -u
echo "== glibc max"
for f in hl libhl.so *.hdll libSDL3.so.0; do objdump -T "$f" | grep -o 'GLIBC_[0-9.]*' ; done | sort -uV | tail -1
