# PROTOTYPE - NOT FOR PRODUCTION
import random, itertools, collections, sys, math
sys.path.insert(0, '.')
import ref_model as M

P = M.profiles()
pols = list(M.POLICIES)

def run(ref_p, pscale, seed=7, npairs=80):
    M.K['burst_ref_p'] = ref_p
    M.K['k_burst'] = -math.log(1 - ref_p) / M.K['burst_ref_x']
    M.K['pressure_scale'] = pscale
    rng = random.Random(seed)
    pairs = [(rng.choice(P), rng.choice(P)) for _ in range(npairs)]
    how = collections.Counter(); turns = []
    w = collections.defaultdict(float); g = collections.defaultdict(int)
    typew = collections.defaultdict(float); typeg = collections.defaultdict(int)
    for pa, pb in itertools.product(pols, pols):
        for x, y in pairs:
            r = M.play(x, y, M.POLICIES[pa], M.POLICIES[pb], rng)
            h = r['how'].split(':')[-1]
            how[h] += 1; turns.append(r['turns'])
            s = 0.5 if r['w'] is None else (1.0 if r['w'] == 0 else 0.0)
            w[pa] += s; g[pa] += 1; w[pb] += 1 - s; g[pb] += 1
            if pa == 'ADP' and pb == 'ADP' or (pa == 'RND' and pb == 'RND'):
                typew[x['type']] += s; typeg[x['type']] += 1
                typew[y['type']] += 1 - s; typeg[y['type']] += 1
    n = sum(how.values()); turns.sort()
    pm = {p: w[p] / g[p] for p in pols}
    tm = {t: typew[t] / typeg[t] for t in 'ABDS' if typeg[t]}
    return dict(med=turns[len(turns) // 2], p10=turns[len(turns) // 10], p90=turns[int(.9 * len(turns))],
                burst=how['burst'] / n, ring=how['ringout'] / n, spin=how['spin'] / n,
                pol=pm, typ=tm)

print("ref_p  pscale | med p10 p90 | burst ring spin | policy mean win: " + " ".join("%4s" % p for p in pols) + " | type win A B D S")
for ref_p in (0.002, 0.005, 0.01, 0.02):
    for ps in (1.0, 3.0, 6.0):
        r = run(ref_p, ps)
        print("%.3f  %4.1f   | %3d %3d %3d | %.2f  %.2f %.2f | %s | %s" % (
            ref_p, ps, r['med'], r['p10'], r['p90'], r['burst'], r['ring'], r['spin'],
            " ".join("%.2f" % r['pol'][p] for p in pols),
            " ".join("%.2f" % r['typ'].get(t, float('nan')) for t in 'ABDS')))
