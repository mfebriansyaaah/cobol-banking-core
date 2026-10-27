#!/usr/bin/env python3
"""Generate a new SQL-backed COBOL module from the cost_center template.

Usage: scripts/generate_module.py <domain> <PREFIX> <table> <ref_field> <name_field> <type_field>
Example: scripts/generate_module.py vendor VND_ vendor vendor_ref vendor_name vendor_type
"""
import sys, re, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def main():
    if len(sys.argv) < 7:
        print(__doc__)
        sys.exit(2)
    domain, prefix, table, ref_field, name_field, type_field = sys.argv[1:7]
    src_path = os.path.join(ROOT, 'cobol/src/cost_center_core.cob')
    src = open(src_path).read()

    # Basic renames
    src = src.replace('cost_center_core', f'{domain}_core')
    src = src.replace('Cost center: create, allocate, close.', f'{domain}: create, process, close.')
    src = src.replace('CSC_CREATE', f'{prefix}CREATE')
    src = src.replace('CSC_LIST', f'{prefix}LIST')
    src = src.replace('CSC_GET', f'{prefix}GET')
    src = src.replace('CSC_ALLO', f'{prefix}CALC')
    src = src.replace('CSC_CLOSE', f'{prefix}DELETE')
    src = src.replace('CSC_SUMMARY', f'{prefix}SUMMARY')
    src = src.replace('CSC_AUDIT', f'{prefix}AUDIT')
    src = src.replace('CSC_VALIDATE', f'{prefix}VALIDATE')
    src = src.replace('cost_center_audit', f'{domain}_audit')
    src = src.replace('cost_center', domain)
    src = src.replace('COST_CENTER_CORE', f'{domain.upper()}_CORE')
    src = src.replace('cc_ref', ref_field)
    src = src.replace('cc_id', f'{domain}_id')
    src = src.replace('dept_name', name_field)
    src = src.replace('cc_type', type_field)
    src = src.replace('WS-AUDIT-CSC', f'WS-AUDIT-{prefix[:3]}')
    src = src.replace('CSC_VALID', f'{prefix}VALID')

    out_path = os.path.join(ROOT, f'cobol/src/{domain}_core.cob')
    open(out_path, 'w').write(src)
    print(f'Generated {out_path}')
    print('NOTE: adjust EVALUATE lengths, SQL status strings, and WS-NUM collisions manually.')

if __name__ == '__main__':
    main()
