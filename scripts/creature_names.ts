/**
 * i18n/<locale>/creatures.json: every foe's name in a language, English one
 * of them, by its id, each game's (wow-data's databases, ../wow-data, its
 * pinned sources), for scripts/locales.ts to put in the language's Text file:
 *   { "forever": { "<creature id>": "<name>" }, "classic": { ... } }
 * A debrief keeps its foes by their ids and reads them in the client's
 * language; Forever's damage meter names a foe only, in the client's
 * language: its id found from this list (the first id of a name). Every foe
 * this language names, none left out for being the English one.
 *
 *   bun scripts/creature_names.ts frFR
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { openDb } from "../../wow-data/src/db";
import { foes } from "./creatures";

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
console.log(`✓ i18n/${locale}/creatures.json: ${Object.keys(out.forever).length} of Forever's foes, ${Object.keys(out.classic).length} of Classic's`);
