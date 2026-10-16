-- Both Spanish clients, using their own TOC locale file, game names and
-- decimal separator. Run on Classic and Forever, also with LOCALE=esMX.
LOCALE = os.getenv("LOCALE") or "esES"
assert(LOCALE == "esES" or LOCALE == "esMX", "choose a Spanish locale")
local G = dofile("addon/test/game.lua")
local ns, passed = G.ns, 0
local L = ns.kit.L
local mexican = LOCALE == "esMX"
local potion = mexican and "Poción de sanación menor" or "Poción de curación menor"
local leopard = mexican and "Leopardo de las nieves" or "Leopardo de la nieve"
local stoneform = mexican and "Forma de piedra" or "Petraforma"
local function check(cond, msg, got)
  assert(cond, msg .. (not cond and got and (": got " .. tostring(got)) or ""))
  passed = passed + 1
  io.stdout:write("✓ ", msg, "\n")
end
local function section(page, title)
  for _, s in ipairs(page.sections) do
    if s.heading == title then return s end
  end
end
local function said(s)
  for _, line in ipairs(G.printed) do
    if line:find(s, 1, true) then return true end
  end
end
local function shown(s)
  for _, line in ipairs(G.shown) do
    if line:find(s, 1, true) then return true end
  end
end

G.login()
check(ns.locale == LOCALE and GetLocale() == LOCALE and L["Debriefs"] == "Informes", "the client's own Spanish file")
check(L["A word Second Wind never says"] == "A word Second Wind never says", "unknown keys retain the English fallback")
check(ns.tenths(2.5) == (mexican and "2.5" or "2,5"), "regional decimal separator, including borrowed prose")
check(
  ns.fmt(L["%s's %s"], "Mago Defias", "Bola de Fuego") == "Bola de Fuego de Mago Defias",
  "reordered spell ownership"
)
check(ns.itemNameOf(118) == potion and ns.itemNameOf(1251) == "Venda de lino", "regional item names, by id")
check(
  ns.creatureNameOf(1201) == leopard and ns.creatureIdOf("Alimaña kóbold") == 6,
  "regional creature names and reverse lookup"
)
check(
  ns.typeIdOf("Alimaña") == ns.CRITTER and ns.typeIdOf("Bestia") == 1 and ns.typeName(6) == "No-muerto",
  "client creature types, by id"
)
check(ns.date(0):find("ene", 1, true), "localized month")
for _, n in ipairs({ 0, 1, 2 }) do
  check(
    ns.kit.plural(n, "%d debrief", "%d debriefs"):format(n) == ("%d %s"):format(n, n == 1 and "informe" or "informes"),
    n .. " debriefs: the Spanish plural rule"
  )
end
ns.showWelcome()
check(
  shown("Un informe después de cada combate casi mortal o muerte.") and ns.welcome.frame:IsShown(),
  "the welcome page is rendered in Spanish"
)
if G.FOREVER then
  check(
    shown("Mantén ese aviso activado en Opciones, Combate."),
    "the Forever warning retains its required game setting"
  )
end
G.slash("help")
check(said("/wind import CODE las importa."), "command help translates explanations, preserving executable commands")

-- A real replay, followed by its card, chat link and text copy.
G.spellNamed(871, "Muro de escudo")
G.state.book = { ["Muro de escudo"] = { id = 871, cd = 1800 } }
local ready = ns.readyTools()
check(#ready == 1 and ready[1].n == "Muro de escudo" and ready[1].k == "guard", "a localized spell is found by id")
G.state.health = G.state.maxHealth
ns.setOption("threshold", 15)
G.sight("Trogg", { level = 11, type = "Humanoide" })
G.pull()
G.wait(1)
G.hit({ from = "Trogg", amount = 90 })
G.wait(1)
G.hit({ from = "Trogg", amount = 70, spell = { 9053, "Bola de Fuego", 4 }, crit = true })
G.spellNamed(6603, "Atacar")
G.wait(2)
G.leave()
local d = ns.record().debriefs[#ns.record().debriefs]
check(d and d.kind == "close", "a close call recorded")
local card = ns.cardOf(d)
check(
  card.title:find("^Combate casi mortal: ") and card.title:find("de salud$"),
  "the assembled close-call title",
  card.title
)
check(section(card, "Enemigos") and section(card, "Los golpes decisivos"), "localized report headings")
local lessons = table.concat(card.lessons, " | ")
check(
  lessons:find("No usaste Muro de escudo, aunque estaba disponible.", 1, true),
  "a confirmed unused protection",
  lessons
)
check(said("|h[Informe]|h"), "the localized debrief link in chat")
local text = ns.textOf(d)
check(
  text:find("Enemigos:", 1, true) and text:find("Recursos que tenías:", 1, true),
  "the text copy uses Spanish headings"
)
local carry = ns.carryPage(ns.carried())
check(carry.title == "Tus recursos de emergencia", "the emergency resources page")
check(section(carry, "Protecciones").lines[1] == "Muro de escudo: disponible", "a ready protection's assembled row")
G.state.bags = { [118] = { count = 2 } }
carry = ns.carryPage(ns.carried())
check(
  section(carry, "Sanación").lines[1] == potion .. " (2): disponible",
  "the bag page retains each region's item names"
)
G.state.bags = {}

-- Unknown use must remain distinct from both used and unused.
local unknown = {
  kind = "close",
  lowPct = 5,
  ready = { { n = "Muro de escudo", k = "guard" } },
  unused = {},
  untold = { "Muro de escudo" },
}
local facts = ns.factsOf(unknown)
check(#facts.untold == 1 and #facts.used == 0 and #facts.unused == 0, "unknown use stays unknown")
local had = section(ns.cardOf(unknown), "Recursos que tenías")
check(
  had.rows[1].state == "untold" and had.lines[1] == "Disponibles, uso no comprobado: Muro de escudo",
  "the Spanish card preserves uncertainty"
)
check(#ns.lessonsOf(unknown) == 0, "no missed-opportunity lesson when use is unknown")
unknown.untold = {}
had = section(ns.cardOf(unknown), "Recursos que tenías")
check(had.rows[1].state == "used" and had.lines[1] == "Usados: Muro de escudo", "confirmed use has its own heading")
unknown.unused = unknown.ready
had = section(ns.cardOf(unknown), "Recursos que tenías")
check(
  had.rows[1].state == "unused" and had.lines[1] == "Disponibles, sin usar: Muro de escudo",
  "confirmed non-use has its own heading"
)

-- Complete, partial and unmeasured control loss. No suggestion that a tool
-- could have been used when control was lost throughout the descent.
local held = {
  kind = "death",
  lowPct = 0,
  readyT = 0,
  lowT = 5,
  length = 5,
  held = { { t = 0, to = 5 } },
  ready = { { n = "Muro de escudo", k = "guard" } },
  unused = { { n = "Muro de escudo", k = "guard" } },
}
local h = ns.lessonsOf(held)
check(
  #h == 1 and h[1] == "Pérdida de control durante toda la caída de salud, hasta tu muerte.",
  "control lost until death",
  h[1]
)
had = section(ns.cardOf(held), "Recursos que tenías")
check(
  had.rows[1].state == "held" and had.lines[1] == "Disponibles, pero no podías actuar: Muro de escudo",
  "unusable tools aren't described as missed opportunities"
)
held.kind, held.lowPct, held.lowT, held.length = "close", 5, 10, 10
held.readyT, held.held = 4, { { t = 5, to = 8, what = "Aturdido", spell = "Porra" } }
held.unused, held.ready = {}, {}
h = ns.lessonsOf(held)
check(
  h[1] == "Aturdido durante tres segundos mientras tu salud bajaba hasta 5 % (Porra).",
  "partial control loss, with its cause and percentage endpoint",
  h[1]
)
held.blind = true
h = ns.lessonsOf(held)
check(
  h[1] == "Aturdido durante tres segundos del combate (Porra).",
  "unmeasured health makes no claim about a descent",
  h[1]
)
check(ns.lowOf({ lowPct = 11, lowAtEnd = true }) == "11 % o menos", "end-of-fight health stays an upper bound")
check(
  ns.lowOf({ lowPct = 20, lowRange = { 15, 25 } }) == "aproximadamente un 20 %",
  "reconstructed health stays approximate"
)

local healing = ns.cardOf({
  kind = "close",
  lowPct = 5,
  heals = { { name = "you", amount = 20 }, { name = "received", amount = 40 }, { name = "Kyle", amount = 10 } },
})
check(
  table.concat(section(healing, "Sanación").lines, " | ") == "Tuya: 20 | En total: 40 | Kyle: 10",
  "healing attribution distinguishes self, total received and named sources"
)

for _, n in ipairs({ 1, 2 }) do
  local hits = ns.cardOf({ kind = "close", lowPct = 5, foes = { { name = "Trogg", hits = n, damage = 80 } } })
  check(
    section(hits, "Enemigos").lines[1]
      == ("Trogg: %d %s con un total de 80 de daño"):format(n, n == 1 and "golpe" or "golpes"),
    n .. " hits: total damage, not damage per hit"
  )
end
local bandages = ns.carryPage({ { n = "Venda de lino", k = "bandage", wrapped = 10, left = 0 } })
check(
  section(bandages, "Vendas").lines[1] == "Venda de lino: Vendaje reciente, 10 s" and bandages.figures[2][1] == "0",
  "the named bandage lockout prevents readiness"
)
local heal = { kind = "close", lowPct = 5, unused = { { n = potion, k = "heal" } } }
check(
  ns.lessonsOf(heal)[1] == "Tenías " .. potion .. " disponible en las bolsas.",
  "a dynamic item name needs no guessed article or gender"
)
for kind, affliction in pairs({
  Poison = "veneno",
  Disease = "una enfermedad",
  Curse = "una maldición",
  Magic = "magia",
}) do
  local cure = { kind = "close", lowPct = 5, unused = { { n = "Remedio", k = "cure", against = kind } } }
  check(
    ns.lessonsOf(cure)[1] == "Tenías Remedio disponible y sufrías los efectos de " .. affliction .. ".",
    "a cure with " .. affliction
  )
end

-- Patterns and all three pull-warning paths, including deaths and low health.
local samples = {}
for i = 1, 3 do
  samples[i] = {
    kind = i == 3 and "death" or "close",
    lowPct = 5,
    startPct = 40,
    at = i,
    zone = "Dun Morogh",
    foes = { { name = "Trogg", npc = 1201, rank = "elite" } },
    unused = { { n = "Muro de escudo", k = "guard", sid = 871 } },
  }
end
local patterns = ns.patternsOf(samples, { n = 20, traits = { low = 4, elite = 3, guard = 5 } })
check(
  patterns.sub:find("2 combates casi mortales y una muerte, desde el", 1, true),
  "mixed report counts and date fit their sentence",
  patterns.sub
)
check(
  patterns.lessons[1] == "En 3 de tus 3 combates casi mortales y muertes: empezaste con menos del 60 % de salud.",
  "the pattern headline is a complete sentence",
  patterns.lessons[1]
)
check(
  section(patterns, "Lo más frecuente").lines[1]
    == "3 de 3: empezaste con menos del 60 % de salud (4 de tus 20 combates)",
  "pattern rates use the right denominator"
)
check(section(patterns, "Más veces sin usar").rows[1].detail == "sin usar en 3 de tus 3", "unused-tool pattern detail")
local counts = { total = 4, deaths = 0, traits = { elite = 3 }, foes = {} }
local warning = ns.wordBefore(counts, { name = "Guardia", rank = "elite", level = 12 }, { level = 12 })
check(
  warning == "Guardia, un enemigo de élite. De tus 4 combates casi mortales: en 3 había un enemigo de élite.",
  "the elite warning",
  warning
)
counts.deaths, counts.traits.above, counts.traits.low = 1, 2, 3
warning = ns.wordBefore(counts, { name = "Guardia", rank = "elite", level = 14 }, { level = 12, pct = 40 })
check(
  warning
    == "Guardia, un enemigo de élite dos niveles por encima del tuyo. De tus 4 combates casi mortales y muertes: en 3 había un enemigo de élite y en 2 había un enemigo que te superaba en dos niveles o más. Tienes un 40 % de salud y 3 de ellos empezaron por debajo del 60 %.",
  "combined warning, with low health and deaths",
  warning
)
counts.traits.elite, counts.traits.above, counts.foes.Guardia = nil, nil, 2
warning = ns.wordBefore(counts, { name = "Guardia", level = 12 }, { level = 12, pct = 40 })
check(
  warning
    == "En 2 de tus 4 combates casi mortales y muertes te enfrentaste a Guardia. Tienes un 40 % de salud y 3 empezaron por debajo del 60 %.",
  "a repeated enemy, with low health",
  warning
)
counts.foes = {}
warning = ns.wordBefore(counts, { name = "Guardia", level = 12 }, { level = 12, pct = 40 })
check(
  warning == "Tienes un 40 % de salud y 3 de tus 4 combates casi mortales y muertes empezaron por debajo del 60 %.",
  "the low-health-only warning",
  warning
)

-- A saved English report follows the new client's locale by id. A player's
-- name and a historical character's neutral status stay intact.
G.spellNamed(78, "Golpe heroico")
G.spellNamed(20594, stoneform)
local list = ns.record().debriefs
table.insert(list, {
  kind = "death",
  at = 7,
  lowPct = 0,
  zone = "Dun Morogh",
  zoneArea = 1,
  sub = "Coldridge Valley",
  subArea = 132,
  killer = { name = "Snow Leopard" },
  recap = { { src = "Snow Leopard", amount = 9 } },
  spells = { { src = "Snow Leopard", amount = 9 } },
  casts = { { id = 78, t = 1, name = "Heroic Strike" } },
  ready = { { n = "Stoneform", k = "guard", sid = 20594 }, { n = "Minor Healing Potion", k = "heal", item = 118 } },
  unused = { { n = "Stoneform", k = "guard", sid = 20594 } },
  foes = {
    { name = "Snow Leopard", npc = 1201, hits = 1, damage = 9, type = "Beast" },
    { name = "Kyle", player = true, hits = 1 },
  },
})
table.insert(list, { kind = "close", at = 8, zone = "Ironforge", sub = "The Library", subInside = 15660, foes = {} })
G.reload()
local old, library = list[#list - 1], list[#list]
check(
  old.foes[1].name == leopard
    and old.killer.name == leopard
    and old.recap[1].src == leopard
    and old.spells[1].src == leopard,
  "saved creature names re-localize by id"
)
check(old.foes[2].name == "Kyle", "player names are preserved")
check(
  old.sub == "Valle de Crestanevada"
    and old.casts[1].name == "Golpe heroico"
    and old.ready[1].n == stoneform
    and old.unused[1].n == stoneform,
  "saved areas, spells and tools follow the client language"
)
check(old.ready[2].n == potion, "saved items follow the regional language")
check(old.foes[1].typeId == 1 and old.foes[1].type == "Bestia", "legacy creature types recover their id")
check(library.sub == "La Biblioteca" and library.subInside == 15660, "building areas retain their ids")
check(L["fallen"] == "sin vida", "a historical character's status doesn't take the reader's gender")
G.reload()
local saved
for _, character in pairs(G.saved().characters) do
  for _, report in ipairs(character.debriefs or {}) do
    if report.at == 7 then saved = report end
  end
end
check(
  saved and saved.foes[1].npc == 1201 and saved.foes[1].name == nil and saved.foes[2].name == "Kyle",
  "the saved file keeps ids and player names"
)

-- A real diagnostic must not invent a cause for an unknown control effect.
G.state.health = G.state.maxHealth
G.slash("probe")
G.pull()
G.stun({ seconds = 2, untold = true })
G.wait(3)
G.leave()
local probe = SecondWindSettings.probes[#SecondWindSettings.probes]
check(
  table.concat(probe.lines, "\n"):find("pérdida de control: solo consta que perdiste el control", 1, true),
  "the diagnostic fallback states only what is known"
)

-- Optional readable artifacts for editorial review of complete generated text.
local output = os.getenv("SPANISH_REPORT")
if output then
  local file = assert(io.open(output, "w"))
  file:write(text, "\n\n", patterns.title, "\n", patterns.sub, "\n", table.concat(patterns.lessons, "\n"), "\n")
  for _, s in ipairs(patterns.sections) do
    file:write(s.heading, ":\n", table.concat(s.lines, "\n"), "\n")
  end
  file:write("\n", warning, "\n\n", table.concat(probe.lines, "\n"), "\n")
  file:close()
end
io.stdout:write(("%s, %s: %d checks passed\n"):format(G.FOREVER and "Forever" or "Classic Era", LOCALE, passed))
