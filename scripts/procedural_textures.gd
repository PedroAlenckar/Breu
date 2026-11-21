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
