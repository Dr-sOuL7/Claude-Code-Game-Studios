# PROTOTYPE - NOT FOR PRODUCTION
"""O8: give LI a second role / tax AP, keep action-level balance. Score = action penalty + component spread."""
import sys, random, collections, itertools, json
sys.path.insert(0, '.')
from multiprocessing import Pool
import lab, ref_model_v02 as M
from validate_choice import COMMON, CANDS
BASE = {**COMMON, **CANDS['A_keep_dodge_numbers'], 'energy_div': 120}
SPACE = dict(li_recoil=(0.3, 0.5), li_stab=(0.5, 0.7), ap_cost=(1,), energy_base=(30, 40), mb_drain_div=(160, 240), mb_evade=(0.3, 0.4), mb_dodge=(0,), ap_exp=(1.0, 0.8, 0.6))

def profiles_wr(over, seed, n_opp=24):
    lab.apply({**BASE, **over}); rng = random.Random(seed)
    skill = [M.POLICIES[k] for k in ('ADP', 'ROT', 'RND')]; wr = {}
    for p in lab.P:
        w = 0.0
        for _ in range(n_opp):
            o = rng.choice(lab.P); pol = rng.choice(skill); r = M.play(p, o, pol, pol, rng)
            w += 0.5 if r['w'] is None else (1.0 if r['w'] == 0 else 0.0)
        wr[p['name']] = w / n_opp
    return wr

def spread(wr):
    v = sorted(wr.values()); n = len(v)
    def marg(sl):
        g = collections.defaultdict(list)
        for k, x in wr.items(): g[k[sl]].append(x)
        m = {k: sum(x)/len(x) for k, x in g.items()}; return max(m.values()) - min(m.values()), m
    b, bm = marg(slice(0, 3)); t, tm = marg(slice(6, 9)); d, dm = marg(slice(3, 6))
    return dict(p05=v[int(.05*n)], p95=v[int(.95*n)], blade=b, tip=t, disc=d, bm=bm, tm=tm, low=sum(x < .25 for x in v), high=sum(x > .70 for x in v))

def score(job):
    over, seed = job
    r = lab.evaluate({**BASE, **over}, seed=seed, npairs=40)
    pa = lab.penalty(r)
    sp = spread(profiles_wr(over, seed))
    comp = max(0, sp['blade'] - 0.10)/0.05 + max(0, sp['tip'] - 0.10)/0.05 + max(0, 0.30 - sp['p05'])/0.05 + max(0, sp['p95'] - 0.70)/0.05
    return pa + comp, pa, comp, over, r, sp

if __name__ == '__main__':
    combos = [dict(zip(SPACE, v)) for v in itertools.product(*SPACE.values())]
    with Pool(4) as pool: res = sorted(pool.map(score, [(o, 41) for o in combos], chunksize=2), key=lambda t: t[0])
    print("baseline (no O8 levers):")
    b = [x for x in res if x[3]['ap_exp'] == 1.0 and x[3]['li_recoil'] == 0.3 and x[3]['li_stab'] == 0.5 and x[3]['energy_base'] == 30 and x[3]['mb_drain_div'] == 160 and x[3]['mb_evade'] == 0.3][0]
    print("  total %.2f act %.2f comp %.2f | %s\n  spread %s" % (b[0], b[1], b[2], lab.fmt(b[4])[:120], {k: (round(v, 2) if isinstance(v, float) else v) for k, v in b[5].items() if k not in ('bm', 'tm')}))
    top = res[:8]
    with Pool(4) as pool: res2 = sorted(pool.map(score, [(o, 4242) for _, _, _, o, _, _ in top]), key=lambda t: t[0])
    print("\nStage 2 (fresh seed) top 8:")
    for tot, pa, comp, o, r, sp in res2:
        print(" total %.2f act %.2f comp %.2f %s\n   %s\n   p05 %.2f p95 %.2f blade %.2f tip %.2f disc %.2f low %d high %d | blades %s | tips %s" % (
            tot, pa, comp, json.dumps(o), lab.fmt(r)[:150], sp['p05'], sp['p95'], sp['blade'], sp['tip'], sp['disc'], sp['low'], sp['high'],
            {k: round(v, 2) for k, v in sorted(sp['bm'].items())}, {k: round(v, 2) for k, v in sorted(sp['tm'].items())}))
