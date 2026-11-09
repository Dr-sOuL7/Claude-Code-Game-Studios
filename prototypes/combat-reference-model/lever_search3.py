# PROTOTYPE - NOT FOR PRODUCTION
"""Round 3: base from round 2 (defend_counter/whiff/hit_meter/special_cost fixed near best), search Dodge levers.
Scoring now also requires every pure action's mean win rate >= 0.36 (viability)."""
import sys, random, json
sys.path.insert(0, '.')
from multiprocessing import Pool
import lab
FIXED = dict(burst_ref_x=106.0, energy_div=240, pressure_st_share=1.0, attack_cost=0, special_pierce=0,
             burst_ref_p=0.003, pressure_scale=3.0, energy_base=20, drain_scale=0.8, stamina_drain=0.9, special_cost=50)
SPACE = dict(defend_counter=(2, 3, 4), whiff_cost=(2, 3), hit_meter_gain=(5, 10),
             dodge_incoming=(1.0, 0.8, 0.65, 0.5), evade_bonus=(0, 0.3, 0.6, 1.0), init_mult=(1.0, 1.08),
             dodge_collision=(0.25, 0.40, 0.55), dodge_decay=(0.10, 0.05, 0.0))
def score(job):
    over, seed, npairs = job
    r = lab.evaluate({**FIXED, **over}, seed=seed, npairs=npairs)
    return lab.penalty(r), over, r
if __name__ == '__main__':
    rng = random.Random(7)
    jobs = [({k: rng.choice(v) for k, v in SPACE.items()}, 31, 40) for _ in range(500)]
    with Pool(4) as pool: res = sorted(pool.map(score, jobs, chunksize=4), key=lambda t: t[0])
    top = res[:10]
    with Pool(4) as pool: res2 = sorted(pool.map(score, [(o, 1709, 200) for _, o, _ in top]), key=lambda t: t[0])
    print("Stage 2 (fresh seed, 200 pairs):")
    for p, o, r in res2: print(" pen %.2f %s\n    %s" % (p, json.dumps(o), lab.fmt(r)))
