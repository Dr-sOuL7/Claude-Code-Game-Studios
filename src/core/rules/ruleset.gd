class_name Ruleset
extends RefCounted
## A versioned, immutable set of combat tuning knobs (design/gdd/combat-system.md §8, §13).
##
## Every number the engine uses comes through here (TR-combat-008). A missing key is
## an error: `num()` pushes an error and returns NAN so the failure is visible, never
## a silent default. Published versions are never edited; add a new file instead.

const DATA_DIR := "res://assets/data/combat/"

var version: String = ""
var _data: Dictionary = {}


static func from_dict(data: Dictionary) -> Ruleset:
	var r := Ruleset.new()
	r._data = data.duplicate(true)
	r.version = String(data.get("version", ""))
	return r


## Loads `combat_ruleset_<version>.json`. Returns null with an error when absent or malformed.
static func load_version(ver: String) -> Ruleset:
	var path := DATA_DIR + "combat_ruleset_%s.json" % ver
	if not FileAccess.file_exists(path):
		push_error("Ruleset: no file at %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Ruleset: %s is not a JSON object" % path)
		return null
	var r := from_dict(parsed)
	if r.version != ver:
		push_error("Ruleset: file %s declares version '%s'" % [path, r.version])
		return null
	return r


## True when `group.key` exists and is a number.
func has(path: String) -> bool:
	var v: Variant = _lookup(path)
	return v is float or v is int


## Numeric knob at "group.key" (or "group.sub.key"). NAN + error when missing.
func num(path: String) -> float:
	var v: Variant = _lookup(path)
	if v is float or v is int:
		return float(v)
	push_error("Ruleset %s: missing numeric knob '%s'" % [version, path])
	return NAN


## String list knob (e.g. match.finish_order).
func strings(path: String) -> Array[String]:
	var out: Array[String] = []
	var v: Variant = _lookup(path)
	if v is Array:
		for item in v:
			out.append(String(item))
	else:
		push_error("Ruleset %s: missing list knob '%s'" % [version, path])
	return out


func _lookup(path: String) -> Variant:
	var node: Variant = _data
	for part in path.split("."):
		if node is Dictionary and (node as Dictionary).has(part):
			node = node[part]
		else:
			return null
	return node
