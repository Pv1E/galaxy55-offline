# Native port (Haxe 4 + Heaps + HashLink)

[Español: `LEEME.md`](LEEME.md) · [Français : `LISEZMOI.md`](LISEZMOI.md)

This folder contains the port of the game to a native desktop application, with no Flash. It is work in progress (with known
bugs, see `BUGS.md` in the repository root); the original Flash game, with its build files and SWFs, remains untouched in the `flash` branch (only the original code the port compiles is kept here).

## Play

Build it (see below) and double-click `jugar.bat`, or download the portable zip from the
[release](../../../releases/tag/v0.9). The start menu offers Continue (the list of saved games: play, edit or delete; each one says which game version created it and last saved it), New game, Kube editor (port addition: draw new blocks and save them as `.kube` files in the `kubes` folder of the game data), Options and Quit.
In New game you choose name and mode: **Adventure** (as in the original, with an empty inventory) or **Creative** (our addition, with biome and size).
Customize sets the seed and whether dying leaves your equipment on the ground (port addition, on unless changed); Edit, in the saves list, changes it later.
Saved games (one `.g55` file per game, in `saves`) and settings go to `%APPDATA%\Galaxy55\` (change it with the `GALAXY55_DATA` environment variable), and screenshots (F2) to its `screenshots` folder.
The game also writes `gpu.txt` there, with the graphics card and driver: attach it when reporting a drawing bug.
The save format may change between versions: do not count on today's saves working forever.

## Controls

They can be changed in Options > Controls > Customize keys (port addition). By default they are the original game's (movement and physics are a copy of `ent/Hero.hx` and `Game.moveHero`).

| Action | Keys |
|---|---|
| Move | W/Z/Up forward, S/Down back, A/D and Left/Right sideways (in Options they can turn, as in the original) |
| Look | mouse (or gamepad) |
| Jump and jetpack | Space or Ctrl; in the air, jetpack (uses fuel, recharges on the ground) |
| Walk slowly | X |
| Helmet | H takes it off or puts it on |
| Coordinates and FPS | F shows or hides them (hidden at the start, as in the original) |
| Dig or place | left click, E or Shift (hold). With an empty hand you dig; with a block you place it if something supports it |
| Choose slot | 1-0 or mouse wheel (goes from one end of the bar to the other; turned off in Options > Controls); Tab = digger (empty hand) |
| Drop the selected stack | R or Del |
| Activate (on-board computer, doors, ancient bomb) | aim, press and release. Holding on until the block breaks digs it out instead: that is how an ancient bomb is picked up without setting it off (it needs a pink charge, like ancient rock). The synthesizer computer also works with a block in hand and with right click (port change) |
| ESCorp canteen (chest) | aim, press and release. The game goes on: drag and drop between the canteen and the inventory (right click half or one, Shift/Ctrl + click half/one, double click gathers; or arrows and Enter, or d-pad, A and X), dragging outside the window looks around and walking away closes it (so do Esc and B) |
| Return to the ship | Shift+K (leaves what you carry in a container, see below), or step into the landing light beam |
| Pilot the ship (port addition) | on-board computer > Pilot the ship: WASD or left stick move it over the planet, mouse or right stick turn the camera, E, Esc, B or Start leave it where it is (it slows down, straightens up and lands by itself) |
| Inventory and palette | I: in adventure, the inventory screen (drag, split stacks, throw outside); in creative, the block palette (click = put the block in the selected slot, wheel = page) |
| Pause | Esc |
| Quick save | F5 |
| Screenshot | F2: a PNG without the helmet or the HUD, at the window size, in `%APPDATA%\Galaxy55\screenshots\` |

There is no run button, as in the original. Gamepad: left stick moves, right stick looks, A jumps and jetpack, B walks slowly,
RT digs, LT places, RB/LB or d-pad right/left change slot, Y drops, Back helmet, Start pause. Menus: arrows/Enter/Esc, mouse or gamepad.

## Build

You need (Windows):
1. **Haxe 4.3.x** (https://haxe.org/download/) and **HashLink 1.16** for Windows (https://github.com/HaxeFoundation/hashlink/releases).
   Put the folders in the `PATH`; `haxe` and `hl` must work in a terminal.
2. Haxe libraries:

       haxelib install format
       haxelib git heaps https://github.com/HeapsIO/heaps
       haxelib git hashlink https://github.com/HaxeFoundation/hashlink
       haxelib dev hlsdl <folder-where-you-cloned-hashlink>/libs/sdl

   (`hlsdl` needs the HashLink source: clone that repository and point `haxelib dev` to its `libs/sdl` folder.)
   This is how the development machine was set up (Heaps from the main branch, HashLink 1.16, no admin rights). **It has not been tested from scratch on another machine**: if something fails, open an *issue*.
3. From the repository root:

       haxe port\game.hxml          full game with menus   (-> port\out\galaxy55.hl)
       haxe port\render.hxml        render technical test  (-> port\out\render.hl)
       haxe port\headless.hxml      screenless planet generator, HashLink
       haxe port\headless_flash.hxml  the same program for Flash (reference)

`jugar.bat` looks for `hl` in the `PATH`; if it is elsewhere, set the `HL` variable to its path first.

### DirectX version (optional)

For machines without OpenGL 3.2 (for example virtual machines with a shared GPU), there is a DirectX 11 build:

       haxelib dev hldx <folder-where-you-cloned-hashlink>/libs/directx
       haxe port\game_dx.hxml       (-> port\out\galaxy55_dx.hl, run it with jugar_dx.bat)

Known issue: if the `hldx` source is newer than your `directx.hdll` (HashLink 1.16 binary + hashlink from git), setting the
display mode fails with "Primitive or library is missing". Fix it in `libs/directx/dx/Window.hx`, `set_displayMode`: wrap the
body in `try { ... } catch( e : Dynamic ) { winSetFullscreen(win, mode != Windowed); }`. Using an `hldx` that matches your
HashLink version avoids the problem.
The game looks for the original graphics in `res\` (portable package) or, if missing, in `src\G55\fla\client\gfx\`; the `GALAXY55_RES` variable forces another folder.

### Other platforms

Get a HashLink build for your platform, copy `galaxy55.hl` into its folder as `hlboot.dat`, put the `res/` folder next to it and run `hl`.
A player got it running on Linux this way; we have not tested it.

## What is here

- `game/` the game: menus (`GalaxyApp`, `Ui`), languages (`Lang`), settings (`Settings`), saves (`SaveData`, `SaveArchive`, `SaveNames`), planet, light and meshing (`World`),
  block models (`Models`), sky and fog (`Sky`), snow (`Snow`), player, digging and placing (`GameView`), inventory (`Inv`, `InvBar`, `Palette`),
  effects and drops (`Fx`, `Drops`), the ship (`Ship`, `ShipData`), comets (`Comets`, `CometGenerator`), the ESCorp
  database (`Kubindex`, `KubData`, `DatabasePanel` and the `Kub*` views), canteen and storage (`Chest`, `ShipStorage`, `SlotGrid`),
  the equipment left on death (`DeathDrops`), ESCorp upgrades (`EscorpUpgrades`), kube editor kubes in the world (`EditorKubes`) and
  paintings (`Painting`).
- `explore/` the star map (`Explorer`, with the merchant robot and the GPS arrows). Flowing water is in `game/WorldProcess.hx`.
- `shim/` `flash.*` compatibility layer so the original generators compile in HashLink.
- `headless/` verification programs: the generator (Adler-32 hash, water and blocks), the ship and the saves (`SaveTest`,
  `SaveTool`). With version 0 of the generator, worlds were identical to the Flash ones; since version 1 (v0.9),
  `gen_ref.txt` holds the reference planets of each version (each planet remembers the version it was first visited with).

## Differences from the original

- Snow in the winter biome is an addition of this port: the original does not have it.
- Creative mode and its palette are an addition of this port. A creative game can switch to survival and back, and the palette
  also has the blocks without a price that give charges (hexalite crystals, citronox and etherium plants...).
- The on-board computer menu has its own look, as in the Flash version (the original was a web page).
  Trade, ESCorp contracts and ESCorp upgrades are in its "Contact ESCorp" sub-menu (port addition); upgrades, paid with hexalite
  charges, have none yet.
- The ESCorp canteen window also shows your inventory, works with drag and drop like the inventory screen (I in adventure,
  also a port addition), also closes with Esc, B or Close, and works with the keyboard and the gamepad (while it is open the arrow keys move its cursor, not the player). Its contents are kept in the save (the original
  kept them on the server) and fall to the ground when it is broken.
- The merchant robot's shop (the original was a web panel), its ship on the star map and the orange GPS arrow pointing to it
  are additions of this port. In the mothership, its stall is in the middle of the hangar and you talk to the robot (click on
  it) to trade or chat. Its prices are the port's own: crafted goods do not resell for more than their ingredients cost and
  some things are only bought.
- ESCorp contracts (on-board computer > Contact ESCorp > ESCorp contracts) are an addition of this port (in the original they came from the server;
  only the list of trivial blocks for the base contracts survives). They are edited in `contracts.json`. With only part of
  the blocks you give what you have and the contract stays in progress: it no longer expires, takes one line of the board
  and only goes away once finished or abandoned (with confirmation; the blocks given are lost). Starting credits are 200
  and arrive at the end of the tutorial (before: 500 from the start).
- Lava makes the ancient bomb explode (port change): the original broke and dropped it, as water still does.
- ESCorp exploration licenses are an addition of this port (in the original the server handled them): in adventure you can
  scan 4 planets (1 main and 3 exploration) and the ship can only be piloted over the main one.
- Cascades and player-placed water get lower at each step, with a sloped surface: an addition of this port. The sea fills
  holes up to its level and, when the water that flows in adds up to the volume of one layer of the sea, the level goes down
  one block on the whole planet, like the original.
- Plants and other models are aimed at by what you see (the pixels of their leaves), not the whole cell (the original treated them as a full block).
- The ancient bomb also sets off the other bombs caught in its blast, one per frame: the original had the code for it, but a
  check made it never fire. The blast leaves the bedrock (layer 0) in place (the original removed it too), the bomb does not
  explode in the hangar, and it throws 8 shards per block instead of 75 so that the game does not freeze.
- The ancient bomb's screen flash no longer strobes (port change, for photosensitive players): in a chain or with several
  bombs in a row it is prolonged instead of restarted and rises again at most once per second (the original flashed red
  and white with every bomb).
- Distant textures use mipmaps like the original, but far plants do not fade away and each far block keeps its own colour
  (in the original, thin plants disappeared with distance and, further away, neighbouring textures got mixed).
- The landing light beam follows any change in the column under the ship and starts on top of low blocks such as plates (the
  original only moved it when a block was broken there); you return to the ship only standing at its base, not from higher up.
- Piloting the ship over the planet is an addition of this port (the original always left it at the same spot on each planet):
  from the on-board computer, only on playable planets (not in the mothership, the hangar, on comets or during the tutorial; in adventure, only over the main planet). It always
  stays at the same height, costs nothing, uses a camera behind and above it and lighter fog while it lasts; the light beam
  shows where it will stay (it fades out at full speed and comes back when going slowly, stopping or landing). It speeds up and slows down smoothly, turns to face where it goes and banks in turns; when you
  leave it, it returns to its usual heading before landing (its blocks, chests and synthesizers do not rotate). The spot is saved per planet; if you never pilot it, the ship lands where it always did.
- Added options: a shadow of the block you are about to place, the name of the targeted block, hiding the selection frame, turning off the water waves
  and a mouse wheel that wraps around (in the original it stopped at both ends of the bar).
- The mining turbo makes you dig three times faster up to 15 blocks around it (5 in the original) and you get it back when
  you break it (the original lost it).
- The F2 screenshot is saved straight to the `screenshots` folder and a message says where (the original opened Flash's save dialog).
- In the hangar, liquids (water, cascades, quicksand, lava...) and the Ancient Bomb cannot be placed: a message says they are
  not allowed on board. The original only stopped the blocks that spread (cascade source and lava), without a message.
- In the hangar you dig four times faster and without charges, like in the ship's synthesizer areas: a change of this port,
  so that editing the ship is comfortable. In the original you dug there as on a planet, with the charges.
- Falling into quicksand (a change of this port): touching it gives the hit of the fall down to it, as on the ground, and the
  sand stops the fall; when leaving it from below, the fall counts from the way out. In the original it only slowed time
  down: the speed kept growing inside and the damage came at the end, that of the whole fall. As in the original, the sand
  takes life while your eyes are in it and, from inside, looking down aims at nothing.
- The ESCorp database (on-board computer) is an addition of this port: the Kubindex with every kube, the planet and comet
  types, the anomalies and the recipes, filled in as you play. The mark for new entries is an icon from Mush (`recent.png`,
  Motion Twin, CC BY-NC-SA 4.0).
- Comets are an addition of this port: 96x96 worlds that visit systems for a while (a fixed draw per system and 2-hour slot,
  not the server). They use no license and the docking time depends on the ship's speed.
- In the synthesizer area and in the hangar, whatever is broken always drops (port change: in the original, what only drops
  by chance was often lost when taken back from there). A drop buried under placed blocks comes out by the side; in the
  original it rose through them and, in the ship, ended on the roof.
- The 77 kubes of Kube (Motion Twin, 2010) are an addition of this port: full blocks with Kube's textures (CC BY-NC-SA 4.0,
  in `NOTICE`), in the creative palette and the ESCorp database (the merchant robot neither sells nor buys them), with one
  `.kube` per block in `port/kubes`. The invisible anomaly (Kube Chests wrapped in invisible kubes), the gems the Kube Chest
  gives in the synthesizer and the coloured toughened glass are additions too.
- Synthesizer recipes give more than in the original (wood, 4 planks; many recipes, 2 instead of 1) and there are new
  recipes: rock column, HardRoq, soft rock and frost tiles, and the ESCorp canteen from 8 iron. The lumen rock trunk is made
  from dead lumen rocks (in the original, from moon rock).
- A save with blocks this version does not know (saved by a newer one) asks before loading; if accepted, it is copied to
  `saves/backups` and those blocks are deleted.
- The ship storage (on-board computer > Storage) is an addition of this port: 4 block slots, like a canteen, and charges
  without slots (yellow up to 24, blue 12, pink 5, hexalite without limit). The original's was on the server and is lost.
- When you die or press Shift+K, what you carry (blocks and charges, not credits) stays in a small ESCorp canteen where you
  were, which never expires and is kept in the save (in the original the server left it, as loot that expired, and the local
  mode took nothing). It is a game option, on unless changed; nothing happens in creative, in the tutorial, in the hangar or
  in the mothership.
- Walking climbs plates (half blocks) without jumping: a change of this port, in the original they stopped you like a wall.
- The 16 CroqueMotel paintings (Motion Twin, CC BY-NC-SA 4.0, in `NOTICE`) are an addition of this port: plates hung on a
  wall, in the creative palette only. In a creative game the kube editor kubes (the `.kube` files of the `kubes` folder) can
  be placed too.
- The planet generator (version 1, a change of this port) follows the original's steps, but each step, structure and hexalite
  crystal has its own randomness and structures are placed by region in a fixed order: planets are no longer identical to the
  Flash version's, and adding a structure only changes the planet inside its box. Saves store blocks by name, so new blocks from
  another version don't break them.
- What is missing is in `TODO.md`, bugs in `BUGS.md` and ideas for later in `IDEAS.en.md` (repository root).
