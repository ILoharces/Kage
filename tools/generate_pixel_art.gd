extends SceneTree

## Genera el pack de pixel art en res://art. Ejecutar con Godot headless.

const INK := Color8(26, 20, 32)
const SKIN := Color8(243, 199, 162)
const SKIN_SHADE := Color8(224, 170, 132)
const HAIR := Color8(74, 52, 40)
const EYE := Color8(26, 20, 32)
const SHOE := Color8(32, 28, 36)
const WHITE := Color8(247, 247, 247)
const WHITE_SHADE := Color8(214, 214, 220)
const BLACK := Color8(28, 28, 34)
const BLACK_SHADE := Color8(14, 14, 18)
const TIE := Color8(192, 48, 48)
const GOLD := Color8(232, 184, 74)
const WOOD_A := Color8(138, 90, 52)
const WOOD_B := Color8(166, 112, 66)
const WOOD_C := Color8(112, 70, 40)
const WOOD_D := Color8(92, 56, 32)
const WALL := Color8(236, 228, 214)
const WALL_LINE := Color8(214, 202, 184)
const WALL_SIDE := Color8(214, 202, 184)
const WALL_SIDE_LINE := Color8(190, 176, 156)
const DOOR := Color8(154, 52, 48)
const DOOR_DARK := Color8(112, 36, 34)
const DOOR_LIGHT := Color8(186, 78, 70)
const EXIT := Color8(52, 122, 78)
const EXIT_DARK := Color8(32, 86, 54)
const EXIT_LIGHT := Color8(78, 156, 102)
const LEAF := Color8(56, 130, 64)
const LEAF_DARK := Color8(36, 96, 46)
const POT := Color8(154, 78, 52)
const METAL := Color8(150, 158, 168)
const METAL_DARK := Color8(90, 98, 110)
const BOOK_R := Color8(176, 64, 58)
const BOOK_B := Color8(58, 96, 168)
const BOOK_G := Color8(58, 130, 78)
const CREAM := Color8(244, 236, 214)
const BLUE := Color8(48, 92, 160)
const GREEN := Color8(56, 140, 72)
const YELLOW := Color8(232, 196, 64)
const CYAN := Color8(64, 168, 176)


func _init() -> void:
	_generate()
	quit()


func _generate() -> void:
	_save("res://art/floor.png", _floor_tile())
	_save("res://art/wall.png", _wall_tile(WALL, WALL_LINE))
	_save("res://art/wall_side.png", _wall_tile(WALL_SIDE, WALL_SIDE_LINE))
	_save("res://art/door.png", _door_sprite(DOOR, DOOR_DARK, DOOR_LIGHT))
	_save("res://art/door_exit.png", _door_sprite(EXIT, EXIT_DARK, EXIT_LIGHT))
	_save("res://art/spy_white.png", _spy_sprite(WHITE, WHITE_SHADE, TIE))
	_save("res://art/spy_black.png", _spy_sprite(BLACK, BLACK_SHADE, GOLD))
	_save("res://art/pistol.png", _pistol_sprite())
	_save("res://art/laptop.png", _laptop_sprite())
	_save("res://art/furniture/painting.png", _painting())
	_save("res://art/furniture/bookshelf.png", _bookshelf())
	_save("res://art/furniture/armchair.png", _armchair())
	_save("res://art/furniture/drawers.png", _drawers())
	_save("res://art/furniture/plant.png", _plant())
	_save("res://art/furniture/lamp.png", _lamp())
	_save("res://art/furniture/clock.png", _clock())
	_save("res://art/furniture/table.png", _table())
	_save("res://art/furniture/weapon_box.png", _weapon_box())
	_save("res://art/items/suitcase.png", _suitcase())
	_save("res://art/items/key.png", _key_icon())
	_save("res://art/items/money.png", _money_icon())
	_save("res://art/items/passport.png", _passport_icon())
	_save("res://art/items/microfilm.png", _microfilm_icon())
	_save("res://art/items/trap_bomb.png", _bomb_icon())
	_save("res://art/items/trap_spring.png", _spring_icon())
	_save("res://art/items/trap_bucket.png", _bucket_icon())
	_save("res://art/items/trap_gun.png", _gun_string_icon())
	_save("res://art/items/trap_timed.png", _timed_bomb_icon())
	_save("res://art/items/counter_cutters.png", _cutters_icon())
	_save("res://art/items/counter_wrench.png", _wrench_icon())
	_save("res://art/items/counter_umbrella.png", _umbrella_icon())
	_save("res://art/items/counter_tongs.png", _tongs_icon())
	_save("res://art/items/counter_mask.png", _mask_icon())
	print("pixel art escrito en res://art")


func _save(path: String, img: Image) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err: Error = img.save_png(abs_path)
	if err != OK:
		push_error("No se pudo guardar %s (%s)" % [path, err])


func _blank(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), color)


func _circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2: int = radius * radius
	for y: int in range(cy - radius, cy + radius + 1):
		for x: int in range(cx - radius, cx + radius + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2:
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, color)


func _outline(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var marks: Array[Vector2i] = []
	for y: int in h:
		for x: int in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			if _opaque(img, x + 1, y) or _opaque(img, x - 1, y) or _opaque(img, x, y + 1) or _opaque(img, x, y - 1):
				marks.append(Vector2i(x, y))
	for p: Vector2i in marks:
		img.set_pixel(p.x, p.y, INK)


func _opaque(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a > 0.0


func _floor_tile() -> Image:
	var img: Image = _blank(32, 32)
	var planks: Array[Color] = [WOOD_A, WOOD_B, WOOD_C, WOOD_A]
	for y: int in 32:
		var band: int = int(y / 8.0)
		var base: Color = planks[band]
		for x: int in 32:
			var grain: bool = ((x * 3 + band * 5) % 8) < 2
			var col: Color = WOOD_B if grain and base == WOOD_A else base
			if y % 8 == 7:
				col = WOOD_D
			elif (x + band * 11) % 16 == 15:
				col = WOOD_C
			img.set_pixel(x, y, col)
	return img


func _wall_tile(base: Color, line: Color) -> Image:
	var img: Image = _blank(32, 32)
	img.fill(base)
	for y: int in 32:
		for x: int in 32:
			if (x + y) % 16 == 0 or y % 16 == 15:
				img.set_pixel(x, y, line)
	return img


func _door_sprite(fill: Color, dark: Color, light: Color) -> Image:
	var img: Image = _blank(24, 40)
	_rect(img, 2, 1, 20, 38, fill)
	_rect(img, 4, 3, 16, 14, light)
	_rect(img, 4, 19, 16, 16, light)
	_rect(img, 5, 4, 14, 12, dark)
	_rect(img, 5, 20, 14, 14, fill)
	_rect(img, 18, 18, 2, 3, GOLD)
	_outline(img)
	return img


func _spy_sprite(suit: Color, shade: Color, accent: Color) -> Image:
	var img: Image = _blank(24, 40)
	_circle(img, 12, 11, 6, SKIN)
	_rect(img, 7, 6, 10, 4, HAIR)
	_rect(img, 8, 14, 8, 2, SKIN_SHADE)
	_rect(img, 7, 16, 10, 12, suit)
	_rect(img, 8, 17, 8, 10, shade)
	_rect(img, 11, 17, 2, 6, accent)
	_rect(img, 8, 28, 3, 8, suit)
	_rect(img, 13, 28, 3, 8, suit)
	_rect(img, 7, 34, 4, 3, SHOE)
	_rect(img, 13, 34, 4, 3, SHOE)
	img.set_pixel(10, 11, EYE)
	img.set_pixel(14, 11, EYE)
	img.set_pixel(12, 13, Color8(196, 120, 110))
	_outline(img)
	return img


func _pistol_sprite() -> Image:
	var img: Image = _blank(28, 14)
	_rect(img, 2, 5, 16, 5, METAL)
	_rect(img, 16, 6, 9, 3, METAL_DARK)
	_rect(img, 6, 9, 5, 4, Color8(70, 74, 82))
	_rect(img, 17, 5, 2, 1, GOLD)
	_outline(img)
	return img


func _laptop_sprite() -> Image:
	var img: Image = _blank(28, 20)
	_rect(img, 3, 3, 22, 12, Color8(36, 40, 48))
	_rect(img, 5, 5, 18, 8, Color8(196, 48, 48))
	_rect(img, 4, 15, 20, 3, METAL_DARK)
	_outline(img)
	return img


func _painting() -> Image:
	var img: Image = _blank(32, 32)
	_rect(img, 4, 6, 24, 18, WOOD_C)
	_rect(img, 7, 9, 18, 12, Color8(120, 170, 196))
	_rect(img, 8, 16, 16, 4, Color8(90, 150, 80))
	_circle(img, 18, 12, 2, YELLOW)
	_outline(img)
	return img


func _bookshelf() -> Image:
	var img: Image = _blank(32, 32)
	_rect(img, 5, 4, 22, 24, WOOD_C)
	_rect(img, 7, 6, 18, 6, CREAM)
	_rect(img, 7, 8, 4, 4, BOOK_R)
	_rect(img, 12, 7, 4, 5, BOOK_B)
	_rect(img, 17, 8, 5, 4, BOOK_G)
	_rect(img, 7, 14, 18, 6, CREAM)
	_rect(img, 8, 15, 4, 5, BOOK_B)
	_rect(img, 13, 15, 5, 5, BOOK_R)
	_rect(img, 19, 16, 4, 4, GOLD)
	_rect(img, 7, 22, 18, 4, WOOD_D)
	_outline(img)
	return img


func _armchair() -> Image:
	var img: Image = _blank(32, 32)
	_rect(img, 6, 10, 20, 12, Color8(150, 42, 42))
	_rect(img, 4, 12, 4, 12, Color8(120, 32, 32))
	_rect(img, 24, 12, 4, 12, Color8(120, 32, 32))
	_rect(img, 8, 20, 16, 4, WOOD_C)
	_rect(img, 8, 8, 16, 4, Color8(170, 54, 54))
	_rect(img, 10, 13, 12, 6, Color8(186, 78, 70))
	_outline(img)
	return img


func _drawers() -> Image:
	var img: Image = _blank(32, 32)
	_rect(img, 6, 6, 20, 22, WOOD_A)
	_rect(img, 8, 8, 16, 5, WOOD_B)
	_rect(img, 8, 15, 16, 5, WOOD_B)
	_rect(img, 8, 22, 16, 4, WOOD_B)
	_rect(img, 14, 10, 4, 2, GOLD)
	_rect(img, 14, 17, 4, 2, GOLD)
	_rect(img, 14, 23, 4, 2, GOLD)
	_outline(img)
	return img


func _plant() -> Image:
	var img: Image = _blank(32, 32)
	_circle(img, 16, 12, 7, LEAF)
	_circle(img, 10, 14, 5, LEAF_DARK)
	_circle(img, 22, 14, 5, LEAF)
	_rect(img, 14, 16, 4, 6, Color8(70, 110, 50))
	_rect(img, 10, 21, 12, 6, POT)
	_rect(img, 9, 21, 14, 2, Color8(176, 96, 64))
	_outline(img)
	return img


func _lamp() -> Image:
	var img: Image = _blank(32, 32)
	_rect(img, 15, 12, 2, 12, METAL_DARK)
	_rect(img, 10, 23, 12, 3, METAL)
	_rect(img, 8, 4, 16, 9, YELLOW)
	_rect(img, 10, 6, 12, 5, Color8(255, 230, 140))
	_outline(img)
	return img


func _clock() -> Image:
	var img: Image = _blank(32, 32)
	_rect(img, 12, 14, 8, 14, WOOD_C)
	_circle(img, 16, 10, 6, CREAM)
	_rect(img, 16, 10, 1, 4, INK)
	_rect(img, 16, 10, 4, 1, INK)
	_rect(img, 11, 26, 10, 2, WOOD_D)
	_outline(img)
	return img


func _table() -> Image:
	var img: Image = _blank(32, 32)
	_rect(img, 4, 10, 24, 8, WOOD_B)
	_rect(img, 6, 18, 3, 8, WOOD_D)
	_rect(img, 23, 18, 3, 8, WOOD_D)
	_rect(img, 4, 10, 24, 2, WOOD_A)
	_outline(img)
	return img


func _weapon_box() -> Image:
	var img: Image = _blank(32, 32)
	_rect(img, 5, 10, 22, 14, Color8(70, 78, 88))
	_rect(img, 5, 10, 22, 3, METAL)
	_rect(img, 14, 15, 4, 4, GOLD)
	_rect(img, 8, 8, 4, 4, WOOD_C)
	_rect(img, 20, 8, 4, 4, WOOD_C)
	_outline(img)
	return img


func _suitcase() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 2, 5, 12, 8, CYAN)
	_rect(img, 5, 3, 6, 3, Color8(40, 130, 140))
	_rect(img, 7, 8, 2, 2, GOLD)
	_outline(img)
	return img


func _key_icon() -> Image:
	var img: Image = _blank(16, 16)
	_circle(img, 5, 8, 3, YELLOW)
	_rect(img, 7, 7, 7, 2, YELLOW)
	_rect(img, 12, 7, 2, 3, YELLOW)
	img.set_pixel(4, 8, INK)
	_outline(img)
	return img


func _money_icon() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 2, 4, 12, 8, GREEN)
	_circle(img, 8, 8, 2, CREAM)
	_outline(img)
	return img


func _passport_icon() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 4, 2, 8, 12, BLUE)
	_rect(img, 6, 4, 4, 3, CREAM)
	_rect(img, 6, 8, 4, 1, GOLD)
	_outline(img)
	return img


func _microfilm_icon() -> Image:
	var img: Image = _blank(16, 16)
	_circle(img, 8, 8, 5, Color8(40, 40, 48))
	_circle(img, 8, 8, 2, Color8(196, 48, 48))
	_outline(img)
	return img


func _bomb_icon() -> Image:
	var img: Image = _blank(16, 16)
	_circle(img, 8, 9, 5, Color8(40, 40, 44))
	_rect(img, 11, 4, 2, 3, Color8(80, 70, 60))
	img.set_pixel(13, 3, YELLOW)
	_outline(img)
	return img


func _spring_icon() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 4, 12, 8, 2, METAL)
	for i: int in 5:
		var y: int = 3 + i * 2
		var x: int = 5 if i % 2 == 0 else 8
		_rect(img, x, y, 4, 2, Color8(220, 220, 228))
	_outline(img)
	return img


func _bucket_icon() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 4, 5, 8, 8, Color8(80, 170, 210))
	_rect(img, 3, 4, 10, 2, Color8(50, 130, 170))
	_rect(img, 6, 2, 4, 2, METAL)
	_outline(img)
	return img


func _gun_string_icon() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 2, 7, 8, 3, METAL_DARK)
	_rect(img, 9, 6, 4, 2, Color8(180, 60, 50))
	_rect(img, 8, 9, 2, 4, Color8(180, 60, 50))
	_outline(img)
	return img


func _timed_bomb_icon() -> Image:
	var img: Image = _blank(16, 16)
	_circle(img, 8, 9, 5, Color8(255, 140, 40))
	_rect(img, 7, 3, 2, 3, INK)
	img.set_pixel(8, 8, INK)
	img.set_pixel(10, 8, INK)
	_outline(img)
	return img


func _cutters_icon() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 3, 10, 4, 2, METAL)
	_rect(img, 9, 10, 4, 2, METAL)
	_rect(img, 6, 6, 4, 4, Color8(200, 60, 50))
	_outline(img)
	return img


func _wrench_icon() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 7, 3, 2, 10, METAL)
	_rect(img, 5, 2, 6, 3, METAL_DARK)
	_rect(img, 5, 12, 6, 2, METAL_DARK)
	_outline(img)
	return img


func _umbrella_icon() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 7, 4, 2, 9, Color8(50, 70, 120))
	_circle(img, 8, 6, 5, Color8(70, 110, 190))
	_rect(img, 3, 6, 10, 1, Color8(40, 70, 140))
	_outline(img)
	return img


func _tongs_icon() -> Image:
	var img: Image = _blank(16, 16)
	_rect(img, 5, 3, 2, 10, METAL)
	_rect(img, 9, 3, 2, 10, METAL)
	_rect(img, 5, 3, 6, 2, METAL_DARK)
	_outline(img)
	return img


func _mask_icon() -> Image:
	var img: Image = _blank(16, 16)
	_circle(img, 8, 8, 5, Color8(70, 110, 70))
	_circle(img, 6, 8, 2, Color8(180, 220, 190))
	_circle(img, 10, 8, 2, Color8(180, 220, 190))
	_rect(img, 4, 11, 8, 2, Color8(50, 80, 50))
	_outline(img)
	return img
