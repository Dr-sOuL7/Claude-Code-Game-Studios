# PROTOTYPE - NOT FOR PRODUCTION
"""Final proposed v0.2 rule set = validate_choice.COMMON + candidate A, with energy_div 120 (closer to the spec's 20 than the searched 240).
Fresh seeds, 512 profiles, invariants over 20,000 matches, and the exact termination bound."""
import sys, random
sys.path.insert(0, '.')
from multiprocessing import Pool
import validate_choice as V, lab, ref_model_v02 as M
V.COMMON['energy_div'] = 120

if __name__ == '__main__':
    name = 'A_keep_dodge_numbers'
    print("FINAL v0.2 parameters:", {**V.COMMON, **V.CANDS[name]})
    with Pool(4) as pool: res = pool.map(V.job, [(name, s) for s in (111, 222, 333, 444)])
    for n, seed, pen, r in res: print("seed %d pen %.2f | %s" % (seed, pen, lab.fmt(r)))
    with Pool(4) as pool: parts = pool.map(V.profile_job, [(name, c) for c in range(8)])
    wr = {k: v for d in parts for k, v in d.items()}; v = sorted(wr.values()); n = len(v)
    print("\n512 profiles x 60 opponents: min %.2f p05 %.2f p25 %.2f med %.2f p75 %.2f p95 %.2f max %.2f (noise ~ +/-0.065)" % (
        v[0], v[int(.05*n)], v[int(.25*n)], v[n//2], v[int(.75*n)], v[int(.95*n)], v[-1]))
    import collections
    for label, sl in (('blade', slice(0, 3)), ('disc', slice(3, 6)), ('tip', slice(6, 9))):
        g = collections.defaultdict(list)
        for k, x in wr.items(): g[k[sl]].append(x)
        print("  by %s:" % label, {k: round(sum(x)/len(x), 2) for k, x in sorted(g.items())})
    top = sorted(wr.items(), key=lambda kv: -kv[1])[:4]; bot = sorted(wr.items(), key=lambda kv: kv[1])[:4]
    print("  top", [(k, round(x, 2)) for k, x in top], "bottom", [(k, round(x, 2)) for k, x in bot])
    print("  profiles below 0.25: %d / 512,  above 0.70: %d / 512" % (sum(x < .25 for x in v), sum(x > .70 for x in v)))
    # invariants, single process
    lab.apply({**V.COMMON, **V.CANDS[name]})
    rng = random.Random(8675309); mx = 0; hows = {}
    for _ in range(20000):
        a, b = rng.choice(lab.P), rng.choice(lab.P)
        pa, pb = rng.choice(lab.POLS), rng.choice(lab.POLS)
        r = M.play(a, b, M.POLICIES[pa], M.POLICIES[pb], rng)
        mx = max(mx, r['turns']); h = r['how'].split(':')[0]; hows[h] = hows.get(h, 0) + 1
    print("\ninvariants over 20000 matches: max turns", mx, "finishes", hows)
    for k in sorted(M.STAT):
        if not k.startswith('NONFINITE'): print("  %-16s %.4f" % (k, M.STAT[k]))
    print("  NaN/inf:", any(k.startswith('NONFINITE') for k in M.STAT), "| timeouts:", hows.get('timeout', 0))
