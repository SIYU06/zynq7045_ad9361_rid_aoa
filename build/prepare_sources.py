"""Verify and unpack the complete source bundle into a new isolated workspace."""
import argparse
import hashlib
import json
import shutil
import tarfile
from pathlib import Path,PurePosixPath

ROOT=Path(__file__).resolve().parents[1]

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1048576),b''):h.update(chunk)
    return h.hexdigest()

def checked(spec):
    p=(ROOT/spec['path']).resolve();p.relative_to(ROOT)
    if not p.is_file() or p.stat().st_size!=spec['size'] or digest(p)!=spec['sha256']:
        raise ValueError('Bundle checksum mismatch: '+spec['path'])
    return p

def unpack(archive,destination):
    destination.mkdir(parents=True)
    with tarfile.open(archive,'r:xz') as stream:
        for member in stream:
            name=PurePosixPath(member.name)
            if name.is_absolute() or '..' in name.parts or '\\' in member.name or ':' in member.name:
                raise ValueError('Unsafe archive member')
            path=(destination/Path(*name.parts)).resolve();path.relative_to(destination.resolve())
            if member.isdir():path.mkdir(parents=True,exist_ok=True)
            elif member.isfile():
                path.parent.mkdir(parents=True,exist_ok=True)
                with stream.extractfile(member) as src,path.open('xb') as dst:shutil.copyfileobj(src,dst)
                path.chmod(member.mode & 0o777)
            else:raise ValueError('Unsupported archive member type')

def prepare(out):
    out=out.resolve()
    if out.exists():raise ValueError('Workspace already exists; choose a fresh output path')
    config=json.loads((ROOT/'src/archives.json').read_text(encoding='utf-8'))
    source=checked(config['source']);board=checked(config['board'])
    parts=[checked(part) for part in config['kernel']['parts']]
    out.mkdir(parents=True)
    unpack(source,out/'source_code');unpack(board,out/'board_support')
    target=out/'source_code'/config['kernel']['output'];target.parent.mkdir(parents=True,exist_ok=True)
    with target.open('xb') as dst:
        for part in parts:
            with part.open('rb') as src:shutil.copyfileobj(src,dst)
    if target.stat().st_size!=config['kernel']['size'] or digest(target)!=config['kernel']['sha256']:
        raise ValueError('Assembled kernel source checksum mismatch')
    manifest=json.loads((ROOT/'src/source_manifest.json').read_text(encoding='utf-8'))
    for item in manifest['files']:
        path=(out/'source_code'/item['path']).resolve();path.relative_to((out/'source_code').resolve())
        if not path.is_file() or path.stat().st_size!=item['size'] or digest(path)!=item['sha256']:
            raise ValueError('Extracted source mismatch: '+item['path'])
    result=dict(ok=True,source_files_verified=len(manifest['files'])+1,kernel_parts=len(parts),
                scope='integrity and extraction only; no build, deployment or RF validation')
    (out/'preparation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(prepare(args.out),indent=2))
