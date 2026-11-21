import sys,io,tarfile,subprocess,struct,hashlib,plistlib,json
from pathlib import Path

MACHO_MAGICS = {bytes.fromhex(h) for h in (
 'cffaedfe','feedfacf','cefaedfe','feedface',
 'cafebabe','bebafeca','cafebabf','bfbafeca')}

def require_arm64e_header(data):
 assert len(data)>=32,'truncated Mach-O header'
 magic,cpu,sub=struct.unpack_from('<III',data)
 assert magic==0xfeedfacf,'require thin little-endian Mach-O 64 (not FAT)'
 assert cpu==0x0100000c,('require ARM64 CPU',hex(cpu))
 assert sub==0x80000002,('require modern arm64e subtype',hex(sub))
 return sub

def macho(data):
 sub=require_arm64e_header(data)
 slices=[(sub,data)]
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
 assert len(result)==1 and result[0]['subtype']==0x80000002,result
 return result

def verify_package(path):
 path=Path(path)
 assert path.suffix=='.deb',path
 control=subprocess.check_output(['dpkg-deb','-f',str(path)]).decode();assert 'Package: com.haoge.touchflow' in control
 assert 'Architecture: iphoneos-arm64e' in control
 assert any(line.startswith('Description:') and '64e单架构' in line for line in control.splitlines()),'single-architecture label missing'
 assert 'firmware (>= 16.0)' in control and 'libroot (' not in control
 payload=subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(path)])
 with tarfile.open(fileobj=io.BytesIO(payload)) as t:
  members={m.name.removeprefix('./'):t.extractfile(m).read() for m in t if m.isfile()}
 assert not any(n.startswith('var/jb/') for n in members)
 prefix='Library/MobileSubstrate/DynamicLibraries/HaogeTouchFlow'
 filt=plistlib.loads(members[prefix+'.plist']);assert filt=={'Filter':{'Bundles':['com.apple.springboard']}}
 prefs_path='Library/PreferenceBundles/HaogeTouchFlowPrefs.bundle/HaogeTouchFlowPrefs'
 detected={n for n,b in members.items() if b[:4] in MACHO_MAGICS}
 assert detected=={prefix+'.dylib',prefs_path},('unexpected Mach-O payload',detected)
 for name in detected:require_arm64e_header(members[name])
 main=macho(members[prefix+'.dylib'])
 prefs=macho(members[prefs_path])
 assert 'Library/PreferenceLoader/Preferences/HaogeTouchFlowPrefs.plist' in members
 for name,data in members.items():
  if name.endswith('.plist'):plistlib.loads(data)
 report=dict(package=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),main=main,prefs=prefs,files=len(members),architecture='arm64e',binary_format='thin',mach_o_paths=sorted(detected),runtime_tested=False)
 path.with_suffix('.verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
 return report

if __name__=='__main__':
 for argument in sys.argv[1:]:
  if Path(argument).suffix=='.deb':verify_package(argument)
