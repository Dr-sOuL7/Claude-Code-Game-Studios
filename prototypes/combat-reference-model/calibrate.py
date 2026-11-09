# PROTOTYPE - NOT FOR PRODUCTION
import sys, itertools
sys.path.insert(0, '.')
import lab
rows = []
for rp, ed, ps in itertools.product((0.001, 0.002, 0.004), (60, 120, 240, 480), (2.0, 4.0, 8.0)):
    r = lab.evaluate(dict(burst_ref_p=rp, energy_div=ed, pressure_scale=ps), npairs=40)
    rows.append((lab.penalty(r), rp, ed, ps, r))
rows.sort(key=lambda t: t[0])
for pen, rp, ed, ps, r in rows[:10]:
    print("pen %.2f  ref_p %.3f ediv %3d pscale %.0f | %s" % (pen, rp, ed, ps, lab.fmt(r)))
