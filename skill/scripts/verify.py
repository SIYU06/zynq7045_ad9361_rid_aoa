"""Read-only checks for engineering evidence; Python 3.8+ standard library."""
import argparse
import hashlib
import json
import math
import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import unquote


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key')
        result[key] = value
    return result


def read_json(path):
    def invalid(value):
        raise ValueError('Non-finite JSON number')
    def finite_float(value):
        result = float(value)
        if not math.isfinite(result):
            raise ValueError('Non-finite JSON number')
        return result
    return json.loads(Path(path).read_text(encoding='utf-8-sig'),
                      object_pairs_hook=unique_pairs, parse_constant=invalid, parse_float=finite_float)


def compare(reference, candidate, abs_tol=0.0, rel_tol=0.0, exclude=()):
    if any(not math.isfinite(x) or x < 0 for x in (abs_tol, rel_tol)):
        raise ValueError('Tolerances must be finite and non-negative')
    if any(not x.startswith('/') for x in exclude):
        raise ValueError('Exclusions must be exact JSON pointers beginning with /')
    changes, seen = [], set()
    def pointer(path, key):
        return path + '/' + str(key).replace('~', '~0').replace('/', '~1')
    def walk(a, b, path):
        if path in exclude:
            seen.add(path)
            return
        if isinstance(a, bool) or isinstance(b, bool):
            same = type(a) is type(b) and a == b
        elif isinstance(a, (int, float)) and isinstance(b, (int, float)):
            if any(isinstance(x, float) and not math.isfinite(x) for x in (a, b)):
                raise ValueError('Non-finite numeric input')
            same = a == b if abs_tol == rel_tol == 0 else math.isclose(a, b, abs_tol=abs_tol, rel_tol=rel_tol)
        elif isinstance(a, dict) and isinstance(b, dict):
            for key in sorted(a.keys() | b.keys()):
                child = pointer(path, key)
                if child in exclude:
                    seen.add(child)
                elif key not in a or key not in b:
                    changes.append(dict(path=child, reason='missing_key'))
                else:
                    walk(a[key], b[key], child)
            return
        elif isinstance(a, list) and isinstance(b, list):
            if len(a) != len(b):
                changes.append(dict(path=path or '/', reason='list_length'))
            for index, (left, right) in enumerate(zip(a, b)):
                walk(left, right, pointer(path, index))
            return
        else:
            same = type(a) is type(b) and a == b
        if not same:
            changes.append(dict(path=path or '/', reason='value_or_type'))
    walk(reference, candidate, '')
    if set(exclude) - seen:
        raise ValueError('An excluded pointer was not present; check spelling')
    return dict(ok=not changes, difference_count=len(changes), differences=changes[:100],
                abs_tol=abs_tol, rel_tol=rel_tol, excluded=list(exclude),
                alignment='dictionary keys and ordered list positions')


def verify_manifest(manifest, root):
    root = Path(root).resolve()
    if not isinstance(manifest, dict) or manifest.get('schema') != 'evidence-manifest-v1':
        raise ValueError('Unsupported manifest schema')
    files = manifest.get('files')
    if not isinstance(files, list) or not files:
        raise ValueError('Manifest must contain at least one file')
    seen, results = set(), []
    for entry in files:
        if not isinstance(entry, dict):
            raise ValueError('Invalid manifest entry')
        rel = entry.get('path', '')
        expected = entry.get('sha256', '')
        if not isinstance(rel, str) or not rel or '\\' in rel or re.match(r'^[A-Za-z]:', rel):
            raise ValueError('Use relative POSIX paths in manifests')
        if Path(rel).is_absolute():
            raise ValueError('Absolute evidence path rejected')
        target = (root / rel).resolve()
        try:
            target.relative_to(root)
        except ValueError:
            raise ValueError('Evidence path escapes its declared root')
        if target in seen:
            raise ValueError('Duplicate evidence file')
        seen.add(target)
        if not isinstance(expected, str) or not re.fullmatch(r'[a-fA-F0-9]{64}', expected):
            raise ValueError('Invalid SHA-256')
        size = entry.get('size')
        if size is not None and (type(size) is not int or size < 0):
            raise ValueError('Invalid byte size')
        if not target.is_file():
            results.append(dict(path=rel, ok=False, reason='missing_file'))
            continue
        digest = hashlib.sha256()
        with target.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
        valid = digest.hexdigest() == expected.lower() and (size is None or target.stat().st_size == size)
        results.append(dict(path=rel, ok=valid, reason='matched' if valid else 'hash_or_size'))
    return dict(ok=all(x['ok'] for x in results), files_checked=len(results), results=results)


def parse_vivado(timing, utilization=None):
    lines = timing.splitlines()
    metrics = None
    names = ['wns_ns', 'tns_ns', 'setup_failing', 'setup_total', 'whs_ns', 'ths_ns',
             'hold_failing', 'hold_total', 'wpws_ns', 'tpws_ns', 'pulse_failing', 'pulse_total']
    for index, line in enumerate(lines):
        if not re.match(r'^\s*WNS\(ns\)\s+TNS\(ns\)', line):
            continue
        for candidate in lines[index + 1:index + 8]:
            fields = candidate.split()
            if len(fields) != 12:
                continue
            try:
                values = [float(x) for x in fields]
            except ValueError:
                continue
            if not all(math.isfinite(x) for x in values):
                raise ValueError('Non-finite timing summary')
            metrics = dict(zip(names, values))
            break
        break
    if metrics is None:
        raise ValueError('Supported 12-column design timing summary not found')
    for key in ('setup_failing', 'hold_failing', 'pulse_failing', 'setup_total', 'hold_total', 'pulse_total'):
        if metrics[key] < 0 or not metrics[key].is_integer():
            raise ValueError('Invalid endpoint count')
        metrics[key] = int(metrics[key])
    checks = {key: int(value) for key, value in re.findall(
        r'^\s*\d+\. checking (\w+) \((\d+)\)', timing, re.M)}
    passed = all(metrics[k] >= 0 for k in ('wns_ns', 'tns_ns', 'whs_ns', 'ths_ns', 'wpws_ns', 'tpws_ns'))
    passed = passed and all(metrics[k] == 0 for k in ('setup_failing', 'hold_failing', 'pulse_failing'))
    resources = {}
    if utilization is not None:
        labels = {'Slice LUTs': 'lut', 'Slice Registers': 'ff', 'Slice': 'slice',
                  'Block RAM Tile': 'bram', 'DSPs': 'dsp'}
        for line in utilization.splitlines():
            fields = [x.strip() for x in line.strip().strip('|').split('|')]
            if len(fields) == 6 and fields[0] in labels:
                used, available, percent = (float(fields[i].replace(',', '')) for i in (1, 4, 5))
                if not all(math.isfinite(x) and x >= 0 for x in (used, available, percent)):
                    raise ValueError('Invalid utilization value')
                resources[labels[fields[0]]] = dict(used=used, available=available, percent=percent)
        if not {'lut', 'ff', 'bram', 'dsp'} <= resources.keys():
            raise ValueError('Required utilization rows not found')
        passed = passed and all(x['used'] <= x['available'] for x in resources.values())
    return dict(ok=passed, timing=metrics, check_timing=checks, resources=resources,
                scope='reported constrained timing and static capacity only', board_signoff=False,
                external_io_delay_gaps={k: checks.get(k) for k in ('no_input_delay', 'no_output_delay')})


def markdown_parts(text):
    plain, fence = [], None
    for line in text.splitlines():
        marker = re.match(r'^\s*(`{3,}|~{3,})', line)
        if marker:
            token = marker[1]
            if fence is None:
                fence = token
            elif token[0] == fence[0] and len(token) >= len(fence):
                fence = None
            continue
        if fence is None:
            plain.append(line)
    anchors, counts = set(), {}
    for line in plain:
        heading = re.match(r'^#{1,6}\s+(.+)', line)
        if heading:
            title = re.sub(r'\[([^]]+)\]\([^)]+\)', r'\1', heading[1]).lower()
            base = ''.join(c for c in title if c in '-_ ' or unicodedata.category(c)[0] in 'LN').replace(' ', '-')
            count = counts.get(base, 0)
            counts[base] = count + 1
            anchors.add(base if count == 0 else base + '-' + str(count))
    return '\n'.join(plain), anchors, fence is None


def check_docs(roots):
    files = set()
    for root in roots:
        path = Path(root)
        if not path.exists():
            raise ValueError('Document input does not exist')
        files.update([path.resolve()] if path.is_file() else (p.resolve() for p in path.rglob('*.md')))
    if not files:
        raise ValueError('No Markdown files selected')
    issues, checked = [], 0
    patterns = {
        'local_user_path': r'(?i)[A-Z]:[/\\]Users[/\\][^\s/\\]+',
        'email': r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}',
        'phone': r'(?<![0-9A-Fa-f])1[3-9]\d{9}(?![0-9A-Fa-f])',
        'device_mac': r'(?i)(?:[0-9a-f]{2}:){5}[0-9a-f]{2}',
        'institution_candidate': r'[\u4e00-\u9fff]{2,}(?:大学|学院|中学)',
    }
    for path in sorted(files):
        text = path.read_text(encoding='utf-8-sig')
        plain, anchors, closed = markdown_parts(text)
        if not closed:
            issues.append(dict(file=path.name, kind='unclosed_fence'))
        for number, line in enumerate(text.splitlines(), 1):
            for kind, pattern in patterns.items():
                if re.search(pattern, line):
                    issues.append(dict(file=path.name, line=number, kind=kind))
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', plain):
            if re.match(r'^[A-Za-z][\w+.-]*:', target):
                continue
            checked += 1
            location, _, fragment = unquote(target.strip('<>')).partition('#')
            destination = (path.parent / location).resolve() if location else path
            if not destination.exists():
                issues.append(dict(file=path.name, kind='missing_link', target=target))
            elif fragment and destination.suffix.lower() == '.md':
                dest_anchors = anchors if destination == path else markdown_parts(destination.read_text(encoding='utf-8-sig'))[1]
                if fragment not in dest_anchors:
                    issues.append(dict(file=path.name, kind='missing_anchor', target=target))
    return dict(ok=not issues, documents=len(files), local_links_checked=checked, issues=issues,
                privacy_scope='heuristic candidates only; manual identity and location review remains necessary')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    p = commands.add_parser('compare')
    p.add_argument('reference'); p.add_argument('candidate')
    p.add_argument('--abs-tol', type=float, default=0.0); p.add_argument('--rel-tol', type=float, default=0.0)
    p.add_argument('--exclude', action='append', default=[])
    p = commands.add_parser('manifest')
    p.add_argument('manifest'); p.add_argument('--root', required=True)
    p = commands.add_parser('vivado')
    p.add_argument('timing'); p.add_argument('--utilization')
    p = commands.add_parser('docs')
    p.add_argument('roots', nargs='+')
    for p in commands.choices.values():
        p.add_argument('--output', help='Optional result JSON; must not overwrite an existing file')
    args = parser.parse_args(argv)
    try:
        if args.command == 'compare':
            result = compare(read_json(args.reference), read_json(args.candidate), args.abs_tol, args.rel_tol, args.exclude)
        elif args.command == 'manifest':
            result = verify_manifest(read_json(args.manifest), args.root)
        elif args.command == 'vivado':
            result = parse_vivado(Path(args.timing).read_text(encoding='utf-8-sig'),
                                  Path(args.utilization).read_text(encoding='utf-8-sig') if args.utilization else None)
        else:
            result = check_docs(args.roots)
        status = 0 if result['ok'] else 1
        if args.output:
            with Path(args.output).open('x', encoding='utf-8') as stream:
                json.dump(result, stream, ensure_ascii=False, indent=2, allow_nan=False)
    except (OSError, ValueError, TypeError, OverflowError) as error:
        result, status = dict(ok=False, error=type(error).__name__, reason=str(error)), 2
    print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
    return status


if __name__ == '__main__':
    sys.exit(main())
