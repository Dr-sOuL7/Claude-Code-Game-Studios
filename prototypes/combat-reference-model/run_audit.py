# PROTOTYPE - NOT FOR PRODUCTION
import random, itertools, collections, statistics, sys, json, math
sys.path.insert(0, '.')
import ref_model as M

rng = random.Random(20261109)
P = M.profiles()
print("profiles", len(P), " types:", dict(collections.Counter(p['type'] for p in P)),
      " identity-domain:", dict(collections.Counter(str(p['domain']) for p in P)))
ex = {n: next(p for p in P if p['name'] == n) for n in ('B03D02T02', 'B05D05T07', 'B04D04T05', 'B01D01T01')}
print("spec examples ->", {n: p['type'] for n, p in ex.items()}, "(spec expects A, D, S, B)")

# --- 1. collision-probability saturation among all 512x512 matchups
sat_base = sat_atk_inert = tot = 0
for a in P:
    for b in P:
        base = 0.4 + (a['MB'] + b['MB']) / 200
        tot += 1
        sat_base += base >= 0.9
        sat_atk_inert += (base >= 0.9 or base + 0.15 <= 0.9 and False)
inert = sum(1 for a in P for b in P if min(0.9, 0.4 + (a['MB'] + b['MB']) / 200) == min(0.9, 0.4 + (a['MB'] + b['MB']) / 200 + 0.15))
print("\n[1] pairings whose base collision P is already >= 0.9 (cap): %.1f%%; pairings where ATTACK's +0.15 changes nothing: %.1f%%" % (100 * sat_base / tot, 100 * inert / tot))

# --- 2. policy round robin over sampled build pairs
pols = list(M.POLICIES)
N_PAIRS = 250
pairs = [(rng.choice(P), rng.choice(P)) for _ in range(N_PAIRS)]
wins = collections.defaultdict(lambda: [0, 0, 0])   # (pa,pb) -> [a wins, b wins, draws]
how = collections.Counter(); turns = []; maxpos_all = []
by_pair_how = collections.defaultdict(collections.Counter)
for pa, pb in itertools.product(pols, pols):
    for (x, y) in pairs:
        r = M.play(x, y, M.POLICIES[pa], M.POLICIES[pb], rng)
        k = wins[(pa, pb)]
        if r['w'] is None: k[2] += 1
        else: k[r['w']] += 1
        h = r['how'].split(':')[-1] if r['how'].startswith('tiebreak') else r['how']
        how[h] += 1; turns.append(r['turns']); maxpos_all.append(r['maxpos'])
        by_pair_how[(pa, pb)][h] += 1
n = sum(how.values())
print("\n[2] %d matches. Finish mix:" % n, {k: "%.1f%%" % (100 * v / n) for k, v in how.most_common()})
turns.sort()
q = lambda f: turns[int(f * (len(turns) - 1))]
print("    turns: min %d p10 %d median %d p90 %d max %d (spec target 20-30)" % (turns[0], q(.1), q(.5), q(.9), turns[-1]))
mp = sorted(maxpos_all)
print("    max position_pressure reached: median %.1f p90 %.1f max %.1f (ring-out threshold 120)" % (mp[len(mp) // 2], mp[int(.9 * len(mp))], mp[-1]))

print("\n    Policy win rate (row vs column, draws as half), averaged over the same build pairs and both seats:")
print("          " + "  ".join("%5s" % p for p in pols) + "   mean")
means = {}
for pa in pols:
    row = []
    for pb in pols:
        a = wins[(pa, pb)]; b = wins[(pb, pa)]
        w = a[0] + b[1] + 0.5 * (a[2] + b[2]); tot = sum(a) + sum(b)
        row.append(w / tot)
    means[pa] = sum(row) / len(row)
    print("    %5s " % pa + "  ".join("%5.2f" % v for v in row) + "   %.2f" % means[pa])

# --- 3. per-pair finish mix for key pairs
print("\n[3] Finish mix for selected policy pairs")
for key in [('ATK', 'ATK'), ('DEF', 'DEF'), ('DOD', 'DOD'), ('CHG', 'ATK'), ('DEF', 'ATK'), ('RND', 'RND')]:
    c = by_pair_how[key]; s = sum(c.values())
    print("    %s vs %s: %s" % (key[0], key[1], {k: "%.0f%%" % (100 * v / s) for k, v in c.most_common()}))

# --- 4. build-level win rate under mirrored RND policies (skill-free baseline)
print("\n[4] Build win rate, RND vs RND, 40 random opponents each (all 512 profiles)")
wr = {}
for p in P:
    w = g = 0
    for _ in range(40):
        o = rng.choice(P)
        r = M.play(p, o, M.POLICIES['RND'], M.POLICIES['RND'], rng)
        g += 1; w += 1 if r['w'] == 0 else (0.5 if r['w'] is None else 0)
    wr[p['name']] = w / g
vals = sorted(wr.values())
print("    min %.2f p10 %.2f median %.2f p90 %.2f max %.2f (sampling noise at n=40 is about +/-0.08)" % (vals[0], vals[51], vals[256], vals[460], vals[-1]))
top = sorted(wr.items(), key=lambda kv: -kv[1])[:5]; bot = sorted(wr.items(), key=lambda kv: kv[1])[:5]
print("    top:", [(n, round(v, 2)) for n, v in top]); print("    bottom:", [(n, round(v, 2)) for n, v in bot])
for label, key in (('blade', lambda p: p['name'][:3]), ('disc', lambda p: p['name'][3:6]), ('tip', lambda p: p['name'][6:9]), ('type', lambda p: p['type'])):
    g = collections.defaultdict(list)
    for p in P: g[key(p)].append(wr[p['name']])
    print("    by %s:" % label, {k: round(sum(v) / len(v), 2) for k, v in sorted(g.items())})

print("\n[5] Invariant bookkeeping (should hold on every sampled turn):")
for k in sorted(STAT := M.STAT): print("    %-22s %s" % (k, STAT[k] if not isinstance(STAT[k], float) else round(STAT[k], 4)))
print("    NaN/inf anywhere:", any(k.startswith('NONFINITE') for k in STAT))
