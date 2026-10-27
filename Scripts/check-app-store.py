#!/usr/bin/env python3
"""Check source target isolation; optionally audit a locally built store bundle."""
from pathlib import Path
import argparse,json,plistlib,re,subprocess
root=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser();parser.add_argument('--bundle',type=Path);parser.add_argument('--distribution',action='store_true');args=parser.parse_args()
issues=[];checks=[]
def require(value,message):
    (checks if value else issues).append(message)
def plist(path):return plistlib.loads(path.read_bytes())
for kind in ['App','Widget']:
    ent=plist(root/f'AppStore/{kind}.entitlements')
    require(ent.get('com.apple.security.app-sandbox') is True,f'{kind}: App Sandbox enabled')
    require(set(ent)=={'com.apple.security.app-sandbox','com.apple.security.application-groups'},f'{kind}: only sandbox and App Group entitlements')
    require(ent['com.apple.security.application-groups']==['$(TeamIdentifierPrefix)fyi.trentini.memoria.store.shared'],f'{kind}: isolated store App Group')
    privacy=plist(root/f'AppStore/{kind}Resources/PrivacyInfo.xcprivacy')
    require(not privacy['NSPrivacyTracking'] and not privacy['NSPrivacyCollectedDataTypes'] and not privacy['NSPrivacyTrackingDomains'],f'{kind}: no tracking or collected data declared')
    reasons={x['NSPrivacyAccessedAPIType']:x['NSPrivacyAccessedAPITypeReasons'] for x in privacy['NSPrivacyAccessedAPITypes']}
    require(reasons.get('NSPrivacyAccessedAPICategoryFileTimestamp')==['C617.1'],f'{kind}: cache metadata reason present')
    if kind=='App':
        require(reasons.get('NSPrivacyAccessedAPICategorySystemBootTime')==['35F9.1'] and reasons.get('NSPrivacyAccessedAPICategoryUserDefaults')==['CA92.1'],'App: timing and own-settings reasons present')
project=json.loads(subprocess.check_output(['/usr/bin/plutil','-convert','json','-o','-',str(root/'Memoria.xcodeproj/project.pbxproj')]))['objects']
targets={x.get('name'):x for x in project.values() if x.get('isa')=='PBXNativeTarget'}
for name,allowed in [('MemoriaStore',{'MemoriaStoreMetrics','MemoriaWidgetSupport','MemoriaLifecycle'}),('MemoriaStoreWidget',{'MemoriaWidgetSupport'})]:
    target=targets[name]
    deps={project[x]['productName'] for x in target['packageProductDependencies']}
    require(deps==allowed,name+': isolated library graph')
    dependencies=[project[project[x]['target']]['name'] for x in target['dependencies']]
    require(dependencies==(['MemoriaStoreWidget'] if name=='MemoriaStore' else []),name+': no helper target dependency')
    for config in project[target['buildConfigurationList']]['buildConfigurations']:
        settings=project[config]['buildSettings']
        require(settings['ENABLE_APP_SANDBOX']=='YES' and settings['ENABLE_HARDENED_RUNTIME']=='YES',name+': sandbox and hardened runtime in '+project[config]['name'])
    require(all('Helper' not in project[x].get('name','') for x in target['buildPhases']),name+': no helper embedding')
for field,limit in [('name',30),('subtitle',30),('promotional-text',170),('description',4000)]:
    value=(root/f'AppStore/Metadata/en-GB/{field}.txt').read_text().strip()
    require(0<len(value)<=limit,field+': metadata length')
keywords=(root/'AppStore/Metadata/en-GB/keywords.txt').read_text().strip()
require(len(keywords.encode())<=100,'keywords: byte limit')
if args.bundle:
    bundle=args.bundle.resolve()
    info=plist(bundle/'Contents/Info.plist')
    require(info.get('LSUIElement') is True,'Bundle: menu-bar agent by default')
    require(info['CFBundleIdentifier']=='fyi.trentini.memoria.store','Bundle: correct identifier')
    require(not (bundle/'Contents/Library/LaunchDaemons').exists(),'Bundle: no LaunchDaemon')
    require(not any('helper' in p.name.lower() or 'worker' in p.name.lower() for p in bundle.rglob('*')),'Bundle: no helper/worker files')
    forbidden=re.compile(r'\b_(?:proc_pidinfo|proc_pidpath|proc_pid_rusage|proc_listallpids|kill|system|popen|AuthorizationCreate|IOReport\w*|SMC\w*)\b|MemoriaServices|MemoriaCollectors|MemoriaCore')
    binaries=[]
    for p in bundle.rglob('*'):
        if p.is_file() and (p.parent.name=='MacOS' or p.suffix=='.dylib'):binaries.append(p)
    for p in binaries:
        symbols=subprocess.check_output(['/usr/bin/nm','-u',str(p)],stderr=subprocess.DEVNULL,text=True)
        require(not forbidden.search(symbols),'Symbols: public monitoring boundary for '+p.name)
    for nested in [bundle,*bundle.glob('Contents/PlugIns/*.appex')]:
        require((nested/'Contents/Resources/PrivacyInfo.xcprivacy').is_file(),'Bundle: privacy manifest in '+nested.name)
        result=subprocess.run(['/usr/bin/codesign','--verify','--strict',str(nested)],capture_output=True)
        require(result.returncode==0,'Bundle: signature integrity for '+nested.name)
        result=subprocess.run(['/usr/bin/codesign','-d','--entitlements',':-',str(nested)],capture_output=True)
        ent=plistlib.loads(result.stdout) if result.returncode==0 else {}
        require(ent.get('com.apple.security.app-sandbox') is True,'Bundle: signed sandbox entitlement for '+nested.name)
        if args.distribution:
            signature=subprocess.run(['/usr/bin/codesign','-d','--verbose=4',str(nested)],capture_output=True,text=True).stderr
            require('Authority=Apple Distribution:' in signature or 'Authority=3rd Party Mac Developer Application:' in signature,'Distribution: App Store certificate for '+nested.name)
            trusted=subprocess.run(['/usr/bin/codesign','--verify','--strict','-R','anchor apple generic',str(nested)],capture_output=True)
            require(trusted.returncode==0,'Distribution: Apple signing anchor for '+nested.name)
            nested_info=plist(nested/'Contents/Info.plist')
            group=nested_info.get('MemoriaAppGroup','')
            require(bool(re.fullmatch(r'[A-Z0-9]{10}\.fyi\.trentini\.memoria\.store\.shared',group)) and ent.get('com.apple.security.application-groups')==[group],'Distribution: provisioned matching App Group for '+nested.name)
            require((nested/'Contents/embedded.provisionprofile').is_file(),'Distribution: embedded provisioning profile for '+nested.name)

        require(not any(ent.get(k) for k in ['com.apple.security.cs.disable-library-validation','com.apple.security.temporary-exception.mach-lookup.global-name']) and (not args.distribution or not ent.get('com.apple.security.get-task-allow')),'Bundle: no debug/temporary exception entitlements for '+nested.name)
print(json.dumps({'checksPassed':len(checks),'issues':issues,'scope':'Static isolation and local bundle integrity; not App Review or runtime acceptance.'},indent=2))
raise SystemExit(1 if issues else 0)
