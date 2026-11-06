## Galaxy 55 (offline) v0.7 — port nativo para Windows (y Linux/macOS con HashLink)

Port **no oficial** de Galaxy 55 (Motion Twin, 2012) a una aplicación nativa (Haxe + Heaps + HashLink). Sin Flash, sin navegador y sin servidor.

**Cómo jugar (Windows):** descomprime la carpeta entera y haz doble clic en `jugar.bat`. Si no abre (equipos sin OpenGL 3.2 o máquinas virtuales), usa `jugar_dx.bat`, la versión DirectX. No hay que instalar nada. Las partidas se guardan en `%APPDATA%\Galaxy55\`.
**Linux y macOS:** zip aparte; necesita HashLink 1.16 instalado (ver su `LEEME.txt`).

### Novedades de la v0.7
Casi todo es de **Cornor923** (¡gracias!, PR 64-95):
- **Base de datos ESCorp** (añadido del port), en el ordenador de a bordo: el **Kubindex** con todos los kubes del juego (apuntar uno con el láser lo localiza; tenerlo en el inventario lo recupera, con sus recetas), los tipos de planeta y cometa explorados y las anomalías, y las recetas descubiertas.
- **Cometas** (añadido del port): mundos pequeños que visitan los sistemas solares un tiempo. Se aterriza sin gastar licencia y el amarre está contado (de 1:30 a 15:00 según la velocidad de la nave).
- **Licencias de exploración de la ESCorp** (añadido del port): en aventura se escanean 4 planetas (1 principal y 3 de exploración) y **la nave solo se pilota sobre el planeta principal**.
- **Editor de kubes** (añadido del port), en el menú de inicio: dibuja bloques nuevos píxel a píxel, míralos en 3D y guárdalos como `.kube` para enviárnoslos.
- Sin parones en el menú, las pantallas de carga, al llegar a un planeta ni en la nave nodriza.
- El ordenador de a bordo, la tienda, los contratos y las licencias ya no paran el juego.
- El volumen de Opciones ya se aplica; la niebla depende de la distancia; la nieve solo cubre bloques a cielo abierto en el planeta nevado.
- Arreglos: el tutorial ya no se atasca en el sintetizador y muestra su flecha verde; la arena movediza hace daño al caer en ella; en la zona del sintetizador y en el hangar todo lo que se rompe se suelta; la hierba roja ya no suelta trozos blancos; el suelo bajo cuatro lingotes juntos ya no se ve negro; y más (los encontrados por **Sekhmet**, ¡gracias!, en `ERRORES.md`).

Todo en el [CHANGELOG](../CHANGELOG.md).

### Qué falta o falla
- Más tipos de cometa y de planeta, y más bloques activables (ideas en `IDEAS.md`).
- Lista completa de errores conocidos: `ERRORES.md` (español) / `BUGS.md` (inglés) / `BUGS.fr.md` (francés) en el repositorio.
- **El formato de las partidas puede cambiar entre versiones.** Las partidas de la v0.6 se cargan (la base de datos empieza vacía).

---

## Galaxy 55 (offline) v0.7 — native port for Windows (and Linux/macOS with HashLink)

**Unofficial** port of Galaxy 55 (Motion Twin, 2012) to a native application (Haxe + Heaps + HashLink). No Flash, no browser and no server.

**How to play (Windows):** unzip the whole folder and double-click `jugar.bat`. If it doesn't open (PCs without OpenGL 3.2 or virtual machines), use `jugar_dx.bat`, the DirectX build. Nothing to install. Saves go to `%APPDATA%\Galaxy55\`.
**Linux and macOS:** separate zip; it needs HashLink 1.16 installed (see its `LEEME.txt`).

### New in v0.7
Almost all of it by **Cornor923** (thank you!, PRs 64-95):
- **ESCorp database** (port addition), on the on-board computer: the **Kubindex** with every kube of the game (pointing the laser at one spots it; having it in the inventory collects it, with its recipes), the planet and comet types explored and the anomalies, and the recipes discovered.
- **Comets** (port addition): small worlds that visit solar systems for a while. Landing uses no license and docking time is limited (1:30 to 15:00 depending on the ship's speed).
- **ESCorp exploration licenses** (port addition): in adventure you scan 4 planets (1 main and 3 exploration) and **the ship can only be piloted over the main planet**.
- **Kube editor** (port addition), in the start menu: draw new blocks pixel by pixel, see them in 3D and save them as `.kube` files to send them to us.
- No more stops on the menu, the loading screens, when arriving on a planet or in the mothership.
- The on-board computer, the shop, the contracts and the licenses no longer pause the game.
- The Options volume now applies; fog depends on distance; snow only covers blocks under the open sky on the snow planet.
- Fixes: the tutorial no longer gets stuck at the synthesizer and shows its green arrow; quicksand hurts when you fall into it; everything broken in the synthesizer area and the hangar drops; the red grass no longer throws white pieces; the floor under four ingots placed together no longer looks black; and more (the ones found by **Sekhmet**, thank you!, in `BUGS.md`).

Everything is in the [CHANGELOG](../CHANGELOG.en.md).

### Missing or broken
- More comet and planet types, and more activatable blocks (ideas in `IDEAS.en.md`).
- Full list of known bugs: `BUGS.md` (English) / `BUGS.fr.md` (French) / `ERRORES.md` (Spanish) in the repository.
- **The save format may change between versions.** v0.6 saves load (the database starts empty).

---

## Galaxy 55 (offline) v0.7 — portage natif pour Windows (et Linux/macOS avec HashLink)

Portage **non officiel** de Galaxy 55 (Motion Twin, 2012) en application native (Haxe + Heaps + HashLink). Sans Flash, sans navigateur et sans serveur.

**Comment jouer (Windows) :** décompresse tout le dossier et double-clique sur `jugar.bat`. S'il ne s'ouvre pas (PC sans OpenGL 3.2 ou machines virtuelles), utilise `jugar_dx.bat`, la version DirectX. Rien à installer. Les parties sont enregistrées dans `%APPDATA%\Galaxy55\`.
**Linux et macOS :** zip séparé ; il faut HashLink 1.16 installé (voir son `LEEME.txt`).

### Nouveautés de la v0.7
Presque tout est de **Cornor923** (merci !, PR 64-95) :
- **Base de données ESCorp** (ajout du port), dans l'ordinateur de bord : le **Kubindex** avec tous les kubes du jeu (viser un kube au laser le localise ; l'avoir dans l'inventaire le récupère, avec ses recettes), les types de planètes et de comètes explorés et les anomalies, et les recettes découvertes.
- **Comètes** (ajout du port) : de petits mondes qui visitent les systèmes solaires pendant un temps. On s'y pose sans dépenser de licence et l'amarrage est limité (de 1:30 à 15:00 selon la vitesse du vaisseau).
- **Licences d'exploration ESCorp** (ajout du port) : en aventure on scanne 4 planètes (1 principale et 3 d'exploration) et **le vaisseau ne se pilote qu'au-dessus de la planète principale**.
- **Éditeur de Kubes** (ajout du port), dans le menu de démarrage : dessine de nouveaux blocs pixel par pixel, regarde-les en 3D et enregistre-les en `.kube` pour nous les envoyer.
- Plus de blocages dans le menu, les écrans de chargement, à l'arrivée sur une planète ni dans le vaisseau-mère.
- L'ordinateur de bord, la boutique, les contrats et les licences ne mettent plus le jeu en pause.
- Le volume des Options s'applique ; le brouillard dépend de la distance ; la neige ne couvre les blocs qu'à ciel ouvert sur la planète enneigée.
- Corrections : le tutoriel ne reste plus bloqué au synthétiseur et affiche sa flèche verte ; le sable mouvant blesse quand on tombe dedans ; tout ce qui est cassé dans la zone du synthétiseur et le hangar tombe ; les herbes rouges ne lâchent plus de morceaux blancs ; le sol sous quatre lingots collés n'est plus noir ; et d'autres (ceux trouvés par **Sekhmet**, merci !, dans `BUGS.fr.md`).

Tout est dans le [CHANGELOG](../CHANGELOG.fr.md).

### Ce qui manque ou ne marche pas
- Plus de types de comètes et de planètes, et plus de blocs activables (idées dans `IDEAS.fr.md`).
- Liste complète des bugs connus : `BUGS.fr.md` (français) / `BUGS.md` (anglais) / `ERRORES.md` (espagnol) dans le dépôt.
- **Le format des sauvegardes peut changer d'une version à l'autre.** Les parties de la v0.6 se chargent (la base de données commence vide).

### Licencia / License / Licence
Código y datos de Galaxy 55 © Motion Twin, **CC BY-NC-SA 4.0**. Este port es una obra derivada bajo la misma licencia: uso no comercial y con crédito. Ver `LICENSE` y `NOTICE`. El icono de "nuevo" de la base de datos es de Mush (Motion Twin, CC BY-NC-SA 4.0).
