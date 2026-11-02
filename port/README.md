# Native port (Haxe 4 + Heaps + HashLink)

[Español: `LEEME.md`](LEEME.md) · [Français : `LISEZMOI.md`](LISEZMOI.md)

This folder contains the port of the game to a native desktop application, with no Flash. It is work in progress (with known
bugs, see `BUGS.md` in the repository root); the original Flash game, with its build files and SWFs, remains untouched in the `flash` branch (only the original code the port compiles is kept here).

## Play

Build it (see below) and double-click `jugar.bat`, or download the portable zip from the
[release](../../../releases/tag/v0.6). The start menu offers Continue (the list of saved games: play, rename or delete), New game, Options and Quit.
In New game you choose name, seed and mode: **Adventure** (as in the original, with an empty inventory) or **Creative** (our addition, with biome and size).
Saved games and settings go to `%APPDATA%\Galaxy55\` (change it with the `GALAXY55_DATA` environment variable), and screenshots (F2) to its `screenshots` folder.
The save format may change between versions: do not count on today's saves working forever.

## Controls

They are the original game's (movement and physics are a copy of `ent/Hero.hx` and `Game.moveHero`).

| Action | Keys |
|---|---|
| Move | W/Z/Up forward, S/Down back, A/D and Left/Right sideways (in Options they can turn, as in the original) |
| Look | mouse (or gamepad) |
| Jump and jetpack | Space or Ctrl; in the air, jetpack (uses fuel, recharges on the ground) |
| Walk slowly | X |
| Helmet | H takes it off or puts it on |
| Coordinates and FPS | F shows or hides them (hidden at the start, as in the original) |
| Dig or place | left click, E or Shift (hold). With an empty hand you dig; with a block you place it if something supports it |
| Choose slot | 1-0 or mouse wheel; Tab = digger (empty hand) |
| Drop the selected stack | R or Del |
| Activate (on-board computer, doors, ancient bomb) | aim, press and release. Holding on until the block breaks digs it out instead: that is how an ancient bomb is picked up without setting it off (it needs a pink charge, like ancient rock) |
| ESCorp canteen (chest) | aim, press and release. The game goes on: click takes and drops (Shift half, Ctrl one; or arrows and Enter, or d-pad and A), dragging outside the window looks around and walking away closes it (so do Esc and B) |
| Return to the ship | Shift+K, or step into the landing light beam |
| Pilot the ship (port addition) | on-board computer > Pilot the ship: WASD or left stick move it over the planet, mouse or right stick turn the camera, E, Esc, B or Start leave it where it is (it slows down, straightens up and lands by itself) |
| Creative: block palette | I (click = put the block in the selected slot, wheel = page) |
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

- `game/` the game: menus (`GalaxyApp`, `Ui`), languages (`Lang`), settings (`Settings`), saves (`SaveData`), planet, light and meshing (`World`),
  block models (`Models`), sky and fog (`Sky`), snow (`Snow`), player, digging and placing (`GameView`), inventory (`Inv`, `InvBar`, `Palette`),
  effects and drops (`Fx`, `Drops`) and the ship (`Ship`, `ShipData`).
- `explore/` the star map (`Explorer`, with the merchant robot and the GPS arrows). Flowing water is in `game/WorldProcess.hx`.
- `shim/` `flash.*` compatibility layer so the original generators compile in HashLink.
- `headless/` verification programs: worlds are identical to the Flash ones (Adler-32 hash, water and blocks); they also read the ship and the saves.

## Differences from the original

- Snow in the winter biome is an addition of this port: the original does not have it.
- Creative mode and its palette are an addition of this port.
- The on-board computer menu has its own look, as in the Flash version (the original was a web page).
- The ESCorp canteen window also shows your inventory, also closes with Esc, B or Close, and works with the keyboard and the
  gamepad (while it is open the arrow keys move its cursor, not the player). Its contents are kept in the save (the original
  kept them on the server) and fall to the ground when it is broken.
- The merchant robot's shop (the original was a web panel), its ship on the star map and the orange GPS arrow pointing to it
  are additions of this port.
- ESCorp contracts (on-board computer > Contracts) are an addition of this port (in the original they came from the server;
  only the list of trivial blocks for the base contracts survives). They are edited in `contracts.json`. Starting credits
  are 200 and arrive at the end of the tutorial (before: 500 from the start).
- Lava makes the ancient bomb explode (port change): the original broke and dropped it, as water still does.
- Cascades and player-placed water get lower at each step, with a sloped surface: an addition of this port. The sea fills
  holes up to its level and, when the water that flows in adds up to the volume of one layer of the sea, the level goes down
  one block on the whole planet, like the original.
- Plants and other models are aimed at by what you see (the pixels of their leaves), not the whole cell (the original treated them as a full block).
- The ancient bomb also sets off the other bombs caught in its blast, one per frame: the original had the code for it, but a
  check made it never fire. The blast leaves the bedrock (layer 0) in place (the original removed it too), the bomb does not
  explode in the hangar, and it throws 8 shards per block instead of 75 so that the game does not freeze.
- Distant textures use mipmaps like the original, but far plants do not fade away and each far block keeps its own colour
  (in the original, thin plants disappeared with distance and, further away, neighbouring textures got mixed).
- The landing light beam follows any change in the column under the ship and starts on top of low blocks such as plates (the
  original only moved it when a block was broken there); you return to the ship only standing at its base, not from higher up.
- Piloting the ship over the planet is an addition of this port (the original always left it at the same spot on each planet):
  from the on-board computer, only on playable planets (not in the mothership, the hangar or during the tutorial). It always
  stays at the same height, costs nothing, uses a camera behind and above it and lighter fog while it lasts; the light beam
  shows where it will stay (it fades out at full speed and comes back when going slowly, stopping or landing). It speeds up and slows down smoothly, turns to face where it goes and banks in turns; when you
  leave it, it returns to its usual heading before landing (its blocks, chests and synthesizers do not rotate). The spot is saved per planet; if you never pilot it, the ship lands where it always did.
- Added options: a shadow of the block you are about to place, the name of the targeted block and turning off the water waves.
- The mining turbo makes you dig three times faster up to 15 blocks around it (5 in the original) and you get it back when
  you break it (the original lost it).
- The F2 screenshot is saved straight to the `screenshots` folder and a message says where (the original opened Flash's save dialog).
- In the hangar, liquids (water, cascades, quicksand, lava...) and the Ancient Bomb cannot be placed: a message says they are
  not allowed on board. The original only stopped the blocks that spread (cascade source and lava), without a message.
- In the hangar you dig four times faster and without charges, like in the ship's synthesizer areas: a change of this port,
  so that editing the ship is comfortable. In the original you dug there as on a planet, with the charges.
- What is missing is in `TODO.md`, bugs in `BUGS.md` and ideas for later in `IDEAS.en.md` (repository root).
