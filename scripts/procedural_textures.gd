extends Node
class_name ProceduralTextures

# Generates gritty low-resolution PS1-style textures AND horror textures
# (haunted posters, night window glass, bloody handprints, peeking faces).

static var _cache: Dictionary = {}

static func get_concrete_texture() -> ImageTexture:
	if _cache.has("concrete"):
		return _cache["concrete"]
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 101
	for y in range(128):
		for x in range(128):
			var base = 0.24 + rng.randf_range(-0.045, 0.045)
			var streak = sin(float(x) * 0.22 + sin(float(y) * 0.05)) * 0.03
			var seam = -0.06 if (y % 32 == 0 or y % 32 == 1) else 0.0
			var v = clamp(base + streak + seam, 0.08, 0.42)
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.93, 1.0))
	var tex = ImageTexture.create_from_image(img)
	_cache["concrete"] = tex
	return tex

static func get_step_texture() -> ImageTexture:
	if _cache.has("step"):
		return _cache["step"]
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 202
	for y in range(64):
		for x in range(64):
			var v = 0.20 + rng.randf_range(-0.04, 0.04)
			if y < 8:
				v = 0.09 + rng.randf_range(-0.02, 0.02)
			img.set_pixel(x, y, Color(v, v * 0.97, v * 0.94, 1.0))
	var tex = ImageTexture.create_from_image(img)
	_cache["step"] = tex
	return tex

static func get_fire_door_texture() -> ImageTexture:
	if _cache.has("door"):
		return _cache["door"]
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 303
	for y in range(128):
		for x in range(128):
			var noise = rng.randf_range(-0.04, 0.04)
			var r = 0.34 + noise
			var g = 0.11 + noise * 0.5
			var b = 0.09 + noise * 0.5
			if x < 6 or x > 121 or y < 6 or y > 121:
				r *= 0.55
				g *= 0.55
				b *= 0.55
			if y > 100:
				var scuff = float(y - 100) / 28.0
				r *= (1.0 - scuff * 0.55)
				g *= (1.0 - scuff * 0.55)
				b *= (1.0 - scuff * 0.55)
			img.set_pixel(x, y, Color(clamp(r, 0.0, 1.0), clamp(g, 0.0, 1.0), clamp(b, 0.0, 1.0), 1.0))
	var tex = ImageTexture.create_from_image(img)
	_cache["door"] = tex
	return tex

static func get_handprint_texture() -> ImageTexture:
	if _cache.has("hand"):
		return _cache["hand"]
	var img = Image.create(96, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng = RandomNumberGenerator.new()
	rng.seed = 404
	
	var finger_tips = [Vector2(20, 34), Vector2(33, 16), Vector2(48, 12), Vector2(63, 18), Vector2(76, 32)]
	var finger_bases = [Vector2(28, 60), Vector2(37, 48), Vector2(48, 46), Vector2(59, 48), Vector2(67, 58)]
	
	for y in range(128):
		for x in range(96):
			var p = Vector2(x, y)
			var alpha = 0.0
			var d_palm1 = (p - Vector2(48, 64)).length() / 18.0
			var d_palm2 = (p - Vector2(52, 76)).length() / 15.0
			if d_palm1 < 1.0:
				alpha = max(alpha, (1.0 - d_palm1 * d_palm1) * 0.9)
			if d_palm2 < 1.0:
				alpha = max(alpha, (1.0 - d_palm2 * d_palm2) * 0.85)
			
			for f in range(5):
				var a = finger_tips[f]
				var b = finger_bases[f]
				var ab = b - a
				var t = clamp((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var closest = a + ab * t
				var thickness = 4.2 if f > 0 else 4.8
				var dist = (p - closest).length() / thickness
				if dist < 1.0:
					alpha = max(alpha, (1.0 - dist * dist) * 0.92)
				if y > a.y and y < a.y + 72 and abs(x - a.x) < 3.2:
					var smear = (1.0 - float(y - a.y) / 72.0) * (1.0 - abs(x - a.x) / 3.2) * 0.45
					alpha = max(alpha, smear)
			
			if alpha > 0.04:
				var grain = rng.randf_range(-0.12, 0.12)
				var a_out = clamp(alpha + grain * 0.5, 0.0, 0.95)
				var col = Color(0.68 + grain, 0.56 + grain * 0.5, 0.52 + grain * 0.5, a_out)
				if alpha < 0.38:
					col = Color(0.28, 0.05, 0.04, a_out * 0.85)
				img.set_pixel(x, y, col)
	
	var tex = ImageTexture.create_from_image(img)
	_cache["hand"] = tex
	return tex

static func get_peeking_face_texture() -> ImageTexture:
	# Pale uncanny PS1 horror face with sunken dark eyes and hollow expression
	if _cache.has("face"):
		return _cache["face"]
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng = RandomNumberGenerator.new()
	rng.seed = 808
	
	for y in range(64):
		for x in range(64):
			var dx = (x - 32.0) / 18.0
			var dy = (y - 33.0) / 24.0
			var d = dx * dx + dy * dy
			if d < 1.0:
				var skin = (1.0 - d) * 0.65 + rng.randf_range(-0.06, 0.06)
				var eye_l = Vector2(x - 23.5, y - 27.0).length() / 5.5
				var eye_r = Vector2(x - 40.5, y - 27.0).length() / 5.5
				var mouth = (abs(x - 32.0) / 6.0) * (abs(x - 32.0) / 6.0) + ((y - 46.0) / 9.5) * ((y - 46.0) / 9.5)
				
				if eye_l < 1.0 or eye_r < 1.0 or mouth < 1.0:
					# Tiny pinprick pale pupil inside dark socket
					if (eye_l < 0.25 or eye_r < 0.25):
						img.set_pixel(x, y, Color(0.75, 0.75, 0.78, 0.95))
					else:
						img.set_pixel(x, y, Color(0.02, 0.01, 0.01, 0.95))
				else:
					img.set_pixel(x, y, Color(skin * 0.72, skin * 0.68, skin * 0.66, clamp((1.0 - d) * 1.3, 0.0, 0.92)))
	var tex = ImageTexture.create_from_image(img)
	_cache["face"] = tex
	return tex

static func get_poster_normal_texture() -> ImageTexture:
	# Vintage building safety/evacuation notice poster with a worker portrait
	if _cache.has("poster_norm"):
		return _cache["poster_norm"]
	var img = Image.create(64, 96, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 911
	
	for y in range(96):
		for x in range(64):
			var grit = rng.randf_range(-0.04, 0.04)
			# Aged yellowish paper background
			var col = Color(0.72 + grit, 0.69 + grit, 0.60 + grit, 1.0)
			# Dark border
			if x < 3 or x > 60 or y < 3 or y > 92:
				col = Color(0.18, 0.16, 0.14, 1.0)
			# Top red safety header bar
			elif y >= 6 and y <= 18 and x >= 6 and x <= 57:
				col = Color(0.58 + grit, 0.16, 0.12, 1.0)
			# Portrait frame in middle (x 14..50, y 24..64)
			elif x >= 14 and x <= 50 and y >= 24 and y <= 64:
				col = Color(0.25 + grit, 0.28 + grit, 0.30 + grit, 1.0)
				# Normal calm human head silhouette & eyes
				var h_dist = Vector2((x - 32.0) / 10.0, (y - 39.0) / 12.0).length()
				var s_dist = Vector2((x - 32.0) / 16.0, (y - 62.0) / 10.0).length()
				if h_dist < 1.0:
					col = Color(0.62 + grit, 0.52 + grit, 0.44 + grit, 1.0)
					# Normal eyes & neutral mouth
					if (abs(x - 28) <= 1 and y == 38) or (abs(x - 36) <= 1 and y == 38):
						col = Color(0.12, 0.12, 0.12, 1.0)
					elif abs(x - 32) <= 3 and y == 45:
						col = Color(0.22, 0.15, 0.14, 1.0)
				elif s_dist < 1.0 and y > 48:
					col = Color(0.18, 0.24, 0.36, 1.0)
			# Fake text lines at bottom (y 70..86)
			elif y >= 70 and y <= 86 and (y % 4 == 0 or y % 4 == 1) and x >= 10 and x <= 53:
				col = Color(0.20, 0.19, 0.18, 1.0)
			img.set_pixel(x, y, col)
	
	var tex = ImageTexture.create_from_image(img)
	_cache["poster_norm"] = tex
	return tex

static func get_poster_haunted_texture() -> ImageTexture:
	# Distorted haunted version of the same poster: melted hollow eyes bleeding down, gaping scream mouth
	if _cache.has("poster_haunt"):
		return _cache["poster_haunt"]
	var img = Image.create(64, 96, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 911
	
	for y in range(96):
		for x in range(64):
			var grit = rng.randf_range(-0.05, 0.05)
			var col = Color(0.64 + grit, 0.60 + grit, 0.52 + grit, 1.0)
			if x < 3 or x > 60 or y < 3 or y > 92:
				col = Color(0.15, 0.13, 0.12, 1.0)
			elif y >= 6 and y <= 18 and x >= 6 and x <= 57:
				col = Color(0.42 + grit, 0.06, 0.05, 1.0)
			elif x >= 14 and x <= 50 and y >= 24 and y <= 64:
				col = Color(0.10 + grit * 0.5, 0.08, 0.08, 1.0)
				var h_dist = Vector2((x - 32.0) / 10.5, (y - 40.0) / 13.5).length()
				if h_dist < 1.0:
					# Corpse pale distorted face
					col = Color(0.55 + grit, 0.52 + grit, 0.50 + grit, 1.0)
					var el = Vector2((x - 27.0) / 3.2, (y - 37.0) / 4.2).length()
					var er = Vector2((x - 37.0) / 3.2, (y - 37.0) / 4.2).length()
					var mouth = Vector2((x - 32.0) / 4.2, (y - 48.0) / 6.5).length()
					if el < 1.0 or er < 1.0 or mouth < 1.0:
						col = Color(0.02, 0.0, 0.0, 1.0)
						# Tiny red glint inside hollow sockets
						if el < 0.28 or er < 0.28:
							col = Color(0.85, 0.08, 0.05, 1.0)
					# Dark blood tears dripping from eye sockets
					elif (abs(x - 27) <= 1 or abs(x - 37) <= 1) and y > 38 and y < 58:
						col = Color(0.28, 0.02, 0.02, 1.0)
			elif y >= 70 and y <= 86 and (y % 4 == 0 or y % 4 == 1) and x >= 10 and x <= 53:
				col = Color(0.35, 0.04, 0.04, 1.0)
			img.set_pixel(x, y, col)
	
	var tex = ImageTexture.create_from_image(img)
	_cache["poster_haunt"] = tex
	return tex

static func get_evac_poster_normal() -> ImageTexture:
	# Green & white "ROTA DE FUGA" stairwell diagram poster (stick figure walking down steps)
	if _cache.has("evac_norm"):
		return _cache["evac_norm"]
	var img = Image.create(64, 80, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 742
	for y in range(80):
		for x in range(64):
			var g = rng.randf_range(-0.03, 0.03)
			var col = Color(0.14 + g, 0.42 + g, 0.22 + g, 1.0) # Emergency exit green
			if x < 4 or x > 59 or y < 4 or y > 75:
				col = Color(0.78 + g, 0.78 + g, 0.74 + g, 1.0)
			# White stairs descending bottom-left to bottom-right
			elif (x >= 10 and x <= 24 and y >= 48 and y <= 68) or (x >= 24 and x <= 38 and y >= 56 and y <= 68) or (x >= 38 and x <= 54 and y >= 63 and y <= 68):
				col = Color(0.84 + g, 0.85 + g, 0.82 + g, 1.0)
			# White stick figure head & torso walking down
			elif Vector2(x - 24, y - 24).length() < 5.0:
				col = Color(0.86, 0.88, 0.85, 1.0)
			elif x >= 21 and x <= 28 and y >= 30 and y <= 46:
				col = Color(0.86, 0.88, 0.85, 1.0)
			img.set_pixel(x, y, col)
	var tex = ImageTexture.create_from_image(img)
	_cache["evac_norm"] = tex
	return tex

static func get_evac_poster_haunted() -> ImageTexture:
	# Haunted version: dark blood-red background, stick figure chased by a towering black silhouette with glowing eyes!
	if _cache.has("evac_haunt"):
		return _cache["evac_haunt"]
	var img = Image.create(64, 80, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 742
	for y in range(80):
		for x in range(64):
			var g = rng.randf_range(-0.04, 0.04)
			var col = Color(0.32 + g, 0.08 + g * 0.5, 0.08 + g * 0.5, 1.0)
			if x < 4 or x > 59 or y < 4 or y > 75:
				col = Color(0.55 + g, 0.52 + g, 0.48 + g, 1.0)
			# Towering black figure looming behind the stick figure on the right!
			elif x >= 34 and x <= 54 and y >= 14 and y <= 68:
				col = Color(0.03, 0.02, 0.02, 1.0)
				if (abs(x - 41) <= 1 and abs(y - 23) <= 1) or (abs(x - 48) <= 1 and abs(y - 23) <= 1):
					col = Color(0.95, 0.12, 0.08, 1.0)
			elif (x >= 10 and x <= 24 and y >= 48 and y <= 68) or (x >= 24 and x <= 38 and y >= 56 and y <= 68):
				col = Color(0.68 + g, 0.65 + g, 0.62 + g, 1.0)
			elif Vector2(x - 19, y - 34).length() < 4.5:
				col = Color(0.80, 0.78, 0.75, 1.0)
			elif x >= 17 and x <= 22 and y >= 39 and y <= 50:
				col = Color(0.80, 0.78, 0.75, 1.0)
			img.set_pixel(x, y, col)
	var tex = ImageTexture.create_from_image(img)
	_cache["evac_haunt"] = tex
	return tex

static func get_missing_poster_normal() -> ImageTexture:
	# Vintage faded "DESAPARECIDO" flyer with a blurred silhouette photo & tear-off strips at bottom
	if _cache.has("miss_norm"):
		return _cache["miss_norm"]
	var img = Image.create(64, 88, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 412
	for y in range(88):
		for x in range(64):
			var g = rng.randf_range(-0.04, 0.04)
			var col = Color(0.76 + g, 0.74 + g, 0.66 + g, 1.0)
			# Tear-off phone number strips at bottom
			if y >= 72 and (x % 9 == 0):
				col = Color(0.18, 0.18, 0.17, 1.0)
			elif y == 71:
				col = Color(0.25, 0.24, 0.22, 1.0)
			# Bold dark header bar
			elif y >= 6 and y <= 15 and x >= 6 and x <= 57:
				col = Color(0.16 + g, 0.16 + g, 0.17 + g, 1.0)
			# Photo box
			elif x >= 15 and x <= 48 and y >= 20 and y <= 55:
				col = Color(0.45 + g, 0.44 + g, 0.42 + g, 1.0)
				var hd = Vector2((x - 32.0) / 9.0, (y - 34.0) / 11.0).length()
				var bd = Vector2((x - 32.0) / 15.0, (y - 54.0) / 10.0).length()
				if hd < 1.0:
					col = Color(0.28 + g, 0.25 + g, 0.23 + g, 1.0)
				elif bd < 1.0 and y > 44:
					col = Color(0.20 + g, 0.20 + g, 0.22 + g, 1.0)
			elif y >= 59 and y <= 67 and (y % 3 == 0) and x >= 10 and x <= 53:
				col = Color(0.22, 0.22, 0.20, 1.0)
			img.set_pixel(x, y, col)
	var tex = ImageTexture.create_from_image(img)
	_cache["miss_norm"] = tex
	return tex

static func get_missing_poster_haunted() -> ImageTexture:
	# Haunted flyer: face violently scratched out with black/red X and glowing red pinprick eyes!
	if _cache.has("miss_haunt"):
		return _cache["miss_haunt"]
	var img = Image.create(64, 88, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 412
	for y in range(88):
		for x in range(64):
			var g = rng.randf_range(-0.04, 0.04)
			var col = Color(0.65 + g, 0.60 + g, 0.55 + g, 1.0)
			if y >= 72 and (x % 9 == 0):
				col = Color(0.15, 0.12, 0.12, 1.0)
			elif y >= 6 and y <= 15 and x >= 6 and x <= 57:
				col = Color(0.48 + g, 0.04, 0.04, 1.0)
			elif x >= 15 and x <= 48 and y >= 20 and y <= 55:
				col = Color(0.12 + g, 0.08, 0.08, 1.0)
				# Violent red X slashed across the photo
				if abs((x - 15) - (y - 20)) <= 2 or abs((48 - x) - (y - 20)) <= 2:
					col = Color(0.68 + g, 0.04, 0.03, 1.0)
				if (abs(x - 27) <= 1 and abs(y - 34) <= 1) or (abs(x - 37) <= 1 and abs(y - 34) <= 1):
					col = Color(1.0, 0.12, 0.08, 1.0)
			elif y >= 59 and y <= 67 and (y % 3 == 0) and x >= 10 and x <= 53:
				col = Color(0.45, 0.04, 0.04, 1.0)
			img.set_pixel(x, y, col)
	var tex = ImageTexture.create_from_image(img)
	_cache["miss_haunt"] = tex
	return tex

static func get_warning_poster_normal() -> ImageTexture:
	# Yellow & black industrial "ATENÇÃO / CUIDADO" hazard triangle poster
	if _cache.has("warn_norm"):
		return _cache["warn_norm"]
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 518
	for y in range(64):
		for x in range(64):
			var g = rng.randf_range(-0.03, 0.03)
			var col = Color(0.72 + g, 0.58 + g, 0.10 + g, 1.0)
			if x < 4 or x > 59 or y < 4 or y > 59:
				col = Color(0.12, 0.12, 0.12, 1.0)
			elif y >= 12 and y <= 46:
				var half_w = float(y - 12) * 0.62
				if abs(x - 32.0) <= half_w:
					if abs(x - 32.0) >= half_w - 3.0 or y >= 43:
						col = Color(0.10, 0.10, 0.10, 1.0)
					elif abs(x - 32.0) <= 2.0 and ((y >= 21 and y <= 34) or (y >= 38 and y <= 41)):
						col = Color(0.10, 0.10, 0.10, 1.0)
			img.set_pixel(x, y, col)
	var tex = ImageTexture.create_from_image(img)
	_cache["warn_norm"] = tex
	return tex

static func get_warning_poster_haunted() -> ImageTexture:
	# Haunted hazard sign: blood-red backdrop with a wide staring horror eye inside the triangle!
	if _cache.has("warn_haunt"):
		return _cache["warn_haunt"]
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 518
	for y in range(64):
		for x in range(64):
			var g = rng.randf_range(-0.04, 0.04)
			var col = Color(0.45 + g, 0.06, 0.05, 1.0)
			if x < 4 or x > 59 or y < 4 or y > 59:
				col = Color(0.08, 0.02, 0.02, 1.0)
			else:
				var eye_w = Vector2((x - 32.0) / 16.0, (y - 32.0) / 9.0).length()
				var pupil = Vector2(x - 32.0, y - 32.0).length()
				if eye_w < 1.0:
					col = Color(0.82 + g, 0.78 + g, 0.72 + g, 1.0)
					if pupil < 5.5:
						col = Color(0.04, 0.01, 0.01, 1.0)
					if pupil < 2.0:
						col = Color(0.95, 0.10, 0.06, 1.0)
			img.set_pixel(x, y, col)
	var tex = ImageTexture.create_from_image(img)
	_cache["warn_haunt"] = tex
	return tex

static func get_blood_wall_splatter_texture() -> ImageTexture:
	# Exaggerated, visceral PS1-style dried blood smear + long vertical drips + chaotic splatters for wall clues
	if _cache.has("blood_wall"):
		return _cache["blood_wall"]
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng = RandomNumberGenerator.new()
	rng.seed = 6667
	
	# 1. Main frantic horizontal/diagonal hand-smeared blood streaks in upper-middle region
	var smear_blobs = [
		Vector3(34, 42, 22), Vector3(64, 38, 28), Vector3(92, 46, 24),
		Vector3(48, 56, 20), Vector3(80, 58, 22), Vector3(24, 52, 14), Vector3(106, 40, 15)
	]
	# 2. Vertical dripping blood trails running down from the smears
	var drip_x = [18, 29, 41, 53, 62, 74, 86, 97, 108]
	var drip_len = [52, 78, 64, 96, 84, 72, 108, 60, 48]
	
	for y in range(128):
		for x in range(128):
			var p = Vector2(x, y)
			var alpha = 0.0
			
			# Smeared core streaks
			for b in smear_blobs:
				var dx = (x - b.x) / (b.z * 1.25)
				var dy = (y - b.y) / (b.z * 0.72)
				var d = dx * dx + dy * dy
				if d < 1.0:
					var streak_noise = 0.65 + 0.35 * sin(y * 0.45 + x * 0.15)
					alpha = max(alpha, (1.0 - d) * 0.88 * streak_noise)
			
			# Long gravity drips running down the concrete
			for i in range(drip_x.size()):
				var dx = abs(x - drip_x[i])
				if y >= 36 and y <= 36 + drip_len[i] and dx <= 2.6:
					var prog = float(y - 36) / float(drip_len[i])
					var width = lerp(2.5, 1.1, prog)
					if prog > 0.90:
						width = 2.4 # Bulbous droplet tip at bottom of drip!
					if dx <= width:
						alpha = max(alpha, (1.0 - dx / (width + 0.4)) * 0.92)
			
			# Random tiny splatter flecks around edges
			if alpha < 0.1 and rng.randf() < 0.012:
				var dist_center = (p - Vector2(64, 54)).length()
				if dist_center < 60.0:
					alpha = rng.randf_range(0.35, 0.78)
			
			if alpha > 0.05:
				var g = rng.randf_range(-0.06, 0.05)
				# Deep visceral dried/wet crimson
				var r = clamp(0.42 + alpha * 0.24 + g, 0.12, 0.68)
				var gr = clamp(0.02 + g * 0.3, 0.0, 0.06)
				var bl = clamp(0.02 + g * 0.3, 0.0, 0.06)
				img.set_pixel(x, y, Color(r, gr, bl, clamp(alpha, 0.0, 0.92)))
	
	var tex = ImageTexture.create_from_image(img)
	_cache["blood_wall"] = tex
	return tex

# =============================================================================
# HAND-PAINTED TREMBLING BLOOD CALLIGRAPHY GENERATOR (Zero clean computer fonts!)
# Draws jagged, frantic, finger-smeared strokes with real drips hanging off letters!
# =============================================================================
static func make_blood_handwritten_texture(symbol: String, phrase: String) -> ImageTexture:
	var cache_key = "blood_txt_" + symbol + "_" + phrase
	if _cache.has(cache_key):
		return _cache[cache_key]
	
	var w = 320
	var h = 224
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(cache_key)
	
	# 1. Draw the large frantic symbol at the top center (X=160, Y=36)
	_draw_blood_symbol(img, symbol, Vector2(160, 38), 24.0, rng)
	
	# 2. Wrap phrase into 2-3 ragged lines
	var words = phrase.to_upper().split(" ")
	var lines: Array[String] = []
	var cur = ""
	for word in words:
		if cur.length() + word.length() + 1 > 15 and cur != "":
			lines.append(cur)
			cur = word
		else:
			cur = word if cur == "" else (cur + " " + word)
	if cur != "":
		lines.append(cur)
	
	# 3. Draw each letter with trembling hand strokes, uneven baseline, frantic slant & hanging drips!
	var line_y = 92.0
	for line in lines:
		var char_w = 17.0
		var total_w = float(line.length()) * char_w
		var start_x = (float(w) - total_w) * 0.5 + rng.randf_range(-10.0, 10.0)
		var baseline_drift = rng.randf_range(-0.4, 0.4)
		for ci in range(line.length()):
			var ch = line[ci]
			if ch == " ":
				continue
			var cx = start_x + float(ci) * char_w + rng.randf_range(-2.2, 2.2)
			var cy = line_y + float(ci) * baseline_drift + rng.randf_range(-4.5, 4.5)
			var scale_x = rng.randf_range(11.0, 15.5)
			var scale_y = rng.randf_range(22.0, 31.0)
			var slant = rng.randf_range(-3.5, 4.5)
			_draw_blood_glyph(img, ch, Vector2(cx, cy), Vector2(scale_x, scale_y), slant, rng)
		line_y += 44.0 + rng.randf_range(-3.0, 5.0)
	
	var tex = ImageTexture.create_from_image(img)
	_cache[cache_key] = tex
	return tex

static func _draw_blood_symbol(img: Image, sym: String, center: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	match sym:
		"◈":
			var pts = [center + Vector2(0, -r), center + Vector2(r * 0.85, 0), center + Vector2(0, r), center + Vector2(-r * 0.85, 0)]
			for i in range(4):
				_paint_blood_stroke(img, pts[i], pts[(i + 1) % 4], 3.4, rng, true)
			_paint_blood_stroke(img, center + Vector2(-4, -3), center + Vector2(4, 3), 3.6, rng, false)
		"✕":
			_paint_blood_stroke(img, center + Vector2(-r * 0.8, -r * 0.9), center + Vector2(r * 0.85, r * 0.9), 3.8, rng, true)
			_paint_blood_stroke(img, center + Vector2(r * 0.85, -r * 0.85), center + Vector2(-r * 0.8, r * 0.95), 3.8, rng, true)
		"☾":
			var prev = Vector2.ZERO
			for s in range(9):
				var ang = lerp(deg_to_rad(55.0), deg_to_rad(305.0), float(s) / 8.0)
				var pt = center + Vector2(cos(ang) * r * 0.85, sin(ang) * r)
				if s > 0:
					_paint_blood_stroke(img, prev, pt, 3.6, rng, s == 8)
				prev = pt
		"▲":
			var p1 = center + Vector2(0, -r)
			var p2 = center + Vector2(r * 0.95, r * 0.85)
			var p3 = center + Vector2(-r * 0.95, r * 0.85)
			_paint_blood_stroke(img, p1, p2, 3.6, rng, true)
			_paint_blood_stroke(img, p2, p3, 3.6, rng, true)
			_paint_blood_stroke(img, p3, p1, 3.6, rng, false)

static func _draw_blood_glyph(img: Image, ch: String, pos: Vector2, sz: Vector2, slant: float, rng: RandomNumberGenerator) -> void:
	# Normalize accented Portuguese letters to base strokes + quick accent slash
	var base = ch
	var has_tilde = false
	var has_acute = false
	var has_circumflex = false
	var has_cedilla = false
	match ch:
		"Á": base = "A"; has_acute = true
		"Ã": base = "A"; has_tilde = true
		"Â": base = "A"; has_circumflex = true
		"É": base = "E"; has_acute = true
		"Ê": base = "E"; has_circumflex = true
		"Í": base = "I"; has_acute = true
		"Ó": base = "O"; has_acute = true
		"Õ": base = "O"; has_tilde = true
		"Ô": base = "O"; has_circumflex = true
		"Ú": base = "U"; has_acute = true
		"Ç": base = "C"; has_cedilla = true
	
	# Normalized 0..1 strokes for jagged horror handwriting
	var strokes: Array = []
	match base:
		"A": strokes = [[[0.0,1.0],[0.5,0.0]], [[0.5,0.0],[1.0,1.0]], [[0.18,0.62],[0.85,0.58]]]
		"B": strokes = [[[0.05,0.0],[0.05,1.0]], [[0.05,0.0],[0.8,0.18]], [[0.8,0.18],[0.1,0.48]], [[0.1,0.48],[0.9,0.72]], [[0.9,0.72],[0.05,1.0]]]
		"C": strokes = [[[0.95,0.15],[0.25,0.0]], [[0.25,0.0],[0.0,0.5]], [[0.0,0.5],[0.25,1.0]], [[0.25,1.0],[0.95,0.85]]]
		"D": strokes = [[[0.05,0.0],[0.05,1.0]], [[0.05,0.0],[0.85,0.22]], [[0.85,0.22],[0.92,0.72]], [[0.92,0.72],[0.05,1.0]]]
		"E": strokes = [[[0.08,0.0],[0.05,1.0]], [[0.08,0.0],[0.92,0.05]], [[0.08,0.48],[0.78,0.46]], [[0.05,1.0],[0.95,0.95]]]
		"F": strokes = [[[0.08,0.0],[0.05,1.0]], [[0.08,0.0],[0.92,0.05]], [[0.08,0.48],[0.75,0.46]]]
		"G": strokes = [[[0.92,0.15],[0.25,0.0]], [[0.25,0.0],[0.0,0.52]], [[0.0,0.52],[0.3,1.0]], [[0.3,1.0],[0.92,0.88]], [[0.92,0.88],[0.92,0.52]], [[0.92,0.52],[0.5,0.52]]]
		"H": strokes = [[[0.05,0.0],[0.05,1.0]], [[0.92,0.0],[0.92,1.0]], [[0.05,0.5],[0.92,0.46]]]
		"I": strokes = [[[0.5,0.0],[0.48,1.0]], [[0.22,0.02],[0.78,0.02]], [[0.22,0.98],[0.78,0.98]]]
		"J": strokes = [[[0.78,0.0],[0.75,0.85]], [[0.75,0.85],[0.35,1.0]], [[0.35,1.0],[0.05,0.78]]]
		"L": strokes = [[[0.08,0.0],[0.08,1.0]], [[0.08,1.0],[0.92,0.95]]]
		"M": strokes = [[[0.0,1.0],[0.08,0.0]], [[0.08,0.0],[0.5,0.62]], [[0.5,0.62],[0.92,0.0]], [[0.92,0.0],[1.0,1.0]]]
		"N": strokes = [[[0.05,1.0],[0.08,0.0]], [[0.08,0.0],[0.92,1.0]], [[0.92,1.0],[0.92,0.0]]]
		"O": strokes = [[[0.48,0.0],[0.95,0.35]], [[0.95,0.35],[0.88,0.82]], [[0.88,0.82],[0.45,1.0]], [[0.45,1.0],[0.05,0.72]], [[0.05,0.72],[0.12,0.22]], [[0.12,0.22],[0.48,0.0]]]
		"P": strokes = [[[0.08,0.0],[0.08,1.0]], [[0.08,0.0],[0.88,0.12]], [[0.88,0.12],[0.85,0.48]], [[0.85,0.48],[0.08,0.55]]]
		"Q": strokes = [[[0.48,0.0],[0.95,0.35]], [[0.95,0.35],[0.85,0.85]], [[0.85,0.85],[0.42,1.0]], [[0.42,1.0],[0.05,0.68]], [[0.05,0.68],[0.12,0.2]], [[0.12,0.2],[0.48,0.0]], [[0.55,0.68],[1.0,1.05]]]
		"R": strokes = [[[0.08,0.0],[0.08,1.0]], [[0.08,0.0],[0.88,0.14]], [[0.88,0.14],[0.82,0.48]], [[0.82,0.48],[0.08,0.52]], [[0.42,0.5],[0.95,1.0]]]
		"S": strokes = [[[0.92,0.12],[0.35,0.0]], [[0.35,0.0],[0.05,0.25]], [[0.05,0.25],[0.88,0.62]], [[0.88,0.62],[0.78,0.95]], [[0.78,0.95],[0.05,0.88]]]
		"T": strokes = [[[0.0,0.04],[1.0,0.0]], [[0.5,0.02],[0.48,1.0]]]
		"U": strokes = [[[0.08,0.0],[0.12,0.85]], [[0.12,0.85],[0.52,1.0]], [[0.52,1.0],[0.9,0.82]], [[0.9,0.82],[0.92,0.0]]]
		"V": strokes = [[[0.0,0.0],[0.5,1.0]], [[0.5,1.0],[1.0,0.0]]]
		"X": strokes = [[[0.05,0.0],[0.95,1.0]], [[0.95,0.0],[0.05,1.0]]]
		"Z": strokes = [[[0.05,0.04],[0.95,0.0]], [[0.95,0.0],[0.05,0.98]], [[0.05,0.98],[0.95,0.94]]]
		_: strokes = [[[0.2,0.5],[0.8,0.5]]]
	
	if has_acute:
		strokes.append([[0.45,-0.25],[0.75,-0.08]])
	if has_tilde:
		strokes.append([[0.2,-0.15],[0.85,-0.22]])
	if has_circumflex:
		strokes.append([[0.25,-0.1],[0.5,-0.28]])
		strokes.append([[0.5,-0.28],[0.78,-0.1]])
	if has_cedilla:
		strokes.append([[0.5,1.02],[0.42,1.22]])
	
	for seg in strokes:
		var a = Vector2(pos.x + seg[0][0] * sz.x + (1.0 - seg[0][1]) * slant, pos.y + seg[0][1] * sz.y)
		var b = Vector2(pos.x + seg[1][0] * sz.x + (1.0 - seg[1][1]) * slant, pos.y + seg[1][1] * sz.y)
		_paint_blood_stroke(img, a, b, rng.randf_range(1.7, 2.7), rng, rng.randf() < 0.22)

static func _paint_blood_stroke(img: Image, a: Vector2, b: Vector2, radius: float, rng: RandomNumberGenerator, allow_drip: bool) -> void:
	var w = img.get_width()
	var h = img.get_height()
	var dist = a.distance_to(b)
	var steps = max(int(dist * 1.4), 4)
	var jitter_x = 0.0
	var jitter_y = 0.0
	
	for s in range(steps + 1):
		var t = float(s) / float(steps)
		# Trembling hand micro-jitter along the stroke
		jitter_x = lerp(jitter_x, rng.randf_range(-1.4, 1.4), 0.45)
		jitter_y = lerp(jitter_y, rng.randf_range(-1.4, 1.4), 0.45)
		var p = a.lerp(b, t) + Vector2(jitter_x, jitter_y)
		# Uneven bloody finger pressure (thicker at start, scratchy/thin at end)
		var r = radius * lerp(1.15, 0.72, t) + rng.randf_range(-0.4, 0.4)
		var ir = int(ceil(r)) + 1
		
		for dy in range(-ir, ir + 1):
			for dx in range(-ir, ir + 1):
				var px = int(p.x) + dx
				var py = int(p.y) + dy
				if px < 0 or px >= w or py < 0 or py >= h:
					continue
				var d = sqrt(float(dx * dx + dy * dy))
				if d <= r:
					# Scratchy concrete grain gaps at outer edge of finger stroke
					if d > r * 0.65 and rng.randf() < 0.35:
						continue
					var core = 1.0 - (d / (r + 0.2))
					var red = clamp(0.32 + core * 0.30 + rng.randf_range(-0.05, 0.05), 0.14, 0.65)
					var alpha = clamp(0.75 + core * 0.25, 0.0, 0.96)
					var existing = img.get_pixel(px, py)
					if alpha > existing.a:
						img.set_pixel(px, py, Color(red, 0.015, 0.012, alpha))
		
		# Occasional vertical blood drip running straight down off the letter stroke!
		if allow_drip and s == steps and rng.randf() < 0.48:
			var drip_len = rng.randi_range(12, 42)
			for dl in range(drip_len):
				var py = int(p.y) + dl
				var px = int(p.x) + (1 if (dl > 20 and rng.randf() < 0.2) else 0)
				if px >= 1 and px < w - 1 and py >= 0 and py < h:
					var da = lerp(0.88, 0.55, float(dl) / float(drip_len))
					img.set_pixel(px, py, Color(0.42, 0.015, 0.012, da))
					if dl > drip_len - 4:
						img.set_pixel(px - 1, py, Color(0.36, 0.012, 0.01, da * 0.85))
						img.set_pixel(px + 1, py, Color(0.36, 0.012, 0.01, da * 0.85))
