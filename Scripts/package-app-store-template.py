#!/usr/bin/env python3
"""Bundle reviewed source and local preview. Never produce an upload-labelled pkg."""
from pathlib import Path
import hashlib,json,shutil,subprocess,tarfile,gzip,sys
root=Path(__file__).resolve().parent.parent
preview=root/'build/store-preview/MemoriaStore.app'
subprocess.run([sys.executable,root/'Scripts/check-app-store.py','--bundle',preview],cwd=root,check=True)
validation=json.loads((root/'AppStore/Validation.json').read_text())
if validation.get('readyForAppStoreUpload') is not False:raise SystemExit('This preparation template must be explicitly marked as not upload-ready.')
kit=root/'build/Memoria-App-Store-Submission-Template'
if kit.exists():shutil.rmtree(kit)
kit.mkdir(parents=True)
shutil.copytree(root/'AppStore',kit/'Submission')
(kit/'Documentation').mkdir()
(kit/'Evidence').mkdir()
shutil.copy2(root/'Evidence/BackgroundVerification.json',kit/'Evidence/BackgroundVerification.json')
(kit/'Documentation/AppStoreRequirements.md').write_text((root/'Documentation/AppStoreRequirements.md').read_text().replace('../AppStore/','../Submission/'))
shutil.copytree(preview,kit/'LocalPreview/MemoriaStore.app')
(kit/'README.txt').write_text('Memoria App Store submission template\n\nStart with Submission/README.md and Submission/Validation.json.\n\nThis is preparation material, not an App Store upload. The local preview is ad-hoc signed, has no App Group entitlement, and has passed limited local background/UI checks, not complete acceptance. No account, signing credentials, review contact or hosted URLs are configured. One actual local overview capture is supplied for reference; final signed screenshots remain pending. No Apple archive/export is fabricated.\n\nSource.tar.gz contains the complete reviewed source snapshot, without Git metadata, build caches or local runtime evidence. Extract it and use the MemoriaStore scheme for the store edition. The direct Memoria scheme is a separate product and must not be submitted as the store edition.\n')
raw=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=root)
files=sorted(set(x.decode() for x in raw.split(b'\0') if x))
excluded={'.git','build','.build','DerivedData','target','__pycache__'}
manifest={}
with (kit/'Source.tar.gz').open('wb') as file,gzip.GzipFile(fileobj=file,mode='wb',filename='',mtime=0) as stream,tarfile.open(fileobj=stream,mode='w|') as archive:
    for relative in files:
        p=root/relative
        if any(part in excluded or part.startswith('.build-') for part in Path(relative).parts):continue
        if not p.is_file():continue
        if p.is_symlink():raise SystemExit('Unexpected source symlink')
        manifest[relative]=hashlib.sha256(p.read_bytes()).hexdigest()
        entry=archive.gettarinfo(str(p),arcname='memoria/'+relative)
        entry.uid=entry.gid=0;entry.uname=entry.gname='';entry.mtime=0
        with p.open('rb') as source:archive.addfile(entry,source)
(kit/'SourceSHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
output=root.parent/'Memoria-App-Store-Submission-Template.zip'
if output.exists():output.unlink()
subprocess.run(['/usr/bin/ditto','-c','-k','--norsrc','--noextattr','--keepParent',str(kit),str(output)],check=True)
print(json.dumps({'bundle':output.name,'bytes':output.stat().st_size,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'sourceFiles':len(manifest),'readyForAppStoreUpload':False},indent=2))
