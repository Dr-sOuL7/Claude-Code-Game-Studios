# PROTOTYPE - NOT FOR PRODUCTION
"""Proposed ruleset v0.3 = v0.2 final + O8 levers. Fresh seeds, 512 profiles, invariants, termination bound."""
import sys, random, collections
sys.path.insert(0, '.')
from multiprocessing import Pool
import validate_choice as V, lab, ref_model_v02 as M
V.COMMON.update(dict(energy_div=120, energy_base=30, mb_drain_div=160, mb_evade=0.4, li_recoil=0.5, li_stab=0.7, ap_cost=1, ap_exp=0.6))
NAME = 'A_keep_dodge_numbers'
if __name__ == '__main__':
    P = {**V.COMMON, **V.CANDS[NAME]}
    print("v0.3 parameters:", P)
    with Pool(4) as pool: res = pool.map(V.job, [(NAME, s) for s in (515, 626, 737, 848)])
    for n, seed, pen, r in res: print("seed %d pen %.2f | %s" % (seed, pen, lab.fmt(r)))
    with Pool(4) as pool: parts = pool.map(V.profile_job, [(NAME, c) for c in range(8)])
    wr = {k: v for d in parts for k, v in d.items()}; v = sorted(wr.values()); n = len(v)
    print("\n512 profiles x 60 opponents: min %.2f p05 %.2f p25 %.2f med %.2f p75 %.2f p95 %.2f max %.2f (noise ~ +/-0.065)" % (v[0], v[int(.05*n)], v[int(.25*n)], v[n//2], v[int(.75*n)], v[int(.95*n)], v[-1]))
    for label, sl in (('blade', slice(0, 3)), ('disc', slice(3, 6)), ('tip', slice(6, 9))):
        g = collections.defaultdict(list)
        for k, x in wr.items(): g[k[sl]].append(x)
        m = {k: round(sum(x)/len(x), 2) for k, x in sorted(g.items())}; print("  by %s: %s  spread %.2f" % (label, m, max(m.values()) - min(m.values())))
    top = sorted(wr.items(), key=lambda kv: -kv[1])[:4]; bot = sorted(wr.items(), key=lambda kv: kv[1])[:4]
    print("  top", [(k, round(x, 2)) for k, x in top], "bottom", [(k, round(x, 2)) for k, x in bot])
    print("  profiles below 0.25: %d / 512,  above 0.70: %d / 512" % (sum(x < .25 for x in v), sum(x > .70 for x in v)))
    # type distribution unchanged (F0 untouched) ; type win rates come from lab.fmt above
    lab.apply(P); K = M.K
    worst = 0; arg = None
    for p in lab.P:
        d = (1 + p['MB'] / K['mb_drain_div'])
        if p['type'] == 'S': d *= K['stamina_drain']
        if p['type'] == 'B': d *= 0.95
        if p['domain'] == 'S': d *= 0.92
        d *= 1 - 0.004 * max(0, p['SM'] - 70); d *= K['drain_scale']
        life = (K['energy_base'] + 1.2 * p['SM']) / d
        if life > worst: worst, arg = life, (p['name'], round(d, 4), K['energy_base'] + 1.2 * p['SM'])
    print("\ntermination bound (slowest passive drain): %.1f turns %s" % (worst, arg))
    rng = random.Random(8675309); mx = 0; hows = {}
    for _ in range(20000):
        a, b = rng.choice(lab.P), rng.choice(lab.P); pa, pb = rng.choice(lab.POLS), rng.choice(lab.POLS)
        r = M.play(a, b, M.POLICIES[pa], M.POLICIES[pb], rng)
        mx = max(mx, r['turns']); h = r['how'].split(':')[0]; hows[h] = hows.get(h, 0) + 1
    print("invariants over 20000 matches: max turns", mx, "finishes", hows)
    for k in sorted(M.STAT):
        if not k.startswith('NONFINITE'): print("  %-16s %.4f" % (k, M.STAT[k]))
    print("  NaN/inf:", any(k.startswith('NONFINITE') for k in M.STAT), "| timeouts:", hows.get('timeout', 0))
