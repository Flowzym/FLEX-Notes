"""Tag validation, temporary CI signing configuration and APK verification.

Private values are read from environment only and never included in errors,
command-line arguments, release reports or stdout. Local signing uses the
existing FLEX_SIGNING_PROPERTIES; prepare is only for GitHub Actions.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent

def run(*args):
    return subprocess.check_output(args, cwd=APP, text=True, stderr=subprocess.PIPE)

def version():
    text = (APP / 'pubspec.yaml').read_text()
    match = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)$', text, re.M)
    if not match:
        raise ValueError('pubspec version must include name and build number')
    return match.group(1), match.group(2)

def check_tag(tag):
    name, code = version()
    if tag != f'v{name}+{code}' or not re.fullmatch(r'v\d+\.\d+\.\d+\+\d+', tag):
        raise ValueError('tag must exactly match vVERSION+BUILD in pubspec.yaml')
    if run('git', 'rev-parse', f'refs/tags/{tag}^{{commit}}').strip() != run('git','rev-parse','HEAD').strip():
        raise ValueError('HEAD is not the requested tagged commit')
    if run('git','status','--porcelain','--untracked-files=no').strip():
        raise ValueError('release source contains tracked modifications')

def prepare(directory):
    names = ['FLEX_RELEASE_KEYSTORE','FLEX_RELEASE_STORE_PASSWORD','FLEX_RELEASE_KEY_PASSWORD','FLEX_RELEASE_KEY_ALIAS','FLEX_SYMBOLS_PASSWORD']
    values = {name:os.environ.get(name,'') for name in names}
    if any(not value for value in values.values()):
        raise ValueError('release signing secrets are not configured; see docs/rebuild/RELEASING.md')
    if directory.exists():
        raise ValueError('temporary signing directory already exists')
    directory.mkdir(mode=0o700, parents=True)
    key = base64.b64decode(values['FLEX_RELEASE_KEYSTORE'], validate=True)
    if not 1000 <= len(key) <= 100000:
        raise ValueError('invalid signing keystore size')
    def write(name, contents):
        target=directory/name
        with target.open('xb') as f:
            os.chmod(target,0o600);f.write(contents)
    write('release.p12',key)
    def prop(value):
        if any(ord(char)<32 for char in value):
            raise ValueError('signing configuration contains unsupported control characters')
        return value.replace('\\','\\\\').replace('=','\\=').replace(':','\\:').replace(' ','\\ ')
    properties={'storeFile':str(directory/'release.p12'),'storePassword':values['FLEX_RELEASE_STORE_PASSWORD'],'keyPassword':values['FLEX_RELEASE_KEY_PASSWORD'],'keyAlias':values['FLEX_RELEASE_KEY_ALIAS']}
    write('signing.properties','\n'.join(f'{k}={prop(v)}' for k,v in properties.items()).encode())
    write('symbols-password',values['FLEX_SYMBOLS_PASSWORD'].encode())

def verify(out):
    name, code = version()
    sdk=Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])/'build-tools'/'36.0.0'
    expected=(APP/'android/release-certificate.sha256').read_text().strip()
    out.mkdir(parents=True,exist_ok=True)
    artifacts=[]
    for abi,label in [('arm64-v8a','arm64'),('armeabi-v7a','armv7')]:
        apk=APP/f'build/app/outputs/flutter-apk/app-{abi}-release.apk'
        signature=run(str(sdk/'apksigner'),'verify','--verbose','--print-certs',str(apk))
        if f'Signer #1 certificate SHA-256 digest: {expected}' not in signature or 'Verified using v3 scheme (APK Signature Scheme v3): true' not in signature:
            raise ValueError('APK signature or permanent certificate does not match')
        badge=run(str(sdk/'aapt2'),'dump','badging',str(apk))
        if f"package: name='at.flowzym.flex_notizbuch' versionCode='{code}' versionName='{name}'" not in badge:
            raise ValueError('APK version/application identity does not match')
        run(str(sdk/'zipalign'),'-c','-P','16','4',str(apk))
        with zipfile.ZipFile(apk) as archive:
            names=archive.namelist()
            if archive.testzip() is not None or any(n.lower().endswith(('.p12','.jks','.keystore','signing.properties','.symbols')) for n in names):
                raise ValueError('APK contains corrupt or private build files')
            if f'lib/{abi}/libsqlcipher.so' not in names or any(n.endswith('/libsqlite3.so') for n in names):
                raise ValueError('encrypted database library is missing')
            if {n.split('/')[1] for n in names if n.startswith('lib/') and n.endswith('.so')} != {abi}:
                raise ValueError('unexpected APK architecture')
        target=out/f'FLEX-{name}+{code}-{label}.apk'
        shutil.copyfile(apk,target)
        digest=hashlib.sha256(target.read_bytes()).hexdigest()
        target.with_suffix('.apk.sha256').write_text(f'{digest}  {target.name}\n')
        artifacts.append({'file':target.name,'bytes':target.stat().st_size,'sha256':digest,'abi':abi})
    manifest={'version':f'{name}+{code}','commit':run('git','rev-parse','HEAD').strip(),'certificateSha256':expected,'signatureV3':True,'artifacts':artifacts}
    (out/'release-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest))

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest='action',required=True)
    sub.add_parser('check-tag').add_argument('--tag',required=True)
    sub.add_parser('prepare').add_argument('--private',required=True,type=Path)
    sub.add_parser('verify').add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    try:
        if args.action=='check-tag': check_tag(args.tag)
        elif args.action=='prepare': prepare(args.private.resolve())
        else: verify(args.out.resolve())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        # Do not print subprocess stderr: external signing tools may include paths.
        raise SystemExit(str(error) if isinstance(error,ValueError) else 'Release verification or tool execution failed.')
