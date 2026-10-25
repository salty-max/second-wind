/**
 * i18n/<locale>/ → addon/SecondWind/Text_<locale>.lua, one for every language
 * the game has (a stub where there is no translation yet, so the TOC never
 * names a missing file): each client loads its own, through
 * Text_[TextLocale].lua in the TOCs, and English stays wherever a translation
 * says nothing (Locale.lua).
 *
 *   i18n/<locale>/meta.json    { "plural": "one" | "fr" | "ru" | "none",
 *                              "decimal": ",", "flagged": true }  (flagged: a
 *                              first translation, no native reader's yet)
 *   i18n/<locale>/words.json   { "English": "translation" }: every L["..."]
 *                              and plural(n, "one", "many") of the addon (the
 *                              kit's own are i18n/kit/'s); i18n/words.json lists them
 *
 *   i18n/<locale>/items.json   the tools' items by id (scripts/creature_names.ts)
 *   i18n/<locale>/subzones.json
 *                              the places inside buildings by their ids, each
 *                              game's, every language's (../addon-kit/
 *                              subzones.py <locale>): a debrief's place inside
 *                              a building kept by its id
 *   i18n/<locale>/creatures.json
 *                              every foe's name in the language, English one
 *                              of them, by its id, each game's, from
 *                              wow-data's databases (scripts/creature_names.ts
 *                              <locale>): a debrief's foes read by their ids,
 *                              a foe Forever's damage meter names only found
 *                              by its name; every Text file has them, its
 *                              language's own (enGB: enUS's)
 *
 * A language without its own words may borrow another's (esMX: esES), with
 * its own metadata overriding the shared catalog's (decimal point in esMX).
 * The family's core (scripts/locales-lib.ts, the kit's copy) reads the words,
 * merges the kit's own (i18n/kit/, translated once for every addon), checks
 * them and writes the files; here, Second Wind's names.
 *
 *   bun scripts/locales.ts            write the Text files
 *   bun scripts/locales.ts --check    fail if one isn't up to date, a word has
 *                                     no translation or a semicolon
 *   bun scripts/locales.ts --keys     write i18n/words.json, every word to translate
 */
import { existsSync } from "node:fs";
import { join, relative } from "node:path";
import { json, q, run } from "./locales-lib";

const ROOT = new URL("..", import.meta.url).pathname;
const I18N = join(ROOT, "i18n");
// (the names: a language the game names nothing in its own, another's)
const NAMES_OF: Record<string, string> = { enGB: "enUS" };

// Every foe's name in a language, by its id, each game's (i18n/<locale>/,
// written from wow-data's databases by scripts/creature_names.ts).
function namesLua(locale: string): string[] {
  const file = join(I18N, NAMES_OF[locale] ?? locale, "creatures.json");
  if (!existsSync(file)) throw new Error(`${relative(ROOT, file)} is missing: run bun scripts/creature_names.ts ${NAMES_OF[locale] ?? locale}`);
  const t: { forever: Record<string, string>; classic: Record<string, string>; foreverLeftOut?: Record<string, string> } = json(file);
  const insideFile = join(I18N, NAMES_OF[locale] ?? locale, "subzones.json");
  if (!existsSync(insideFile)) throw new Error(`${relative(ROOT, insideFile)} is missing: python3 ../addon-kit/subzones.py ${NAMES_OF[locale] ?? locale}`);
  const inside: { forever?: Record<string, string>; classic?: Record<string, string> } = json(insideFile);
  const items: Record<string, string> = json(join(I18N, NAMES_OF[locale] ?? locale, "items.json"));
  const lines = ["ns.names({"];
  for (const [key, list] of [
    ["creatures", t.forever],
    ["creaturesClassic", t.classic],
    // (Forever's left out by wow-data's build: a saved debrief's foe by its id alone)
    ["creaturesLeftOut", t.foreverLeftOut ?? {}],
    ["inside", inside.forever ?? {}],
    ["insideClassic", inside.classic ?? {}],
    ["items", items],
  ] as const) {
    lines.push(`  ${key} = {`);
    const items = Object.entries(list).sort(([a], [b]) => Number(a) - Number(b));
    for (let i = 0; i < items.length; i += 4) lines.push(`    ${items.slice(i, i + 4).map(([id, n]) => `[${id}]=${q(n)},`).join(" ")}`);
    lines.push("  },");
  }
  lines.push("})");
  return lines;
}

run({ root: ROOT, addon: "addon/SecondWind", skip: /^(Text|Creatures)_/, names: namesLua });
