@tool
extends RefCounted

# Reads theme.json and edits its top-level values in place, leaving everything
# else (formatting, key order, the components/settings blocks) untouched.
# Re-serializing the whole file instead would reformat it and turn integers
# like 16 into 16.0.

# theme.json files are hand-written and sometimes have trailing commas.
static func parse(text: String) -> Dictionary:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		var trailing_commas := RegEx.create_from_string(",(\\s*[}\\]])")
		data = JSON.parse_string(trailing_commas.sub(text, "$1", true))
	return data if typeof(data) == TYPE_DICTIONARY else {}

# after_key: where to add the key if it's missing (right after that top-level
# key); otherwise it goes at the top of the object.
static func set_string(text: String, key: String, value: String, after_key := "") -> String:
	return _set_value(text, key, JSON.stringify(value), after_key)

# Written inline as a comma-separated list: "tags": ["dark", "retro"]
static func set_string_array(text: String, key: String, values: PackedStringArray, after_key := "") -> String:
	var items := PackedStringArray()
	for value in values:
		items.append(JSON.stringify(value))
	return _set_value(text, key, "[%s]" % ", ".join(items), after_key)

static func set_int(text: String, key: String, value: int, after_key := "") -> String:
	return _set_value(text, key, str(value), after_key)

# Removes a top-level key along with its line and the comma that separated it.
static func remove_key(text: String, key: String) -> String:
	return _remove_from_spans(text, _top_level_spans(text), key)

# Sets entry_key inside the top-level object `object_key` (e.g. a component in
# "components"), one entry per line like the rest of the file. Creates the
# object when theme.json doesn't have it (after after_key, if given).
static func set_object_entry(text: String, object_key: String, entry_key: String, value_text: String, after_key := "") -> String:
	var spans := _top_level_spans(text)
	if not spans.has(object_key) or text[spans[object_key][0]] != "{":
		var indent := _key_indent(text, "")
		var block := "{\n%s\t%s: %s\n%s}" % [indent, JSON.stringify(entry_key), value_text, indent]
		return _set_value(text, object_key, block, after_key)
	var open: int = spans[object_key][0]
	var inner := object_spans(text, open)
	if inner.has(entry_key):
		var span: Array = inner[entry_key]
		return text.substr(0, span[0]) + value_text + text.substr(span[1])
	var entry_indent := object_entry_indent(text, object_key)
	var last_end := -1
	for k in inner:
		if not k.begins_with("__"):
			last_end = maxi(last_end, inner[k][1])
	var entry := "%s: %s" % [JSON.stringify(entry_key), value_text]
	if last_end >= 0:
		return text.substr(0, last_end) + ",\n" + entry_indent + entry + text.substr(last_end)
	# Empty object: write it out with the one entry.
	var block := "{\n%s%s\n%s}" % [entry_indent, entry, _key_indent(text, object_key)]
	return text.substr(0, open) + block + text.substr(spans[object_key][1])

# Removes entry_key from the top-level object `object_key`.
static func remove_object_entry(text: String, object_key: String, entry_key: String) -> String:
	var spans := _top_level_spans(text)
	if not spans.has(object_key) or text[spans[object_key][0]] != "{":
		return text
	return _remove_from_spans(text, object_spans(text, spans[object_key][0]), entry_key)

static func _remove_from_spans(text: String, spans: Dictionary, key: String) -> String:
	if not spans.has(key):
		return text
	var span: Array = spans[key]
	var start: int = span[2]
	var end: int = span[1]
	var after := end
	while after < text.length() and text[after] in " \t":
		after += 1
	if after < text.length() and text[after] == ",":
		# Not the last key: drop it, its comma, and the whitespace leading up to it.
		end = after + 1
		while start > 0 and text[start - 1] in " \t\r\n":
			start -= 1
	else:
		# Last key: drop the comma before it instead.
		var before := start - 1
		while before >= 0 and text[before] in " \t\r\n":
			before -= 1
		if before >= 0 and text[before] == ",":
			start = before
		elif before >= 0 and text[before] == "{":
			start = before + 1  # it was the only key
	return text.substr(0, start) + text.substr(end)

# Replaces the value of a top-level key, or adds the key when it's missing.
# Nested keys with the same name (a setting's "description") are never touched.
static func _set_value(text: String, key: String, value_text: String, after_key := "") -> String:
	var spans := _top_level_spans(text)
	if not spans.has("__open"):
		return text
	if spans.has(key):
		var span: Array = spans[key]
		return text.substr(0, span[0]) + value_text + text.substr(span[1])
	if after_key != "" and spans.has(after_key):
		# Inserted before whatever follows the anchor's value (its comma or the
		# closing brace), so commas stay valid either way.
		var anchor: Array = spans[after_key]
		var entry := ",\n%s%s: %s" % [_key_indent(text, after_key), JSON.stringify(key), value_text]
		return text.substr(0, anchor[1]) + entry + text.substr(anchor[1])
	var has_keys := spans.keys().any(func(k): return not k.begins_with("__"))
	var line := "\n%s%s: %s%s" % [_key_indent(text, ""), JSON.stringify(key), value_text, "," if has_keys else ""]
	var at: int = spans["__open"] + 1
	return text.substr(0, at) + line + text.substr(at)

# Indentation of a top-level key's line (or of the first key when key is ""),
# defaulting to a tab.
static func _key_indent(text: String, key: String) -> String:
	var spans := _top_level_spans(text)
	var key_start := -1
	if key != "" and spans.has(key):
		key_start = spans[key][2]
	else:
		for k in spans:
			if not k.begins_with("__"):
				key_start = spans[k][2]
				break
	if key_start < 0:
		return "\t"
	var line_start := text.rfind("\n", key_start) + 1
	var indent := text.substr(line_start, key_start - line_start)
	return indent if indent.strip_edges() == "" else "\t"

# Public form of _set_value for callers that format the value themselves.
static func set_raw(text: String, key: String, value_text: String, after_key := "") -> String:
	return _set_value(text, key, value_text, after_key)

# The exact text of each entry in a top-level object value (e.g. "settings"),
# in file order: [[key, value_text], ...]. Lets unchanged entries be written
# back exactly as they were.
static func object_entries(text: String, key: String) -> Array:
	var spans := _top_level_spans(text)
	if not spans.has(key):
		return []
	var inner := object_spans(text, spans[key][0])
	var out := []
	for k in inner:
		if not k.begins_with("__"):
			out.append([k, text.substr(inner[k][0], inner[k][1] - inner[k][0])])
	return out

# Indentation used for entries inside a top-level object value, e.g. two tabs
# for "settings" entries; falls back to the parent's indent plus a tab.
static func object_entry_indent(text: String, key: String) -> String:
	var spans := _top_level_spans(text)
	var parent_indent := _key_indent(text, key)
	if not spans.has(key):
		return parent_indent + "\t"
	var inner := object_spans(text, spans[key][0])
	for k in inner:
		if not k.begins_with("__"):
			var key_start: int = inner[k][2]
			var line_start := text.rfind("\n", key_start) + 1
			var indent := text.substr(line_start, key_start - line_start)
			if indent.strip_edges() == "":
				return indent
			break
	return parent_indent + "\t"

static func _top_level_spans(text: String) -> Dictionary:
	return object_spans(text, text.find("{"))

# key -> [value_start, value_end, key_start] for the object whose "{" is at
# open_index, plus "__open"/"__close" for its braces.
static func object_spans(text: String, open_index: int) -> Dictionary:
	var spans := {}
	var n := text.length()
	var i := open_index
	if i < 0 or i >= n or text[i] != "{":
		return spans
	spans["__open"] = i
	i += 1
	while i < n:
		while i < n and (text[i] in " \t\r\n,"):
			i += 1
		if i >= n:
			break
		if text[i] == "}":
			spans["__close"] = i
			break
		if text[i] != "\"":
			break  # not JSON we understand; stop rather than guess
		var key_start := i
		var key_end := _string_end(text, i)
		var key := text.substr(i + 1, key_end - i - 2)
		i = key_end
		while i < n and (text[i] in " \t\r\n"):
			i += 1
		if i >= n or text[i] != ":":
			break
		i += 1
		while i < n and (text[i] in " \t\r\n"):
			i += 1
		var value_end := _value_end(text, i)
		spans[key] = [i, value_end, key_start]
		i = value_end
	return spans

# i is at an opening quote; returns the index just past the closing quote.
static func _string_end(text: String, i: int) -> int:
	var n := text.length()
	var j := i + 1
	while j < n:
		var c := text[j]
		if c == "\\":
			j += 2
			continue
		if c == "\"":
			return j + 1
		j += 1
	return n

static func _value_end(text: String, i: int) -> int:
	var n := text.length()
	if i >= n:
		return n
	var c := text[i]
	if c == "\"":
		return _string_end(text, i)
	if c == "{" or c == "[":
		var depth := 0
		var j := i
		while j < n:
			var ch := text[j]
			if ch == "\"":
				j = _string_end(text, j)
				continue
			if ch == "{" or ch == "[":
				depth += 1
			elif ch == "}" or ch == "]":
				depth -= 1
				if depth == 0:
					return j + 1
			j += 1
		return n
	var k := i
	while k < n and not (text[k] in ",}] \t\r\n"):
		k += 1
	return k
