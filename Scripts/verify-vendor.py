#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json

root=Path(__file__).resolve().parent.parent
count=0
for folder in sorted((root/"Worker/vendor").iterdir()):
    if not folder.is_dir():continue
    manifest=json.loads((folder/".cargo-checksum.json").read_text())
    for relative,expected in manifest["files"].items():
        path=folder/relative
        assert path.resolve().is_relative_to(folder.resolve()),relative
        assert hashlib.sha256(path.read_bytes()).hexdigest()==expected,str(path)
        count+=1
source=json.loads((root/"Worker/vendor/macmon/SOURCE_SHA256.json").read_text())
for relative,expected in source.items():
    path=root/"Worker/vendor/macmon"/relative
    assert hashlib.sha256(path.read_bytes()).hexdigest()==expected,str(path)
print(f"Verified {count} vendored file digests, including unchanged retained macmon library source.")
