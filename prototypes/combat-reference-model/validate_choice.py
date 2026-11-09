# PROTOTYPE - NOT FOR PRODUCTION
"""Stress-test candidate rule sets: 3 fresh seeds x 300 pairs, then all 512 profiles x 60 opponents (skill-mixed policies)."""
import sys, random, collections, json
sys.path.insert(0, '.')
from multiprocessing import Pool
import lab, ref_model_v02 as M

COMMON = dict(burst_ref_x=106.0, energy_div=240, pressure_st_share=1.0, attack_cost=0, special_pierce=0, burst_ref_p=0.003,
              pressure_scale=3.0, energy_base=20, drain_scale=0.8, stamina_drain=0.9, special_cost=50, hit_meter_gain=10, whiff_cost=3)
CANDS = {
 'A_keep_dodge_numbers': dict(defend_counter=4, dodge_incoming=0.65, evade_bonus=0, init_mult=1.0, dodge_collision=0.25, dodge_decay=0.10),
 'B_stronger_dodge':     dict(defend_counter=3, dodge_incoming=0.5,  evade_bonus=0.6, init_mult=1.0, dodge_collision=0.40, dodge_decay=0.05),
}
def job(a):
    name, seed = a
    r = lab.evaluate({**COMMON, **CANDS[name]}, seed=seed, npairs=300)
    return name, seed, lab.penalty(r), r

def profile_job(a):
    name, chunk = a
    lab.apply({**COMMON, **CANDS[name]})
    rng = random.Random(500 + chunk)
    out = {}
    skill = [M.POLICIES['ADP'], M.POLICIES['ROT'], M.POLICIES['RND']]
    for p in lab.P[chunk::8]:
        w = 0.0
        for _ in range(60):
            o = rng.choice(lab.P); pol = rng.choice(skill)
            r = M.play(p, o, pol, pol, rng)
            w += 0.5 if r['w'] is None else (1.0 if r['w'] == 0 else 0.0)
        out[p['name']] = w / 60
    return out

if __name__ == '__main__':
    with Pool(4) as pool:
        res = pool.map(job, [(n, s) for n in CANDS for s in (101, 202, 303)])
    for name, seed, pen, r in res: print("%-22s seed %d pen %.2f | %s" % (name, seed, pen, lab.fmt(r)))
    for name in CANDS:
        with Pool(4) as pool: parts = pool.map(profile_job, [(name, c) for c in range(8)])
        wr = {k: v for d in parts for k, v in d.items()}
        v = sorted(wr.values()); n = len(v)
        print("\n%s -- 512 profiles x 60 opponents: min %.2f p05 %.2f p25 %.2f med %.2f p75 %.2f p95 %.2f max %.2f  (noise ~ +/-0.065)" % (
            name, v[0], v[int(.05*n)], v[int(.25*n)], v[n//2], v[int(.75*n)], v[int(.95*n)], v[-1]))
        top = sorted(wr.items(), key=lambda kv: -kv[1])[:4]; bot = sorted(wr.items(), key=lambda kv: kv[1])[:4]
        print("  top", [(k, round(x, 2)) for k, x in top], " bottom", [(k, round(x, 2)) for k, x in bot])
        for lab_, sl in (('blade', slice(0, 3)), ('disc', slice(3, 6)), ('tip', slice(6, 9))):
            g = collections.defaultdict(list)
            for k, x in wr.items(): g[k[sl]].append(x)
            print("  by %s:" % lab_, {k: round(sum(x)/len(x), 2) for k, x in sorted(g.items())})
    print("\ninvariants:", {k: round(x, 4) for k, x in sorted(M.STAT.items()) if not k.startswith('NONFINITE')}, "NaN/inf:", any(k.startswith('NONFINITE') for k in M.STAT))
