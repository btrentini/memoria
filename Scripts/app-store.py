#!/usr/bin/env python3
"""Future local archive/export workflow. Never upload or submit automatically."""
from pathlib import Path
import argparse,os,plistlib,re,subprocess,sys
root=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('action',choices=['check','preview','archive','export'])
parser.add_argument('--team',help='Apple Developer Team ID (public identifier, not a credential)')
parser.add_argument('--version',default='1.0.0');parser.add_argument('--build',default='1')
parser.add_argument('--allow-provisioning-updates',action='store_true',help='Explicitly allow Xcode to contact your configured developer account')
args=parser.parse_args()
def run(command):subprocess.run(list(map(str,command)),cwd=root,check=True)
run([sys.executable,root/'Scripts/check-app-store.py'])
if args.action=='check':raise SystemExit(0)
if args.action=='preview':
    run([sys.executable,root/'Scripts/build-app-store-preview.py']);raise SystemExit(0)
if not args.team or not re.fullmatch('[A-Z0-9]{10}',args.team):parser.error('Set --team to your real 10-character Apple Developer Team ID; no team is configured in this template.')
if not re.fullmatch(r'\d+\.\d+\.\d+',args.version) or not re.fullmatch(r'[1-9]\d*',args.build):parser.error('Use version Major.Minor.Patch and a positive monotonically increasing build number.')
out=root/'build/app-store';out.mkdir(parents=True,exist_ok=True)
archive=out/f'Memoria-{args.version}-{args.build}.xcarchive'
xcode=Path(os.environ.get('DEVELOPER_DIR','/Applications/Xcode.app/Contents/Developer'))/'usr/bin/xcodebuild'
provisioning=['-allowProvisioningUpdates'] if args.allow_provisioning_updates else []
if args.action=='archive':
    if archive.exists():parser.error('Archive already exists. Review it or choose a new build number; archives are not overwritten.')
    run([xcode,'-project',root/'Memoria.xcodeproj','-scheme','MemoriaStore','-configuration','Release','-destination','generic/platform=macOS','-derivedDataPath',out/'DerivedData','-archivePath',archive,'archive',f'DEVELOPMENT_TEAM={args.team}',f'MARKETING_VERSION={args.version}',f'CURRENT_PROJECT_VERSION={args.build}','CODE_SIGN_STYLE=Automatic',*provisioning])
    run([sys.executable,root/'Scripts/check-app-store.py','--bundle',archive/'Products/Applications/MemoriaStore.app'])
else:
    if not (archive/'Info.plist').is_file():parser.error('Create a real Xcode archive first; the local preview is not an archive.')
    run([sys.executable,root/'Scripts/check-app-store.py','--bundle',archive/'Products/Applications/MemoriaStore.app'])
    options={'method':'app-store-connect','destination':'export','teamID':args.team,'signingStyle':'automatic','manageAppVersionAndBuildNumber':False,'stripSwiftSymbols':True,'uploadSymbols':True}
    path=out/'ExportOptions.plist';path.write_bytes(plistlib.dumps(options))
    destination=out/f'Export-{args.version}-{args.build}'
    if destination.exists():parser.error('Export directory already exists. Review it or choose a new build number.')
    run([xcode,'-exportArchive','-archivePath',archive,'-exportPath',destination,'-exportOptionsPlist',path,*provisioning])
print('Local preparation completed. Validate the signed export in Xcode and complete the submission checklist. No upload was requested.')
