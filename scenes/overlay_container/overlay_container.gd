extends MarginContainer

var songo_data = SongoDataResource.get_instance()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	UiHelper.darkout = %DarkOut
	UiHelper.overlay_window = %OverlayWindow
	UiHelper.keyboard = %Keyboard
	UiHelper.ui_event.connect(_on_overlay_update)
	Controller.quitting_songo.connect(_on_songo_quit)
	VolumeTcpListener.volume_updated.connect(_on_volume_changed)
	%Keyboard.shown_changed.connect(func(_shown): _refresh_overlay())
	%InfoPanel.go_to_collection_requested.connect(_on_go_to_collection_requested)
	# Hidden at rest too, not just transparent: a visible panel still eats clicks.
	%DarkOutTransition.modulate.a = 0.0
	%DarkOutTransition.hide()


const TRANSITION_FADE_TIME := 0.25
const TRANSITION_MIN_HOLD := 0.4
# True for the whole go-to-album/artist jump. Keeps the (empty) overlay window
# up so songo_app doesn't route input into the half-built pages.
var _transitioning := false


# Only one of the quick menu / info panel / keyboard shows at a time. A Y hold
# that starts (or is still going) while the info panel or keyboard is open stays
# ignored until Y is released, so the quick menu doesn't pop up the moment they
# close.
var _y_hold_blocked := false
var _quitting := false
# Mirrors songo_data.importing. While true the import panel is up and the
# overlay window stays visible, so songo_app routes no input to the main UI.
var _importing := false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _quitting: return

	if songo_data.importing != _importing: _set_importing(songo_data.importing)
	if _importing:
		_render_import_progress()
		return

	# songo_app skips route_inputs while the window is up, so back for the
	# keyboard is handled here.
	if %Keyboard.visible && Input.is_action_just_pressed("back"):
		%Keyboard.dismiss()

	var y_held = Input.is_action_pressed("Y")
	if not y_held: _y_hold_blocked = false
	elif %InfoPanel.visible || %Keyboard.visible || _transitioning: _y_hold_blocked = true

	var want_quick_menu = y_held && not _y_hold_blocked
	if want_quick_menu != %QuickMenu.showing:
		if want_quick_menu: %QuickMenu.open_menu()
		else: %QuickMenu.close_menu()
		_refresh_overlay()
	elif %QuickMenu.showing:
		# Keep labels current, e.g. after switching target playlist.
		%QuickMenu.update_quick_menu_vals()


func _show_info_panel():
	if %QuickMenu.showing || %Keyboard.visible || _importing: return
	%InfoPanel.show()
	_refresh_overlay()
	# After the window is up, so the panel's grab_focus lands.
	%InfoPanel.set_for_track(SongoPlayer.current_song)

func _hide_info_panel():
	%InfoPanel.hide()
	_refresh_overlay()

# The window and darkout stay up while any overlay content is showing. During a
# transition the window stays up (empty) to keep input off the main UI, but the
# darkout drops once the panel is gone so it doesn't pop off after the fade out.
func _refresh_overlay():
	var any_open = %InfoPanel.visible || %QuickMenu.showing || %Keyboard.visible || _importing
	%OverlayWindow.visible = any_open || _transitioning
	%DarkOut.visible = any_open

# Imports can start from anywhere (settings, directory select, auto import on
# boot), so this polls songo_data rather than relying on each caller. Whatever
# else the overlay was showing is closed so the import panel is the only thing up.
func _set_importing(importing: bool):
	_importing = importing
	if importing:
		if %QuickMenu.showing: %QuickMenu.close_menu()
		if %Keyboard.visible: %Keyboard.dismiss()
		%InfoPanel.hide()
		# Don't pop the quick menu if Y is still held when the import ends.
		_y_hold_blocked = true
	%ImportProgressContainer.visible = importing
	_refresh_overlay()
	# Take focus off the main viewport so its focused button can't be pressed.
	if importing: %OverlayWindow.grab_focus()

func _render_import_progress():
	var progress = clamp(songo_data.import_progress, 0, 1.0)
	match songo_data.import_step:
		0:
			%ImportProgressLabel.text = "Files found %d" % int(songo_data.import_progress)
			%ProgressBar.visible = false
			%ImportStepLabel.text = "Step 1/3 Finding audio files"
		1:
			%ProgressBar.visible = true
			%ImportProgressLabel.text = "Progress %.1f%%" % (progress * 100)
			%ProgressBar.scale.x = progress
			%ImportStepLabel.text = "Step 2/3 Indexing audio files"
		2:
			%ProgressBar.visible = true
			%ImportProgressLabel.text = "Progress %.1f%%" % (progress * 100)
			%ProgressBar.scale.x = progress
			%ImportStepLabel.text = "Step 3/3 Building Album Covers"

func _on_go_to_collection_requested(index_action: Callable, collection) -> void:
	if _transitioning: return
	_transitioning = true
	_refresh_overlay()

	# The transition lives in the main tree, which the overlay window always
	# draws over, so fade the info panel out alongside it.
	%DarkOutTransition.show()
	var tween = create_tween().set_parallel()
	tween.tween_property(%DarkOutTransition, "modulate:a", 1.0, TRANSITION_FADE_TIME)
	tween.tween_property(%InfoPanel, "modulate:a", 0.0, TRANSITION_FADE_TIME)
	UiHelper.transition_fade.emit(true, TRANSITION_FADE_TIME)
	await tween.finished
	%InfoPanel.hide()
	%InfoPanel.modulate.a = 1.0
	_refresh_overlay()

	# Hold at least TRANSITION_MIN_HOLD in the middle so a fast rebuild doesn't
	# make the fade flicker; a slow one just holds as long as it takes.
	var min_hold = get_tree().create_timer(TRANSITION_MIN_HOLD)
	await Controller.rebuild_nav_to_collection(index_action, collection)
	if min_hold.time_left > 0: await min_hold.timeout

	tween = create_tween()
	tween.tween_property(%DarkOutTransition, "modulate:a", 0.0, TRANSITION_FADE_TIME)
	UiHelper.transition_fade.emit(false, TRANSITION_FADE_TIME)
	await tween.finished
	%DarkOutTransition.hide()
	_transitioning = false
	_refresh_overlay()

func _on_overlay_update(event):
	#print("got here?")
	if event == UiHelper.EVENT.TOGGLE_INFO:
		# The transition hides the panel itself; don't let back/select race it.
		if _transitioning || _importing: return
		if %InfoPanel.visible:
			_hide_info_panel()
		else:
			_show_info_panel()

func _on_songo_quit():
	# Stop _process from hiding the window under the exit message.
	_quitting = true
	%ImportProgressContainer.hide()
	%DarkOut.show()
	%OverlayWindow.show()
	%ExitingOverlayContainer.show()
	
func _on_volume_changed(new_val):
	%VolumeContainer.update_volume(new_val)
