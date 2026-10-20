/**
 * i18n/<locale>/creatures.json: every foe's name in a language, English one
 * of them, by its id, each game's (wow-data's databases, ../wow-data, its
 * pinned sources), for scripts/locales.ts to put in the language's Text file:
 *   { "forever": { "<creature id>": "<name>" }, "classic": { ... } }
 * And i18n/<locale>/items.json: the tools' items (Tools.lua's ITEMS) by id, in
 * the language, { "<item id>": "<name>" } (Forever's name, else Classic's): a
 * debrief names its items at once, the game naming an item only once loaded.
 * A debrief keeps its foes by their ids and reads them in the client's
 * language; Forever's damage meter names a foe only, in the client's
 * language: its id found from this list (the first id of a name). Every foe
 * this language names, none left out for being the English one.
 *
 *   bun scripts/creature_names.ts frFR
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type * as WowDb from "../../wow-data/src/db";
import { foes } from "./creatures";
import { readFileSync } from "node:fs";
import { familyPath } from "./root";

// through the family folder, from a worktree too (scripts/root.ts)
const { openDb } = (await import(familyPath("wow-data", "src", "db.ts"))) as typeof WowDb;

const locale = process.argv[2];
if (!locale || !/^[a-z]{2}[A-Z]{2}$/.test(locale)) {
  console.error("usage: bun scripts/creature_names.ts <locale> (enUS, frFR, deDE...)");
  process.exit(2);
}
const DIR = join(import.meta.dir, "..", "i18n", locale);

function names(game: "forever" | "classic"): Record<string, string> {
  const db = openDb(game);
  const named = new Map<number, string>();
  for (const r of db.query("SELECT id, name FROM name WHERE kind = 'creature' AND locale = ?").all(locale) as { id: number; name: string }[])
    named.set(r.id, r.name.trim());
  db.close();
  const out: Record<string, string> = {};
  for (const f of foes(game)) {
    const n = named.get(f.id);
    // (a placeholder: "(PNJ #15672)", "[Abbot Schuncke]")
    if (n && !/^[[(]/.test(n)) out[f.id] = n;
  }
  return out;
}

const out = { forever: names("forever"), classic: names("classic") };
mkdirSync(DIR, { recursive: true });
writeFileSync(join(DIR, "creatures.json"), `${JSON.stringify(out, null, 1)}\n`);

// the tools' items, by id
const tools = readFileSync(join(import.meta.dir, "..", "addon", "SecondWind", "Tools.lua"), "utf8");
const itemsBlock = tools.slice(tools.indexOf("local ITEMS = {"), tools.indexOf("\n}\n", tools.indexOf("local ITEMS = {")));
const itemIds = [...itemsBlock.matchAll(/\{\s*id = (\d+)/g)].map((m) => Number(m[1]));
const items: Record<string, string> = {};
for (const game of ["forever", "classic"] as const) {
  const db = openDb(game);
  const get = db.query("SELECT name FROM name WHERE kind = 'item' AND id = ? AND locale = ?");
  for (const id of itemIds) {
    const n = (get.get(id, locale) as { name: string } | null)?.name?.trim();
    if (n && !items[id] && !/^[[(]/.test(n)) items[id] = n;
  }
  db.close();
}
writeFileSync(join(DIR, "items.json"), `${JSON.stringify(Object.fromEntries(Object.entries(items).sort(([a], [b]) => Number(a) - Number(b))), null, 1)}\n`);
console.log(
  `✓ i18n/${locale}/creatures.json: ${Object.keys(out.forever).length} of Forever's foes, ${Object.keys(out.classic).length} of Classic's; items.json: ${Object.keys(items).length} of ${itemIds.length} tools' items`,
);
