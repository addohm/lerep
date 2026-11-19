"""Generate Lerep/Data.lua from the source data in .source/ (get it with tools/fetch_sources.py).

Run it with no arguments: python3 tools/gen_data.py

What it writes, and where each part comes from:

- Craftsman's Writs: every "Craftsman's Writ: ..." item in the game data (ItemSparse), the quest it
  starts, and from the player-recorded quest data: the item and count the customer wants, and the
  rep it gives. The customer, where players have recorded handing one in.
- Waylaid Crates: every "Waylaid Crate: ..." item, its tier, white (raw goods) or green (crafted
  goods), level, and the bundles it accepts (from the "Stock Crate" spell: material names in its
  text, counts in its effects). The Favor each pays isn't in any data file: FAVOR below holds the
  published numbers (Artisan from player reports).
- Recipes: every profession recipe (SkillLineAbility + SpellEffect "create item" + SpellReagents)
  that makes a writ item, a bundle material, or something those are made from (3 levels deep).
- Vendor prices: what players recorded vendors charging for those materials.
- Merchant's Favor rewards: everything players recorded vendors selling for Favor.
- The camps' NPCs and their positions.
- Item names for every item the data mentions.
"""
import csv
import glob
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".source"
OUT = ROOT / "Lerep" / "Data.lua"

FAVOR_CURRENCY = 3402
FACTIONS = {"Alliance": 2586, "Horde": 2587}

# Profession skill lines -> name. Recipes are only taken from these.
PROFESSIONS = {171: "Alchemy", 164: "Blacksmithing", 185: "Cooking", 333: "Enchanting",
               202: "Engineering", 129: "First Aid", 165: "Leatherworking", 186: "Mining",
               197: "Tailoring"}

TIERS = ["Apprentice", "Journeyman", "Expert", "Artisan"]
# Favor per filled crate: (white, green) by tier. Apprentice to Expert from the published
# Merchant's Favor numbers; Artisan from players' reports. Not in the game data.
FAVOR = {"Apprentice": (5, 10), "Journeyman": (10, 20), "Expert": (15, 30), "Artisan": (20, 40)}
WRIT_TIER = {75: "Journeyman", 125: "Expert", 200: "Artisan"}
SEALED_WRITS = {262888: "Journeyman", 262889: "Expert", 262890: "Artisan"}
# Coin Pouch values are guesses from guides; Lerep records the real ones as you hand writs in.
COIN_POUCH = {"Journeyman": 3500, "Expert": 8000, "Artisan": 15200}

RECIPE_DEPTH = 3

# The Favor goals the Options picker lists: itemID -> (Favor, gold copper, standing needed, what it
# is, side or None).
# From guides and Wowhead (no vendor data yet); recorded vendor prices replace the Favor and copper.
# Standing: 5 Friendly, 6 Honored, 7 Revered, 8 Exalted; 0 = none.
GOALS = {
    262766: (6000, 0, 8, "Pack Kodo mount (needs level 60 and Journeyman Riding)", None),
    284664: (1500, 0, 7, "Minimule pet", None),
    270888: (1200, 0, 6, "Tradeskill Sign toy", "Alliance"),
    270887: (1200, 0, 6, "Tradeskill Sign toy", "Horde"),
    262765: (200, 50000, 8, "Faction tabard", "Alliance"),
    262764: (200, 50000, 8, "Faction tabard", "Horde"),
    271621: (1000, 0, 0, "Alchemy Certification title (needs skill 300)", None),
    271622: (1000, 0, 0, "Blacksmithing Certification title (needs skill 300)", None),
    271624: (1000, 0, 0, "Enchanting Certification title (needs skill 300)", None),
    271625: (1000, 0, 0, "Engineering Certification title (needs skill 300)", None),
    271626: (1000, 0, 0, "Leatherworking Certification title (needs skill 300)", None),
    271627: (1000, 0, 0, "Tailoring Certification title (needs skill 300)", None),
}


def die(msg):
    sys.exit(msg)


def table(name):
    path = SOURCE / f"{name}.csv"
    if not path.exists():
        die(f"Can't find .source/{name}.csv: run tools/fetch_sources.py first.")
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def eg(dataset, key):
    """Merge one player-recorded dataset across every build, newest last (so newest wins)."""
    files = sorted(glob.glob(str(SOURCE / "eg" / f"{dataset}_*.json")),
                   key=lambda p: int(re.search(r"_(\d+)\.json$", p).group(1)))
    if not files:
        die(f"No .source/eg/{dataset}_*.json: run tools/fetch_sources.py first.")
    merged = {}
    for path in files:
        with open(path, encoding="utf-8") as f:
            for k, v in json.load(f).get(key, {}).items():
                merged.setdefault(k, {}).update(v)
    return merged


# Vendor discount by standing with the vendor's faction (4 Neutral ... 8 Exalted).
DISCOUNT = {4: 0, 5: 0, 6: 0.10, 7: 0.15, 8: 0.20}


def full_price(costs):
    """The undiscounted copper price from a vendor entry's {standing: copper} (0 if none)."""
    best = 0
    for standing, copper in (costs or {}).items():
        d = DISCOUNT.get(int(standing))
        if d is not None and copper:
            best = max(best, round(copper / (1 - d)))
    return best


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def main():
    items = {int(r["ID"]): r for r in table("ItemSparse")}

    def name(i):
        return items[i]["Display_lang"] if i in items else None

    names_to_ids = {}
    for i, r in items.items():
        names_to_ids.setdefault(r["Display_lang"], []).append(i)

    quests = eg("quests.enUS", "quests")
    npcs = eg("npcs", "npcs")
    vendors = eg("vendors", "vendors")

    # --- Recipes: item -> the profession spells that create it.
    skill_of = {}
    for r in table("SkillLineAbility"):
        sl = int(r["SkillLine"])
        if sl in PROFESSIONS:
            skill_of[int(r["Spell"])] = PROFESSIONS[sl]
    reagents = {}
    for r in table("SpellReagents"):
        sid = int(r["SpellID"])
        lst = []
        for n in range(8):
            item, count = int(r[f"Reagent_{n}"]), int(r[f"ReagentCount_{n}"])
            if item > 0 and count > 0:
                lst.append((item, count))
        if lst:
            reagents[sid] = lst
    makers = {}
    for r in table("SpellEffect"):
        if r["Effect"] != "24":  # create item
            continue
        sid, product = int(r["SpellID"]), int(r["EffectItemType"])
        if sid in skill_of and sid in reagents and product:
            makers.setdefault(product, []).append((sid, max(1, int(float(r["EffectBasePointsF"] or 1)))))
    spell_names = {int(r["ID"]): r["Name_lang"] for r in table("SpellName")} if (SOURCE / "SpellName.csv").exists() else {}

    # --- Crates and their bundles.
    effect_spell = {int(r["ID"]): int(r["SpellID"]) for r in table("ItemEffect")}
    item_spells = {}
    for r in table("ItemXItemEffect"):
        item_spells.setdefault(int(r["ItemID"]), []).append(effect_spell.get(int(r["ItemEffectID"])))
    spells = {int(r["ID"]): r for r in table("Spell")}
    effects = {}
    for r in table("SpellEffect"):
        effects.setdefault(int(r["SpellID"]), {})[int(r["EffectIndex"])] = r

    vendor_items = set()
    for v in vendors.values():
        for e in v.get("entries", {}).values():
            if "itemId" in e:
                vendor_items.add(e["itemId"])

    used_in_recipes = {m for lst in reagents.values() for m, _ in lst}

    def material_id(mat_name):
        ids = names_to_ids.get(mat_name, [])
        if not ids:
            die(f"No item called {mat_name!r} in ItemSparse")
        # Some names have old duplicates (Dark Iron Ore: 11099 and 11370). Prefer the item a recipe
        # makes or uses, or a vendor sells; else the lowest ID.
        live = [i for i in sorted(ids) if i in makers or i in used_in_recipes or i in vendor_items]
        if len(live) > 1:
            print(f"  note: {mat_name!r} could be {live}; using {live[0]}")
        return (live or sorted(ids))[0]

    crates = {}
    for i, r in items.items():
        n = r["Display_lang"]
        if not n.startswith("Waylaid Crate: "):
            continue
        label = n[len("Waylaid Crate: "):]
        tier = next((t for t in TIERS if t in label.split()), None)
        if not tier:
            die(f"Can't tell the tier of {n!r}")
        green = r["OverallQualityID"] == "2"
        bundles = []
        for sid in item_spells.get(i, []):
            desc = spells.get(sid, {}).get("Description_lang", "")
            for m in re.finditer(r"\$M(\d+) ([^\r\n|]+)", desc):
                idx = int(m.group(1)) - 1
                count = int(float(effects[sid][idx]["EffectBasePointsF"]))
                bundles.append((material_id(m.group(2).strip()), count))
        if not bundles:
            die(f"No bundles found for {n!r}")
        crates[i] = {"label": label, "tier": tier, "green": green,
                     "level": int(r["RequiredLevel"]), "favor": FAVOR[tier][1 if green else 0],
                     "bundles": bundles}

    # --- Sealed (filled) crates and the quest that hands each in: Lerep records the Favor it pays.
    sealed = {}
    for qid, q in quests.items():
        if q.get("title") != "A Sealed Crate":
            continue
        for o in q.get("objectives", []):
            r = items.get(o.get("objectId"))
            if o.get("type") == "item" and r and r["Display_lang"].startswith("Sealed "):
                tier = next((t for t in TIERS if t in r["Display_lang"]), None)
                if tier and r["OverallQualityID"] in ("1", "2"):
                    sealed[int(qid)] = (o["objectId"], tier, r["OverallQualityID"] == "2")

    # --- Writs.
    takers = {}
    for nid, v in npcs.items():
        for q in v.get("takes", {}):
            takers.setdefault(int(q), (int(nid), v))
    writs = {}
    for i, r in items.items():
        if not r["Display_lang"].startswith("Craftsman's Writ: "):
            continue
        qid = int(r["StartQuestID"])
        q = quests.get(str(qid))
        if not q:
            die(f"No quest data for {r['Display_lang']!r} (quest {qid})")
        wanted = [o for o in q.get("objectives", []) if o.get("type") == "item" and o["objectId"] != i]
        if len(wanted) != 1:
            die(f"{r['Display_lang']!r}: expected one item objective, got {wanted}")
        rep = {x["factionId"]: x.get("override", 0) // 100 for x in q.get("rewards", {}).get("reputation", [])}
        amount = rep.get(FACTIONS["Alliance"]) or rep.get(FACTIONS["Horde"])
        if amount not in WRIT_TIER:
            die(f"{r['Display_lang']!r}: unexpected rep {amount}")
        w = {"quest": qid, "item": wanted[0]["objectId"], "count": wanted[0]["amount"], "rep": amount,
             "tier": WRIT_TIER[amount]}
        if qid in takers:
            nid, v = takers[qid]
            pos = (v.get("positions") or [{}])[0]
            w["customer"] = (v["name"], pos.get("uiMap"), pos.get("mapX"), pos.get("mapY"))
        writs[i] = w

    # --- Recipes for writ items and bundle materials, and what they're made from.
    wanted = {w["item"] for w in writs.values()} | {m for c in crates.values() for m, _ in c["bundles"]}
    recipes, frontier, seen = {}, set(wanted), set()
    for _ in range(RECIPE_DEPTH):
        nxt = set()
        for item in frontier - seen:
            seen.add(item)
            for sid, yield_ in makers.get(item, []):
                recipes[sid] = {"name": spell_names.get(sid) or name(item), "profession": skill_of[sid],
                                "product": item, "yield": yield_, "reagents": reagents[sid]}
                nxt.update(m for m, _ in reagents[sid])
        frontier = nxt
    materials = set(wanted) | {m for rc in recipes.values() for m, _ in rc["reagents"]} | set(seen)

    # --- Vendor prices for those materials (the lowest recorded), and Favor rewards.
    vendor_prices, rewards = {}, {}
    for v in vendors.values():
        for e in v.get("entries", {}).values():
            item = e.get("itemId")
            if not item:
                continue
            # Limited-stock items are left out: a plan can't count on buying them.
            copper = full_price(e.get("costs"))
            if item in materials and copper and not e.get("costItems") and not e.get("limited"):
                per = copper / max(1, e.get("stack", 1))
                vendor_prices[item] = min(vendor_prices.get(item, per), per)
            for c in e.get("costItems", []):
                if c.get("currencyId") == FAVOR_CURRENCY:
                    rewards[item] = (c["amount"], full_price(e.get("costs")))

    # --- The camps.
    def npc(npc_id, fallback_name):
        v = npcs.get(str(npc_id), {})
        pos = (v.get("positions") or [{}])[0]
        return (v.get("name", fallback_name), pos.get("uiMap"), pos.get("mapX"), pos.get("mapY"))

    camps = {
        "Alliance": {"faction": 2586, "factionName": "Azeroth Commerce Authority",
                     "place": "Three Corners, Redridge Mountains", "label": (280179, 98247),
                     "intake": npc(256390, "Marcy Baker"), "scribe": npc(256742, "Dianne Softstep")},
        "Horde": {"faction": 2587, "factionName": "Durotar Supply and Logistics",
                  "place": "west of the Crossroads, the Barrens", "label": (280180, 98248),
                  "intake": npc(256386, "Dokimi"), "scribe": npc(256672, "Kurvelk Shadowhoof")},
    }

    # --- Names for every item mentioned.
    mentioned = set(materials) | set(writs) | set(crates) | set(rewards) | set(SEALED_WRITS)
    mentioned |= {262902, 262917, 248549, 280179, 280180} | {v[0] for v in sealed.values()}
    mentioned |= {p for rc in recipes.values() for p in [rc["product"]]}
    item_names = {i: name(i) for i in mentioned if name(i)}

    goals = {}
    for i, (favor, copper, standing, what, side) in GOALS.items():
        if i in rewards:
            favor, copper = rewards[i]
        goals[i] = (favor, copper, standing, what, side)
    item_names.update({i: name(i) for i in goals if name(i)})

    write(writs, crates, sealed, recipes, vendor_prices, rewards, goals, camps, item_names)
    print(f"Wrote {OUT.relative_to(ROOT)}: {len(writs)} writs, {len(crates)} crates, {len(recipes)} recipes, "
          f"{len(vendor_prices)} vendor prices, {len(rewards)} Favor rewards, {len(item_names)} item names")


def num(x):
    if x is None:
        return "nil"
    if isinstance(x, float):
        return f"{x:.4f}".rstrip("0").rstrip(".")
    return str(x)


def pos_lua(t):
    n, m, x, y = t
    return f"{{ name = {lua_str(n)}, map = {num(m)}, x = {num(x)}, y = {num(y)} }}"


def pairs_lua(lst):
    return "{ " + ", ".join(f"{{ {a}, {b} }}" for a, b in lst) + " }"


def write(writs, crates, sealed, recipes, vendor_prices, rewards, goals, camps, item_names):
    build = (SOURCE / "BUILD").read_text().strip() if (SOURCE / "BUILD").exists() else "?"
    L = []
    w = L.append
    w("-- Lerep's data. Generated by tools/gen_data.py: don't edit by hand, run the script again.")
    w(f"-- Game data from Forever build {build}; quest, NPC and vendor data from Efficient Games")
    w("-- (https://efficient.games), licensed under CC BY 4.0.")
    w("local _, ns = ...")
    w("")
    w("ns.data = {}")
    w("local D = ns.data")
    w("")
    w(f'D.build = "{build}"')
    w(f"D.favorCurrency = {FAVOR_CURRENCY}")
    w("")
    w("-- Your side's trade faction and its camp: intake (crates, Crate Return, the Shipping Label) and")
    w("-- the scribe who sells Forged Delivery Receipts.")
    w("D.camps = {")
    for side, c in camps.items():
        w(f"\t{side} = {{ faction = {c['faction']}, factionName = {lua_str(c['factionName'])}, place = {lua_str(c['place'])},")
        w(f"\t\tlabelItem = {c['label'][0]}, labelQuest = {c['label'][1]},")
        w(f"\t\tintake = {pos_lua(c['intake'])},")
        w(f"\t\tscribe = {pos_lua(c['scribe'])} }},")
    w("}")
    w("")
    w("-- Rep and Favor rules. receipt*: the guide numbers until Lerep records the real ones.")
    w("D.labelRep, D.labelFavor = 2000, 50")
    w("D.receipt = { item = 262902, favor = 15, standing = 5, rep = 50, container = 262917 } -- standing 5 = Friendly")
    w("D.genericCrate = 248549 -- an unread Waylaid Crate: reading its label turns it into a typed one")
    w("D.coinPouch = { " + ", ".join(f"{t} = {v}" for t, v in COIN_POUCH.items()) + " } -- copper, guesses")
    w("D.sealedWrits = { " + ", ".join(f"[{i}] = \"{t}\"" for i, t in SEALED_WRITS.items()) + " }")
    w("")
    w("-- itemID = { quest, item (what the customer wants), count, rep, tier, customer = {...} if known }")
    w("D.writs = {")
    for i in sorted(writs):
        x = writs[i]
        cust = f", customer = {pos_lua(x['customer'])}" if "customer" in x else ""
        w(f"\t[{i}] = {{ quest = {x['quest']}, item = {x['item']}, count = {x['count']}, rep = {x['rep']}, tier = \"{x['tier']}\"{cust} }},")
    w("}")
    w("")
    w("-- itemID = { label, tier, green (crafted goods), level, favor, bundles = { { itemID, count } } }")
    w("-- Any one bundle fills the crate.")
    w("D.crates = {")
    for i in sorted(crates):
        c = crates[i]
        w(f"\t[{i}] = {{ label = {lua_str(c['label'])}, tier = \"{c['tier']}\", green = {str(c['green']).lower()}, "
          f"level = {c['level']}, favor = {c['favor']}, bundles = {pairs_lua(c['bundles'])} }},")
    w("}")
    w("")
    w("-- The quests that hand in a filled crate: questID = { sealed crate item, tier, green }")
    w("D.sealedCrates = {")
    for q in sorted(sealed):
        i, t, g = sealed[q]
        w(f"\t[{q}] = {{ item = {i}, tier = \"{t}\", green = {str(g).lower()} }},")
    w("}")
    w("")
    w("-- recipeSpellID = { name, profession, product, yield, reagents = { { itemID, count } } }")
    w("D.recipes = {")
    for sid in sorted(recipes):
        r = recipes[sid]
        w(f"\t[{sid}] = {{ name = {lua_str(r['name'])}, profession = \"{r['profession']}\", product = {r['product']}, "
          f"yield = {r['yield']}, reagents = {pairs_lua(r['reagents'])} }},")
    w("}")
    w("")
    w("-- itemID = copper each, at vendors")
    w("D.vendorPrices = {")
    for i in sorted(vendor_prices):
        w(f"\t[{i}] = {num(round(vendor_prices[i], 2))},")
    w("}")
    w("")
    w("-- itemID = { favor, copper } sold for Merchant's Favor (rank gates aren't recorded)")
    w("D.rewards = {")
    for i in sorted(rewards):
        f, c = rewards[i]
        w(f"\t[{i}] = {{ {f}, {c} }},")
    w("}")
    w("")
    w("-- The Favor goals Options lists: itemID = { favor, copper, standing needed (0 none), what it is,")
    w("-- side (nil: both) }")
    w("D.goals = {")
    for i in sorted(goals):
        f, c, st, what, side = goals[i]
        side_lua = f'"{side}"' if side else "nil"
        w(f"\t[{i}] = {{ {f}, {c}, {st}, {lua_str(what)}, {side_lua} }},")
    w("}")
    w("")
    w("D.itemNames = {")
    for i in sorted(item_names):
        w(f"\t[{i}] = {lua_str(item_names[i])},")
    w("}")
    OUT.write_text("\n".join(L) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
