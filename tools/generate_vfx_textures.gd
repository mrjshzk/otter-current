extends SceneTree

## Generates the black-and-white pattern textures used by the quad-based VFX
## (splash foam, wake, dust, bubbles, sparkle, splash ring).
## Banded (hard-step) alpha gives a chunky, retro/arcade look instead of smooth gradients.
## Run with: godot --headless --path . --script tools/generate_vfx_textures.gd

const OUT_DIR := "res://assets/vfx"
const SIZE_BLOB := 64
const SIZE_SMALL := 32

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	write_png("blob.png", _blob())
	write_png("star.png", _star())
	write_png("ring.png", _ring())
	print("Generated vfx textures in ", OUT_DIR)
	quit()

func write_png(file_name: String, image: Image) -> void:
	var err := image.save_png(OUT_DIR + "/" + file_name)
	assert(err == OK, "failed to write " + file_name)
	print("wrote ", file_name)

## Soft radial blob in 3 hard alpha bands. Used for foam puffs, dust and bubbles.
func _blob() -> Image:
	var img := Image.create(SIZE_BLOB, SIZE_BLOB, false, Image.FORMAT_RGBA8)
	var half := float(SIZE_BLOB) / 2.0
	for y in SIZE_BLOB:
		for x in SIZE_BLOB:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(half, half)) / half
			var a := 0.0
			if d < 0.28:
				a = 1.0
			elif d < 0.5:
				a = 0.6
			elif d < 0.72:
				a = 0.25
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img

## 4-point sparkle flare (long arms along X/Y, short diagonals) with a bright core.
func _star() -> Image:
	var img := Image.create(SIZE_SMALL, SIZE_SMALL, false, Image.FORMAT_RGBA8)
	var half := float(SIZE_SMALL) / 2.0
	for y in SIZE_SMALL:
		for x in SIZE_SMALL:
			var p := (Vector2(x + 0.5, y + 0.5) - Vector2(half, half)) / half
			var theta := atan2(p.y, p.x)
			var radius: float = 0.28 + 0.42 * absf(cos(2.0 * theta))
			var r := p.length()
			var a := 0.0
			if r < radius * 0.7:
				a = 1.0
			elif r < radius:
				a = 0.55
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img

## Annulus ring in 2 hard alpha bands. Used for the splash impact ring.
func _ring() -> Image:
	var img := Image.create(SIZE_SMALL, SIZE_SMALL, false, Image.FORMAT_RGBA8)
	var half := float(SIZE_SMALL) / 2.0
	for y in SIZE_SMALL:
		for x in SIZE_SMALL:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(half, half)) / half
			var a := 0.0
			if d >= 0.4 and d < 0.72:
				a = 1.0
			elif d >= 0.72 and d < 0.9:
				a = 0.45
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img