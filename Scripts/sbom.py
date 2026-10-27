#!/usr/bin/env python3
"""Generate SPDX 2.3 inventory from the offline worker lock and retained sources."""
from pathlib import Path
import hashlib
import json
import tomllib

root = Path(__file__).resolve().parent.parent
lock = tomllib.loads((root/"Worker/Cargo.lock").read_text())
inventory = {p["name"]:p for p in json.loads((root/"Documentation/vendor-inventory.json").read_text())}
packages = [{
    "SPDXID":"SPDXRef-Memoria","name":"Memoria","versionInfo":"0.1.0",
    "downloadLocation":"NOASSERTION","filesAnalyzed":False,
    "licenseConcluded":"MIT","licenseDeclared":"MIT","copyrightText":"Copyright 2026 Bruno Trentini",
    "description":"Stable Swift/C application and shared widget support module; no third-party package dependency."
},{
    "SPDXID":"SPDXRef-MemoriaWidget","name":"MemoriaWidget","versionInfo":"0.1.0",
    "downloadLocation":"NOASSERTION","filesAnalyzed":False,
    "licenseConcluded":"MIT","licenseDeclared":"MIT","copyrightText":"Copyright 2026 Bruno Trentini",
    "description":"Sandboxed WidgetKit extension; first-party aggregate snapshot support and Apple system frameworks only."
}]
relationships = [{"spdxElementId":"SPDXRef-DOCUMENT","relationshipType":"DESCRIBES","relatedSpdxElement":"SPDXRef-Memoria"}]
relationships.append({"spdxElementId":"SPDXRef-Memoria","relationshipType":"CONTAINS","relatedSpdxElement":"SPDXRef-MemoriaWidget"})
for p in lock["package"]:
    name,version=p["name"],p["version"]
    identifier="SPDXRef-"+name
    source=inventory.get(name)
    item={"SPDXID":identifier,"name":name,"versionInfo":version,"filesAnalyzed":False,
          "downloadLocation":f"https://crates.io/api/v1/crates/{name}/{version}/download" if source else "NOASSERTION",
          "licenseConcluded":"NOASSERTION","licenseDeclared":source["license"] if source else "MIT",
          "copyrightText":"NOASSERTION"}
    if source:
        item["checksums"]=[{"algorithm":"SHA256","checksumValue":source["sha256"]}]
        item["externalRefs"]=[{"referenceCategory":"PACKAGE-MANAGER","referenceType":"purl","referenceLocator":f"pkg:cargo/{name}@{version}"}]
    if name=="macmon":
        item["downloadLocation"]="git+https://github.com/vladkens/macmon.git@39e98aa73e49256e6281b2a228f6ef3499ae3209"
        item["description"]="Retained library source unchanged; unused CLI/server source omitted and manifest replaced with a library-only manifest. See Worker/MODIFICATIONS.md."
    packages.append(item)
    for dep in p.get("dependencies",[]):
        relationships.append({"spdxElementId":identifier,"relationshipType":"DEPENDS_ON","relatedSpdxElement":"SPDXRef-"+dep.split()[0]})
relationships.append({"spdxElementId":"SPDXRef-Memoria","relationshipType":"OPTIONAL_DEPENDENCY_OF","relatedSpdxElement":"SPDXRef-memoria-worker"})
# Correct direction: the worker is an optional dependency of the stable app.
relationships[-1].update(spdxElementId="SPDXRef-memoria-worker",relatedSpdxElement="SPDXRef-Memoria")
document={
    "spdxVersion":"SPDX-2.3","dataLicense":"CC0-1.0","SPDXID":"SPDXRef-DOCUMENT",
    "name":"Memoria application, widget extension and optional worker",
    "documentNamespace":"https://github.com/btrentini/memoria/sbom/0.1.0-"+hashlib.sha256((root/"Worker/Cargo.lock").read_bytes()+json.dumps(packages,sort_keys=True).encode()).hexdigest()[:16],
    "creationInfo":{"created":"2026-10-27T00:00:00Z","creators":["Tool: Memoria Scripts/sbom.py"],"comment":"Audit date; exact scan time retained in evidence. System frameworks excluded from packaged dependencies."},
    "packages":packages,"relationships":relationships
}
(root/"Documentation/SBOM.spdx.json").write_text(json.dumps(document,indent=2)+"\n")
lines=["# Third-party notices","","Only the optional worker incorporates third-party code. The stable application uses Apple system frameworks.",""]
for p in lock["package"]:
    name=p["name"]
    if name=="memoria-worker":continue
    folder=root/"Worker/vendor"/("macmon" if name=="macmon" else name+"-"+p["version"])
    licence_files=sorted(f for f in folder.iterdir() if f.is_file() and ("LICENSE" in f.name.upper() or "COPYING" in f.name.upper()))
    lines += [f"## {name} {p['version']}","",f"Declared licence: {inventory[name]['license'] if name in inventory else 'MIT'}.",""]
    for f in licence_files:
        lines += [f"Source: {f.relative_to(root)}","","    "+f.read_text().replace("\n","\n    "),""]
(root/"ThirdPartyNotices/NOTICE.md").write_text("\n".join(lines)+"\n")
print(f"SPDX inventory: {len(packages)} packages; notices retain upstream licence text.")
