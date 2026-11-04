"""Behavioral regression checks using temporary, synthetic evidence only."""
import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import verify


TIMING = '''Design Timing Summary
 WNS(ns) TNS(ns) TNS Failing Endpoints TNS Total Endpoints WHS(ns) THS(ns) THS Failing Endpoints THS Total Endpoints WPWS(ns) TPWS(ns) TPWS Failing Endpoints TPWS Total Endpoints
 ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------
 0.559 0.000 0 1000 0.053 0.000 0 1000 0.264 0.000 0 400
1. checking no_input_delay (15)
2. checking no_output_delay (13)
'''
UTIL = '''
| Slice LUTs | 40487 | 0 | 0 | 218600 | 18.52 |
| Slice Registers | 54571 | 0 | 0 | 437200 | 12.48 |
| Slice | 17104 | 0 | 0 | 54650 | 31.30 |
| Block RAM Tile | 161 | 0 | 0 | 545 | 29.54 |
| DSPs | 154 | 0 | 0 | 900 | 17.11 |
'''


class Checks(unittest.TestCase):
    def test_compare_nested_tolerance(self):
        self.assertTrue(verify.compare({'rows': [None, True, 0.5]}, {'rows': [None, True, 0.50001]}, 0.00002)['ok'])
        self.assertFalse(verify.compare([0.5], [0.51], 0.00002)['ok'])

    def test_compare_structure_and_types(self):
        for a, b in [({'x': 0}, {}), ([1], [1, 2]), (True, 1), (None, 0), ('1', 1), ([1, 2], [2, 1])]:
            with self.subTest(a=a, b=b):
                self.assertFalse(verify.compare(a, b)['ok'])

    def test_compare_large_integer_exactness(self):
        a = 10 ** 400
        self.assertTrue(verify.compare(a, a)['ok'])
        self.assertFalse(verify.compare(a, a + 1)['ok'])

    def test_compare_exclusions_are_explicit(self):
        self.assertTrue(verify.compare({'a/b': 1}, {'a/b': 2}, exclude=['/a~1b'])['ok'])
        with self.assertRaises(ValueError):
            verify.compare({'x': 1}, {'x': 1}, exclude=['/typo'])

    def test_compare_invalid_tolerance_and_numbers(self):
        for tolerance in [-1, float('inf'), float('nan')]:
            with self.subTest(tolerance=tolerance), self.assertRaises(ValueError):
                verify.compare(1, 1, tolerance)
        with self.assertRaises(ValueError):
            verify.compare(float('nan'), float('nan'))

    def test_json_rejects_duplicate_and_nonfinite(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / 'input.json'
            for text in ['{"x":1,"x":2}', '[NaN]', '[Infinity]', '[1e999]']:
                p.write_text(text, encoding='utf-8')
                with self.subTest(text=text), self.assertRaises(ValueError):
                    verify.read_json(p)

    def test_manifest_match_tamper_and_size(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / 'evidence.bin'
            p.write_bytes(b'evidence')
            entry = dict(path=p.name, sha256=hashlib.sha256(p.read_bytes()).hexdigest(), size=8)
            manifest = dict(schema='evidence-manifest-v1', files=[entry])
            self.assertTrue(verify.verify_manifest(manifest, folder)['ok'])
            p.write_bytes(b'changed!')
            self.assertFalse(verify.verify_manifest(manifest, folder)['ok'])
            p.unlink()
            self.assertFalse(verify.verify_manifest(manifest, folder)['ok'])

    def test_manifest_rejects_escape_and_duplicates(self):
        with tempfile.TemporaryDirectory() as folder:
            entry = dict(path='../outside.bin', sha256='0' * 64)
            with self.assertRaises(ValueError):
                verify.verify_manifest(dict(schema='evidence-manifest-v1', files=[entry]), folder)
            entry['path'] = 'sample.bin'
            with self.assertRaises(ValueError):
                verify.verify_manifest(dict(schema='evidence-manifest-v1', files=[entry, entry]), folder)
            with self.assertRaises(ValueError):
                verify.verify_manifest(dict(schema='evidence-manifest-v1', files=[]), folder)

    def test_timing_resources_and_external_gap(self):
        result = verify.parse_vivado(TIMING, UTIL)
        self.assertTrue(result['ok'])
        self.assertFalse(result['board_signoff'])
        self.assertEqual(result['timing']['wns_ns'], 0.559)
        self.assertEqual(result['resources']['lut']['used'], 40487)
        self.assertEqual(result['external_io_delay_gaps'], dict(no_input_delay=15, no_output_delay=13))

    def test_negative_timing_is_failure(self):
        self.assertFalse(verify.parse_vivado(TIMING.replace('0.559', '-0.001'))['ok'])
        self.assertFalse(verify.parse_vivado(TIMING.replace('0.053', '-0.001'))['ok'])
        self.assertFalse(verify.parse_vivado(TIMING.replace('0.264', '-0.001'))['ok'])

    def test_unsupported_report_is_not_zero_filled(self):
        with self.assertRaises(ValueError):
            verify.parse_vivado('No supported summary')
        with self.assertRaises(ValueError):
            verify.parse_vivado(TIMING, '| DSPs | unsupported |')

    def test_docs_resolve_links_and_skip_fenced_example(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'a.md').write_text('# Entry\n\n[next](b.md#target)\n\n```markdown\n[example](missing.md)\n```\n', encoding='utf-8')
            (root / 'b.md').write_text('# Target\n', encoding='utf-8')
            self.assertTrue(verify.check_docs([root])['ok'])
            (root / 'b.md').write_text('# Changed\n', encoding='utf-8')
            result = verify.check_docs([root])
            self.assertFalse(result['ok'])
            self.assertEqual(result['issues'][0]['kind'], 'missing_anchor')

    def test_docs_missing_file_fence_and_privacy_candidate(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            synthetic_address = 'test' + '@' + 'example.invalid'
            (root / 'a.md').write_text('# Entry\n[missing](lost.md)\n' + synthetic_address + '\n```\n', encoding='utf-8')
            result = verify.check_docs([root])
            self.assertFalse(result['ok'])
            kinds = {x['kind'] for x in result['issues']}
            self.assertTrue({'missing_link', 'unclosed_fence', 'email'} <= kinds)
            self.assertNotIn(synthetic_address, json.dumps(result))

    def test_cli_exit_codes_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            a, b = root / 'a.json', root / 'b.json'
            a.write_text('{"x":1}', encoding='utf-8')
            b.write_text('{"x":1}', encoding='utf-8')
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(verify.main(['compare', str(a), str(b)]), 0)
                self.assertEqual(verify.main(['compare', str(a), str(b), '--output', str(a)]), 2)
                b.write_text('{"x":2}', encoding='utf-8')
                self.assertEqual(verify.main(['compare', str(a), str(b)]), 1)
            self.assertEqual(a.read_text(encoding='utf-8'), '{"x":1}')


if __name__ == '__main__':
    unittest.main(verbosity=2)
