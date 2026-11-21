from pathlib import Path
import hashlib,json,subprocess
r=Path(__file__).resolve().parents[1]
files={}
for p in r.rglob('*'):
 rel=p.relative_to(r)
 if not p.is_file() or p.suffix in ('.pyc','.pyo') or any(part.startswith('.') or part in ('packages','__pycache__') for part in rel.parts):continue
 files[rel.as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
out=r/'packages';out.mkdir(exist_ok=True)
try:commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip()
except Exception:commit=None
(out/'source_manifest.json').write_text(json.dumps(dict(commit=commit,files=files),indent=2))
print('Source manifest:',len(files),'files')
