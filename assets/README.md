# Project logo

An original painted fantasy-item logo in the same family as Lorekeeper's Codex,
Explorer's Field Journal and Hearthtale, inspired by the visual style of
[Archivist for Forever](https://www.curseforge.com/wow/addons/archivist-for-forever).
Generated using the built-in image generation tool.

A battered frost-blue shield, gold rim, rising blue wind and a warm central flame:
a close call survived, with something left to learn.

- `logo-1024.png`: 1024px square, for the CurseForge project page.
- `logo.png`: 512px square export.
- `logo-master.png`: full-resolution generated master; resize this for future exports.
- `logo-prompts.json`: the generation prompt and style references.
- `../addon/SecondWind/Media/Logo.tga`: uncompressed 256px texture used in game, its corners
  rounded as the siblings' (radius 34): `magick logo.png -resize 256x256 -alpha off mask.png
  -compose CopyOpacity -composite -compress none TGA:Logo.tga`, the mask a white
  `roundrectangle 0,0 255,255 34,34` on black.
