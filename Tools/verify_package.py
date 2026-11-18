import sys,io,tarfile,subprocess,struct,hashlib,plistlib,json
from pathlib import Path

def macho(data):
 magic=struct.unpack_from('>I',data)[0]
 if magic==0xcafebabe:
  n=struct.unpack_from('>I',data,4)[0];slices=[]
  for i in range(n):
   cpu,sub,off,size,align=struct.unpack_from('>5I',data,8+i*20);slices.append((sub,data[off:off+size]))
 else:slices=[(struct.unpack_from('<I',data,8)[0],data)]
 result=[]
 for sub,b in slices:
  assert struct.unpack_from('<I',b,0)[0]==0xfeedfacf
  p=32;deps=[];cs=None;minos=None;sdk=None
  for i in range(struct.unpack_from('<I',b,16)[0]):
   cmd,n=struct.unpack_from('<II',b,p)
   if cmd in (0xc,0x80000018,0x8000001f):
    so=struct.unpack_from('<I',b,p+8)[0];deps.append(b[p+so:p+n].split(b'\0')[0].decode())
   if cmd==0x32:minos,sdk=struct.unpack_from('<II',b,p+12)
   if cmd==0x1d:cs=struct.unpack_from('<II',b,p+8)
   p+=n
  assert minos==0x100000,(minos,sdk)
  assert cs is not None
  start,size=cs;count=struct.unpack_from('>I',b,start+8)[0];pages=0
  for i in range(count):
   typ,rel=struct.unpack_from('>II',b,start+12+8*i);cd=start+rel
   if struct.unpack_from('>I',b,cd)[0]!=0xfade0c02:continue
   _,length,version,flags,hashOff,identifierOff,special,slots,limit=struct.unpack_from('>9I',b,cd)
   hashSize,hashType,platform,pageLog=struct.unpack_from('>4B',b,cd+36)
   fn={1:hashlib.sha1,2:hashlib.sha256,3:hashlib.sha256,4:hashlib.sha384}.get(hashType);assert fn
   pageSize=1<<pageLog
   for j in range(slots):
    expected=b[cd+hashOff+j*hashSize:cd+hashOff+(j+1)*hashSize];actual=fn(b[j*pageSize:min((j+1)*pageSize,limit)]).digest()[:hashSize]
    assert expected==actual,('signature',sub,j)
   pages+=slots
  assert pages>0
  assert any('libroothide.dylib' in d for d in deps),deps
  assert not any('libroot.dylib' in d and 'libroothide' not in d for d in deps)
  result.append(dict(subtype=sub,signature_pages=pages,minos=minos,sdk=sdk,dependencies=deps))
 assert {x['subtype']&0xffffff for x in result}=={0,2},result
 return result

for argument in sys.argv[1:]:
 path=Path(argument)
 if path.suffix!='.deb':continue
 control=subprocess.check_output(['dpkg-deb','-f',str(path)]).decode();assert 'Package: com.haoge.touchflow' in control
 assert 'Architecture: iphoneos-arm64e' in control
 assert 'firmware (>= 16.0)' in control and 'libroot (' not in control
 payload=subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(path)])
 with tarfile.open(fileobj=io.BytesIO(payload)) as t:
  members={m.name.removeprefix('./'):t.extractfile(m).read() for m in t if m.isfile()}
 assert not any(n.startswith('var/jb/') for n in members)
 prefix='Library/MobileSubstrate/DynamicLibraries/HaogeTouchFlow'
 filt=plistlib.loads(members[prefix+'.plist']);assert filt=={'Filter':{'Bundles':['com.apple.springboard']}}
 main=macho(members[prefix+'.dylib'])
 prefs=macho(members['Library/PreferenceBundles/HaogeTouchFlowPrefs.bundle/HaogeTouchFlowPrefs'])
 assert 'Library/PreferenceLoader/Preferences/HaogeTouchFlowPrefs.plist' in members
 for name,data in members.items():
  if name.endswith('.plist'):plistlib.loads(data)
 report=dict(package=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),main=main,prefs=prefs,files=len(members),runtime_tested=False)
 path.with_suffix('.verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
