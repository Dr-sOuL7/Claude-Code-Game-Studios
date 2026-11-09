# PROTOTYPE - NOT FOR PRODUCTION
import sys, itertools
sys.path.insert(0, '.')
import lab
rows = []
for eb, ds, sh, ps in itertools.product((0, 30, 60), (1.0, 0.6), (0.0, 0.5, 1.0), (2.0, 4.0)):
    r = lab.evaluate(dict(burst_ref_p=0.003, energy_div=240, pressure_scale=ps, energy_base=eb, drain_scale=ds, pressure_st_share=sh), npairs=40)
    rows.append((lab.penalty(r), eb, ds, sh, ps, r))
rows.sort(key=lambda t: t[0])
for pen, eb, ds, sh, ps, r in rows[:8]:
    print("pen %.2f ebase %2d dscale %.1f stshare %.1f pscale %.0f | %s" % (pen, eb, ds, sh, ps, lab.fmt(r)))
