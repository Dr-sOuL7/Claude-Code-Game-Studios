class_name PartsCatalogue
extends RefCounted
## The fixed SPINFORGE component set: 8 blades, 8 discs, 8 tips and 15 cosmetic cores.
##
## Loaded once from `assets/data/parts/` (or built from a Dictionary in tests).
## Conservation is a property of the data, enforced by tests, not by this class.
## Single-threaded use only; instances are immutable after construction.

const CATALOGUE_PATH := "res://assets/data/parts/parts_catalogue.json"
const CORES_PATH := "res://assets/data/parts/parts_cores.json"

## id -> {"ap": int, "li": int, "label": String}
var blades: Dictionary = {}
## id -> {"ms": int, "st": int, "label": String}
var discs: Dictionary = {}
## id -> {"mb": int, "sm": int, "label": String}
var tips: Dictionary = {}
## id -> {"name": String, "primary": String, "secondary": String, "theme": String}
var cores: Dictionary = {}


## Builds a catalogue from already-parsed data (the shape of parts_catalogue.json,
## optionally with a "cores" key from parts_cores.json).
static func from_dict(data: Dictionary, cores_data: Dictionary = {}) -> PartsCatalogue:
	var cat := PartsCatalogue.new()
	cat.blades = _copy_parts(data.get("blades", {}))
	cat.discs = _copy_parts(data.get("discs", {}))
	cat.tips = _copy_parts(data.get("tips", {}))
	cat.cores = _copy_parts(cores_data.get("cores", {}))
	return cat


## Loads the committed data files. Returns null (with an error) if either file is
## missing or malformed, so a caller can never run with a partial catalogue.
static func load_default() -> PartsCatalogue:
	var parts: Variant = _read_json(CATALOGUE_PATH)
	var cores_data: Variant = _read_json(CORES_PATH)
	if not (parts is Dictionary) or not (cores_data is Dictionary):
		push_error("PartsCatalogue: could not load %s or %s" % [CATALOGUE_PATH, CORES_PATH])
		return null
	return from_dict(parts, cores_data)


## Sorted ids, so iteration order is stable across platforms.
func blade_ids() -> Array[String]:
	return _sorted_keys(blades)


func disc_ids() -> Array[String]:
	return _sorted_keys(discs)


func tip_ids() -> Array[String]:
	return _sorted_keys(tips)


func core_ids() -> Array[String]:
	return _sorted_keys(cores)


## Every [blade_id, disc_id, tip_id] triple (512 for the shipped set), in sorted order.
func all_part_triples() -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	for b in blade_ids():
		for d in disc_ids():
			for t in tip_ids():
				out.append(PackedStringArray([b, d, t]))
	return out


static func _copy_parts(src: Dictionary) -> Dictionary:
	var out := {}
	for id in src.keys():
		out[String(id)] = (src[id] as Dictionary).duplicate()
	return out


static func _sorted_keys(d: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for k in d.keys():
		keys.append(String(k))
	keys.sort()
	return keys


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	return JSON.parse_string(text)
