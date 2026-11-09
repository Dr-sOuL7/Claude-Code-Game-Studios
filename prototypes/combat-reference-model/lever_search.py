# PROTOTYPE - NOT FOR PRODUCTION
"""Random search over counterplay levers on a fixed calibrated baseline.
Stage 1: 480 random lever sets, 40 build pairs each.  Stage 2: top 12 re-scored on fresh seeds, 150 pairs."""
import sys, random, json
sys.path.insert(0, '.')
from multiprocessing import Pool
import lab

BASELINE = dict(burst_ref_p=0.003, energy_div=240, energy_base=0, drain_scale=0.6,
                pressure_st_share=1.0, pressure_scale=3.0)
SPACE = dict(
    attack_cost=(0, 1, 2, 3), whiff_cost=(0, 2, 4), defend_counter=(0, 0.5, 1, 2),
    dodge_incoming=(1.0, 0.8, 0.65), evade_bonus=(0, 0.2, 0.4), init_mult=(1.08, 1.0),
    hit_meter_gain=(0, 5, 10), special_pierce=(0, 0.5, 1.0), special_cost=(100, 70, 50),
)

def score(job):
    over, seed, npairs = job
    r = lab.evaluate({**BASELINE, **over}, seed=seed, npairs=npairs)
    return lab.penalty(r), over, r

if __name__ == '__main__':
    rng = random.Random(42)
    jobs = [({k: rng.choice(v) for k, v in SPACE.items()}, 11, 40) for _ in range(480)]
    jobs.insert(0, ({}, 11, 40))                       # baseline with no levers
    with Pool(4) as pool:
        res = pool.map(score, jobs, chunksize=4)
    base = res[0]
    res = sorted(res[1:], key=lambda t: t[0])
    print("BASELINE (no levers): pen %.2f | %s" % (base[0], lab.fmt(base[2])))
    top = res[:12]
    print("\nStage 1 top 5:")
    for p, o, r in top[:5]: print(" pen %.2f %s\n    %s" % (p, o, lab.fmt(r)))
    jobs2 = [(o, 977, 150) for _, o, _ in top] + [({}, 977, 150)]
    with Pool(4) as pool:
        res2 = pool.map(score, jobs2)
    print("\nStage 2 (fresh seed, 150 pairs):")
    for p, o, r in sorted(res2[:-1], key=lambda t: t[0]):
        print(" pen %.2f %s\n    %s" % (p, json.dumps(o), lab.fmt(r)))
    print("\nBaseline re-scored: pen %.2f | %s" % (res2[-1][0], lab.fmt(res2[-1][2])))
