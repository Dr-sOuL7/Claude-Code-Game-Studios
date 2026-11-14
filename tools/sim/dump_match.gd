extends SceneTree
## Batch trace dumper for the differential check (story combat-engine/004).
##
## godot --headless --path . -s res://tools/sim/dump_match.gd -- <cases.jsonl> <out.jsonl> [ruleset_version]
## Each cases line: {"seed": int, "a": "B05D05T05", "b": "B01D08T06"}. Each output line:
## {"case": {...}, "turns": [...]} in the format of MatchTrace. Exit 0 on success, 2 on bad input.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <cases.jsonl> <out.jsonl> [ruleset_version]")
		quit(2)
		return
	var params := CombatParams.load_version(args[2] if args.size() > 2 else "v1")
	var cat := PartsCatalogue.load_default()
	if params == null or cat == null:
		printerr("dump_match: could not load ruleset or parts")
		quit(2)
		return
	var cases_text := FileAccess.get_file_as_string(args[0])
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	if cases_text.is_empty() or out == null:
		printerr("dump_match: cannot read %s or write %s" % [args[0], args[1]])
		quit(2)
		return
	var count := 0
	for line in cases_text.split("\n", false):
		var c: Variant = JSON.parse_string(line)
		if not (c is Dictionary):
			printerr("dump_match: bad case line: %s" % line)
			quit(2)
			return
		var trace := MatchTrace.run_case(params, cat, int(c["seed"]), String(c["a"]), String(c["b"]))
		out.store_line(JSON.stringify({"case": c, "turns": trace}))
		count += 1
	out.close()
	print("dumped %d matches" % count)
	quit(0)
