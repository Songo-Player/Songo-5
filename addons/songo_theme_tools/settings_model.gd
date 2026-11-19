@tool
extends RefCounted

# The "settings" block of a theme.json, as a list of entries the settings
# window edits. Each entry:
#   key            the setting's key (what theme scripts read)
#   committed_key  key as of the last commit; conditions in other settings
#                  are re-pointed from it when a rename is committed
#   data           the setting's JSON object (values, labels, default, ...)
#   kind           how the editor presents it (see KINDS); not stored in JSON
#   raw            the setting's original text, written back unchanged when
#                  the entry isn't dirty
#   dirty          edited since load
#   key_auto       new setting whose key still follows its display name
#   notes          things fixed up on load, shown to the user
#
# What the app expects (ThemeManager, setting_line_item.gd):
#   values         2+ options. [true, false] makes an on/off toggle.
#   labels         text shown for each value; required for anything but a
#                  toggle (for toggles: [text when on, text when off]).
#   default        one of values.
#   display_name   the name players see; description is shown under it.
#   dependents     components that read the setting. Required on Songo
#                  Classic's settings (ThemeManager reads it to give themes
#                  that borrow its components the right defaults), so it's
#                  always written.
#   visible_when   { other_key: [values] }: only shown while every listed
#                  setting has one of its listed values.

const ThemeJson := preload("theme_json.gd")

# What the app shows for a toggle without labels (setting_line_item.tscn's
# SettingValueTrueLabel / SettingValueFalseLabel text).
const TOGGLE_ON_TEXT := "True"
const TOGGLE_OFF_TEXT := "False"

const KIND_TOGGLE := "toggle"
const KIND_TEXT := "text"
const KIND_NUMBER := "number"
const KIND_COLOR := "color"
const KINDS := [KIND_TOGGLE, KIND_TEXT, KIND_NUMBER, KIND_COLOR]
const KIND_NAMES := {
	KIND_TOGGLE: "On / off toggle",
	KIND_TEXT: "Choice of options",
	KIND_NUMBER: "Choice of numbers",
	KIND_COLOR: "Choice of colors",
}
const KIND_HINTS := {
	KIND_TOGGLE: "Players flip it on or off. Scripts get true or false.",
	KIND_TEXT: "Players step through a list of named options. Scripts get the option's stored value (text).",
	KIND_NUMBER: "Players step through a list of numbers, e.g. sizes or counts. Scripts get the number.",
	KIND_COLOR: "Players step through a list of colors. Scripts get the color as hex text without # (e.g. \"f2c230\"); use Color(value) or Color.html(value).",
}

# ThemeManager.THEMABLE_COMPONENTS
const COMPONENTS := ["main_menu", "background_root", "header", "main_song_view", "footer", "song_follow", "collection_button", "collection_header"]

# Key order for settings written from scratch; existing settings keep theirs.
const KEY_ORDER := ["values", "labels", "default", "display_name", "description", "dependents", "visible_when"]

var entries: Array = []
var components := {}
var error := ""

# ---- Loading ----

func load_from_text(text: String) -> bool:
	entries.clear()
	components = {}
	error = ""
	var data := ThemeJson.parse(text)
	if data.is_empty():
		error = "theme.json didn't parse. Fix it by hand first."
		return false
	if data.get("components") is Dictionary:
		components = data["components"]
	var settings = data.get("settings", {})
	if not settings is Dictionary:
		error = "\"settings\" in theme.json isn't an object, so it can't be edited here."
		return false
	var raw := {}
	for pair in ThemeJson.object_entries(text, "settings"):
		raw[pair[0]] = pair[1]
	for key in settings:
		var info = settings[key]
		var entry := _make_entry(key, (info as Dictionary).duplicate(true) if info is Dictionary else {})
		entry["raw"] = raw.get(key, "")
		entry["dirty"] = not entry["notes"].is_empty()
		entries.append(entry)
	return true

func _make_entry(key: String, data: Dictionary) -> Dictionary:
	var entry := {
		"key": key, "committed_key": key, "data": data, "kind": detect_kind(key, data),
		"raw": "", "dirty": true, "key_auto": false, "notes": PackedStringArray(),
	}
	var values = data.get("values")
	if values is Array and entry["kind"] != KIND_TOGGLE:
		var labels = data.get("labels")
		if not labels is Array or labels.size() != values.size():
			var fixed := []
			for i in values.size():
				fixed.append(str(labels[i]) if labels is Array and i < labels.size() else display_value(values[i]))
			data["labels"] = fixed
			entry["notes"].append("Its labels were missing or didn't match its options, which the app needs to show them. They've been filled in from the values; save to write them.")
	# A missing "dependents" only matters on Songo Classic; it's added when the
	# setting is next edited (format_setting) rather than flagged here.
	return entry

static func detect_kind(key: String, data: Dictionary) -> String:
	var values = data.get("values", [])
	if not values is Array or values.is_empty():
		return KIND_TEXT
	if values.size() == 2 and values.all(func(v): return v is bool) and values[0] != values[1]:
		return KIND_TOGGLE
	if values.all(func(v): return v is float or v is int):
		return KIND_NUMBER
	if values.all(func(v): return v is String and is_hex_color(v)):
		# Short hex-looking words ("add", "bed") shouldn't count as colors.
		var hint := (key + " " + str(data.get("display_name", ""))).to_lower()
		if values.any(func(v): return v.trim_prefix("#").length() >= 6) or "color" in hint or "colour" in hint:
			return KIND_COLOR
	return KIND_TEXT

static func is_hex_color(value: String) -> bool:
	var re := RegEx.create_from_string("^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
	return re.search(value) != null

# ---- Adding, removing, ordering ----

func add_setting(kind: String, at: int) -> Dictionary:
	var display_name: String = {
		KIND_TOGGLE: "New Toggle", KIND_TEXT: "New Choice", KIND_NUMBER: "New Number", KIND_COLOR: "New Color",
	}[kind]
	var data := {"values": [], "labels": [], "default": null, "display_name": display_name, "dependents": []}
	match kind:
		KIND_TOGGLE:
			data = {"values": [true, false], "default": true, "display_name": display_name, "dependents": []}
		KIND_TEXT:
			data["values"] = ["option_a", "option_b"]
			data["labels"] = ["Option A", "Option B"]
		KIND_NUMBER:
			data["values"] = [1.0, 2.0, 3.0]
			data["labels"] = ["1", "2", "3"]
		KIND_COLOR:
			data["values"] = ["f2c230", "6ec6ff"]
			data["labels"] = ["Yellow", "Blue"]
	if data["default"] == null:
		data["default"] = data["values"][0]
	var entry := _make_entry(unique_key(slug(display_name)), data)
	entry["kind"] = kind
	entry["notes"] = PackedStringArray()
	entry["key_auto"] = true
	at = clampi(at, 0, entries.size())
	entries.insert(at, entry)
	return entry

func duplicate_setting(index: int) -> Dictionary:
	var source: Dictionary = entries[index]
	var data: Dictionary = source["data"].duplicate(true)
	data["display_name"] = "%s Copy" % data.get("display_name", source["key"])
	var entry := _make_entry(unique_key(source["key"] + "_copy"), data)
	entry["kind"] = source["kind"]
	entry["notes"] = PackedStringArray()
	entries.insert(index + 1, entry)
	return entry

# Settings whose conditions mention this one (they lose those conditions).
func settings_depending_on(key: String) -> Array:
	return entries.filter(func(e): return e["key"] != key and _conditions(e).has(key))

func remove_setting(index: int) -> void:
	var key: String = entries[index]["key"]
	entries.remove_at(index)
	for e in entries:
		if _conditions(e).has(key):
			_conditions(e).erase(key)
			_tidy_conditions(e)
			e["dirty"] = true

func move_setting(index: int, delta: int) -> int:
	var to := clampi(index + delta, 0, entries.size() - 1)
	if to != index:
		var entry = entries[index]
		entries.remove_at(index)
		entries.insert(to, entry)
		# Order is part of the file, so every setting is rewritten in order;
		# untouched ones still keep their original text.
		_order_changed = true
	return to

var _order_changed := false

# ---- Keys ----

static func slug(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	while "__" in out:
		out = out.replace("__", "_")
	out = out.strip_edges().trim_prefix("_").trim_suffix("_")
	if out != "" and out[0] >= "0" and out[0] <= "9":
		out = "_" + out
	return out

func unique_key(base: String, ignore: Dictionary = {}) -> String:
	if base == "":
		base = "setting"
	var key := base
	var n := 2
	while entries.any(func(e): return e != ignore and e["key"] == key):
		key = "%s_%d" % [base, n]
		n += 1
	return key

static func is_valid_key(key: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$").search(key) != null

func key_taken(key: String, by: Dictionary) -> bool:
	return entries.any(func(e): return e != by and e["key"] == key)

# Points other settings' conditions at the entry's new key, once it's a valid
# and unique one. Called when the key field is committed (not on every
# keystroke, so a key typed partway through can't collide with another).
func commit_key(entry: Dictionary) -> void:
	var old: String = entry["committed_key"]
	var new: String = entry["key"]
	if old == new or not is_valid_key(new) or key_taken(new, entry):
		return
	for e in entries:
		var conditions := _conditions(e)
		if e != entry and conditions.has(old):
			var rebuilt := {}
			for k in conditions:
				rebuilt[new if k == old else k] = conditions[k]
			e["data"]["visible_when"] = rebuilt
			e["dirty"] = true
	entry["committed_key"] = new

# Component switches ({"setting": key, "scenes": {...}}) that pick a scene by
# this setting's value: { component: [scene keys] }.
func component_switches(key: String) -> Dictionary:
	var out := {}
	for component in components:
		var c = components[component]
		if c is Dictionary and c.get("setting") == key and c.get("scenes") is Dictionary:
			out[component] = c["scenes"].keys()
	return out

# ---- Options ----

# A committed change to an option's value: conditions in other settings that
# listed the old value now list the new one. Skipped when the old value still
# belongs to another option (it'd be ambiguous which one they meant).
func commit_option_value(entry: Dictionary, old_value, new_value) -> void:
	if _same(old_value, new_value) or entry["data"]["values"].any(func(v): return _same(v, old_value)):
		return
	for e in entries:
		var values = _conditions(e).get(entry["key"])
		if e != entry and values is Array:
			for i in values.size():
				if _same(values[i], old_value):
					values[i] = new_value
					e["dirty"] = true

func remove_option(entry: Dictionary, index: int) -> void:
	var data: Dictionary = entry["data"]
	var removed = data["values"][index]
	var was_default := _same(data.get("default"), removed)
	data["values"].remove_at(index)
	data["labels"].remove_at(index)
	if was_default and not data["values"].is_empty():
		data["default"] = data["values"][mini(index, data["values"].size() - 1)]
	if not data["values"].any(func(v): return _same(v, removed)):
		for e in entries:
			var values = _conditions(e).get(entry["key"])
			if e != entry and values is Array:
				for i in range(values.size() - 1, -1, -1):
					if _same(values[i], removed):
						values.remove_at(i)
						e["dirty"] = true
	entry["dirty"] = true

# Switching type converts the options where it can and keeps them lined up
# with any conditions that point at them.
func set_kind(entry: Dictionary, kind: String) -> void:
	var old_kind: String = entry["kind"]
	if old_kind == kind:
		return
	var data: Dictionary = entry["data"]
	var old_values: Array = data.get("values", []).duplicate()
	var old_labels: Array = data.get("labels", []).duplicate() if data.get("labels") is Array else []
	var default_index := _index_of(old_values, data.get("default"))
	var new_values := []
	var new_labels := []
	match kind:
		KIND_TOGGLE:
			new_values = [true, false]
			var on_label = old_labels[0] if old_labels.size() > 0 else TOGGLE_ON_TEXT
			var off_label = old_labels[1] if old_labels.size() > 1 else TOGGLE_OFF_TEXT
			new_labels = [on_label, off_label]
		KIND_TEXT:
			for i in old_values.size():
				var label: String = old_labels[i] if i < old_labels.size() else display_value(old_values[i])
				new_labels.append(label)
				new_values.append(old_values[i] if old_values[i] is String else (slug(label) if slug(label) != "" else "option_%d" % (i + 1)))
		KIND_NUMBER:
			for i in old_values.size():
				var v = old_values[i]
				new_values.append(float(v) if (v is String and v.is_valid_float()) or v is float or v is int else float(i + 1))
				new_labels.append(old_labels[i] if i < old_labels.size() else display_value(new_values[i]))
		KIND_COLOR:
			var palette := ["f2c230", "6ec6ff", "ff6b8b", "6fcf97", "f4f1e8", "ff8a1f"]
			for i in old_values.size():
				var v = old_values[i]
				new_values.append(v if v is String and is_hex_color(v) else palette[i % palette.size()])
				new_labels.append(old_labels[i] if i < old_labels.size() else "Color %d" % (i + 1))
	if kind != KIND_TOGGLE and new_values.size() < 2:
		new_values = {KIND_TEXT: ["option_a", "option_b"], KIND_NUMBER: [1.0, 2.0], KIND_COLOR: ["f2c230", "6ec6ff"]}[kind]
		new_labels = {KIND_TEXT: ["Option A", "Option B"], KIND_NUMBER: ["1", "2"], KIND_COLOR: ["Yellow", "Blue"]}[kind]
	data["values"] = new_values
	if kind == KIND_TOGGLE and new_labels == [TOGGLE_ON_TEXT, TOGGLE_OFF_TEXT]:
		data.erase("labels")
	else:
		data["labels"] = new_labels
	data["default"] = new_values[default_index] if default_index >= 0 and default_index < new_values.size() else new_values[0]
	# Conditions on this setting follow the options by position.
	for e in entries:
		var values = _conditions(e).get(entry["key"])
		if e != entry and values is Array:
			var mapped := []
			for v in values:
				var i := _index_of(old_values, v)
				if i >= 0 and i < new_values.size():
					mapped.append(new_values[i])
			e["data"]["visible_when"][entry["key"]] = mapped
			e["dirty"] = true
	entry["kind"] = kind
	entry["dirty"] = true

# ---- Conditions (visible_when) ----

func _conditions(entry: Dictionary) -> Dictionary:
	var vw = entry["data"].get("visible_when")
	if vw is Dictionary:
		return vw
	return {}

func conditions(entry: Dictionary) -> Dictionary:
	if not entry["data"].get("visible_when") is Dictionary:
		entry["data"]["visible_when"] = {}
	return entry["data"]["visible_when"]

func _tidy_conditions(entry: Dictionary) -> void:
	if _conditions(entry).is_empty():
		entry["data"].erase("visible_when")

# Settings this one can be conditioned on: any other setting except ones that
# (directly or not) depend on it, which would make a loop.
func condition_candidates(entry: Dictionary) -> Array:
	return entries.filter(func(e): return e != entry and not _depends_on(e, entry["key"], {}))

func _depends_on(entry: Dictionary, key: String, seen: Dictionary) -> bool:
	if seen.has(entry["key"]):
		return false
	seen[entry["key"]] = true
	for k in _conditions(entry):
		if k == key:
			return true
		var other := find(k)
		if not other.is_empty() and _depends_on(other, key, seen):
			return true
	return false

# The entry with this key, or {} if there isn't one.
func find(key: String) -> Dictionary:
	for e in entries:
		if e["key"] == key:
			return e
	return {}

# ---- Checks ----

# { "errors": [...], "warnings": [...] } for one setting. Errors block saving.
func issues(entry: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	var data: Dictionary = entry["data"]
	var key: String = entry["key"]
	if key == "":
		errors.append("Give it a key.")
	elif not is_valid_key(key):
		errors.append("The key can only use letters, numbers and _, and can't start with a number.")
	elif key_taken(key, entry):
		errors.append("Another setting already uses the key \"%s\"." % key)
	elif key != entry["committed_key"] and entry["committed_key"] != "" and not component_switches(entry["committed_key"]).is_empty():
		errors.append("theme.json's components pick a scene with \"%s\", so it can't be renamed here; change the component first." % entry["committed_key"])
	if str(data.get("display_name", "")).strip_edges() == "":
		errors.append("Give it a name; it's what players see.")

	var values: Array = data.get("values", []) if data.get("values") is Array else []
	var labels: Array = data.get("labels", []) if data.get("labels") is Array else []
	if values.size() < 2:
		errors.append("It needs at least two options to switch between.")
	if entry["kind"] != KIND_TOGGLE:
		for i in values.size():
			if i < labels.size() and str(labels[i]).strip_edges() == "":
				errors.append("Option %d needs text to show players." % (i + 1))
			if entry["kind"] == KIND_TEXT and str(values[i]).strip_edges() == "":
				errors.append("Option %d needs a stored value." % (i + 1))
			if entry["kind"] == KIND_NUMBER and not (values[i] is float or values[i] is int):
				errors.append("Option %d's value isn't a number." % (i + 1))
			for j in i:
				if _same(values[i], values[j]):
					errors.append("Options %d and %d have the same value; each needs its own." % [j + 1, i + 1])
	if _index_of(values, data.get("default")) < 0:
		errors.append("Pick which option it starts on (its default).")

	for other_key in _conditions(entry):
		var other := find(other_key)
		var wanted = _conditions(entry)[other_key]
		if other.is_empty():
			errors.append("It's only shown when \"%s\" has certain values, but there's no setting with that key." % other_key)
		elif other == entry:
			errors.append("It can't depend on itself.")
		elif not wanted is Array or wanted.is_empty():
			errors.append("Pick at least one %s value it's shown for." % other["data"].get("display_name", other_key))
		else:
			for v in wanted:
				if _index_of(other["data"].get("values", []), v) < 0:
					errors.append("It's shown when %s is %s, which isn't one of its options any more." % [other["data"].get("display_name", other_key), display_value(v)])

	var switches := component_switches(key)
	for component in switches:
		var scenes: Array = switches[component]
		var missing := values.filter(func(v): return not str(v) in scenes).map(func(v): return display_value(v))
		if not missing.is_empty():
			warnings.append("The %s component picks its scene with this setting, but has no scene for %s; those fall back to the default option's scene." % [component, ", ".join(PackedStringArray(missing))])
	warnings.append_array(entry["notes"])
	return {"errors": errors, "warnings": warnings}

func has_errors() -> bool:
	return entries.any(func(e): return not issues(e)["errors"].is_empty())

func is_dirty() -> bool:
	return _order_changed or entries.any(func(e): return e["dirty"] or e["key"] != e["committed_key"]) or _removed_since_load()

var _loaded_keys := []
func mark_loaded() -> void:
	_loaded_keys = entries.map(func(e): return e["key"])
	_order_changed = false

func _removed_since_load() -> bool:
	var keys := entries.map(func(e): return e["key"])
	return _loaded_keys.size() != keys.size() or _loaded_keys.any(func(k): return not k in keys)

# ---- Writing ----

# theme.json text with the settings block rebuilt from the entries. Unchanged
# settings are written back byte for byte; edited and new ones are formatted
# like the existing files (one key per line, short arrays inline).
func apply_to_text(text: String) -> String:
	var indent := ThemeJson.object_entry_indent(text, "settings")
	var parent_indent := indent.substr(0, maxi(indent.length() - 1, 0)) if indent.ends_with("\t") else ""
	var parts := PackedStringArray()
	for e in entries:
		var body: String = e["raw"] if not e["dirty"] and e["raw"] != "" and e["key"] == e["committed_key"] else format_setting(e, indent)
		parts.append("%s%s: %s" % [indent, JSON.stringify(e["key"]), body])
	var block := "{}" if parts.is_empty() else "{\n%s\n%s}" % [",\n".join(parts), parent_indent]
	var after := ""
	var top := ThemeJson.parse(text)
	for candidate in ["tags", "components", "description", "name"]:
		if top.has(candidate):
			after = candidate
			break
	return ThemeJson.set_raw(text, "settings", block, after)

func format_setting(entry: Dictionary, indent: String) -> String:
	var data: Dictionary = entry["data"]
	if entry["kind"] == KIND_TOGGLE and data.get("labels") is Array and data["labels"].size() >= 2:
		var on_label := str(data["labels"][0]).strip_edges()
		var off_label := str(data["labels"][1]).strip_edges()
		if on_label == "" and off_label == "":
			data.erase("labels")
		else:
			data["labels"] = [on_label if on_label != "" else TOGGLE_ON_TEXT, off_label if off_label != "" else TOGGLE_OFF_TEXT]
	if str(data.get("description", "")).strip_edges() == "":
		data.erase("description")
	_tidy_conditions(entry)
	if not data.has("dependents"):
		data["dependents"] = []

	var keys := []
	for k in data:
		keys.append(k)
	for k in KEY_ORDER:
		if not k in keys and data.has(k):
			keys.append(k)
	if entry["raw"] == "":
		keys.sort_custom(func(a, b): return _order_rank(a) < _order_rank(b))
	var decimals := _uses_decimals(data.get("values", []))
	var lines := PackedStringArray()
	for k in keys:
		lines.append("%s\t%s: %s" % [indent, JSON.stringify(k), _format_value(k, data[k], decimals)])
	return "{\n%s\n%s}" % [",\n".join(lines), indent]

func _order_rank(k: String) -> int:
	var i := KEY_ORDER.find(k)
	return i if i >= 0 else KEY_ORDER.size()

func _format_value(key: String, value, decimals: bool) -> String:
	if key == "visible_when" and value is Dictionary:
		var parts := PackedStringArray()
		for k in value:
			var other := find(k)
			var other_decimals := _uses_decimals(other["data"].get("values", [])) if not other.is_empty() else false
			parts.append("%s: %s" % [JSON.stringify(k), _format_value("", value[k], other_decimals)])
		return "{ %s }" % ", ".join(parts)
	if value is Array:
		return "[%s]" % ", ".join(PackedStringArray(value.map(func(v): return _format_value("", v, decimals))))
	if value is float or value is int:
		return format_number(value, decimals)
	if value is bool:
		return "true" if value else "false"
	if value is String:
		return JSON.stringify(value)
	return JSON.stringify(value)

# Whole numbers are written as 16, or 1.0 when the setting also has values
# like 0.8 (matching how the existing themes write them).
static func format_number(value, decimals: bool) -> String:
	var f := float(value)
	if f == floorf(f) and absf(f) < 1e15:
		return ("%d.0" if decimals else "%d") % int(f)
	return String.num(f)

static func _uses_decimals(values) -> bool:
	return values is Array and values.any(func(v): return (v is float or v is int) and float(v) != floorf(float(v)))

# ---- Helpers ----

static func display_value(v) -> String:
	if v is bool:
		return "On" if v else "Off"
	if v is float or v is int:
		return format_number(v, false)
	return str(v)

# The line a theme script uses to read this setting. No fallback is needed:
# ThemeManager fills settings from each setting's default (and adds keys a
# saved settings file is missing), so the key is always there.
func code_snippet(entry: Dictionary) -> String:
	return "ThemeManager.settings.get(%s)" % JSON.stringify(entry["key"])

# JSON numbers load as floats, so 16 and 16.0 are the same option.
static func _same(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	if typeof(a) != typeof(b):
		return false
	return a == b

static func _index_of(values, v) -> int:
	if not values is Array:
		return -1
	for i in values.size():
		if _same(values[i], v):
			return i
	return -1
