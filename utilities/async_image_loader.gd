class_name AsyncImageLoader
extends RefCounted

signal image_loaded(texture: ImageTexture)
signal load_failed(error: String)

const MAX_QUEUE_SIZE := 50

static var _queue: Array[AsyncImageLoader] = []
static var _mutex := Mutex.new()

var _image_path: String
var _cancelled := false
var _loading := false
var _task_id: int = -1


## Entry point
static func load_async(image_path: String) -> AsyncImageLoader:
	var loader := AsyncImageLoader.new()
	loader._image_path = image_path
	loader._start_load()
	return loader


func cancel() -> void:
	if _cancelled:
		return
	_cancelled = true


func _start_load() -> void:
	_add_to_queue()
	_loading = true

	# Submit background task to the built-in pool
	_task_id = WorkerThreadPool.add_task(func ():
		_load_image_task()
	)


func _add_to_queue() -> void:
	_mutex.lock()
	_queue.append(self)
	if _queue.size() > MAX_QUEUE_SIZE:
		var oldest: AsyncImageLoader = _queue[0]
		oldest.cancel()
		_queue.pop_front()
	_mutex.unlock()


func _remove_from_queue() -> void:
	_mutex.lock()
	_queue.erase(self)
	_mutex.unlock()


func _load_image_task() -> void:
	if _cancelled:
		call_deferred("_cleanup")
		return

	var image := Image.new()
	var err := image.load(_image_path)

	if _cancelled:
		call_deferred("_cleanup")
		return

	if err != OK:
		call_deferred("_on_load_failed", "Failed to load image: %s (Error %d)" % [_image_path, err])
	else:
		var texture := ImageTexture.create_from_image(image)
		call_deferred("_on_load_complete", texture)


func _on_load_complete(texture: ImageTexture) -> void:
	if not _cancelled:
		image_loaded.emit(texture)
	_cleanup()


func _on_load_failed(error: String) -> void:
	if not _cancelled:
		load_failed.emit(error)
	_cleanup()


func _cleanup() -> void:
	_loading = false
	_remove_from_queue()
	_task_id = -1
