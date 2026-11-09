# PROTOTYPE - NOT FOR PRODUCTION
"""Round 2: wider lever ranges + calibration knobs.  Stage 1: 600 samples x 40 pairs. Stage 2: top 10 on fresh seed, 200 pairs."""
import sys, random, json
sys.path.insert(0, '.')
from multiprocessing import Pool
import lab

FIXED = dict(burst_ref_x=106.0, energy_div=240, pressure_st_share=1.0, init_mult=1.0, dodge_incoming=1.0, attack_cost=0, special_pierce=0)
SPACE = dict(
    defend_counter=(1.5, 2, 3, 4), whiff_cost=(0, 2, 3), evade_bonus=(0, 0.3), hit_meter_gain=(5, 10, 15),
    special_cost=(50, 70), pressure_scale=(3.0, 5.0, 7.0), burst_ref_p=(0.003, 0.006, 0.01),
    drain_scale=(0.6, 0.8, 1.0), energy_base=(0, 20), stamina_drain=(0.8, 0.9),
)
def score(job):
    over, seed, npairs = job
    r = lab.evaluate({**FIXED, **over}, seed=seed, npairs=npairs)
    return lab.penalty(r), over, r

if __name__ == '__main__':
    rng = random.Random(2026)
    jobs = [({k: rng.choice(v) for k, v in SPACE.items()}, 21, 40) for _ in range(600)]
    with Pool(4) as pool: res = sorted(pool.map(score, jobs, chunksize=4), key=lambda t: t[0])
    top = res[:10]
    with Pool(4) as pool: res2 = sorted(pool.map(score, [(o, 1303, 200) for _, o, _ in top]), key=lambda t: t[0])
    print("Stage 2 (fresh seed, 200 pairs):")
    for p, o, r in res2: print(" pen %.2f %s\n    %s" % (p, json.dumps(o), lab.fmt(r)))
