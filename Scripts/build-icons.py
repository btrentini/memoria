#!/usr/bin/env python3
"""Export checked-in artwork with Apple's CoreGraphics/ImageIO; no generation API."""
from pathlib import Path
import os
import json
import shutil
import subprocess

root=Path(__file__).resolve().parent.parent
developer=Path(os.environ.get("DEVELOPER_DIR","/Applications/Xcode.app/Contents/Developer"))
output=root/"build"
output.mkdir(exist_ok=True)
subprocess.run([
    str(developer/"Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"),
    "-swift-version","6","-target","arm64-apple-macosx26.0",
    "-sdk",str(developer/"Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"),
    "-module-cache-path",os.environ.get("MEMORIA_MODULE_CACHE",str(output/"module-cache")),
    "-warnings-as-errors",str(root/"Scripts/export-icons.swift"),"-o",str(output/"export-icons")
],check=True)
subprocess.run([str(output/"export-icons"),str(root)],check=True)

# Optional conventional Xcode asset catalog. Do not add it beside the modern
# .icon in the same target: Icon Composer supersedes that app icon catalog.
catalog=root/"Branding/LegacyAssets.xcassets"
icon=catalog/"AppIcon.appiconset"
icon.mkdir(parents=True,exist_ok=True)
images=[]
for points in [16,32,128,256,512]:
    for scale in [1,2]:
        suffix="@2x" if scale==2 else ""
        name=f"icon_{points}x{points}{suffix}.png"
        shutil.copy2(root/"Branding/Exports/Memoria-Default.iconset"/name,icon/name)
        images.append({"size":f"{points}x{points}","idiom":"mac","filename":name,"scale":f"{scale}x"})
info={"version":1,"author":"Memoria"}
(catalog/"Contents.json").write_text(json.dumps({"info":info},indent=2)+"\n")
(icon/"Contents.json").write_text(json.dumps({"images":images,"info":info},indent=2)+"\n")
print("Conventional macOS asset catalog exported separately from the Icon Composer target.")
