# PROTOTYPE - NOT FOR PRODUCTION
"""Does burst frequency / energy reserve close the component gap?  Candidate A rules; 512 profiles x 40 opponents per setting."""
import sys, random, collections, itertools
sys.path.insert(0, '.')
from multiprocessing import Pool
import lab, ref_model_v02 as M
from validate_choice import COMMON, CANDS

def run(a):
    over, chunk = a
    lab.apply({**COMMON, **CANDS['A_keep_dodge_numbers'], **over})
    rng = random.Random(900 + chunk); skill = [M.POLICIES[n] for n in ('ADP', 'ROT', 'RND')]; out = {}
    for p in lab.P[chunk::8]:
        w = 0.0
        for _ in range(40):
            o = rng.choice(lab.P); pol = rng.choice(skill); r = M.play(p, o, pol, pol, rng)
            w += 0.5 if r['w'] is None else (1.0 if r['w'] == 0 else 0.0)
        out[p['name']] = w / 40
    return out

if __name__ == '__main__':
    print("burst_ref_p ebase | profile p05 p95 | blade range (min..max) | tip range | burst share (sanity run)")
    for rp, eb in itertools.product((0.003, 0.006, 0.012), (20, 40, 60)):
        over = dict(burst_ref_p=rp, energy_base=eb)
        with Pool(4) as pool: parts = pool.map(run, [(over, c) for c in range(8)])
        wr = {k: v for d in parts for k, v in d.items()}; v = sorted(wr.values()); n = len(v)
        def marg(sl):
            g = collections.defaultdict(list)
            for k, x in wr.items(): g[k[sl]].append(x)
            m = {k: sum(x) / len(x) for k, x in g.items()}; return min(m.values()), max(m.values()), min(m, key=m.get), max(m, key=m.get)
        b, t = marg(slice(0, 3)), marg(slice(6, 9))
        r = lab.evaluate({**COMMON, **CANDS['A_keep_dodge_numbers'], **over}, seed=77, npairs=60)
        print("  %.3f      %2d  | %.2f %.2f | %.2f(%s)..%.2f(%s) | %.2f(%s)..%.2f(%s) | burst %.2f ring %.2f spin %.2f med %d pen %.2f" % (
            rp, eb, v[int(.05 * n)], v[int(.95 * n)], b[0], b[2], b[1], b[3], t[0], t[2], t[1], t[3], r['burst'], r['ring'], r['spin'], r['med'], lab.penalty(r)))
