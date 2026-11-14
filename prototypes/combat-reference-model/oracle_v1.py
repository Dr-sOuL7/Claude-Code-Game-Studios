# PROTOTYPE - NOT FOR PRODUCTION
"""Independent oracle for the SPINFORGE combat engine (story combat-engine/004).

Written from design/gdd/combat-system.md v0.3 and the committed data files
(assets/data/parts/*.json, assets/data/combat/combat_ruleset_v1.json). It shares no
code with the GDScript engine; the only things the two sides must agree on are the
documented contracts: MINSTD, the stream-seed mixing, the collision phase order and the
action-selection stream. Run `python3 -I oracle_v1.py` for a self-check.
"""
import json, math, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MOD = 2147483647
ACTIONS = ['attack', 'defend', 'dodge', 'charge', 'special']
ATK, DEF, DOD, CHG, SPC = range(5)
FINISH = ['none', 'burst', 'ringout', 'spin', 'draw']

def load(path):
    with open(os.path.join(ROOT, path)) as f:
        return json.load(f)

class Prng:
    def __init__(self, seed=1):
        s = seed % MOD
        self.state = s if s != 0 else 1
    def next_int(self):
        self.state = (16807 * self.state) % MOD
        return self.state
    def next_float(self):
        return float(self.next_int() - 1) / float(MOD - 1)
    def uniform(self, a, b):
        return a + (b - a) * self.next_float()
    def next_index(self, n):
        return int(math.floor(self.next_float() * n))

def mixed_seed(seed, stream):
    x = seed % MOD
    x = (x + 1 + stream * 1000003) % MOD
    for _ in range(4):
        x = (x * x + x * 48271 + 11 + stream) % MOD
    return x if x != 0 else 1

def for_stream(seed, stream):
    return Prng(mixed_seed(seed, stream))

def flatten(d, prefix=''):
    out = {}
    for k, v in d.items():
        if k.startswith('_'):
            continue
        key = prefix + k
        if isinstance(v, dict):
            out.update(flatten(v, key + '.'))
        elif isinstance(v, (int, float)) and not isinstance(v, bool):
            out[key] = float(v)
    return out

def ruleset(version='v1'):
    r = flatten(load('assets/data/combat/combat_ruleset_%s.json' % version))
    r['k_burst'] = -math.log(1.0 - r['burst.ref_p']) / r['burst.ref_x']
    return r

def parts():
    p = load('assets/data/parts/parts_catalogue.json')
    return p['blades'], p['discs'], p['tips']

def triples():
    b, d, t = parts()
    return [(x, y, z) for x in sorted(b) for y in sorted(d) for z in sorted(t)]

def build(blade, disc, tip, R):
    b, d, t = parts()
    s = dict(ap=b[blade]['ap'], li=b[blade]['li'], ms=d[disc]['ms'], st=d[disc]['st'], mb=t[tip]['mb'], sm=t[tip]['sm'])
    sc = [(s['ap'] + s['mb'] - 35) / 110.0, (s['st'] + s['li'] - 40) / 100.0, (s['sm'] - 15) / 70.0]
    top = 0
    for i in (1, 2):
        if sc[i] > sc[top]:
            top = i
    second = max(sc[i] for i in range(3) if i != top)
    s['type'] = top if sc[top] - second >= R['classification.type_margin'] else 3   # 0 A, 1 D, 2 S, 3 B
    mean_o = sum(sc[i] for i in range(3) if i != top) / 2.0
    s['domain'] = top if (sc[top] >= R['classification.identity_ratio'] * mean_o and mean_o > 0.0) else -1
    return s

def new_player(s, R):
    return dict(s=s, energy=R['energy.base'] + R['energy.per_sm'] * s['sm'], stab=R['stability.max'], pos=0.0, pp=0.0,
                meter=0.0, guard=0, dodge=0, combo=0, last=-1, rep=0)

def aggressive(a):
    return a == ATK or a == SPC

def legal(pl, R):
    out = [ATK, DEF, DOD, CHG]
    if pl['meter'] >= R['special.cost']:
        out.append(SPC)
    return out

def outgoing(R, me, act, opp_act, aggr):
    s = me['s']
    v = R['impact.ap_ref'] * (s['ap'] / R['impact.ap_ref']) ** R['impact.ap_exp'] * (1.0 + s['mb'] / R['impact.mobility_divisor'])
    v *= R['impact.action_mult.' + ACTIONS[act]]
    if s['type'] == 0: v *= R['impact.attack_type_synergy']
    if s['type'] == 3: v *= R['impact.balance_type_synergy']
    v *= 1.0 + R['impact.ap_spec_rate'] * max(0.0, s['ap'] - R['impact.ap_spec_threshold'])
    if s['domain'] == 0: v *= R['impact.attack_identity']
    if aggr:
        if me['combo'] >= 2:
            v *= 1.0 + R['impact.momentum_per_stack'] * min(int(R['impact.momentum_max_stacks']), me['combo'] - 1)
        if opp_act == DOD or opp_act == CHG:
            v *= R['impact.initiative_mult']
    if me['rep'] >= int(R['impact.adaptation_repeats']) and act != me['last']:
        v *= R['impact.adaptation_mult']
    return v

def snapshot(pl):
    return [pl['energy'], pl['stab'], pl['pos'], pl['pp'], pl['meter'], pl['guard'], pl['dodge'], pl['combo'], pl['rep'], pl['last']]

def play(blade_a, disc_a, tip_a, blade_b, disc_b, tip_b, seed, R=None, max_turns=400):
    """Plays one match with the shared action-selection stream (stream 99). Returns a list of turn dicts."""
    R = R or ruleset()
    pl = [new_player(build(blade_a, disc_a, tip_a, R), R), new_player(build(blade_b, disc_b, tip_b, R), R)]
    shared = for_stream(seed, 0)
    pp_ = [for_stream(seed, 1), for_stream(seed, 2)]
    chooser = for_stream(seed, 99)
    trace = []
    finished = False
    t = 0
    while not finished and t < max_turns:
        t += 1
        acts = []
        for i in range(2):
            lg = legal(pl[i], R)
            acts.append(lg[chooser.next_index(len(lg))])
        aggr = [aggressive(acts[0]), aggressive(acts[1])]
        stf = max(R['stability.arena_floor'], 1.0 - R['stability.arena_decay_per_turn'] * (t - 1))
        terms = [0.0, 0.0]
        for i in range(2):
            s = pl[i]['s']
            c = R['collision.mb_spec_rate'] * max(0.0, s['mb'] - R['collision.mb_spec_threshold'])
            if aggr[i]: c += R['collision.aggressive_bonus']
            if acts[i] == DOD:
                c -= R['collision.dodge_reduction'] * max(0.0, 1.0 - R['collision.dodge_decay'] * pl[i]['dodge'])
            terms[i] = c
        p_raw = R['collision.base'] + (pl[0]['s']['mb'] + pl[1]['s']['mb']) / R['collision.mobility_divisor'] + (terms[0] + terms[1])
        p_col = min(R['collision.max'], max(R['collision.min'], p_raw))
        collided = shared.next_float() < p_col
        pb_log = [-1.0, -1.0]; pr_log = [-1.0, -1.0]
        burst = [False, False]
        if collided:
            imp = [outgoing(R, pl[i], acts[i], acts[1 - i], aggr[i]) * pp_[i].uniform(R['impact.random_min'], R['impact.random_max']) for i in range(2)]
            inc = [0.0, 0.0]; prev = [0.0, 0.0]
            for j in range(2):
                tg = pl[j]; s = tg['s']; v = imp[1 - j]
                if acts[j] == DEF:
                    before = v
                    v *= 1.0 - max(R['incoming.defend_floor'], R['incoming.defend_fresh'] - R['incoming.defend_step'] * tg['guard'])
                    if s['type'] == 1: v *= R['incoming.defense_type_mult']
                    if s['domain'] == 1: v *= R['incoming.defense_identity_mult']
                    prev[j] = before - v
                if acts[j] == DOD: v *= R['incoming.dodge_incoming']
                if acts[j] == CHG: v *= R['incoming.charge_mult']
                if s['type'] == 3: v *= R['incoming.balance_type_mult']
                v *= 1.0 - R['incoming.st_spec_rate'] * max(0.0, s['st'] - R['incoming.st_spec_threshold'])
                v *= 1.0 - R['incoming.mb_evade'] * (s['mb'] - R['incoming.mb_evade_offset']) / R['incoming.mb_evade_range']
                inc[j] = v
            for j in range(2):
                tg = pl[j]; s = tg['s']
                st_eff = s['st'] * stf
                loss = (inc[j] / st_eff) * (1.0 - R['stability.li_stab'] * (s['li'] - R['stability.li_offset']) / R['stability.li_range'])
                push = (inc[j] / (s['ms'] + R['pressure.st_share'] * s['st'])) * R['pressure.scale']
                rel = tg['pp']
                tg['stab'] = max(0.0, tg['stab'] - loss)
                tg['pos'] += push + rel
                tg['pp'] = 0.0
                tg['energy'] -= inc[j] / R['energy.impact_divisor']
                tg['meter'] = min(R['special.meter_max'], tg['meter'] + R['special.hit_meter_gain'])
            for j in range(2):
                if prev[j] > 0.0 and R['defend_counter.ratio'] > 0.0:
                    h = pl[1 - j]; hs = h['s']
                    ret = R['defend_counter.ratio'] * prev[j]
                    h['stab'] = max(0.0, h['stab'] - ret / (hs['st'] * stf))
                    h['pos'] += ret / (hs['ms'] + R['pressure.st_share'] * hs['st']) * R['pressure.scale']
            for j in range(2):
                tg = pl[j]; s = tg['s']; hs = pl[1 - j]['s']
                x = inc[j] * (hs['ms'] / s['li']) * (1.0 + (R['stability.max'] - tg['stab']) / R['stability.max'])
                if acts[j] == CHG: x *= R['burst.charge_mult']
                if aggr[1 - j] and (acts[j] == DOD or acts[j] == CHG): x *= R['burst.initiative_mult']
                x *= 1.0 - R['burst.li_spec_rate'] * max(0.0, s['li'] - R['burst.li_spec_threshold'])
                pbj = min(R['burst.cap'], max(0.0, 1.0 - math.exp(-R['k_burst'] * x)))
                pb_log[j] = pbj
                burst[j] = pp_[j].next_float() < pbj
            for i in range(2):
                me = pl[i]; s = me['s']
                rec = imp[i] / (s['st'] * stf)
                rec *= 1.0 - R['stability.li_recoil'] * (s['li'] - R['stability.li_offset']) / R['stability.li_range']
                if s['type'] == 1: rec *= R['stability.defense_recoil_mult']
                if aggr[i] and me['combo'] >= 2:
                    rec *= 1.0 + R['impact.momentum_per_stack'] * min(int(R['impact.momentum_max_stacks']), me['combo'] - 1)
                me['stab'] = max(0.0, me['stab'] - rec)
        else:
            for i in range(2):
                if not aggr[i]:
                    pl[i]['pp'] += R['pressure.passive_gain']
        for i in range(2):
            me = pl[i]; s = me['s']
            drain = R['energy.drain_base'] + s['mb'] / R['energy.mb_drain_divisor']
            if s['type'] == 2: drain *= R['energy.stamina_type_mult']
            if s['type'] == 3: drain *= R['energy.balance_type_mult']
            if s['domain'] == 2: drain *= R['energy.stamina_identity_mult']
            drain *= 1.0 - R['energy.sm_spec_rate'] * max(0.0, s['sm'] - R['energy.sm_spec_threshold'])
            drain *= R['energy.drain_scale']
            me['energy'] -= drain
            if aggr[i]:
                me['energy'] -= R['energy.ap_cost'] * (s['ap'] - R['energy.ap_cost_offset']) / R['energy.ap_cost_range']
                if not collided: me['energy'] -= R['energy.whiff_cost']
            if me['pos'] > R['pressure.drain_threshold']:
                me['energy'] -= me['pos'] / R['pressure.drain_divisor']
            if acts[i] == CHG:
                g = R['special.charge_gain']
                if s['type'] == 2: g *= R['special.stamina_charge_mult']
                if s['type'] == 3: g *= R['special.balance_charge_mult']
                me['meter'] = min(R['special.meter_max'], me['meter'] + g)
            if acts[i] == SPC: me['meter'] = 0.0
            me['guard'] = me['guard'] + 1 if acts[i] == DEF else 0
            me['dodge'] = me['dodge'] + 1 if acts[i] == DOD else 0
            me['combo'] = me['combo'] + 1 if (collided and aggr[i]) else 0
            me['rep'] = me['rep'] + 1 if acts[i] == me['last'] else 1
            me['last'] = acts[i]
        lost = [0, 0]                       # finish codes: 0 none, 1 burst, 2 ringout, 3 spin
        for j in range(2):
            if burst[j]: lost[j] = 1
        if lost == [0, 0]:
            for j in range(2):
                me = pl[j]
                if me['pos'] > R['pressure.ringout_threshold']:
                    pr = min(R['pressure.ringout_cap'], R['pressure.ringout_base'] + (me['pos'] - R['pressure.ringout_threshold']) / R['pressure.ringout_slope_divisor'])
                    pr *= 1.0 - R['pressure.ms_spec_rate'] * max(0.0, me['s']['ms'] - R['pressure.ms_spec_threshold'])
                    pr = min(R['pressure.ringout_cap'], max(0.0, pr))
                    pr_log[j] = pr
                    if pp_[j].next_float() < pr: lost[j] = 2
        if lost == [0, 0]:
            for j in range(2):
                if pl[j]['energy'] <= 0.0: lost[j] = 3
        fin = [False, -1, 'none', '']
        if lost != [0, 0]:
            finished = True
            if lost[0] and lost[1]:
                if abs(pl[0]['stab'] - pl[1]['stab']) < 1e-9:
                    fin = [True, -1, 'draw', 'simultaneous']
                else:
                    w = 0 if pl[0]['stab'] > pl[1]['stab'] else 1
                    fin = [True, w, FINISH[lost[1 - w]], 'tiebreak']
            else:
                loser = 0 if lost[0] else 1
                fin = [True, 1 - loser, FINISH[lost[loser]], '']
        trace.append(dict(t=t, acts=acts, pc=p_col, col=collided, pb=pb_log, pr=pr_log, p=[snapshot(pl[0]), snapshot(pl[1])], fin=fin))
    return trace

def cases(n, master=20261114):
    """n reproducible (seed, build_a, build_b) cases from MINSTD."""
    tr = triples(); g = Prng(master); out = []
    for _ in range(n):
        a = tr[g.next_index(len(tr))]; b = tr[g.next_index(len(tr))]
        out.append(dict(seed=g.next_int(), a=''.join(a), b=''.join(b)))
    return out

def run_case(c, R=None):
    a, b = c['a'], c['b']
    return play(a[0:3], a[3:6], a[6:9], b[0:3], b[3:6], b[6:9], c['seed'], R)

if __name__ == '__main__':
    R = ruleset()
    cs = cases(5)
    for c in cs:
        tr = run_case(c, R)
        print(c, 'turns', len(tr), 'finish', tr[-1]['fin'])
    # golden stream values the GDScript test also pins
    g = Prng(1); print('minstd first five', [g.next_int() for _ in range(5)])
    print('mixed_seed(1,0), (1,1), (2026,99):', mixed_seed(1, 0), mixed_seed(1, 1), mixed_seed(2026, 99))
