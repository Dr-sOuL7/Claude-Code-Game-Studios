# PROTOTYPE - NOT FOR PRODUCTION
import sys, random, itertools
sys.path.insert(0, '.')
import lab, ref_model_v02 as M
from validate_choice import COMMON, CANDS
lab.apply({**COMMON, **CANDS['A_keep_dodge_numbers']})
rng = random.Random(8675309); mx = 0; n = 0; hows = {}
for _ in range(20000):
    a, b = rng.choice(lab.P), rng.choice(lab.P)
    pa, pb = rng.choice(lab.POLS), rng.choice(lab.POLS)
    r = M.play(a, b, M.POLICIES[pa], M.POLICIES[pb], rng)
    mx = max(mx, r['turns']); n += 1; hows[r['how'].split(':')[0]] = hows.get(r['how'].split(':')[0], 0) + 1
print("matches", n, "max turns", mx, "finishes", hows)
for k in sorted(M.STAT):
    if not k.startswith('NONFINITE'): print("  %-16s %.4f" % (k, M.STAT[k]))
print("NaN/inf:", any(k.startswith('NONFINITE') for k in M.STAT), "| timeouts:", hows.get('timeout', 0))
