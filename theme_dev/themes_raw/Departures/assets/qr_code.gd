@tool
extends Control
## The QR code on the boarding pass stub. The modules were encoded once with
## qrencode (byte mode, error correction L, 29x29) from the URL below, and are
## drawn here as whole-pixel squares so the code stays sharp and scannable.
## Regenerate: qrencode -t ASCII -m 0 -l L "<url>", one row per line, '#' = 1.

const P = preload("palette.gd")

const URL := "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
const QUIET_ZONE := 2  # light modules around the code; readers need a margin
const MODULES := [
	"11111110001000010111001111111",
	"10000010111001111110101000001",
	"10111010100000100101101011101",
	"10111010010010011000001011101",
	"10111010111010010110001011101",
	"10000010101011111111001000001",
	"11111110101010101010101111111",
	"00000000101100100111000000000",
	"11010011000110100000001110110",
	"11101000010111101110101001001",
	"00111111100110001101101001110",
	"01100001111111010010000110110",
	"01001110101101000101111001011",
	"11100100010100010101010100000",
	"01101011011101101110110001111",
	"00011101100101111111101001010",
	"01111111001011000101110100010",
	"01010001001010001010001101001",
	"10101010000110100000111100011",
	"00000100111010010101001000011",
	"10010110111001110000111110100",
	"00000000111101000101100010111",
	"11111110111000100110101010010",
	"10000010001001001010100011101",
	"10111010010010000100111110000",
	"10111010111110100001001011110",
	"10111010001010000111010011101",
	"10000010100011101100100010010",
	"11111110100111111110100110010",
]

@export var ink := P.INK
@export var paper := P.PAPER

func _draw() -> void:
	var count: int = MODULES.size()
	var total := count + QUIET_ZONE * 2
	# Whole pixels per module, as large as the space allows.
	var module := maxf(floorf(minf(size.x, size.y) / total), 1.0)
	var side := module * total
	var origin := ((size - Vector2(side, side)) / 2.0).floor()
	draw_rect(Rect2(origin, Vector2(side, side)), paper)
	var start := origin + Vector2(QUIET_ZONE, QUIET_ZONE) * module
	for y in count:
		var row: String = MODULES[y]
		for x in count:
			if row[x] == "1":
				draw_rect(Rect2(start + Vector2(x, y) * module, Vector2(module, module)), ink)
