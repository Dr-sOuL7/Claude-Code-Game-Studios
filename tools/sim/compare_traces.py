# PROTOTYPE - NOT FOR PRODUCTION
"""Differential check: GDScript engine vs the Python oracle on N seeded matches.

    python3 -I tools/sim/compare_traces.py compare [N]          # run both, compare (needs `godot` on PATH)
    python3 -I tools/sim/compare_traces.py freeze N OUT.jsonl   # write oracle-only golden traces for CI

Integers, booleans and strings must be identical; floats must agree to 1e-9 absolute or relative.
"""
import json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'prototypes', 'combat-reference-model'))
import oracle_v1 as O

TOL = 1e-9

def same(a, b):
    if isinstance(a, bool) or isinstance(b, bool) or isinstance(a, str) or isinstance(b, str):
        return a == b
    if isinstance(a, (list, tuple)):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return abs(a - b) <= TOL * max(1.0, abs(a), abs(b))

def first_diff(py, gd):
    for i, (x, y) in enumerate(zip(py, gd)):
        for k in ('t', 'acts', 'col', 'fin', 'pc', 'pb', 'pr', 'p'):
            if not same(x[k], y[k]):
                return 'turn %d key %s: oracle=%s engine=%s' % (x['t'], k, x[k], y[k])
    if len(py) != len(gd):
        return 'length: oracle %d turns, engine %d turns' % (len(py), len(gd))
    return None

def compare(n):
    R = O.ruleset()
    cs = O.cases(n)
    with tempfile.TemporaryDirectory() as d:
        cp = os.path.join(d, 'cases.jsonl'); op = os.path.join(d, 'out.jsonl')
        with open(cp, 'w') as f:
            for c in cs: f.write(json.dumps(c) + '\n')
        r = subprocess.run(['godot', '--headless', '--path', ROOT, '-s', 'res://tools/sim/dump_match.gd', '--', cp, op],
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(op):
            print('engine dump failed:', r.returncode, r.stdout[-400:], r.stderr[-400:]); return 2
        gd = [json.loads(l) for l in open(op)]
    bad = 0; turns = 0; finishes = {}
    for c, g in zip(cs, gd):
        py = O.run_case(c, R)
        turns += len(py)
        fin = py[-1]['fin'][2]; finishes[fin] = finishes.get(fin, 0) + 1
        diff = first_diff(py, g['turns'])
        if diff:
            bad += 1
            if bad <= 5: print('MISMATCH', c, '->', diff)
    print('cases %d, turns compared %d, finishes %s, mismatching matches %d' % (len(cs), turns, finishes, bad))
    return 1 if bad or len(gd) != len(cs) else 0

def freeze(n, out):
    R = O.ruleset()
    with open(out, 'w') as f:
        for c in O.cases(n, master=777):
            f.write(json.dumps({'case': c, 'turns': O.run_case(c, R)}) + '\n')
    print('wrote', n, 'golden traces to', out)
    return 0

if __name__ == '__main__':
    if len(sys.argv) >= 2 and sys.argv[1] == 'compare':
        sys.exit(compare(int(sys.argv[2]) if len(sys.argv) > 2 else 200))
    if len(sys.argv) >= 4 and sys.argv[1] == 'freeze':
        sys.exit(freeze(int(sys.argv[2]), sys.argv[3]))
    print(__doc__); sys.exit(2)
