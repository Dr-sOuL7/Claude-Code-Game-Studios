# PROTOTYPE - NOT FOR PRODUCTION
"""Scoring harness for the v0.2 lever search. Evaluates a K-override against the
targets proposed in design/gdd/combat-system.md (open decision O4)."""
import random, itertools, collections, math, sys
import ref_model_v02 as M

P = M.profiles()
POLS = list(M.POLICIES)
PURE = ['ATK', 'DEF', 'DOD', 'CHG']
BASE = dict(M.K)

def apply(over):
    M.K.clear(); M.K.update(BASE); M.K.update(over)
    M.K['k_burst'] = -math.log(1 - M.K['burst_ref_p']) / M.K['burst_ref_x']

def evaluate(over, seed=11, npairs=60):
    apply(over)
    rng = random.Random(seed)
    pairs = [(rng.choice(P), rng.choice(P)) for _ in range(npairs)]
    how = collections.Counter(); turns = []
    w = collections.defaultdict(float); g = collections.defaultdict(int)
    cell = collections.defaultdict(float); celln = collections.defaultdict(int)
    typew = collections.defaultdict(float); typen = collections.defaultdict(int)
    for pa, pb in itertools.product(POLS, POLS):
        for x, y in pairs:
            r = M.play(x, y, M.POLICIES[pa], M.POLICIES[pb], rng)
            h = r['how'].split(':')[-1]
            how[h] += 1; turns.append(r['turns'])
            s = 0.5 if r['w'] is None else (1.0 if r['w'] == 0 else 0.0)
            w[pa] += s; g[pa] += 1; w[pb] += 1 - s; g[pb] += 1
            cell[(pa, pb)] += s; celln[(pa, pb)] += 1
            if (pa, pb) in (('ADP', 'ADP'), ('RND', 'RND'), ('ROT', 'ROT')):
                typew[x['type']] += s; typen[x['type']] += 1
                typew[y['type']] += 1 - s; typen[y['type']] += 1
    n = sum(how.values()); turns.sort()
    pm = {p: w[p] / g[p] for p in POLS}
    # symmetric head-to-head: row policy vs column policy, both seats
    h2h = {}
    for a in POLS:
        for b in POLS:
            ab = cell[(a, b)] / celln[(a, b)]; ba = 1 - cell[(b, a)] / celln[(b, a)]
            h2h[(a, b)] = (ab + ba) / 2
    tm = {t: typew[t] / typen[t] for t in 'ABDS' if typen[t]}
    # every pure policy should have a counter (>=0.55) among the other pure/heuristic policies
    counters = {x: max(h2h[(y, x)] for y in POLS if y != x) for x in PURE}
    return dict(med=turns[len(turns) // 2], p10=turns[len(turns) // 10], p90=turns[int(.9 * len(turns))],
                burst=how['burst'] / n, ring=how['ringout'] / n, spin=(how['spin'] + how['draw']) / n,
                pm=pm, h2h=h2h, tm=tm, counters=counters)

def penalty(r):
    """0 = meets every proposed target. Components are unit-less 'how far outside the band'."""
    pen = 0.0
    pen += max(0, 20 - r['med']) / 10 + max(0, r['med'] - 28) / 10          # median 20-28 turns
    pen += max(0, 0.22 - r['burst']) / 0.1 + max(0, r['burst'] - 0.38) / 0.1
    pen += max(0, 0.10 - r['ring']) / 0.1 + max(0, r['ring'] - 0.30) / 0.1
    pen += max(0, 0.35 - r['spin']) / 0.1 + max(0, r['spin'] - 0.60) / 0.1
    top = max(r['pm'][p] for p in PURE + ['ROT', 'RND'])                      # no pure policy should dominate
    pen += max(0, top - 0.58) / 0.05
    for x in PURE:                                                            # each pure policy needs a counter
        pen += max(0, 0.56 - r['counters'][x]) / 0.05
    for x in PURE:                                                            # every action must be viable
        pen += max(0, 0.36 - r['pm'][x]) / 0.05
    spread = max(r['tm'].values()) - min(r['tm'].values())
    pen += max(0, spread - 0.20) / 0.1                                        # type win-rate spread
    return pen

def fmt(r):
    return ("med %2d [p10 %2d p90 %2d] burst %.2f ring %.2f spin %.2f | pure ATK %.2f DEF %.2f DOD %.2f CHG %.2f | "
            "best-counter vs ATK %.2f DEF %.2f DOD %.2f CHG %.2f | types %s") % (
        r['med'], r['p10'], r['p90'], r['burst'], r['ring'], r['spin'],
        r['pm']['ATK'], r['pm']['DEF'], r['pm']['DOD'], r['pm']['CHG'],
        r['counters']['ATK'], r['counters']['DEF'], r['counters']['DOD'], r['counters']['CHG'],
        " ".join("%s%.2f" % (k, v) for k, v in sorted(r['tm'].items())))

if __name__ == '__main__':
    # regression: lever defaults must reproduce v0.1 exactly
    import ref_model as V1
    rng1, rng2 = random.Random(5), random.Random(5)
    V1.K['burst_ref_p'] = 0.05
    ok = True
    apply({})
    for _ in range(300):
        a, b = rng1.choice(P), rng1.choice(P); rng2.choice(P); rng2.choice(P)
        pa, pb = rng1.choice(POLS), rng1.choice(POLS); rng2.choice(POLS); rng2.choice(POLS)
        # separate rng streams for the matches themselves, same seed
        r1 = V1.play(next(x for x in V1.profiles() if x['name'] == a['name']), next(x for x in V1.profiles() if x['name'] == b['name']),
                     V1.POLICIES[pa], V1.POLICIES[pb], random.Random(len(a['name']) + hash((a['name'], b['name'], pa, pb)) % 1000))
        r2 = M.play(a, b, M.POLICIES[pa], M.POLICIES[pb], random.Random(len(a['name']) + hash((a['name'], b['name'], pa, pb)) % 1000))
        if (r1['w'], r1['how'], r1['turns']) != (r2['w'], r2['how'], r2['turns']): ok = False; break
    print("v0.2 with levers off reproduces v0.1 on 300 matches:", ok)
