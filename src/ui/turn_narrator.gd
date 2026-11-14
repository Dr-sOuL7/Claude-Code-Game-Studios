class_name TurnNarrator
extends RefCounted
## Turns a resolved turn's engine events into short player-facing lines.
## Pure formatting over the event schema in src/core/combat/README.md.

const ACTION_LABELS: Array[String] = ["ATTACK", "DEFEND", "DODGE", "CHARGE", "SPECIAL"]
const SHOW_BURST_RISK_FROM := 0.005


static func action_line(actions: Array[int], names: Array[String]) -> String:
	return "%s: %s   vs   %s: %s" % [names[0], tr_action(actions[0]), names[1], tr_action(actions[1])]


static func tr_action(a: int) -> String:
	return TranslationServer.translate(ACTION_LABELS[a])


static func describe(events: Array[Dictionary], names: Array[String]) -> PackedStringArray:
	var out := PackedStringArray()
	for e in events:
		match e["type"]:
			"collision_roll":
				if e["collided"]:
					out.append(TranslationServer.translate("CLASH! (%d%% collision chance)") % roundi(e["probability"] * 100.0))
				else:
					out.append(TranslationServer.translate("No contact - they circle past each other (%d%% chance to clash)") % roundi(e["probability"] * 100.0))
			"impact":
				out.append(TranslationServer.translate("Hit on %s: %d impact (stability -%.1f, pushed +%.1f)") % [
						names[e["target"]], roundi(e["incoming"]), e["stability_loss"], e["pressure_gain"]])
			"defend_counter":
				out.append(TranslationServer.translate("Guard counter! %s is thrown back (stability -%.1f, pushed +%.1f)") % [
						names[e["hitter"]], e["stability_loss"], e["pressure_gain"]])
			"burst_check":
				if e["burst"]:
					out.append(TranslationServer.translate("BURST! %s - broken apart!") % names[e["target"]])
				elif e["probability"] >= SHOW_BURST_RISK_FROM:
					out.append(TranslationServer.translate("Burst risk for %s: %.1f%% - held together") % [names[e["target"]], e["probability"] * 100.0])
			"passive_pressure":
				out.append(TranslationServer.translate("Pressure stored by %s: +%d (released at the next clash)") % [names[e["player"]], roundi(e["gain"])])
			"ringout_check":
				if e["ringout"]:
					out.append(TranslationServer.translate("RING OUT! %s - out of the arena!") % names[e["player"]])
				else:
					out.append(TranslationServer.translate("Ring-out risk for %s: %d%% - still in") % [names[e["player"]], roundi(e["probability"] * 100.0)])
			"upkeep":
				if e["whiff_cost"] > 0.0:
					out.append(TranslationServer.translate("Missed attack by %s (-%d energy)") % [names[e["player"]], roundi(e["whiff_cost"])])
			"match_finished":
				out.append(finish_line(e["winner"], e["finish"], e["detail"], names))
	return out


static func finish_line(winner: int, finish: String, detail: String, names: Array[String]) -> String:
	if winner < 0:
		return TranslationServer.translate("DRAW - both tops fall at once!")
	var how := {"burst": "BURST FINISH", "ringout": "RING-OUT FINISH", "spin": "SPIN FINISH"}.get(finish, finish.to_upper()) as String
	var line := TranslationServer.translate("WINNER: %s by %s") % [names[winner], TranslationServer.translate(how)]
	if detail == "tiebreak":
		line += TranslationServer.translate(" (both fell - more stability left)")
	return line
