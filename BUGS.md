# Known bugs (native version)

[Español: `ERRORES.md`](ERRORES.md) · [Français : `BUGS.fr.md`](BUGS.fr.md)

If you find one that is not listed, open an *issue* with what you were doing and, if possible, a screenshot.
Fixed ones are moved to the bottom. Technical details are in [`port/RESUMEN.md`](port/RESUMEN.md) (Spanish).

## Open

| # | Where | What happens |
|---|---|---|
| 4 | Lighting | **To check while playing:** partial blocks (plates, iron, chests…) now take each corner's light from the neighbouring cells, like the original (`Builder.addCustomQuad`); before, the whole face had a single light. Models already used the original's light. |
| 8 | Winter | **Spruce leaves** drop material; in the original they may not. |
| 10 | Rendering | Dropped **crystals** (charges) look too wide. |
| 14 | Water | **(Fix?)** When you open a cave next to the sea, the water rushes in and fills it at once at the same height as the sea, without getting lower as it advances. Now, as in the original (`net/Local.hx` and `SReduceWater`), the water that flows in is counted and, each time it adds up to the volume of one layer of the sea (hundreds or thousands of blocks, depending on the planet), the top layer disappears on the whole planet: the sea goes down one block. A small cave does not get there and still fills at once up to the sea level, as in the original. |

## Fixed

- v0.7 (from **Sekhmet**, fixed by **Cornor923**): volume at 0 is silent; a cascade behind glass is visible.
- v0.7: the floor under four ingots placed together in the ship no longer looks black (port change).
- v0.7 (fixed by **Cornor923**, PRs 81-86): the tall red grass no longer throws white pieces; the tutorial no longer gets stuck if the aluminium is used up on another recipe; the tutorial green arrow shows; the window no longer shows small at launch.
- v0.7 (fixed by **Cornor923**, PRs 87-94): falling into quicksand no longer leaves the damage of the whole fall for the end; a block that only drops by chance is no longer lost when broken in the synthesizer area or in the hangar; a drop buried in the synthesizer area no longer ends on the ship's roof; the tutorial congratulations no longer stay on the map nor say "your main planet" on another planet; no more stops when the menu appears, when loading a planet or the mothership; in French, the kube editor help says "enregistrer" again.
- v0.6 (found by **Sekhmet**, thank you!): placing a block on top of the highest layer no longer uses it up without placing it (nothing is aimed at, like the original); with your head inside a cascade source or quicksand you can aim at and dig what is in front (the original does not count the camera's cell); quicksand, ice and glass no longer look hollow next to a cascade (port change: their face against the cascade is drawn, since here the cascade gets lower).
- v0.5 (#15, from **Sekhmet**): the ship no longer changes place when the game is reopened. Up to v0.4 the landing spot was
  computed with the player's changes: digging or building where it lands put the ship somewhere else and the player, saved
  inside, fell to the ground. Since v0.5 it is computed on the original terrain (checked with `port/dev/nave_sitio.txt`). A v0.4
  save where the ship had already moved sees it go back once to its usual spot after moving to v0.5.
- v0.4: the menu uses a single small background planet (it used to be three big ones that changed every 22 s): no more stutter while they are generated; one ~0.4 s hitch remains at the start, when the planet is first drawn (#13). The cascade does not freeze next to ice, only with the freezer, like the original (#12, checked).
- v0.3 (found and reported by **Sekhmet**, thank you!): quicksand and water no longer look transparent from inside (screen tint and fog in the liquid's colour, like the original); it no longer snows under water; water has side and bottom faces; submerged ice stays behind the water; star map texts follow the chosen language.
- v0.4 (reported by **Sekhmet**, thank you!): water flows (`WorldProcess.hx`, the original `Process.hx`); blocks can be placed underwater; no more snow under a roof or in caves; ice no longer drops a block when broken (like the original); key shortcuts (Tab digs and 1–0 are the 10 slots; the last one used to have no key).
- v0.4: the block in the hand no longer shakes when walking; the creative palette highlight no longer sticks.
- v0.4 (fixed by **Cornor923**, thank you!, PRs 17-30, port change): no oxygen use underwater in creative; ice next to water is no longer cut into triangles seen from below; the creative palette help fits its panel and no block is marked when it opens; no gap under a block on the sea with waves on; after dying you stay in the ship (also when loading a game saved at 0 life); no damage in the hangar; trades with the robot are no longer lost when saving in the mothership and play time there is counted; on the map the ship has the same colors on every planet, keeps its heading when it stops and is centered on the hangar's ship.
- v0.4: the game also runs with DirectX (`port/game_dx.hxml`), useful where OpenGL 3.2 is missing (e.g. virtual machines).
- v0.4: layer 0 (bedrock) is drawn, like in the original: the bottom of a hole dug down to it no longer shows the void and the sky under the planet.
- v0.4: the synthesizer uses the blocks in the inventory first, like the original: while the inventory has all of them, the blocks placed in its area stay as a template and the same recipe can be crafted again and again; when one is missing, the placed blocks are used up (this undoes the v0.2 change).

- v0.2 (change from the original): snow mounds hiding a plant (`BWinterHidden`) look like regular snow, without their own glow.
- v0.2: deleting a saved game from the menu (Delete button, then pick the save; the confirmation no longer opens twice).
- v0.2: it no longer snows inside the ship.
- v0.2: the map no longer freezes when entering a system (it is generated in the background while you travel).
- v0.2 (change from the original): when entering a planet the camera zooms into it instead of fading to black, and the name shows only once.
- v0.2: the cascade source can be removed (targeting now works as in the original).
- v0.2: particles when breaking a block; dropped blocks spin at the original speed.
- v0.2: Dead city can be chosen in New game (Shed not yet).
- v0.2 (change from the original): planet curvature is 60 % of the original one (it was too noticeable, especially on small planets).
- v0.2: the selected block is shown in the hand.
- v0.2: star map with the original animations: entering and leaving a system (zoom, hyperspace, flashes; leaving lets you cross the ring and ejects you a moment later), scanning (fade, name and bar) and landing; common background with maelstrom.
- v0.2 (change from the original): the synthesizer always uses up the blocks placed in its area.
- v0.2 (change from the original): ground herbs and ice stalactites can be broken; they give tall grass (33 %) or ice (7 %), like the original's plants and black ice.

- Appearing "in the sky" when entering the synthesizer (not seen again).
- Synthesizer blocks duplicating when placed.
- Black screen when taking off to the star map.
- Returning from a planet left the ship outside its galaxy (now it returns next to the planet).
