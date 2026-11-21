#!/bin/sh
# "Galaxy 55.app" autonoma para macOS (HashLink y sus bibliotecas dentro: el jugador no instala nada), hecha en un Mac por
# GitHub Actions (.github/workflows/mac.yml). Uso, desde la raiz del repo, con hashlink y dylibbundler de Homebrew:
#   sh port/tools/mac-app.sh VERSION hlc.zip CARPETA_DE_SALIDA
# Compila el codigo C de hlc.zip (port/tools/build-hlc-sources.sh) con compilar.sh (port/tools/build-hlc.sh), mete el
# servidor dedicado en la app, copia las bibliotecas de Homebrew en Contents/libs (dylibbundler), firma la app ad hoc y deja
# en la salida "Galaxy55-VERSION-macOS.zip" con la app, el lanzador del servidor y el LEEME.
set -e
VERSION=$1
HLC=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
OUT=$3
ROOT=$(pwd)
W="$(mktemp -d)/Galaxy 55"
mkdir -p "$W/res"
# recursos: los mismos que port/tools/package.ps1 (su lista $res, el mapa, los iconos del multijugador y los sonidos)
for r in $(grep '^\$res = @(' port/tools/package.ps1 | grep -o '"[^"]*"' | tr -d '"'); do cp "src/G55/fla/client/gfx/$r" "$W/res/$r"; done
cp src/G55/fla/explore/gfx/tiles.png "$W/res/explore_tiles.png"
cp src/G55/fla/explore/gfx/mp_icons.png "$W/res/explore_mp_icons.png"
for f in src/G55/fla/client/sfx/*.wav; do cp "$f" "$W/res/sfx_$(basename "$f")"; done
(cd "$W" && unzip -q "$HLC")
sed "s/__VERSION__/$VERSION/" port/tools/build-hlc.sh > "$W/compilar.sh"
# icono: la imagen PNG de 256x256 que lleva port/galaxy55.ico
python3 - port/galaxy55.ico "$W/icon.png" << 'PY'
import struct, sys
b = open(sys.argv[1], "rb").read()
for k in range(struct.unpack_from("<H", b, 4)[0]):
	w, h, _, _, _, _, size, off = struct.unpack_from("<BBBBHHII", b, 6 + 16 * k)
	if w == 0 and h == 0 and b[off:off + 4] == b"\x89PNG":
		open(sys.argv[2], "wb").write(b[off:off + size])
PY
(cd "$W" && sh compilar.sh)
APP="$W/Galaxy 55.app"
cp "$W/galaxy55-serveur" "$APP/Contents/Resources/galaxy55-serveur"
# las bibliotecas de Homebrew (libhl, los hdll, SDL3, OpenAL, libuv, mbedtls, libpng...) dentro de la app
HL="$(brew --prefix hashlink)/lib"
dylibbundler -od -b -cd -x "$APP/Contents/Resources/galaxy55" -x "$APP/Contents/Resources/galaxy55-serveur" \
	-d "$APP/Contents/libs/" -p "@executable_path/../libs/" -s "$HL" -s "$(brew --prefix)/lib"
# dylibbundler deja el mismo LC_RPATH dos veces y los macOS de ahora no cargan nada asi ("duplicate LC_RPATH"); como todas las
# referencias son ya @executable_path/../libs/..., no hace falta ninguno: se quitan todos (tambien los de Homebrew). Despues,
# cada archivo cambiado se vuelve a firmar (ad hoc), o en Apple Silicon no se abre
for f in "$APP/Contents/Resources/galaxy55" "$APP/Contents/Resources/galaxy55-serveur" "$APP"/Contents/libs/*; do
	for r in $(otool -l "$f" | awk '/cmd LC_RPATH/ { getline; getline; print $2 }'); do
		install_name_tool -delete_rpath "$r" "$f" 2> /dev/null || true
	done
	codesign --force -s - "$f"
done
codesign --force -s - "$APP"
if otool -L "$APP/Contents/Resources/galaxy55" "$APP/Contents/Resources/galaxy55-serveur" "$APP"/Contents/libs/* | grep -q "$(brew --prefix)"; then
	echo "la app aun usa bibliotecas de Homebrew:"
	otool -L "$APP/Contents/Resources/galaxy55" "$APP"/Contents/libs/* | grep "$(brew --prefix)"
	exit 1
fi
# paquete: la app, el servidor dedicado (sus datos junto al script, no dentro de la app) y el LEEME
P="$(mktemp -d)/Galaxy 55 (macOS)"
mkdir -p "$P"
cp -R "$APP" "$P/"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$P/"
printf '#!/bin/sh\n# Galaxy 55 (offline) v%s - servidor multijugador dedicado (sin ventana). Ordenes: help, stop\nD="$(cd "$(dirname "$0")" && pwd)"\ncd "$D/Galaxy 55.app/Contents/Resources" && exec ./galaxy55-serveur --data "$D/serveur" "$@"\n' "$VERSION" > "$P/galaxy55-serveur.command"
chmod +x "$P/galaxy55-serveur.command"
cat > "$P/LEEME.txt" << TXT
Galaxy 55 (offline) v$VERSION - macOS (Apple Silicon)
Port NO oficial de Galaxy 55 (Motion Twin, 2012). Licencia CC BY-NC-SA 4.0 (ver LICENSE y NOTICE).

Francais : double-clic sur "Galaxy 55.app" (tu peux la ranger dans Applications). Elle n'est pas signee par Apple :
la premiere fois, macOS refuse de l'ouvrir. Va alors dans Reglages Systeme > Confidentialite et securite, en bas :
"Ouvrir quand meme", puis confirme. Ensuite elle s'ouvre normalement. Serveur dedie : galaxy55-serveur.command
(port 55055 TCP et UDP, donnees dans le dossier "serveur" a cote). Parties et identite du multijoueur dans ~/Galaxy55.
Le multijoueur marche avec les joueurs Windows et Linux qui ont CETTE meme version.

English: double-click "Galaxy 55.app". It is not signed by Apple: the first time macOS refuses to open it; go to System
Settings > Privacy & Security, at the bottom: "Open Anyway", and confirm. Dedicated server: galaxy55-serveur.command.

Espanol: doble clic en "Galaxy 55.app". No esta firmada por Apple: la primera vez macOS no la abre; ve a Ajustes del
Sistema > Privacidad y seguridad, abajo: "Abrir igualmente", y confirma. Servidor dedicado: galaxy55-serveur.command.
TXT
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
(cd "$(dirname "$P")" && ditto -c -k --sequesterRsrc --keepParent "Galaxy 55 (macOS)" "$OUT/Galaxy55-$VERSION-macOS.zip")
echo "app: $OUT/Galaxy55-$VERSION-macOS.zip"
# para las comprobaciones del workflow
echo "$APP" > "$OUT/app-path.txt"
