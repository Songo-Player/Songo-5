extends MarginContainer
## Top of a collection page: the collection's name on the board in big flaps,
## its artwork (or an icon for the kind of list), and a flipping total.

const P = preload("../assets/palette.gd")

const TYPE_ICONS := {
	"ALBUM": preload("res://assets/record.svg"),
	"ARTIST": preload("res://assets/user.svg"),
	"PLAYLIST": preload("res://assets/layergroup.svg"),
	"SETTING": preload("res://assets/gear.svg"),
}
const DEFAULT_ICON := preload("res://assets/music.svg")

func _ready() -> void:
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	%NameFlap.refresh()
	%CountFlap.refresh()
	%DefaultIcon.modulate = P.accent_ink()
	var frame := %DefaultIcon.get_parent().get_parent() as PanelContainer
	var style := frame.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = P.frame()
	style.border_color = P.rule()

func setup(sort_key) -> void:
	var kind: String = CollectionHelper.collection_type
	%NameFlap.set_text(str(CollectionHelper.collection_name))
	%CountFlap.set_text("%5d" % int(CollectionHelper.collection_size), true, 0.2)

	%DefaultIcon.texture = DEFAULT_ICON
	for key in TYPE_ICONS:
		if key in kind:
			%DefaultIcon.texture = TYPE_ICONS[key]
			break

	var image_texture = CollectionHelper.collection_image_texture
	%CustomImage.visible = image_texture != null and image_texture is Texture2D
	%DefaultIcon.get_parent().visible = not %CustomImage.visible
	if %CustomImage.visible: %CustomImage.texture = image_texture

	var kind_text := kind.replace("_", " ")
	if sort_key is String and SongoSort.TYPES.has(sort_key):
		var direction := "DESC" if "_desc" in sort_key else "ASC"
		kind_text += "  ·  " + str(SongoSort.TYPES[sort_key]).to_upper().trim_prefix("SORTED ") + " " + direction
		UiHelper.flash_message("%s (%s)" % [SongoSort.TYPES[sort_key], direction])
	%KindLabel.text = kind_text
