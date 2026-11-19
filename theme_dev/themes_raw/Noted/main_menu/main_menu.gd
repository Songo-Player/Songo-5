@tool
extends MarginContainer
## The main menu as a sticky note with index tabs along its top, one per
## menu entry. Moving between tabs turns the note to that tab's color and
## rewrites it: the entry's name in big handwriting, a few notes about the
## library, a hand-drawn button, and a polaroid of something from the
## library. Pressing A on a tab (or the button) opens it.

const P = preload("../assets/palette.gd")
const Squiggle = preload("../assets/squiggle.gd")
const IndexTab = preload("../assets/index_tab.gd")
const LibraryNotes = preload("../assets/library_notes.gd")
const FONT = preload("../assets/font_hand.tres")

const TAB_WIDTH := 80.0
const TAB_LEFT := 15.0
const FLIP_TIME := 0.12

const EDITOR_PREVIEW_ITEMS := [
	["All Songs", "res://assets/music.svg"],
	["Albums", "res://assets/record.svg"],
	["Artists", "res://assets/user.svg"],
	["Playlists", "res://assets/layergroup.svg"],
	["Settings", "res://assets/gear.svg"],
	["Exit", "res://assets/exit_walk.svg"],
]

var buttons: Array[Button] = []
var _items: Array[MenuItemData] = []
var _selected := -1
var _tween: Tween
var _flip: Tween

func _ready() -> void:
	_items = _resolve_menu_items()
	for i in _items.size():
		_add_tab(_items[i], i)
	for i in buttons.size():
		var prev := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var next := buttons[(i + 1) % buttons.size()]
		for side in ["left", "top"]:
			buttons[i].set("focus_neighbor_" + side, buttons[i].get_path_to(prev))
		for side in ["right", "bottom"]:
			buttons[i].set("focus_neighbor_" + side, buttons[i].get_path_to(next))
	%Stack.resized.connect(_layout_tabs)
	%ViewButton.pressed.connect(_open_selected)
	_layout_tabs()
	for label in [%Title, %Heart, %ViewButton]:
		label.material = Squiggle.material(0.15)
	if not buttons.is_empty():
		_select(0, false)
	if Engine.is_editor_hint(): return
	if not buttons.is_empty(): buttons[0].grab_focus()

# Controller isn't available while editing (it's an autoload), so the editor
# gets a fixed set of entries just to preview the layout.
func _resolve_menu_items() -> Array[MenuItemData]:
	if Engine.is_editor_hint():
		var preview: Array[MenuItemData] = []
		for entry in EDITOR_PREVIEW_ITEMS:
			preview.append(MenuItemData.new(entry[0], entry[1], Callable()))
		return preview
	return Controller.menu_items

func _add_tab(item: MenuItemData, index: int) -> void:
	var tab := IndexTab.new()
	tab.tab_icon = item.icon()
	tab.fill = P.note(index)
	tab.edge = P.note_edge(index)
	tab.tooltip_text = item.label
	%Tabs.add_child(tab)
	buttons.append(tab)
	tab.focus_entered.connect(_select.bind(index))
	tab.pressed.connect(_open_selected)

# Tabs are as wide as the original sketch's, or narrower when there are
# more entries than fit along the note.
func _layout_tabs() -> void:
	if buttons.is_empty(): return
	var room: float = %Stack.size.x - TAB_LEFT * 2.0
	var width := minf(TAB_WIDTH, floorf(room / buttons.size()))
	%Tabs.position = Vector2(TAB_LEFT, 0)
	%Tabs.size = Vector2(width * buttons.size(), %Note.offset_top)
	for tab in buttons:
		tab.custom_minimum_size = Vector2(width, %Note.offset_top)

func _select(index: int, animate := true) -> void:
	if index == _selected: return
	_selected = index
	for i in buttons.size():
		var tab: Control = buttons[i]
		var lifted := 1.0 if i == index else 0.0
		if animate and not Engine.is_editor_hint():
			create_tween().tween_property(tab, "lift", lifted, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tab.lift = lifted
	_recolor_note(P.note(index), P.note_edge(index), animate)
	if animate and not Engine.is_editor_hint():
		_flip_page(index)
	else:
		_write_page(index)

func _recolor_note(fill: Color, edge: Color, animate: bool) -> void:
	var style := %Note.get_theme_stylebox("panel") as StyleBoxFlat
	if _tween and _tween.is_valid(): _tween.kill()
	if not animate or Engine.is_editor_hint():
		style.bg_color = fill
		style.border_color = edge
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(style, "bg_color", fill, FLIP_TIME * 2.0)
	_tween.tween_property(style, "border_color", edge, FLIP_TIME * 2.0)

# The writing fades out, the page is rewritten, and it fades back in.
func _flip_page(index: int) -> void:
	if _flip and _flip.is_valid(): _flip.kill()
	_flip = create_tween()
	_flip.tween_property(%Page, "modulate:a", 0.0, FLIP_TIME)
	_flip.tween_callback(_write_page.bind(index))
	_flip.tween_property(%Page, "modulate:a", 1.0, FLIP_TIME)

func _write_page(index: int) -> void:
	var item := _items[index]
	var notes := LibraryNotes.for_entry(item.label)
	%Title.text = item.label
	var lines: Array = notes.lines
	for i in %Notes.get_child_count():
		var line := %Notes.get_child(i) as Label
		line.text = lines[i] if i < lines.size() else ""
	%ViewButton.text = notes.button
	var photo: Dictionary = notes.photo
	var record = photo.record
	var caption := ""
	if record != null:
		caption = str(record.title) if photo.kind == "song" else str(record.name)
	%Polaroid.show_record(photo.kind, record, caption)

func _open_selected() -> void:
	if _selected < 0 or Engine.is_editor_hint(): return
	var item := _items[_selected]
	if item.action.is_valid():
		item.action.call()
