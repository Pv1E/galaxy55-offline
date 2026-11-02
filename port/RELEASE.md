## Galaxy 55 (offline) v0.6 — port nativo para Windows (y Linux/macOS con HashLink)

Port **no oficial** de Galaxy 55 (Motion Twin, 2012) a una aplicación nativa (Haxe + Heaps + HashLink). Sin Flash, sin navegador y sin servidor.

**Cómo jugar (Windows):** descomprime la carpeta entera y haz doble clic en `jugar.bat`. Si no abre (equipos sin OpenGL 3.2 o máquinas virtuales), usa `jugar_dx.bat`, la versión DirectX. No hay que instalar nada. Las partidas se guardan en `%APPDATA%\Galaxy55\`.
**Linux y macOS:** zip aparte; necesita HashLink 1.16 instalado (ver su `LEEME.txt`).

### Novedades de la v0.6
- **Pilotar la nave** (añadido del port): desde el ordenador de a bordo, "Pilotar la nave" la mueve sobre el planeta (WASD o palanca izquierda; E, Esc, B o Start la dejan y aterriza sola). El sitio se guarda por planeta.
- **Contratos de la ESCorp** (añadido del port, de **Cornor923**): botón "Contratos (ESCorp)" del ordenador de a bordo; entrega bloques a cambio de créditos. El tablero es el mismo para todos y cambia cada 30 minutos. **Las partidas nuevas empiezan con 200 créditos (antes 500), que llegan al acabar el tutorial, o desde el principio sin tutorial**; las partidas guardadas conservan los suyos.
- De **Cornor923** (¡gracias!, PR 60-63): la lava hace explotar la bomba antigua (cambio del port); se ponen bloques delante de plantas, modelos y bloques parciales; el marco de la ventana de la nave ya no se mezcla con el neón de fuera.
- Arreglos de fallos encontrados por **Sekhmet** (¡gracias!): poner un bloque encima de la capa más alta ya no lo gasta sin ponerlo; con la cabeza dentro de una fuente de cascada o de arena movediza se puede excavar lo de delante; la arena movediza, el hielo y el cristal ya no se ven huecos junto a una cascada.
- La nave que cambiaba de sitio al reabrir una partida era un fallo de la v0.4, ya arreglado desde la v0.5.

Todo en el [CHANGELOG](../CHANGELOG.md).

### Qué falta o falla
- Dar más uso a la velocidad en el viaje espacial (ideas en `IDEAS.md`), y más bloques activables.
- Lista completa de errores conocidos: `ERRORES.md` (español) / `BUGS.md` (inglés) / `BUGS.fr.md` (francés) en el repositorio.
- **El formato de las partidas puede cambiar entre versiones.**

---

## Galaxy 55 (offline) v0.6 — native port for Windows (and Linux/macOS with HashLink)

**Unofficial** port of Galaxy 55 (Motion Twin, 2012) to a native application (Haxe + Heaps + HashLink). No Flash, no browser and no server.

**How to play (Windows):** unzip the whole folder and double-click `jugar.bat`. If it doesn't open (PCs without OpenGL 3.2 or virtual machines), use `jugar_dx.bat`, the DirectX build. Nothing to install. Saves go to `%APPDATA%\Galaxy55\`.
**Linux and macOS:** separate zip; it needs HashLink 1.16 installed (see its `LEEME.txt`).

### New in v0.6
- **Pilot the ship** (port addition): from the on-board computer, "Pilot the ship" moves it over the planet (WASD or left stick; E, Esc, B or Start leave it and it lands by itself). The spot is saved per planet.
- **ESCorp contracts** (port addition, by **Cornor923**): "Contracts (ESCorp)" button on the on-board computer; deliver blocks for credits. The board is the same for everyone and changes every 30 minutes. **New games start with 200 credits (before: 500), sent at the end of the tutorial, or from the start without it**; saved games keep theirs.
- From **Cornor923** (thank you!, PRs 60-63): lava makes the ancient bomb explode (port change); blocks can be placed in front of plants, models and partial blocks; the ship's window frame no longer mixes with the neon light outside.
- Fixes for bugs found by **Sekhmet** (thank you!): placing a block on top of the highest layer no longer uses it up without placing it; with your head inside a cascade source or quicksand you can dig what is in front; quicksand, ice and glass no longer look hollow next to a cascade.
- The ship that changed place when reopening a game was a v0.4 bug, already fixed since v0.5.

Everything in the [CHANGELOG](../CHANGELOG.en.md).

### Missing or broken
- Giving ship speed more use in space travel (ideas in `IDEAS.en.md`), and more activatable blocks.
- Full list of known bugs: `BUGS.md` (English) / `BUGS.fr.md` (French) / `ERRORES.md` (Spanish) in the repository.
- **The save format may change between versions.**

---

## Galaxy 55 (offline) v0.6 — portage natif pour Windows (et Linux/macOS avec HashLink)

Portage **non officiel** de Galaxy 55 (Motion Twin, 2012) en application native (Haxe + Heaps + HashLink). Sans Flash, sans navigateur et sans serveur.

**Comment jouer (Windows) :** décompresse tout le dossier et double-clique sur `jugar.bat`. S'il ne s'ouvre pas (PC sans OpenGL 3.2 ou machines virtuelles), utilise `jugar_dx.bat`, la version DirectX. Rien à installer. Les parties sont enregistrées dans `%APPDATA%\Galaxy55\`.
**Linux et macOS :** zip séparé ; il faut HashLink 1.16 installé (voir son `LEEME.txt`).

### Nouveautés de la v0.6
- **Piloter le vaisseau** (ajout du port) : depuis l'ordinateur de bord, « Piloter le vaisseau » le déplace au-dessus de la planète (WASD ou stick gauche ; E, Échap, B ou Start le laissent et il atterrit tout seul). L'endroit est enregistré par planète.
- **Contrats ESCorp** (ajout du port, de **Cornor923**) : bouton « Contrats (ESCorp) » de l'ordinateur de bord ; livre des blocs contre des crédits. Le tableau est le même pour tous et change toutes les 30 minutes. **Les nouvelles parties commencent avec 200 crédits (avant : 500), envoyés à la fin du tutoriel, ou dès le début sans tutoriel** ; les parties enregistrées gardent les leurs.
- De **Cornor923** (merci !, PR 60-63) : la lave fait exploser la bombe antique (changement du port) ; on pose des blocs devant les plantes, les modèles et les blocs partiels ; le cadre de la fenêtre du vaisseau ne se mélange plus avec le néon dehors.
- Corrections de bugs trouvés par **Sekhmet** (merci !) : poser un bloc au-dessus de la couche la plus haute ne le consomme plus sans le poser ; la tête dans une source de cascade ou dans des sables mouvants, on peut creuser ce qui est devant ; les sables mouvants, la glace et le verre ne paraissent plus creux à côté d'une cascade.
- Le vaisseau qui changeait de place en rouvrant une partie était un bug de la v0.4, déjà corrigé depuis la v0.5.

Tout est dans le [CHANGELOG](../CHANGELOG.fr.md).

### Ce qui manque ou ne marche pas
- Donner plus d'usage à la vitesse dans le voyage spatial (idées dans `IDEAS.fr.md`), et plus de blocs activables.
- Liste complète des bugs connus : `BUGS.fr.md` (français) / `BUGS.md` (anglais) / `ERRORES.md` (espagnol) dans le dépôt.
- **Le format des sauvegardes peut changer d'une version à l'autre.**

### Licencia / License / Licence
Código y datos de Galaxy 55 © Motion Twin, **CC BY-NC-SA 4.0**. Este port es una obra derivada bajo la misma licencia: uso no comercial y con crédito. Ver `LICENSE` y `NOTICE`.
