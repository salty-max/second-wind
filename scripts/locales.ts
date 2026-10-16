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
 *                              and plural(n, "one", "many") of the addon, its
 *                              kit's included; i18n/words.json lists them
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
 *
 *   bun scripts/locales.ts            write the Text files
 *   bun scripts/locales.ts --check    fail if one isn't up to date, a word has
 *                                     no translation or a semicolon
 *   bun scripts/locales.ts --keys     write i18n/words.json, every word to translate
 */
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";

const ROOT = new URL("..", import.meta.url).pathname;
const I18N = join(ROOT, "i18n");
const ADDON = join(ROOT, "addon/SecondWind");
const LOCALES = ["enUS", "enGB", "deDE", "frFR", "esES", "esMX", "ruRU", "ptBR", "itIT", "koKR", "zhCN", "zhTW"];
const ENGLISH = new Set(["enUS", "enGB"]);
const BORROWS: Record<string, string> = { esMX: "esES" };
// (the names: a language the game names nothing in its own, another's)
const NAMES_OF: Record<string, string> = { enGB: "enUS" };
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// every L["..."] and plural(n, "one", "many") of the addon's own files and its
// kit's; the kit's month names (K.day)
function keys(): string[] {
  const found = new Set<string>(MONTHS);
  const unq = (s: string) => s.replace(/\\(["\\n])/g, (_, c) => (c === "n" ? "\n" : c));
  for (const f of readdirSync(ADDON).sort()) {
    if (!f.endsWith(".lua") || /^(Text|Creatures)_/.test(f)) continue;
    const src = readFileSync(join(ADDON, f), "utf8");
    for (const m of src.matchAll(/\bL\[\s*"((?:[^"\\]|\\.)*)"\s*\]/g)) found.add(unq(m[1]));
    for (const m of src.matchAll(/plural\([^,()]+(?:\([^()]*\))?,\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\s*\)/g)) {
      found.add(unq(m[1]));
      found.add(unq(m[2]));
    }
  }
  return [...found].sort();
}

const q = (s: string) => `"${s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
const json = (file: string) => (existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : {});

// Numbered blanks may change order, but must keep each argument's type and
// multiplicity. Literal percent signs in a formatted sentence stay escaped.
function formatArgs(s: string): string[] {
  let next = 0;
  return [...s.matchAll(/%%|%(?:(\d+)\$)?(0?\d*(?:\.\d+)?[sdfi])/g)]
    .filter(([token]) => token !== "%%")
    .map(([, index, spec]) => `${index ? Number(index) : ++next}:${spec.slice(-1)}`)
    .sort();
}

// Every foe's name in a language, by its id, each game's (i18n/<locale>/,
// written from wow-data's databases by scripts/creature_names.ts).
function namesLua(locale: string): string[] {
  const file = join(I18N, NAMES_OF[locale] ?? locale, "creatures.json");
  if (!existsSync(file)) throw new Error(`${relative(ROOT, file)} is missing: run bun scripts/creature_names.ts ${NAMES_OF[locale] ?? locale}`);
  const t: { forever: Record<string, string>; classic: Record<string, string> } = json(file);
  const insideFile = join(I18N, NAMES_OF[locale] ?? locale, "subzones.json");
  if (!existsSync(insideFile)) throw new Error(`${relative(ROOT, insideFile)} is missing: python3 ../addon-kit/subzones.py ${NAMES_OF[locale] ?? locale}`);
  const inside: { forever?: Record<string, string>; classic?: Record<string, string> } = json(insideFile);
  const items: Record<string, string> = json(join(I18N, NAMES_OF[locale] ?? locale, "items.json"));
  const lines = ["ns.names({"];
  for (const [key, list] of [
    ["creatures", t.forever],
    ["creaturesClassic", t.classic],
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

function luaFor(locale: string): string {
  const own = (l: string) => existsSync(join(I18N, l, "words.json"));
  const from = own(locale) ? locale : BORROWS[locale] && own(BORROWS[locale]) ? BORROWS[locale] : null;
  const lines = [`-- Generated by scripts/locales.ts from i18n/: edit those, not this file.`, "local _, ns = ..."];
  if (ENGLISH.has(locale) || !from)
    lines.push(`-- (${ENGLISH.has(locale) ? "English: the words as the addon writes them" : "no translation yet: English words"}; the game's names)`);
  else {
    const meta = { ...json(join(I18N, from, "meta.json")), ...json(join(I18N, locale, "meta.json")) };
    const words: Record<string, string> = json(join(I18N, from, "words.json"));
    lines.push("ns.translate({", `  locale = ${q(locale)},`, `  plural = ${q(meta.plural ?? "one")},`);
    if (meta.decimal) lines.push(`  decimal = ${q(meta.decimal)},`);
    lines.push("  words = {");
    for (const [k, v] of Object.entries(words)
      .filter(([, v]) => v)
      .sort(([a], [b]) => a.localeCompare(b)))
      lines.push(`    [${q(k)}] = ${q(v)},`);
    lines.push("  },", "})");
  }
  lines.push(...namesLua(locale));
  return `${lines.join("\n")}\n`;
}

const args = process.argv.slice(2);
const all = keys();
if (args[0] === "--keys") {
  writeFileSync(join(I18N, "words.json"), `${JSON.stringify(Object.fromEntries(all.map((k) => [k, ""])), null, 2)}\n`);
  console.log(`✓ i18n/words.json: ${all.length} words to translate`);
  process.exit(0);
}
const check = args.includes("--check");
let bad = false;
for (const locale of LOCALES) {
  const out = join(ADDON, `Text_${locale}.lua`);
  const lua = luaFor(locale);
  if (check) {
    if ((existsSync(out) ? readFileSync(out, "utf8") : "") !== lua) {
      console.error(`✗ ${relative(ROOT, out)} is out of date: run bun run locales`);
      bad = true;
    }
  } else writeFileSync(out, lua);
  if (!existsSync(join(I18N, locale, "words.json"))) continue;
  const words: Record<string, string> = json(join(I18N, locale, "words.json"));
  const meta = json(join(I18N, locale, "meta.json"));
  const missing = all.filter((k) => !words[k]);
  const unused = Object.keys(words).filter((k) => !all.includes(k));
  console.log(`${locale}: ${all.length - missing.length}/${all.length} words${meta.flagged ? ", flagged" : ""}`);
  if (missing.length) {
    console.error(`  ✗ no translation: ${missing.join(" | ")}`);
    if (check) bad = true;
  }
  if (unused.length) console.log(`  words no longer used: ${unused.join(" | ")}`);
  for (const [english, word] of Object.entries(words)) {
    const expected = formatArgs(english);
    if (!expected.length) continue;
    const actual = formatArgs(word);
    const strayPercent = word.replace(/%%|%(?:\d+\$)?0?\d*(?:\.\d+)?[sdfi]/g, "").includes("%");
    if (expected.join() !== actual.join() || strayPercent) {
      console.error(`  ✗ format arguments differ: ${english} → ${word}`);
      bad = true;
    }
  }
  // (no semicolons in what players read, in any language: the gender token's own aside)
  for (const v of Object.values(words))
    if (v.replace(/\$g[^:;]*:[^;]*;/g, "").includes(";")) {
      console.error(`  ✗ a semicolon: ${v}`);
      bad = true;
    }
}
for (const k of all)
  if (k.includes(";")) {
    console.error(`✗ a semicolon: ${k}`);
    bad = true;
  }
if (bad) process.exit(1);
