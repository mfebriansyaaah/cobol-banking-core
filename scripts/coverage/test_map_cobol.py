"""Unit tests for map_cobol.py. Stdlib only; no gcov, no database, no build.

Run:  python3 scripts/coverage/test_map_cobol.py
"""
import json
import os
import stat
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
from map_cobol import build_cobertura, load_counts, main, map_lines


class LoadCountsTest(unittest.TestCase):
    def _write(self, text):
        d = tempfile.mkdtemp()
        p = os.path.join(d, 'x.c.gcov')
        with open(p, 'w') as f:
            f.write(text)
        self.addCleanup(lambda: __import__('shutil').rmtree(d, ignore_errors=True))
        return p

    def test_counts_and_uncovered(self):
        p = self._write(
            '        1:    5:/* Line: 10 : a */\n'
            '        3:    6:x = 1;\n'
            '    #####:    7:y = 2;\n'
            '        -:    8:/* Line: 11 : b */\n'
            '    =====:    9:z = 3;\n'
        )
        self.assertEqual(load_counts(p), {5: 1, 6: 3, 7: 0, 9: 0})

    def test_junk_lines_ignored(self):
        p = self._write('not a gcov line\n\n        2:   10:ok;\n')
        self.assertEqual(load_counts(p), {10: 2})


class MapLinesTest(unittest.TestCase):
    def test_maps_to_cobol_lines(self):
        csrc = ['/* Line: 10 : a */\n', 'x = 1;\n', 'x = 2;\n',
                '/* Line: 11 : b */\n', 'y = 3;\n']
        # C lines 2,3 attributed to COBOL 10; C line 5 to COBOL 11.
        e, h = map_lines(csrc, {2: 1, 3: 0, 5: 4})
        self.assertEqual(e, {10, 11})
        self.assertEqual(h, {10, 11})

    def test_uncovered_cobol_line(self):
        csrc = ['/* Line: 20 : x */\n', 'a = 1;\n']
        e, h = map_lines(csrc, {2: 0})
        self.assertEqual(e, {20})
        self.assertEqual(h, set())

    def test_uninstrumented_lines_do_not_create_entries(self):
        csrc = ['header;\n', '/* Line: 30 : x */\n', 'a = 1;\n']
        e, h = map_lines(csrc, {1: 99})
        self.assertEqual(e, set())
        self.assertEqual(h, set())

    def test_no_marker_means_no_mapping(self):
        e, h = map_lines(['a = 1;\n'], {1: 5})
        self.assertEqual(e, set())

    def test_copybook_markers_are_not_attributed_to_the_host(self):
        # Real GnuCOBOL markers name the source file. COPYbook lines must
        # not land on the host module's line numbers (they describe a
        # different file, and the collision inflated/deflated host rates).
        csrc = [
            '/* Line: 10       : MOVE      : /r/cobol/src/m1.cob */\n', 'x = 1;\n',
            '/* Line: 11       : MOVE      : /r/cobol/copy/common_idem.cpy */\n', 'y = 2;\n',
            '/* Line: 12       : MOVE      : /r/cobol/src/m1.cob */\n', 'z = 3;\n',
        ]
        e, h = map_lines(csrc, {2: 1, 4: 0, 6: 1}, host_file='m1.cob')
        self.assertEqual(e, {10, 12})
        self.assertEqual(h, {10, 12})

    def test_markers_without_a_source_file_stay_with_the_host(self):
        # Simplified/hand-written markers (no file) are inline host output.
        csrc = ['/* Line: 10 : a */\n', 'x = 1;\n']
        e, h = map_lines(csrc, {2: 1}, host_file='m1.cob')
        self.assertEqual(e, {10})
        self.assertEqual(h, {10})

    def test_mapping_is_deterministic(self):
        csrc = [
            '/* Line: 10       : MOVE      : /r/cobol/src/m1.cob */\n', 'x = 1;\n',
            '/* Line: 11       : MOVE      : /r/cobol/copy/common_idem.cpy */\n', 'y = 2;\n',
        ]
        counts = {2: 3, 4: 0}
        first = map_lines(csrc, counts, host_file='m1.cob')
        second = map_lines(csrc, counts, host_file='m1.cob')
        self.assertEqual(first, second)


class CoberturaTest(unittest.TestCase):
    def test_xml_shape_and_escaping(self):
        import xml.etree.ElementTree as ET
        rows = [{'module': 'a<b', 'executable': 2, 'covered': 1, 'percent': 50.0,
                 'lines': {10: 1, 20: 0}}]
        x = build_cobertura(rows, 2, 1)
        t = ET.fromstring(x)
        self.assertEqual(t.tag, 'coverage')
        self.assertEqual(t.get('line-rate'), '0.5000')
        cls = t.findall('.//class')
        self.assertEqual(len(cls), 1)
        self.assertEqual(cls[0].get('name'), 'a<b')
        self.assertEqual(cls[0].get('filename'), 'cobol/src/a<b.cob')
        lines = {int(e.get('number')): int(e.get('hits')) for e in cls[0].findall('.//line')}
        self.assertEqual(lines, {10: 1, 20: 0})

    def test_zero_executable(self):
        import xml.etree.ElementTree as ET
        x = build_cobertura([], 0, 0)
        t = ET.fromstring(x)
        self.assertEqual(t.get('line-rate'), '0.0000')


class MainEndToEndTest(unittest.TestCase):
    """main() with fake gcov/strings on PATH: exercises orchestration."""

    def setUp(self):
        self.work = tempfile.mkdtemp()
        self.cov = tempfile.mkdtemp()
        self.bin = tempfile.mkdtemp()
        self.addCleanup(lambda: __import__('shutil').rmtree(self.work, ignore_errors=True))
        self.addCleanup(lambda: __import__('shutil').rmtree(self.cov, ignore_errors=True))
        self.addCleanup(lambda: __import__('shutil').rmtree(self.bin, ignore_errors=True))
        # fake `strings <x.gcno>` -> /tmp/<module>.c
        with open(os.path.join(self.bin, 'strings'), 'w') as f:
            f.write('#!/usr/bin/env bash\nbase=$(basename "$1" .gcno)\necho "/tmp/$base.c"\n')
        # fake `gcov <module>.gcno` (run with cwd=work) -> work/<module>.c.gcov
        with open(os.path.join(self.bin, 'gcov'), 'w') as f:
            f.write('#!/usr/bin/env bash\nbase=$(basename "$1" .gcno)\n'
                    'cat > "$(pwd)/$base.c.gcov" <<\'EOF\'\n'
                    '        -:    0:Source:x\n'
                    '        1:    5:/* Line: 7 : pick */\n'
                    '        1:    6:ok = 1;\n'
                    '        -:    7:/* Line: 8 : skip */\n'
                    '    #####:    8:nope = 1;\n'
                    'EOF\n')
        for b in ('strings', 'gcov'):
            os.chmod(os.path.join(self.bin, b), 0o755)
        self.old_path = os.environ.get('PATH', '')
        os.environ['PATH'] = self.bin + os.pathsep + self.old_path
        self.addCleanup(lambda: os.environ.__setitem__('PATH', self.old_path))
        # module sources + gcno placeholders
        with open(os.path.join(self.work, 'm1.c'), 'w') as f:
            f.write('h;\n' * 4 + '/* Line: 7 : pick */\nq;\n/* Line: 8 : skip */\nr;\n')
        open(os.path.join(self.work, 'm1.gcno'), 'w').close()

    def test_main_writes_text_json_and_cobertura(self):
        import io
        from contextlib import redirect_stdout
        out = io.StringIO()
        with redirect_stdout(out):
            rc = main([self.work, self.cov, 'm1', 'ghost', '--cobertura',
                       os.path.join(self.cov, 'cob.xml')])
        self.assertEqual(rc, 0)
        text = out.getvalue()
        self.assertIn('COBOL curated line coverage', text)
        self.assertIn('m1', text)
        data = json.load(open(os.path.join(self.cov, 'cobol.json')))
        self.assertEqual(data['executable'], 2)
        self.assertEqual(data['covered'], 1)
        self.assertEqual(data['percent'], 50.0)
        by_mod = {m['module']: m for m in data['modules']}
        self.assertEqual(by_mod['m1']['covered'], 1)
        # ghost module: missing sources -> zeroed row, schema-compatible
        self.assertEqual(by_mod['ghost'], {'module': 'ghost', 'executable': 0,
                                           'covered': 0, 'percent': 0.0})
        import xml.etree.ElementTree as ET
        t = ET.parse(os.path.join(self.cov, 'cob.xml')).getroot()
        self.assertEqual(len(t.findall('.//class')), 2)


if __name__ == '__main__':
    unittest.main(verbosity=2)
