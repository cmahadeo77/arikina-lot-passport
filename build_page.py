"""Build a lot passport page from live chain data.  usage: python build_page.py [LOT_OBJECT_ID] [out.html]"""
import json, sys, urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).parent
dep = json.loads((ROOT / "deployment.json").read_text())
lot = sys.argv[1] if len(sys.argv) > 1 else dep["castor_lot"]
out = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "web" / "lot-passport.html"
q = '{ object(address:"%s"){ version asMoveObject{ contents{ json } } } }' % lot
req = urllib.request.Request(f"https://graphql.{dep['network']}.sui.io/graphql", data=json.dumps({"query": q}).encode(),
                             headers={"Content-Type": "application/json", "User-Agent": "arikina-passport"})
obj = json.load(urllib.request.urlopen(req))["data"]["object"]
meta = {"lot": lot, "network": dep["network"], "package": dep["package"],
        "snapshot_at": datetime.now(timezone.utc).isoformat()}
html = (ROOT / "web" / "template.html").read_text(encoding="utf-8")
html = html.replace("__SNAPSHOT__", json.dumps(obj)).replace("__META__", json.dumps(meta))
out.write_text(html, encoding="utf-8")
print("wrote", out)
