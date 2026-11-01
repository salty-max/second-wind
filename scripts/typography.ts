/**
 * French typography in i18n/frFR/words.json, as the French client writes it
 * (the family's rule, 31 October 2026): a no-break space (U+00A0) before ":",
 * "?", "!" and a literal "%" ("%%" in a format string, or a lone "%" that
 * opens no token: "sous 35 %."). A plain space there becomes one; a game's
 * name with its own colon ("World of Warcraft: Forever") has none to change.
 * Idempotent: a second run changes nothing. addon-kit's terms.ts checks it too.
 *
 *   bun scripts/typography.ts            write it
 *   bun scripts/typography.ts --check    fail if a word has a plain space there
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const FILE = join(import.meta.dir, "..", "i18n", "frFR", "words.json");
// (a token: "%s", "%d", "%1$s", "%.1f", "%+d"... a lone "%" is literal when none of that follows: "35 %.")
const PLAIN = /[ \u202f](?=[:?!]|%%|%(?!\.\d|[-+0-9$a-zA-Z%]))/g;

const text = readFileSync(FILE, "utf8");
const words: Record<string, string> = JSON.parse(text);
// (match, not test: a global pattern's test keeps its place between words)
const wrong = Object.entries(words).filter(([, v]) => v.match(PLAIN));
if (process.argv.includes("--check")) {
  if (wrong.length) {
    for (const [k, v] of wrong) console.error(`  ${JSON.stringify(k)} → ${JSON.stringify(v)}`);
    console.error(`✗ ${wrong.length} French words with a plain space before : ? ! or %: bun scripts/typography.ts`);
    process.exit(1);
  }
  console.log("✓ French typography: a no-break space before every : ? ! and %");
} else {
  for (const k of Object.keys(words)) words[k] = words[k].replace(PLAIN, " ");
  writeFileSync(FILE, `${JSON.stringify(words, null, 2)}\n`);
  console.log(`✓ ${wrong.length} French words given a no-break space`);
}
