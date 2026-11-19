"""Download the source data tools/gen_data.py reads into .source/ (git-ignored).

Run it with no arguments: python3 tools/fetch_sources.py [client build]

- Forever's game data tables (DB2) as CSV from wago.tools, for one client build (the newest
  wowf build by default).
- Efficient Games' player-recorded data (quests, NPCs, vendors, turn-ins) for every Forever build
  from github.com/JIVESCORP/eg-link-output-wowf (CC BY 4.0: the README credits it).

Files that fail to download or aren't JSON are skipped with a message; gen_data.py works with
whatever builds it finds.
"""
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".source"
EG = SOURCE / "eg"

WAGO = "https://wago.tools"
EG_API = "https://api.github.com/repos/JIVESCORP/eg-link-output-wowf/contents/data/wowf"
EG_RAW = "https://raw.githubusercontent.com/JIVESCORP/eg-link-output-wowf/main/data/wowf"

TABLES = ["ItemSparse", "ItemXItemEffect", "ItemEffect", "Spell", "SpellEffect", "SpellReagents",
          "SkillLineAbility", "SpellName"]
EG_DATASETS = ["quests.enUS", "npcs", "vendors", "turn_ins"]


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Lerep-data-tool"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def newest_build():
    builds = json.loads(get(f"{WAGO}/api/builds"))
    return max((b["version"] for b in builds.get("wowf", [])), key=lambda v: [int(x) for x in v.split(".")])


def main():
    SOURCE.mkdir(exist_ok=True)
    EG.mkdir(exist_ok=True)
    build = sys.argv[1] if len(sys.argv) > 1 else newest_build()
    print(f"Game data: build {build}")
    for table in TABLES:
        data = get(f"{WAGO}/db2/{table}/csv?build={build}")
        (SOURCE / f"{table}.csv").write_bytes(data)
        print(f"  {table}.csv ({len(data)} bytes)")
    (SOURCE / "BUILD").write_text(build + "\n")

    builds = [x["name"] for x in json.loads(get(EG_API)) if x["type"] == "dir"]
    print(f"Player data: {len(builds)} builds")
    for b in builds:
        short = b.split(".")[-1]
        for ds in EG_DATASETS:
            try:
                data = get(f"{EG_RAW}/{b}/{ds}.json")
                json.loads(data)
            except Exception as e:  # missing dataset for that build, or not JSON
                print(f"  skipped {b}/{ds}.json ({type(e).__name__})")
                continue
            (EG / f"{ds}_{short}.json").write_bytes(data)
    print("Done. Now run tools/gen_data.py.")


if __name__ == "__main__":
    main()
