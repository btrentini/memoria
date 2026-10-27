#!/usr/bin/env python3
from pathlib import Path
import os,subprocess
root=Path(__file__).resolve().parent.parent
out=root/'build/store-preview'
developer=Path(os.environ.get('DEVELOPER_DIR','/Applications/Xcode.app/Contents/Developer'))
bin=developer/'Toolchains/XcodeDefault.xctoolchain/usr/bin'
sdk=developer/'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'
frameworks=developer/'Platforms/MacOSX.platform/Developer/Library/Frameworks'
args=[str(bin/'swiftc'),'-swift-version','6','-target','arm64-apple-macosx26.0','-sdk',str(sdk),'-module-cache-path',str(out/'module-cache'),'-I',str(out),'-I',str(root/'Sources/MemoriaStoreNative/include'),'-L',str(out),'-F',str(frameworks),'-framework','Testing','-lMemoriaStoreMetrics','-lMemoriaWidgetSupport','-lMemoriaLifecycle','-parse-as-library','-strict-concurrency=complete','-warnings-as-errors','-plugin-path',str(bin.parent/'lib/swift/host/plugins/testing'),'-Xlinker','-rpath','-Xlinker',str(out),'-Xlinker','-rpath','-Xlinker',str(frameworks)]
args += [str(p) for p in sorted((root/'Tests/MemoriaStoreTests').glob('*.swift'))]
args += [str(p) for p in sorted((root/'Tests/MemoriaLifecycleTests').glob('*.swift'))]
args += [str(root/'Scripts/TestMain.swift'),'-o',str(out/'StoreTests')]
if os.environ.get('MEMORIA_NESTED_SANDBOX')=='1':args+=['-disable-sandbox']
subprocess.run(args,cwd=root,check=True,timeout=900)
subprocess.run([str(out/'StoreTests')],cwd=root,check=True,timeout=120)
