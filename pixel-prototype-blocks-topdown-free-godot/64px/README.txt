2D Pixel Prototype: Isometric Tileset 64px Godot
Version 1.0
by Mythryl Studio

Free 2D isometric greybox tileset: blocks, ramps, walls, props. Any engine, plus Godot, Unity and Tiled files.

HOW THIS SET WORKS

Isometric tiles on a 2:1 grid. Each cell is 64 x 32 px; a full block is 64 x 64 px, and each block up moves 32 px up the screen. A 64 px character stands two blocks tall.

Pieces that take a colour come in 3 surface styles (panel, plain, lines), each in 9 colours (slate, light, dark, orange, red, yellow, green, blue, purple). The rest keep their own colours.

  blocks       10 pieces
  ramps        7 pieces
  stairs       4 pieces
  walls        12 pieces
  pipes        7 pieces
  structure    13 pieces
  primitives   15 pieces
  props        26 pieces
  interactive  12 pieces
  pickups      5 pieces
  hazards      8 pieces
  nature       9 pieces
  markers      20 pieces
  notes        16 pieces

SHEETS

Everything comes on grid sheets: style/colour/group.png, and objects/ for pieces in their own colours. Sheets are grids of 64 x 32 px cells. Each piece takes a block of whole cells and stands at its bottom-left; bigger pieces take more cells.

The coin, gem, heart, star and key also come spinning: objects/pickups-spin.png has each one's 8 frames in a row, one full turn, to play at 10 frames a second.

FACINGS

Turned pieces come in each facing: s, w, n, e, the way the front faces (for a slope or stairs, the low end). Signs and notes read correctly from every facing.

GODOT 4

The godot folder has a TileSet per surface style (panel.tres, plain.tres, lines.tres), each with every colour and the objects, and an example scene. Copy the whole download into your project: the TileSets find the sheets beside them. For crisp pixels, set Default Texture Filter to Nearest (Project Settings, under Textures).
The TileSets are isometric (diamond down, 64 x 32 px). Each piece anchors on the front cell of its footprint. Stack levels as TileMapLayers, each moved up 32 px, with Y Sort on.
Every tile carries its piece, group, facing and kind as custom data.

All images are PNG with transparency. Scale by whole numbers
(2x, 3x, 4x) with nearest-neighbour filtering to keep pixels crisp.

LICENCE

See LICENSE.txt. In short: use these in your own commercial or
non-commercial projects, edited or not. Do not resell or share the
files themselves. Credit is appreciated but not required.

UPDATES

This pack may receive future updates with content as it becomes
available, and everyone who has it will receive the new assets.

Made something with these, or have an idea for the pack? Tell me:
https://mythryl.com
