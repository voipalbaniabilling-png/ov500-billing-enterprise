#!/usr/bin/env python3
"""Download a pinned Billing release; prepare privately before the native installer runs."""
import argparse,hashlib,json,os,pathlib,re,shutil,ssl,stat,subprocess,sys,tarfile,tempfile,urllib.parse,urllib.request
HERE=pathlib.Path(__file__).resolve().parent
MAX_DOWNLOAD=2*1024**3
MAX_EXPANDED=8*1024**3
PINNED_PUBLISHER_KEY=b'''-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAU+SkvjdBZC6i/Kx5mMAy8zkDBQ+8YmTEoo+18stZx8c=
-----END PUBLIC KEY-----\n'''

def public_https(url):
 u=urllib.parse.urlsplit(url)
 if u.scheme!='https' or not u.hostname or u.username or u.password or u.fragment:
  raise ValueError('Release URL must be HTTPS without embedded credentials or fragment')
 return url

class HTTPSRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,req,fp,code,msg,headers,newurl):
  public_https(newurl)
  return super().redirect_request(req,fp,code,msg,headers,newurl)

def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()

def fetch(url,target):
 public_https(url)
 opener=urllib.request.build_opener(HTTPSRedirect(),urllib.request.HTTPSHandler(context=ssl.create_default_context()))
 request=urllib.request.Request(url,headers={'User-Agent':'VOIPALBANIA-Installer/1.0'})
 try:
  with opener.open(request,timeout=120) as response,target.open('xb') as output:
   public_https(response.url);total=0
   while True:
    block=response.read(1024*1024)
    if not block:break
    total+=len(block)
    if total>MAX_DOWNLOAD:raise ValueError('Release download exceeds distribution size allowance')
    output.write(block)
 except ValueError:raise
 except Exception:raise RuntimeError('Release download failed; check configured HTTPS address and network') from None

def release_url(meta, asset_override=None):
 """Resolve one immutable GitHub Release asset."""
 sha=meta.get('sha256','')
 if not isinstance(sha,str) or not re.fullmatch('[0-9a-f]{64}',sha):raise ValueError('A trusted release SHA256 is required')
 gh=meta.get('github_release')
 if not isinstance(gh,dict):raise ValueError('GitHub Release configuration is required')
 repo=gh.get('repository','');tag=gh.get('tag','');asset=asset_override or gh.get('asset','')
 if not isinstance(repo,str) or not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',repo):raise ValueError('Set github_release.repository to OWNER/REPOSITORY')
 if not isinstance(tag,str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,127}',tag):raise ValueError('Set github_release.tag to a fixed release tag')
 if not isinstance(asset,str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]{0,254}',asset) or asset in ('.','..'):raise ValueError('Set github_release.asset to a plain release filename')
 url='https://github.com/'+repo+'/releases/download/'+urllib.parse.quote(tag,safe='')+'/'+urllib.parse.quote(asset,safe='')
 return public_https(url)

def verify_signature(archive,signature,public_key=PINNED_PUBLISHER_KEY):
 archive=pathlib.Path(archive);signature=pathlib.Path(signature)
 if archive.is_symlink() or not archive.is_file() or signature.is_symlink() or not signature.is_file() or signature.stat().st_size!=64:
  raise ValueError('Invalid release signature input')
 fd,key_name=tempfile.mkstemp(prefix='ov500-publisher-',suffix='.pem');key=pathlib.Path(key_name)
 digest_fd,digest_name=tempfile.mkstemp(prefix='ov500-release-digest-');digest_file=pathlib.Path(digest_name)
 try:
  with os.fdopen(fd,'wb') as output:output.write(public_key)
  key.chmod(0o600)
  with os.fdopen(digest_fd,'wb') as output:output.write(bytes.fromhex(digest(archive)))
  digest_file.chmod(0o600)
  if not shutil.which('openssl'):raise ValueError('OpenSSL is required to authenticate releases')
  result=subprocess.run(['openssl','pkeyutl','-verify','-pubin','-inkey',str(key),'-rawin','-in',str(digest_file),'-sigfile',str(signature)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  if result.returncode:raise ValueError('Release publisher signature verification failed')
 finally:
  for path in (key,digest_file):
   try:path.unlink()
   except FileNotFoundError:pass


def unpack(archive,destination):
 # Never trust archive paths, owners, links or executable modes, even after SHA validation.
 seen=set();total=0
 with tarfile.open(archive,'r|gz') as source:
  for member in source:
   name=pathlib.PurePosixPath(member.name)
   if name.is_absolute() or '..' in name.parts or not name.parts or name.parts[0]!='voipalbania-billing-go' or '\\' in member.name:
    raise ValueError('Unsafe release archive path')
   rel=pathlib.Path(*name.parts)
   if str(rel) in seen:raise ValueError('Duplicate release archive member')
   seen.add(str(rel))
   if len(seen)>100000:raise ValueError('Too many release members')
   target=destination/rel
   if member.isdir():target.mkdir(parents=True,exist_ok=True,mode=0o755);continue
   if not member.isfile():raise ValueError('Release links/special files are not permitted')
   total+=member.size
   if total>MAX_EXPANDED:raise ValueError('Expanded release exceeds distribution size allowance')
   target.parent.mkdir(parents=True,exist_ok=True,mode=0o755)
   with source.extractfile(member) as incoming,target.open('xb') as outgoing:shutil.copyfileobj(incoming,outgoing)
   target.chmod(0o755 if member.mode&0o111 else 0o644)
 root=destination/'voipalbania-billing-go'
 # The private evidence parent stays0700; deployed source directories need traversal.
 root.chmod(0o755)
 for directory in root.rglob('*'):
  if directory.is_dir():directory.chmod(0o755)
 manifest=json.loads((root/'manifest.json').read_text())
 expected=manifest.get('files')
 if not isinstance(expected,dict) or not expected:raise ValueError('Missing release file manifest')
 actual={str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()}
 if actual!=set(expected)|{'manifest.json'}:raise ValueError('Release file inventory mismatch')
 for rel,sha in expected.items():
  if not isinstance(sha,str) or not re.fullmatch('[0-9a-f]{64}',sha) or digest(root/rel)!=sha:raise ValueError('Release file integrity mismatch')
 if not (root/'install.py').is_file():raise ValueError('Missing native installer')
 return root,len(expected)

def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--release',default=str(HERE/'release.json'),help='Pinned GitHub Release metadata and SHA256')
 ap.add_argument('--archive',help='Use an already downloaded package, with the same pinned SHA256')
 ap.add_argument('--config',help='Native root-owned mode0600 installation JSON')
 ap.add_argument('--work-dir',default='/var/lib/voipalbania-installer')
 action=ap.add_mutually_exclusive_group();action.add_argument('--prepare',action='store_true',help='Verify/extract only; do not install services or databases');action.add_argument('--apply',action='store_true');action.add_argument('--verify',action='store_true')
 ap.add_argument('--signature',help='Detached Ed25519 signature for a local --archive (defaults to ARCHIVE.sig)')
 ap.add_argument('--defer-services',action='store_true',help='Prepare an isolated/offline install without claiming systemd activation')
 a=ap.parse_args();os.umask(0o077)
 if a.defer_services and not a.apply:ap.error('--defer-services requires --apply')
 if not a.prepare and not a.config:ap.error('--config is required for plan/apply/verify; use --prepare to validate the package only')
 if a.apply and os.geteuid()!=0:raise ValueError('Root required to install')
 meta=json.loads(pathlib.Path(a.release).read_text());sha=meta.get('sha256','')
 if not isinstance(sha,str) or not re.fullmatch('[0-9a-f]{64}',sha):raise ValueError('A trusted release SHA256 is required')
 if a.signature and not a.archive:ap.error('--signature is only valid with --archive')
 url=release_url(meta) if not a.archive else None
 if a.archive and (not pathlib.Path(a.archive).is_file() or pathlib.Path(a.archive).stat().st_size>MAX_DOWNLOAD):raise ValueError('Invalid local release archive')
 work=pathlib.Path(a.work_dir)
 if work.is_symlink():raise ValueError('Private work directory required')
 work.mkdir(parents=True,exist_ok=True,mode=0o700)
 st=work.stat()
 if st.st_uid!=os.geteuid() or stat.S_IMODE(st.st_mode)&0o077:raise ValueError('Work directory must be owned by the invoking user and mode0700')
 run=pathlib.Path(tempfile.mkdtemp(prefix='release-',dir=work));archive=run/'release.tar.gz'
 print(json.dumps({'status':'preparing','evidence':str(run)}),flush=True)
 if a.archive:
  with pathlib.Path(a.archive).open('rb') as source,archive.open('xb') as target:shutil.copyfileobj(source,target)
  signature=pathlib.Path(a.signature) if a.signature else pathlib.Path(str(a.archive)+'.sig')
 else:
  signature_asset=meta.get('github_release',{}).get('signature_asset','')
  if not isinstance(signature_asset,str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]{0,254}',signature_asset) or signature_asset in ('.','..') or signature_asset==meta.get('github_release',{}).get('asset'):
   raise ValueError('Set github_release.signature_asset to a separate detached signature filename')
  fetch(url,archive)
  signature=run/'release.sig';fetch(release_url(meta,signature_asset),signature)
 verify_signature(archive,signature)
 if digest(archive)!=sha:raise ValueError('Downloaded release SHA256 mismatch; installer was not executed')
 root,count=unpack(archive,run)
 if a.prepare:print(json.dumps({'status':'prepared','files_verified':count,'release':str(root),'sha256':sha}));return
 command=[sys.executable,str(root/'install.py'),'--config',str(pathlib.Path(a.config).resolve())]
 if a.apply:command.append('--apply')
 if a.verify:command.append('--verify')
 if a.defer_services:command.append('--defer-services')
 p=subprocess.run(command,cwd=root)
 if p.returncode:raise RuntimeError('Native installer failed; preserve the private evidence directory')
 print(json.dumps({'status':'verified' if a.verify else 'installed' if a.apply else 'plan_complete','release':str(root),'files_verified':count}))

if __name__=='__main__':
 try:main()
 except Exception as e:print(json.dumps({'status':'failed','reason':str(e)}),file=sys.stderr);sys.exit(1)
