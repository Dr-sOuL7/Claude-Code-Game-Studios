# PROTOTYPE - NOT FOR PRODUCTION
"""Reference model of Beyblade: Arena combat, spec v0.1 (audit tool, NOT shipping code).

Purpose: check that the audited rules are numerically well-behaved (bounded
probabilities, guaranteed termination) and surface balance risks. Python is used
only because the Godot binary was not available when this was written; the
shipping engine will be GDScript and must reproduce these rules.
"""
import math, random, itertools, collections, statistics, sys, json

B = {'B01':(40,40),'B02':(50,30),'B03':(60,20),'B04':(30,50),'B05':(20,60),'B06':(55,25),'B07':(45,35),'B08':(35,45)}
D = {'D01':(50,50),'D02':(65,35),'D03':(80,20),'D04':(35,65),'D05':(20,80),'D06':(70,30),'D07':(60,40),'D08':(40,60)}
T = {'T01':(50,50),'T02':(70,30),'T03':(85,15),'T04':(30,70),'T05':(15,85),'T06':(60,40),'T07':(40,60),'T08':(75,25)}

# ---- tuning knobs (all data-driven in the real game) -------------------------
K = dict(
    burst_ref_x=106.0, burst_ref_p=0.05, burst_cap=0.75,   # calibration: median Attack hit on neutral = 5%
    pressure_scale=1.0, stab_max=100.0, special_cost=100.0,
    energy_div=20.0, ringout_threshold=120.0, ringout_base=0.25, ringout_cap=0.90,
    # ---- v0.2 candidate levers, ALL OFF by default (= v0.1 behaviour) ----
    attack_cost=0.0,        # extra energy lost by a player who commits ATTACK/SPECIAL (every turn)
    whiff_cost=0.0,         # extra energy lost by ATTACK/SPECIAL when no collision happens
    defend_counter=0.0,     # share of damage prevented by DEFEND returned to the hitter as stability loss + pressure
    dodge_incoming=1.0,     # incoming-damage multiplier when the target DODGEd and a collision still happened
    evade_bonus=0.0,        # impact bonus on the next aggressive action after a DODGE that avoided collision
    init_mult=1.08,         # initiative bonus vs DODGE/CHARGE (spec: 1.08)
    hit_meter_gain=0.0,     # special_meter gained by the target each time it is hit
    special_pierce=0.0,     # share of DEFEND mitigation ignored by SPECIAL
    ap_exp=1.0,             # effective AP = 40*(AP/40)^ap_exp (1.0 = spec, linear)
    mb_drain_div=80.0,      # passive drain = 1 + MB/mb_drain_div (spec: 80)
    mb_evade=0.0,           # incoming *= 1 - mb_evade*(MB-15)/70 (speed makes clean hits harder)
    mb_dodge=0.0,           # DODGE collision reduction += mb_dodge*(MB-15)/70
    li_recoil=0.0,          # recoil *= 1 - li_recoil*(LI-20)/40  (LI 20..60 -> 0..li_recoil reduction)
    li_stab=0.0,            # stability loss *= 1 - li_stab*(LI-20)/40
    ap_cost=0.0,            # ATTACK/SPECIAL energy cost per turn = ap_cost*(AP-20)/40
    mb_cap_bonus=0.0,       # collision cap raised by mb_cap_bonus*(MB-50)/35 for the dodging side? (unused)
    dodge_collision=0.25,   # collision-probability reduction from DODGE (spec: 0.25)
    dodge_decay=0.10,       # per-consecutive-use decay of DODGE (spec: 0.10)
    stamina_drain=0.8,      # Stamina-type drain multiplier (spec: 0.8)
    energy_base=0.0,        # flat energy reserve added to 1.2*SM (spec: 0)
    drain_scale=1.0,        # multiplier on passive drain (spec: 1)
    pressure_st_share=0.0,  # pressure divisor = MS + share*ST (spec: 0 => MS only)
)
K['k_burst'] = -math.log(1 - K['burst_ref_p']) / K['burst_ref_x']

AGGR = ('ATK', 'SPC')

def profiles():
    out = []
    for (bn,(ap,li)),(dn,(ms,st)),(tn,(mb,sm)) in itertools.product(B.items(), D.items(), T.items()):
        out.append(classify(dict(name=bn+dn+tn, AP=ap, LI=li, MS=ms, ST=st, MB=mb, SM=sm)))
    return out

def classify(p):
    """Normalised scores (each 0..1 over the content set). MS is NOT used: MS+ST is constant."""
    off = (p['AP'] + p['MB'] - 35) / 110.0
    de  = (p['ST'] + p['LI'] - 40) / 100.0
    sta = (p['SM'] - 15) / 70.0
    sc = {'A': off, 'D': de, 'S': sta}
    ranked = sorted(sc.items(), key=lambda kv: -kv[1])
    top, second = ranked[0], ranked[1]
    p['scores'] = sc
    p['type'] = top[0] if top[1] - second[1] >= 0.15 else 'B'
    others = [v for k, v in sc.items() if k != top[0]]
    mean_o = sum(others) / 2
    p['domain'] = top[0] if (top[1] >= 1.25 * mean_o and mean_o > 0) else None
    return p

STAT = collections.Counter()   # invariant bookkeeping
def note(name, v):
    s = STAT[name + '_min'] if (name + '_min') in STAT else None
    STAT[name + '_min'] = v if s is None else min(s, v)
    s = STAT[name + '_max'] if (name + '_max') in STAT else None
    STAT[name + '_max'] = v if s is None else max(s, v)
    if v != v or v in (float('inf'), float('-inf')):
        STAT['NONFINITE_' + name] += 1

def new_state(p):
    return dict(p=p, energy=K['energy_base'] + 1.2 * p['SM'], stab=K['stab_max'], pos=0.0, pp=0.0, meter=0.0,
                guard=0, dodge=0, combo=0, last=None, rep=0, evade=False)

# ---- policies ---------------------------------------------------------------
def pol_atk(me, op, t, rng): return 'SPC' if me['meter'] >= K['special_cost'] else 'ATK'
def pol_def(me, op, t, rng): return 'DEF'
def pol_dod(me, op, t, rng): return 'DOD'
def pol_chg(me, op, t, rng): return 'SPC' if me['meter'] >= K['special_cost'] else 'CHG'
def pol_rnd(me, op, t, rng):
    acts = ['ATK', 'DEF', 'DOD', 'CHG'] + (['SPC'] if me['meter'] >= K['special_cost'] else [])
    return rng.choice(acts)
_ROT = ['ATK', 'DEF', 'ATK', 'DOD', 'CHG', 'ATK']
def pol_rot(me, op, t, rng):
    if me['meter'] >= K['special_cost']: return 'SPC'
    return _ROT[t % len(_ROT)]
def pol_adp(me, op, t, rng):
    """Heuristic: attack when ahead on energy, otherwise defend; use Special when ready and ahead."""
    if me['meter'] >= K['special_cost']: return 'SPC'
    if me['energy'] >= op['energy']: return 'ATK'
    return 'DEF' if me['guard'] < 2 else 'ATK'
POLICIES = dict(ATK=pol_atk, DEF=pol_def, DOD=pol_dod, CHG=pol_chg, RND=pol_rnd, ROT=pol_rot, ADP=pol_adp)

# ---- one turn ---------------------------------------------------------------
def play(p0, p1, pol0, pol1, rng, max_turns=400, trace=None):
    S = [new_state(p0), new_state(p1)]
    pols = [pol0, pol1]
    collisions = 0
    maxpos = 0.0
    for t in range(1, max_turns + 1):
        acts = [pols[i](S[i], S[1 - i], t, rng) for i in range(2)]
        for i in range(2):
            assert acts[i] != 'SPC' or S[i]['meter'] >= K['special_cost'], 'illegal special'
        dodge_eff = [max(0.0, 1 - K['dodge_decay'] * S[i]['dodge']) if acts[i] == 'DOD' else 0.0 for i in range(2)]
        stfac = max(0.25, 1 - 0.005 * (t - 1))     # arena destabilisation applies to ST

        # collision probability
        P = 0.4 + (S[0]['p']['MB'] + S[1]['p']['MB']) / 200.0
        for i in range(2):
            P += 0.005 * max(0, S[i]['p']['MB'] - 70)
            if acts[i] in AGGR: P += 0.15
            if acts[i] == 'DOD': P -= (K['dodge_collision'] + K['mb_dodge'] * (S[i]['p']['MB'] - 15) / 70.0) * dodge_eff[i]
        Pc = min(0.9, max(0.2, P))
        note('P_collision', Pc)
        collided = rng.random() < Pc

        burst = [False, False]
        if collided:
            collisions += 1
            imp = [0.0, 0.0]
            for i in range(2):
                me, p = S[i], S[i]['p']; op = S[1 - i]
                base = 40.0 * (p['AP'] / 40.0) ** K['ap_exp'] * (1 + p['MB'] / 120.0)
                m = {'ATK': 1.5, 'DEF': 1.0, 'DOD': 0.7, 'CHG': 0.5, 'SPC': 5.0}[acts[i]]
                v = base * m
                if p['type'] == 'A': v *= 1.15
                if p['type'] == 'B': v *= 1.05
                v *= 1 + 0.006 * max(0, p['AP'] - 50)
                if p['domain'] == 'A': v *= 1.08
                if acts[i] in AGGR:
                    stacks = min(3, me['combo'] - 1) if me['combo'] >= 2 else 0
                    v *= 1 + 0.05 * stacks
                    if acts[1 - i] in ('DOD', 'CHG'): v *= K['init_mult']
                    if me['evade']: v *= 1 + K['evade_bonus']
                if me['rep'] >= 2 and acts[i] != me['last']: v *= 1.05
                v *= rng.uniform(0.9, 1.1)
                imp[i] = v
                note('impact', v)
            for j in range(2):                       # j is the target, i the hitter
                i = 1 - j
                tgt, tp = S[j], S[j]['p']; hit = S[i]['p']
                inc = imp[i]
                prevented = 0.0
                if acts[j] == 'DEF':
                    before = inc
                    red = max(0.05, 0.40 - 0.10 * tgt['guard'])
                    if acts[i] == 'SPC': red *= 1 - K['special_pierce']
                    inc *= 1 - red
                    if tp['type'] == 'D': inc *= 0.8
                    if tp['domain'] == 'D': inc *= 0.92
                    prevented = before - inc
                if acts[j] == 'DOD': inc *= K['dodge_incoming']
                if acts[j] == 'CHG': inc *= 1.25
                if tp['type'] == 'B': inc *= 0.95
                inc *= 1 - 0.005 * max(0, tp['ST'] - 70)
                inc *= 1 - K['mb_evade'] * (tp['MB'] - 15) / 70.0
                est = tp['ST'] * stfac
                tgt['stab'] = max(0.0, tgt['stab'] - (inc / est) * (1 - K['li_stab'] * (tp['LI'] - 20) / 40.0))
                tgt['pos'] += (inc / (tp['MS'] + K['pressure_st_share'] * tp['ST'])) * K['pressure_scale'] + tgt['pp']
                tgt['pp'] = 0.0
                tgt['energy'] -= inc / K['energy_div']
                tgt['meter'] = min(100.0, tgt['meter'] + K['hit_meter_gain'])
                if K['defend_counter'] and prevented > 0:       # DEFEND punishes the hitter
                    hp = S[i]['p']
                    ret = K['defend_counter'] * prevented
                    S[i]['stab'] = max(0.0, S[i]['stab'] - ret / (hp['ST'] * stfac))
                    S[i]['pos'] += ret / (hp['MS'] + K['pressure_st_share'] * hp['ST']) * K['pressure_scale']
                # burst
                x = inc * (hit['MS'] / tp['LI']) * (1 + (K['stab_max'] - tgt['stab']) / K['stab_max'])
                if acts[j] == 'CHG': x *= 1.2
                if acts[i] in AGGR and acts[j] in ('DOD', 'CHG'): x *= 1.05
                x *= 1 - 0.007 * max(0, tp['LI'] - 50)
                pb = min(K['burst_cap'], 1 - math.exp(-K['k_burst'] * x))
                note('P_burst', pb); note('x_burst', x)
                if rng.random() < pb: burst[j] = True
            for i in range(2):                        # recoil on the hitter
                p = S[i]['p']
                rec = imp[i] / (p['ST'] * stfac)
                rec *= 1 - K['li_recoil'] * (p['LI'] - 20) / 40.0
                if p['type'] == 'D': rec *= 0.85
                if acts[i] in AGGR and S[i]['combo'] >= 2: rec *= 1 + 0.05 * min(3, S[i]['combo'] - 1)
                S[i]['stab'] = max(0.0, S[i]['stab'] - rec)
        else:
            for i in range(2):
                if acts[i] not in AGGR: S[i]['pp'] += 3.0

        # system effects
        for i in range(2):
            me, p = S[i], S[i]['p']
            drain = 1 + p['MB'] / K['mb_drain_div']
            if p['type'] == 'S': drain *= K['stamina_drain']
            if p['type'] == 'B': drain *= 0.95
            if p['domain'] == 'S': drain *= 0.92
            drain *= 1 - 0.004 * max(0, p['SM'] - 70)
            drain *= K['drain_scale']
            me['energy'] -= drain
            if acts[i] in AGGR:
                me['energy'] -= K['attack_cost'] + K['ap_cost'] * (p['AP'] - 20) / 40.0
                if not collided: me['energy'] -= K['whiff_cost']
            me['evade'] = (not collided) and acts[i] == 'DOD'
            if me['pos'] > 70: me['energy'] -= me['pos'] / 50.0
            if acts[i] == 'CHG':
                g = 15.0
                if p['type'] == 'S': g *= 1.25
                if p['type'] == 'B': g *= 1.05
                me['meter'] = min(100.0, me['meter'] + g)
            if acts[i] == 'SPC': me['meter'] = 0.0
            me['guard'] = me['guard'] + 1 if acts[i] == 'DEF' else 0
            me['dodge'] = me['dodge'] + 1 if acts[i] == 'DOD' else 0
            if collided and acts[i] in AGGR: me['combo'] += 1
            else: me['combo'] = 0
            me['rep'] = me['rep'] + 1 if acts[i] == me['last'] else 1
            me['last'] = acts[i]
            maxpos = max(maxpos, me['pos'])
            note('energy', me['energy']); note('pos', me['pos'])

        # victory
        out = [None, None]     # how each player lost
        for j in range(2):
            if burst[j]: out[j] = 'burst'
        if out == [None, None]:
            for j in range(2):
                me = S[j]; p = me['p']
                if me['pos'] > K['ringout_threshold']:
                    pr = min(K['ringout_cap'], K['ringout_base'] + (me['pos'] - K['ringout_threshold']) / 100.0)
                    pr *= 1 - 0.005 * max(0, p['MS'] - 70)
                    note('P_ringout', pr)
                    if rng.random() < pr: out[j] = 'ringout'
        if out == [None, None]:
            for j in range(2):
                if S[j]['energy'] <= 0: out[j] = 'spin'
        if out != [None, None]:
            if out[0] and out[1]:
                # simultaneous: lower... tie-break on remaining stability, else draw
                if abs(S[0]['stab'] - S[1]['stab']) < 1e-9: return dict(w=None, how='draw', turns=t, col=collisions, maxpos=maxpos)
                w = 0 if S[0]['stab'] > S[1]['stab'] else 1
                return dict(w=w, how='tiebreak:' + out[1 - w], turns=t, col=collisions, maxpos=maxpos)
            loser = 0 if out[0] else 1
            return dict(w=1 - loser, how=out[loser], turns=t, col=collisions, maxpos=maxpos)
    return dict(w=None, how='timeout', turns=max_turns, col=collisions, maxpos=maxpos)
