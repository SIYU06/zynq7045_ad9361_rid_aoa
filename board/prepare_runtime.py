"""Create A/B runtime overlays in a fresh output directory; never installs them."""
import argparse
import subprocess
import sys
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--workspace',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
p.add_argument('--modules',type=Path)
a=p.parse_args();source=a.workspace.resolve()/'source_code'
entry=source/'reproduce/prepare_board_overlay.py'
if not entry.is_file():p.error('Prepare sources with build/prepare_sources.py first')
command=[sys.executable,'-X','utf8','-B',str(entry),'--out',str(a.out.resolve())]
if a.modules:command+=['--modules',str(a.modules.resolve())]
sys.exit(subprocess.call(command,cwd=str(source)))
