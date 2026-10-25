/**
 * The addon's package: the family's (scripts/package-lib.ts, the kit's copy):
 * addon/SecondWind as it is, one zip for every game, each game loading its own
 * TOC; its TOCs checked.
 *
 *   bun scripts/package.ts           dist/SecondWind and dist/SecondWind-<version>.zip
 *   bun scripts/package.ts --no-zip  the folder only (to copy into a game)
 *   bun scripts/package.ts --check   the TOCs only
 */
import { join } from "node:path";
import { run } from "./package-lib";

// (each game's own files: the creatures and the game's tables: each game's own, TBC Anniversary reading Classic Era's)
run({ root: join(import.meta.dir, ".."), name: "SecondWind", games: { classic: ["Creatures_Classic.lua", "Game_Classic.lua"], tbc: ["Creatures_Classic.lua", "Game_Classic.lua"], forever: ["Creatures_Forever.lua", "Game_Forever.lua"] } });
