/**
 * i18n/<locale>/creatures.json and types.json: the game's names in a
 * language, from wow-data's Forever database (../wow-data, its pinned
 * sources), for scripts/locales.ts to put in the language's Text file.
 *   creatures.json  { "<name>": <creature id> }: Forever's damage meter names
 *                   a foe only, in the client's language: its creature, for
 *                   its portrait (the first id a name has, as
 *                   Creatures_Forever.lua's English names; a name the English
 *                   table has already left out)
 *   types.json      { "<the language's word>": "<the English one>" }: a
 *                   creature type as UnitCreatureType gives it, for its icon
 *                   and the critter test
 *
 *   bun scripts/creature_names.ts frFR
 */
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { openDb } from "../../wow-data/src/db";
import { byName, foes } from "./creatures";

const locale = process.argv[2];
if (!locale || !/^[a-z]{2}[A-Z]{2}$/.test(locale)) {
  console.error("usage: bun scripts/creature_names.ts <locale> (frFR, deDE...)");
  process.exit(2);
}
const DIR = join(import.meta.dir, "..", "i18n", locale);
const db = openDb("forever");

const list = foes("forever");
const english = byName(list);
const named = new Map<number, string>();
for (const r of db.query("SELECT id, name FROM name WHERE kind = 'creature' AND locale = ?").all(locale) as { id: number; name: string }[])
  named.set(r.id, r.name);
const creatures = [...byName(list.filter((f) => named.has(f.id)).map((f) => ({ id: f.id, name: named.get(f.id)! })))]
  // (a name the English table has already; a placeholder: "(PNJ #15672)", "[Abbot Schuncke]")
  .filter(([n]) => !english.has(n) && !/^[[(]/.test(n))
  .sort(([a], [b]) => a.localeCompare(b));

const types = db
  .query(
    `SELECT t.name AS tr, e.name AS en FROM name t JOIN name e ON e.kind = t.kind AND e.id = t.id AND e.locale = 'enUS'
     WHERE t.kind = 'creature_type' AND t.locale = ? AND t.name <> e.name ORDER BY t.id`,
  )
  .all(locale) as { tr: string; en: string }[];
db.close();

writeFileSync(join(DIR, "creatures.json"), `${JSON.stringify(Object.fromEntries(creatures), null, 1)}\n`);
writeFileSync(join(DIR, "types.json"), `${JSON.stringify(Object.fromEntries(types.map((t) => [t.tr, t.en])), null, 2)}\n`);
console.log(`✓ i18n/${locale}: ${creatures.length} creatures' names, ${types.length} creature types`);
