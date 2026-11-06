# Changelog (native version)

[Español: `CHANGELOG.md`](CHANGELOG.md) · [Français : `CHANGELOG.fr.md`](CHANGELOG.fr.md)

## v0.7 — pre-release
- **ESCorp database** (port addition), on the on-board computer, with three tabs: the **Kubindex**, with every kube of the
  game by category (pointing the laser at one spots it; having it in the inventory collects it, with how many times it was
  placed, broken and crafted, the recipes that make it and the ones that use it); **Space**, with the planet and comet types
  explored and the anomalies met; and **Recipes**, discovered when one of their kubes is collected. A notice top right says
  what is new and new entries are marked until looked at. It opens at once. In creative everything is known; in the
  tutorial it opens after the hull plating is made.
- **Comets** (port addition): small worlds that visit solar systems for a while (in each 2-hour slot, a system has a 1 in 6
  chance). Scanning one is landing, without using a license. Docking time is limited (1:30 to 15:00 depending on the ship's
  speed; it only runs on the ground) and, when it runs out, you go back to the ship. Taking off loses it. The cinder comet
  has Meteorite Bed rock, Charred Debris, blue etherium veins with Etherium Meteorites and lava, no water.
- No more stops when the start menu appears, on the loading screens, when arriving on a planet or loading the mothership
  (up to nearly a second before, and about 6 s on the first visit to the mothership).
- Falling into quicksand: touching it gives the hit of the fall, as on the ground, and the sand stops the fall (port change:
  in the original the damage came at the end, for the whole fall).
- A block broken in the synthesizer area or in the hangar always drops, even if elsewhere it only drops by chance; a drop
  buried under placed blocks comes out by the side instead of ending on the ship's roof (port changes).
- Away from the main planet, the on-board computer no longer offers "Pilot the ship" (it used to show it and refuse when
  pressed).
- The congratulations at the end of the tutorial go away on takeoff and last 12 s (16 before): they no longer come back on
  the next planet, followed by "this is your main planet".
- Kube editor: in French, the help says "enregistrer" again for Ctrl+S.
- With the ESCorp database open, the key help no longer shows behind its tabs.
- **Kube editor** (port addition): in the start menu, under New game. Draw the faces of a block pixel by pixel in one of the
  shapes the game already draws (cube, 6-sided cube, box, door, plant, panel, column...), watch it turn in 3D and save it as a
  `.kube` file in the `kubes` folder of the game data to send it to us. Any game block can be the starting point.
- The synthesizer computer also works with a block in hand and with right click (port change).
- Two quick clicks place both blocks (port change: the original did not place the second one if it came within 0.47 s).
- During the tutorial the synthesizer only makes aluminium and hull plating: the aluminium can no longer be used up on
  another recipe, leaving the tutorial stuck.
- The tutorial shows the green arrow to the emergency landing planet.
- Opening the on-board computer or the pause menu puts the pointer at the centre of the window.
- The game window opens at its size and with its title (it used to show small for a moment).
- The tall red grass no longer throws white pieces when broken.
- The floor under partial blocks placed together (e.g. four iron or aluminium ingots in the ship) no longer looks black
  (port change: in the original those blocks let no light through; walls and ceilings are unchanged).
- Kube editor: a kube named like a reserved Windows name (con, aux, nul...) can now be saved.
- **ESCorp exploration licenses** (port addition; in the original the server handled them): in adventure, scanning a planet
  uses a license, 4 in all (1 main and 3 exploration); unlimited in creative. The first scanned planet is the main one (with
  the tutorial, its planet). **The ship can only be piloted over the main planet**: elsewhere, the on-board computer does
  not offer "Pilot the ship". There, "Exploration licenses" shows them and lets you change the main planet (free the first
  time, then 1000 credits and 24 real hours between changes); on the map, "Abandon" frees a planet's license. Older saves
  give a license to visited planets and the start planet is the main one.
- The Options volume now applies to the sounds (0 is silence).
- A cascade behind glass is visible; the camera no longer enters the block above when climbing a cascade.
- Blocks can be placed on tall grass (it is trampled) and the placement ghost only shows where a block can go.
- Dropped blocks no longer shake on the ground; herbs drop their own herb.
- Snow only covers blocks on the snow planet and under the open sky.
- Fog depends on the distance and no longer changes when turning the camera.
- The on-board computer, the shop, the contracts and the licenses no longer pause the game (you keep healing in the ship).
- The merchant robot no longer jumps with the ship into a system; opening the map no longer closes the game on a slow PC.
- On-board computer buttons without the notes in parentheses.
- Partial blocks next to a neon light look lit again; the ship stays visible across the edge of the world.

## v0.6 — pre-release
- Repository: the files that only built the Flash version (`client*.hxml`, `build.bat`/`build.sh`, the SWFs in `release/`,
  `libs/heaps` and `libs/format_old`) are removed from `main`. They remain untouched in the `flash` branch. The game does not change.
- **Pilot the ship** (port addition): on the on-board computer, "Pilot the ship" moves it over the planet with WASD or the left
  stick (the mouse or right stick turn the camera) and E, Esc, B or Start leave it there. Always at the same height and free;
  it speeds up and slows down smoothly, turns to face where it goes and banks in turns, and when you leave it, it slows down,
  straightens up and lands by itself. The light beam shows where it will stay: it fades out at full speed and
  comes back when going slowly, stopping or landing. Only on playable planets: not in the mothership, the hangar or during the tutorial.
  The spot is saved per planet, also mid-flight; earlier saved games do not change.
- From **Cornor923** (thanks!, PRs 60-63):
  - **ESCorp contracts** (port addition; in the original they were server-side and are lost): "Contracts (ESCorp)" button on
    the on-board computer with 3 contracts to deliver blocks for credits (one base contract from the original's trivial
    blocks and two orders). The board is the same for everyone and changes every 30 real minutes; deliveries are saved with
    the game. Configured in `contracts.json` without rebuilding. Disabled during the tutorial. Starting credits drop from 500
    to 200, sent by ESCorp at the end of the tutorial (0 during it).
  - Lava makes the ancient bomb explode (port change: the original broke and dropped it, as water still does).
  - With a block in hand, it is placed in front of plants, models and partial blocks (it could not be before), and herbs and
    stalactites are overwritten when placing, as in the original.
  - From inside the ship, a window frame no longer z-fights with a neon light right outside it (back faces culled, like the original).
- Fixes for bugs found by **Sekhmet**: placing a block on top of the highest layer no longer uses it up without placing it; with
  your head inside a cascade source or quicksand you can aim at and dig what is in front, as in the original; quicksand, ice and
  glass no longer look hollow next to a cascade (port change).

## v0.5 — pre-release
- Fixes by Cornor923 (thank you!), merged from their PRs 17-30 (port change): no oxygen use underwater in creative; ice next
  to water is no longer cut into triangles seen from below; the creative palette help fits its panel and no block is marked
  when it opens; no gap under a block on the sea with waves on; after dying you stay in the ship (also when loading a game saved
  at 0 life); no damage in the hangar; trades with the robot are no longer lost when saving in the mothership and play time
  there is counted; on the map the ship has the same colors on every planet, keeps its heading when it stops and is centered
  on the hangar's ship.
- From the original, brought in by **Cornor923** (thank you!, PRs 31-51):
  - the camera and the HUD shake when blocks break and when you land;
  - the mining turbo works (power 3 within 15 blocks, with its HUD icon);
  - you slowly regain life in your ship;
  - the ancient bomb explodes when activated (and sets off the bombs it reaches);
  - Shift+K fades to white for about 3 seconds and puts you in the ship with full life and oxygen;
  - the view sinks when dying, rises with Shift+K and the teleporter, and dips a little when you get hit;
  - under water the field of view narrows and the sky takes the liquid's colour, with no stars;
  - the sea level drops by one block when the water flooding holes fills one layer of the sea;
  - fragments of the block fly off where the laser hits;
  - the original's starry sky on planets, turning as you walk;
  - mipmapped textures: the far landscape no longer flickers (port change: plants do not fade away with distance);
  - a visible selection frame, dropped blocks the original's size, icons and the planet loading bar like the original;
  - F2 saves a screenshot without the HUD and F shows or hides the coordinates and FPS (hidden at the start);
  - the break sound plays once per dropped block, chains included;
  - the canteen window no longer pauses the game and closes when you walk away;
  - the landing beam follows the ground under the ship (digging or building under it no longer leaves it floating);
  - in the hangar: no liquids or bomb, supports work (a door or a neon with nothing holding it falls) and digging is faster
    and needs no charges (port change).
- More from **Cornor923** (thank you!, PRs 52-59, port change unless noted):
  - **new start menu**: Continue opens the saved games list (play, rename, delete); New game asks for name, seed and mode
    (Creative: biome and size; Adventure: tutorial yes/no);
  - **guided tutorial** (port addition) for new adventure games, which start in space with an empty inventory, like the
    original; it can be skipped from the pause menu or the on-board computer;
  - the on-board computer no longer has the test shortcut to the mothership;
  - the selectors' "<" arrow goes to the previous choice; the Dead city shows its name and colour on the map;
  - in creative, a hard fall no longer shakes the screen like a hit;
  - an open ship door no longer counts as a hole in the hangar and doors are saved closed, like the original;
  - fixes lost when merging PRs 31-51 (turbo icon shaking with the HUD, test command help, READMEs).

## v0.4 — pre-release
- **Health and oxygen**, like the original: hard falls, lava, acid water, burning coal and acid herbs hurt; under water
  your oxygen runs out and then you drown; quicksand drowns you too; the healing plant and box heal. Health and oxygen bars
  at the bottom (only shown when not full) and a red or blue flash. When you die you go back to the ship with full health,
  without losing anything. No damage in creative mode.
- Options split into sections (General, Controls, Graphics, Interface): it no longer fitted on one screen.
- Plants and other models: you aim at what you see (their leaves, not the whole cell); with several plants together it is now easy to break the one you look at (port change).
- **Water waves**, the original's; they can be turned off in Options.
- Partial blocks (plates, iron, chests…): per-corner light like the original.
- Menu: a single small background planet; no more stutter while it is generated.
- **Flowing water** (the original `Process.hx`): the sea fills what you dig next to it up to its level; cascades and lava fall,
  spread and disappear without a source; grass gets covered and uncovered; anchored blocks and details break when their
  support is removed. Cascades and the water you place get lower at each step, with a sloped surface (port addition).
- **Merchant robot on the star map:** it travels between the sector's systems; click it and it stops and waits for you, and
  docking takes you into its ship (the mothership), with the shop. Leaving brings you back to the map. On the map, its ship has the
  shape of the mothership seen from above.
- **Taking off is leaving the planet**, like the original: the planet is unloaded (its changes are saved) and nothing is
  drawn behind the map. To go back, you land. If you save or close the game in space (or inside the robot's ship),
  "Continue" brings you back to the map where you were; the save list says "In space".
- Star map: Esc (or the gamepad's Start) opens a pause menu (Resume, Options, Main menu).
- The original **GPS arrows** on the map: they point to the planets you visited (and their systems) and to the robot (in orange).
- Options: a shadow of the block you are about to place and the name of the targeted block (small, bottom right); both can be turned off.
- Creative mode: the four waters (normal, dark, acid and winter) are in the palette.
- Fixes by **Cornor923** (thank you!): the bedrock (layer 0) is drawn and you can build on it; the main menu sticks to the
  edges on wide windows; the synthesizer uses the inventory's blocks first and keeps the area as a template (like the
  original); the game runs as `galaxy55.exe`, with its icon (Discord no longer says "Half-Life"); water and ice are drawn in
  the right order; blocks can no longer be placed inside a cascade source or quicksand; shop, chest, palette and map
  backgrounds cover the whole window; centered labels on the map buttons, clear of the Close button; names for many blocks
  that had none (snowy variants, charges, plants, bonus crystals).
- The block in the hand no longer shakes when walking.
- Fixes reported by Sekhmet (thank you!): key shortcuts (Tab digs and 1-0 are the 10 slots), blocks can be placed underwater,
  no snow under a roof or in caves, ice no longer drops a block when broken, a shadow of the block about to be placed, the name
  of the targeted block, and the freezer freezes nearby water and lava again.
- Linux: the zips use `/` in paths (they used to extract files with `\`); Linux steps from Sekhmet in the zip's `LEEME`.
## v0.3.1 — pre-release
- Options: vertical sync (VSync) and FPS limit (30, 60, 120, 144, 240 or unlimited).
- Fixes by **Cornor923** (thank you!): the liquid veil and menu backgrounds cover windows wider than 16:9, no dark
  patches through ice, the head no longer clips into blocks when falling or hovering, `jugar.bat` uses `hlw.exe` (no
  console) when present, and a French README.

## v0.3 — pre-release
- Hangar: rebuild your ship block by block, like in the original; leave through the teleporter to save it.
- Shop: buy and sell blocks for credits, with the merchant robot.
- Sound: the 12 original effects (footsteps, jump, landing, hard fall, jetpack, laser, breaking and picking up blocks).
- Fixed crosshair in the centre of the screen.
- Complete block names in Spanish, English and French (they used to show in Spanish or mixed).
- Chests: a tap opens them and holding the laser breaks them (their contents drop). In your ship, the computer and the
  doors can't be broken.
- Creative: palette with the gamepad (R3), copy the targeted block (L3 or middle click) and two new blocks, yellow and
  black plating, for hazard stripes.
- Mothership: deep space sky (Milky Way, nebulae, thousands of stars and distant galaxies), bays with hazard-stripe
  borders and an editor (`editar_nodriza.bat`).
- Fewer hitches when breaking or placing blocks, especially in the mothership.
- The ship teleport beam no longer disappears in the winter fog.
- Fixes reported by Sekhmet (thank you!): inside a liquid the screen and fog take its colour, like the original
  (quicksand no longer looks transparent); no snow under water; water has side faces; submerged ice stays behind the
  water; star map texts translated.
- Original French biome names (Terres Rouges, Rocaille sombre, Sables arides), found by Sekhmet on the old Twinpedia.
- Optional DirectX build (`haxe port\game_dx.hxml`, `jugar_dx.bat`), besides the OpenGL one.
- Mothership: unbreakable, better lit, doors closed, laser force fields on the hangars, 10 marked bays, your ship
  parked in yours (you spawn inside and its computer takes you back), and a shop with an animated merchant robot in
  the entrance tunnel.
- Gamepad: chests, shop and slot switching (LB/RB).
- The game no longer freezes for a few seconds at startup.
- `jugar.bat` works even when the PATH has folders with parentheses.

## v0.2 — pre-release
- Star map with the original animations (entering and leaving a system, hyperspace, flashes, server wait), common
  background with maelstrom; systems are generated in the background so it no longer freezes.
- Held block in the hand and break particles, copied from the original.
- Dead city selectable in New game.
- Fixes: deleting saves, removing the cascade source on the ship, dropped block spin, snow inside the ship.
- Changes from the original: the synthesizer uses the blocks in its area; breakable herbs and stalactites; curvature at
  60 %; snow mounds hiding a plant look like snow; camera zooms into the planet when entering.

## v0.1 — pre-release
First published native version: menus and saved games, planets identical to the Flash ones, digging/placing/jetpack,
creative mode, ship (teleporter, doors, synthesizer with the original recipes, computer), star map
(sector, systems, scanning and landing; the universe is part of the saved game) and a portable package with `jugar.bat`.
Known bugs: [`BUGS.md`](BUGS.md).

The earlier Flash version has its own changelog in [`docs/flash/CHANGELOG_flash.md`](docs/flash/CHANGELOG_flash.md) (Spanish).
