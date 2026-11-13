#!/usr/bin/env python3
"""Map GnuCOBOL gcov counts back to COBOL source lines.

GnuCOBOL translates COBOL to C; this script compiles nothing itself. It
expects, per module: `<module>.c` (generated with `cobc -C`) and
`<module>.gcno` (from a `--coverage` compile) in WORK_DIR, plus the `.gcda`
files the instrumented binary wrote next to them. For every instrumented C
line it finds the nearest preceding `/* Line: N : ... */` translator marker
and attributes the C execution count to COBOL line N.

Markers name the source file they came from (`... : /path/x.cob */`). Only
markers naming the module's own `.cob` are attributed to it: COPYbook lines
(`.cpy`) compile into the host but describe a different file, so attributing
them by bare line number collided with unrelated host lines and moved
per-module rates whenever a copybook grew (PR-03B/04B/14A/14B re-baselines).
Markers without a file (simplified/hand-written) stay with the host.

Outputs (identical to the historical inline version):
- human-readable table on stdout,
- coverage/cobol.json (machine-readable totals + per-module rows),
- optionally Cobertura XML (--cobertura) with one <class> per module and
  one <line> per executable COBOL line (hits 1/0).

Usage:
  map_cobol.py WORK_DIR COVERAGE_DIR MODULE... [--cobertura PATH]

Pure functions (load_counts, map_lines, build_cobertura) are unit-tested in
scripts/coverage/test_map_cobol.py; only run_module() touches gcov/strings.
"""
import argparse
import json
import os
import re
import subprocess
import sys

MARKER = re.compile(r'/\* Line:\s*(\d+)\s*:')
MARKER_SRC = re.compile(r'(\S+\.(?:cob|cpy))\s*\*/')
COUNT = re.compile(r'^\s*([0-9]+|#####|=====|-):\s*(\d+):')


def recorded_source(gcno):
    """Absolute C path the compiler recorded in the .gcno (or None)."""
    out = subprocess.run(['strings', gcno], capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.startswith('/tmp/') and line.endswith('.c'):
            return line
    return None


def load_counts(path):
    """Parse a gcov file into {generated-C-line: execution-count}."""
    counts = {}
    with open(path, errors='replace') as f:
        for line in f:
            m = COUNT.match(line)
            if not m:
                continue
            tag, lineno = m.group(1), int(m.group(2))
            if tag == '-':
                continue
            counts[lineno] = 0 if tag in ('#####', '=====') else int(tag)
    return counts


def map_lines(csrc_lines, counts, host_file=None):
    """Attribute C execution counts to COBOL lines.

    csrc_lines: generated C source lines (with /* Line: N */ markers).
    counts: {generated-C-line: execution-count} from load_counts().
    host_file: when given, markers naming a different source file (a
        COPYbook) are skipped instead of being attributed to the host's
        line numbers; markers without a file stay with the host.
    Returns (exec_lines, hit_lines): sets of COBOL line numbers.
    """
    current = None
    exec_lines = set()
    hit_lines = set()
    for i, line in enumerate(csrc_lines, start=1):
        m = MARKER.search(line)
        if m:
            current = int(m.group(1))
            if host_file is not None:
                src = MARKER_SRC.search(line)
                if src and src.group(1).rsplit('/', 1)[-1] != host_file:
                    current = None
            continue
        if current is None or i not in counts:
            continue
        exec_lines.add(current)
        if counts[i] > 0:
            hit_lines.add(current)
    return exec_lines, hit_lines


def build_cobertura(rows, total_exec, total_hit):
    """Cobertura XML: one <class> per module, one <line> per executable line."""
    def q(s):
        return (s.replace('&', '&amp;').replace('<', '&lt;')
                 .replace('>', '&gt;').replace('"', '&quot;'))

    def rate(hit, exc):
        return '%.4f' % (hit / exc,) if exc else '0.0000'

    out = ['<?xml version="1.0" ?>',
           '<coverage version="1.0" line-rate="%s" lines-covered="%d" lines-valid="%d">' % (
               rate(total_hit, total_exec), total_hit, total_exec),
           '  <packages>',
           '    <package name="cobol" line-rate="%s">' % rate(total_hit, total_exec),
           '      <classes>']
    for r in rows:
        e, h = r['executable'], r['covered']
        out.append('        <class name="%s" filename="cobol/src/%s.cob" line-rate="%s">' % (
            q(r['module']), q(r['module']), rate(h, e)))
        out.append('          <lines>')
        for n in sorted(r.get('lines', {})):
            out.append('            <line number="%d" hits="%d"/>' % (n, r['lines'][n]))
        out.append('          </lines>')
        out.append('        </class>')
    out += ['      </classes>', '    </package>', '  </packages>', '</coverage>', '']
    return '\n'.join(out)


def run_module(work, module):
    """Full gcov orchestration for one module. Returns a result row dict."""
    empty = {'module': module, 'executable': 0, 'covered': 0, 'percent': 0.0, 'lines': {}}
    csrc = os.path.join(work, module + '.c')
    gcno = os.path.join(work, module + '.gcno')
    if not (os.path.exists(csrc) and os.path.exists(gcno)):
        return empty
    src_path = recorded_source(gcno)
    if not src_path:
        return empty
    subprocess.run(['cp', csrc, src_path], check=False)
    gcov_file = os.path.join(work, os.path.basename(src_path) + '.gcov')
    if os.path.exists(gcov_file):
        os.remove(gcov_file)
    subprocess.run(['gcov', module + '.gcno'], cwd=work, capture_output=True, text=True)
    if not os.path.exists(gcov_file):
        return empty
    counts = load_counts(gcov_file)
    with open(csrc, errors='replace') as f:
        csrc_lines = f.readlines()
    exec_lines, hit_lines = map_lines(csrc_lines, counts, host_file=module + '.cob')
    e, h = len(exec_lines), len(hit_lines)
    return {
        'module': module,
        'executable': e,
        'covered': h,
        'percent': round(100.0 * h / e, 2) if e else 0.0,
        'lines': {n: (1 if n in hit_lines else 0) for n in exec_lines},
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('work_dir')
    ap.add_argument('coverage_dir')
    ap.add_argument('modules', nargs='+')
    ap.add_argument('--cobertura', default=None)
    ns = ap.parse_args(argv)
    work = ns.work_dir
    coverage_dir = ns.coverage_dir

    total_exec = total_hit = 0
    rows = []
    for module in ns.modules:
        r = run_module(work, module)
        total_exec += r['executable']
        total_hit += r['covered']
        rows.append(r)

    overall = round(100.0 * total_hit / total_exec, 2) if total_exec else 0.0
    print('COBOL curated line coverage (mapped from generated C):')
    for r in sorted(rows, key=lambda x: (-x['percent'], x['module'])):
        print(f"  {r['module']:<28} {r['covered']:>6}/{r['executable']:<6} {r['percent']:>6.2f}%")
    print(f"  {'TOTAL':<28} {total_hit:>6}/{total_exec:<6} {overall:>6.2f}%")
    # cobol.json keeps the historical schema (no per-line detail); the
    # per-line mapping lives in the Cobertura report when requested.
    slim = [{k: r[k] for k in ('module', 'executable', 'covered', 'percent')} for r in rows]
    with open(os.path.join(coverage_dir, 'cobol.json'), 'w') as f:
        json.dump({'modules': slim, 'executable': total_exec, 'covered': total_hit,
                   'percent': overall}, f)
    if ns.cobertura:
        with open(ns.cobertura, 'w') as f:
            f.write(build_cobertura(rows, total_exec, total_hit))
    return 0


if __name__ == '__main__':
    sys.exit(main())
