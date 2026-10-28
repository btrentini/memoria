#!/usr/bin/env python3
"""Compile a sandboxed local preview; never call it an App Store archive/export."""
from pathlib import Path
import argparse,os,plistlib,shutil,subprocess
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--bundle-only",action="store_true",help="Repackage already compiled preview executables after resource changes");args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
out=root/'build/store-preview';out.mkdir(parents=True,exist_ok=True)
developer=Path(os.environ.get('DEVELOPER_DIR','/Applications/Xcode.app/Contents/Developer'))
bin=developer/'Toolchains/XcodeDefault.xctoolchain/usr/bin'
sdk=developer/'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'
def run(args):subprocess.run(list(map(str,args)),cwd=root,check=True,timeout=900)
if not args.bundle_only:
    run([bin/'clang','-target','arm64-apple-macosx26.0','-isysroot',sdk,'-Wall','-Wextra','-Werror','-I',root/'Sources/MemoriaStoreNative/include','-c',root/'Sources/MemoriaStoreNative/native.c','-o',out/'store-native.o'])
    flags=['-swift-version','6','-target','arm64-apple-macosx26.0','-sdk',str(sdk),'-O','-whole-module-optimization','-strict-concurrency=complete','-warnings-as-errors','-module-cache-path',str(out/'module-cache'),'-I',str(out),'-I',str(root/'Sources/MemoriaStoreNative/include'),'-L',str(out)]
    if os.environ.get('MEMORIA_NESTED_SANDBOX')=='1':flags+=['-disable-sandbox']
    for old in ['libMemoriaWidgetSupport.dylib','libMemoriaStoreMetrics.dylib']:(out/old).unlink(missing_ok=True)
    for name,extra in [('MemoriaLifecycle',['-framework','ServiceManagement']),('MemoriaWidgetSupport',['-application-extension']),('MemoriaStoreMetrics',['-I',str(root/'Sources/MemoriaStoreNative/include'),str(out/'store-native.o'),'-framework','IOKit'])]:
        run([bin/'swiftc',*flags,'-enable-testing','-parse-as-library','-emit-module','-emit-library','-static','-module-name',name,'-emit-module-path',out/(name+'.swiftmodule'),'-o',out/('lib'+name+'.a'),*extra,*sorted((root/'Sources'/name).glob('*.swift'))])
    for name,files,extra in [('MemoriaStore',[*sorted((root/'StoreApp').glob('*.swift')),root/'App/WidgetPublisher.swift',root/'App/BrandMark.swift',root/'App/MemoryUsageSummary.swift'],['-lMemoriaStoreMetrics','-lMemoriaWidgetSupport','-lMemoriaLifecycle']),('MemoriaStoreWidget',[*list((root/'Widget').glob('*.swift')),root/'App/BrandMark.swift'],['-lMemoriaWidgetSupport','-application-extension'])]:
        run([bin/'swiftc',*flags,'-parse-as-library','-module-name',name,'-Xlinker','-rpath','-Xlinker','@executable_path/../Frameworks',*extra,*files,'-o',out/name])
app=out/'MemoriaStore.app'
if app.exists():shutil.rmtree(app)
for widget in [False,True]:
    name='MemoriaStoreWidget' if widget else 'MemoriaStore';kind='Widget' if widget else 'App'
    bundle=app/'Contents/PlugIns/MemoriaStoreWidget.appex' if widget else app
    for folder in ['MacOS','Resources']:(bundle/'Contents'/folder).mkdir(parents=True,exist_ok=True)
    shutil.copy2(out/name,bundle/'Contents/MacOS'/name)
    info=plistlib.loads((root/f'AppStore/{kind}-Info.plist').read_bytes())
    replace={'$(EXECUTABLE_NAME)':name,'$(PRODUCT_NAME)':name,'$(PRODUCT_BUNDLE_IDENTIFIER)':'fyi.trentini.memoria.store'+('.widget' if widget else ''),'$(MARKETING_VERSION)':'1.0.0','$(CURRENT_PROJECT_VERSION)':'1'}
    def expand(x):
        if isinstance(x,dict):return {k:expand(v) for k,v in x.items()}
        if isinstance(x,list):return [expand(v) for v in x]
        if isinstance(x,str):
            for a,b in replace.items():x=x.replace(a,b)
        return x
    info=expand(info);info['MemoriaAppGroup']=''
    if not widget:
        info.pop('CFBundleIconName',None);info['CFBundleIconFile']='Memoria.icns';shutil.copy2(root/'Branding/Exports/Memoria-Default.icns',bundle/'Contents/Resources/Memoria.icns')
    (bundle/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    shutil.copy2(root/f'AppStore/{kind}Resources/PrivacyInfo.xcprivacy',bundle/'Contents/Resources/PrivacyInfo.xcprivacy')
    for image in (root/'App/Resources').glob('*.png'):shutil.copy2(image,bundle/'Contents/Resources'/image.name)
    if widget:
        ent=out/'preview.entitlements';ent.write_bytes(plistlib.dumps({'com.apple.security.app-sandbox':True}))
        run(['/usr/bin/codesign','--force','--sign','-','--timestamp=none','--options','runtime','--entitlements',ent,bundle])
run(['/usr/bin/codesign','--force','--sign','-','--timestamp=none','--options','runtime','--entitlements',out/'preview.entitlements',app])
run(['/usr/bin/codesign','--verify','--strict','--deep',app])
print('Sandboxed local preview built. Ad-hoc signature; App Group unavailable; not valid for App Store upload.')
