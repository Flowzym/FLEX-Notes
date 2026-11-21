from pathlib import Path
import subprocess,zipfile,hashlib,re,struct,shutil,json,base64
import sys
abi, label = sys.argv[1:3]
app=Path('/workspace/FLEX-Notes/flutter_app/build/app/outputs/flutter-apk/app-'+abi+'-release.apk')
tools=Path('/workspace/sdk/android/build-tools/36.0.0');out=Path('/workspace/build77') / label; out.mkdir(exist_ok=True)
expected=Path('/workspace/FLEX-Notes/flutter_app/android/release-certificate.sha256').read_text().strip()
sig=subprocess.run([str(tools/'apksigner'),'verify','--verbose','--print-certs',str(app)],capture_output=True,text=True,check=True)
assert 'Signer #1 certificate SHA-256 digest: '+expected in sig.stdout
badging=subprocess.run([str(tools/'aapt2'),'dump','badging',str(app)],capture_output=True,text=True,check=True)
assert "package: name='at.flowzym.flex_notizbuch' versionCode='77' versionName='0.27.0'" in badging.stdout
assert "application-label:'FLEX'" in badging.stdout
manifest=subprocess.run([str(tools/'aapt2'),'dump','xmltree',str(app),'--file','AndroidManifest.xml'],capture_output=True,text=True,check=True)
assert 'at.flowzym.flex_notizbuch.test' not in manifest.stdout
assert 'at.flowzym.flex_notizbuch.materials' in manifest.stdout
assert 'sharedUserId' not in manifest.stdout
align=subprocess.run([str(tools/'zipalign'),'-c','-P','16','-v','4',str(app)],capture_output=True,text=True,check=True)
password=next(line.split('=',1)[1] for line in Path('/workspace/.private/flex-android-signing/signing.properties').read_text().splitlines() if line.startswith('storePassword=')).encode()
with zipfile.ZipFile(app) as z:
 assert z.testzip() is None
 names=z.namelist();assert not any(n.lower().endswith(('.p12','.keystore','.jks','signing.properties')) for n in names)
 for name in names:
  with z.open(name) as f:
   tail=b''
   while data:=f.read(1024*1024):
    part=tail+data
    assert password not in part,'Private signing data found in APK'
    tail=part[-len(password):]
 libs=[n for n in names if n.startswith('lib/') and n.endswith('.so')]
 abis=sorted({n.split('/')[1] for n in libs});assert abis==[abi]
 assert 'lib/'+abi+'/libsqlcipher.so' in names
 assert not any(n.endswith('/libsqlite3.so') for n in names)
 for name in libs:
  if name.startswith(('lib/arm64-v8a/','lib/x86_64/')):
   d=z.read(name);order='<' if d[5]==1 else '>'
   offset=struct.unpack_from(order+'Q',d,32)[0];step,count=struct.unpack_from(order+'HH',d,54)
   loads=[struct.unpack_from(order+'Q',d,offset+i*step+48)[0] for i in range(count) if struct.unpack_from(order+'I',d,offset+i*step)[0]==1]
   assert loads and min(loads)>=16384
artifact=Path('/workspace/exports/FLEX-0.27.0+77-'+label+'.apk');shutil.copyfile(app,artifact)
sha=hashlib.sha256(artifact.read_bytes()).hexdigest()
artifact.with_suffix('.apk.sha256').write_text(sha+'  '+artifact.name+'\n')
for name,data in [('signature.log',sig.stdout),('badging.log',badging.stdout),('manifest.log',manifest.stdout),('alignment.log',align.stdout)]: (out/name).write_text(data)
result={'version':'0.27.0+77','applicationId':'at.flowzym.flex_notizbuch','label':'FLEX','oldApplicationId':'at.flowzym.flex_notizbuch.test','sameStorageAsOldApp':False,'certificateSha256':expected,'artifact':artifact.name,'bytes':artifact.stat().st_size,'sha256':sha,'signature':'verified','zipIntegrity':'verified','zipAlignment16KB':'verified','elf64Alignment16KB':'verified','privateSigningDataInApk':False,'abis':abis,'deviceInstallTested':False,'sqlcipherBundled':True}
(out/'apk-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
