@tool
extends RefCounted
## Hands out materials for squiggle.gdshader, the line boil that makes text
## and doodles look redrawn by hand a few times a second. Materials of the
## same strength are shared, along with one noise texture, and the Wobble
## setting holds them all still (still squiggly, just not moving).

const SHADER = preload("squiggle.gdshader")
const P = preload("palette.gd")
const FPS := 6.0

static var _noise: NoiseTexture2D
static var _materials := {}

## A shared squiggle material. Strength around 0.1 to 0.3 for text and
## icons, higher for loose doodles.
static func material(strength: float) -> ShaderMaterial:
	var key := snappedf(strength, 0.01)
	if _materials.has(key): return _materials[key]
	if _noise == null:
		_noise = NoiseTexture2D.new()
		_noise.noise = FastNoiseLite.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("noise", _noise)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("scale", Vector2.ONE)
	mat.set_shader_parameter("fps", FPS if P.wobble() else 0.0)
	_materials[key] = mat
	return mat

## Applies the Wobble setting to every material handed out so far.
static func refresh() -> void:
	for mat in _materials.values():
		(mat as ShaderMaterial).set_shader_parameter("fps", FPS if P.wobble() else 0.0)
