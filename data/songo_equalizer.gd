extends Resource
class_name SongoEqualizer

const BAND_COUNT := 10
const BAND_FREQUENCIES: Array[int] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
const MIN_GAIN_DB := -30.0
const MAX_GAIN_DB := 12.0

@export var band_gains_db: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func get_band_gain(band_index: int) -> float:
	if band_index < 0 or band_index >= band_gains_db.size():
		return 0.0
	return band_gains_db[band_index]

func set_band_gain(band_index: int, gain_db: float) -> void:
	if band_index < 0 or band_index >= band_gains_db.size():
		return
	band_gains_db[band_index] = clamp(gain_db, MIN_GAIN_DB, MAX_GAIN_DB)

func reset() -> void:
	for i in range(band_gains_db.size()):
		band_gains_db[i] = 0.0
