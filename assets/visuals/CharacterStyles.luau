--[[
	CharacterStyles : coiffures et vêtements modulaires (§03 « vêtements interchangeables », §20).
	Chargé par export-characters.luau (pas un script du jeu). Un vêtement = { pre?, post? } :
	  pre(wear, b)  colore les zones du corps (Parts.body) et règle les surépaisseurs ;
	  post(rig, b)  ajoute ses propres pièces (ourlets, cols, poches, bretelles…).
]]

return function(Kit: any, Parts: any)
	local add, limb, tube, bar, strand = Kit.add, Kit.limb, Kit.tube, Kit.bar, Kit.strand
	local V, at, UPRIGHT, mirror, hex = Kit.V, Kit.at, Kit.UPRIGHT, Kit.mirror, Kit.hex
	local shade, prefix = Parts.shade, Parts.prefix
	local rad = math.rad
	local SIDES = { 1, -1 }
	local SHADOW = { shadow = true }

	local Styles = { hair = {}, tops = {}, bottoms = {} }

	----------------------------------------------------------------------------------------------
	-- Coiffures. Toutes posent d'abord une calotte ; `c` = couleur, `o` = options.
	----------------------------------------------------------------------------------------------
	local function hairOpts(o: any): any
		return { reflectance = (o and o.gloss) or 0.06, shadow = true }
	end

	-- Calotte : dessus et arrière du crâne ; `line` = hauteur de la naissance des cheveux sur le front
	local function cap(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		local line = (o and o.line) or 5.0
		-- dessus : ellipsoïde décalé vers l'arrière, dont le bord avant coupe le front à `line`
		add(rig, "Head", "HairTop", "ell", c, V(1.1, 0.78, 1.06), at(0, line + 0.06, 0.07), opts)
		-- arrière et nuque
		add(rig, "Head", "HairBack", "ell", c, V(1.08, 1.0, 0.72), at(0, 4.74, 0.22), opts)
		-- tempes
		for _, side in SIDES do
			add(
				rig,
				"Head",
				"HairTemple",
				"ell",
				c,
				V(0.2, 0.5, 0.56),
				at(side * 0.46, line - 0.14, 0.02),
				opts
			)
		end
	end
	Styles.cap = cap

	-- Cherry : queue de cheval très haute, longue et ondulée, deux mèches ondulées devant les oreilles
	function Styles.hair.highWavyPonytail(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		cap(rig, c, o)
		-- base de la queue, relevée au sommet arrière du crâne
		add(rig, "Head", "PonyBase", "ell", c, V(0.6, 0.44, 0.6), at(0, 5.3, 0.22), opts)
		add(
			rig,
			"Head",
			"PonyTie",
			"cyl",
			(o and o.tie) or shade(c, 1.6),
			V(0.09, 0.38, 0.38),
			at(0, 5.44, 0.3) * CFrame.Angles(rad(-38), 0, 0) * UPRIGHT
		)
		-- la queue monte, bascule vers l'arrière puis retombe en S jusqu'aux hanches
		local length = (o and o.length) or 1
		local spine = {
			V(0, 5.44, 0.3),
			V(0, 5.62, 0.56),
			V(0.05, 5.4, 0.84),
			V(-0.1, 4.94, 0.96),
			V(0.12, 4.44, 0.92),
			V(-0.12, 3.94, 0.84),
			V(0.1, 3.46, 0.76),
			V(-0.07, 3.04, 0.68),
			V(0.04, 2.7, 0.6),
		}
		local widths = { 0.42, 0.5, 0.6, 0.7, 0.74, 0.68, 0.56, 0.4, 0.18 }
		if length < 1 then
			for i = 4, #spine do
				spine[i] = V(spine[i].X, 5.02 - (5.02 - spine[i].Y) * length, spine[i].Z)
			end
		end
		strand(rig, "Head", "Ponytail", c, spine, widths, 0.72, opts)
		-- ondulations latérales : boucles alternées qui élargissent la silhouette de dos
		local curls = {
			{ V(0.3, 4.9, 0.9), 0.36 },
			{ V(-0.32, 4.42, 0.88), 0.38 },
			{ V(0.32, 3.9, 0.8), 0.34 },
			{ V(-0.28, 3.42, 0.74), 0.3 },
			{ V(0.2, 3.02, 0.66), 0.22 },
		}
		for i, curl in curls do
			local p: Vector3 = curl[1]
			if length < 1 then
				p = V(p.X, 5.02 - (5.02 - p.Y) * length, p.Z)
			end
			local w: number = curl[2]
			add(
				rig,
				"Head",
				"PonyCurl",
				"ell",
				c,
				V(w, w * 2, w * 0.7),
				at(p.X, p.Y, p.Z) * CFrame.Angles(0, 0, rad(if i % 2 == 0 then 24 else -24)),
				opts
			)
		end
		-- mèches du visage : de la tempe à la clavicule, en zigzag
		for _, side in SIDES do
			local x = side * 0.5
			strand(rig, "Head", "FaceStrand", c, {
				V(x * 0.9, 5.06, -0.28),
				V(x * 1.04, 4.8, -0.33),
				V(x * 1.0, 4.52, -0.33),
				V(x * 1.07, 4.24, -0.31),
				V(x * 1.0, 3.98, -0.3),
				V(x * 1.06, 3.76, -0.3),
			}, { 0.12, 0.14, 0.13, 0.12, 0.1, 0.05 }, 0.75, { reflectance = opts.reflectance })
		end
	end

	-- Maya : carré bouclé (boucles rondes autour de la tête, nuque dégagée)
	function Styles.hair.curlyBob(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		cap(rig, c, { line = 5.04, gloss = opts.reflectance })
		local n = 9
		for row = 0, 2 do
			local y = 5.12 - row * 0.34
			local radius = 0.5 + row * 0.07
			for i = 0, n - 1 do
				-- arc de 250° autour de l'arrière : le visage reste dégagé
				local a = rad(-125 + (250 / (n - 1)) * i + row * 7)
				local x, z = math.sin(a) * radius, math.cos(a) * radius * 0.92 + 0.06
				local d = 0.34 + ((i + row) % 3) * 0.03
				add(
					rig,
					"Head",
					"Curl",
					"ball",
					c,
					V(d, d, d),
					at(x, y, z),
					{ reflectance = opts.reflectance }
				)
			end
		end
		for _, side in SIDES do
			add(
				rig,
				"Head",
				"CurlFront",
				"ball",
				c,
				V(0.3, 0.3, 0.3),
				at(side * 0.44, 5.06, -0.3),
				{ reflectance = opts.reflectance }
			)
			add(
				rig,
				"Head",
				"CurlFront",
				"ball",
				c,
				V(0.26, 0.26, 0.26),
				at(side * 0.2, 5.2, -0.4),
				{ reflectance = opts.reflectance }
			)
		end
		add(
			rig,
			"Head",
			"CurlTop",
			"ball",
			c,
			V(0.36, 0.36, 0.36),
			at(0, 5.3, -0.2),
			{ reflectance = opts.reflectance }
		)
	end

	-- Lina : queue de cheval haute et lisse, sportive
	function Styles.hair.sportPonytail(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		cap(rig, c, o)
		add(rig, "Head", "PonyBase", "ell", c, V(0.44, 0.4, 0.44), at(0, 5.3, 0.34), opts)
		add(
			rig,
			"Head",
			"PonyTie",
			"cyl",
			(o and o.tie) or hex("#F4F1EA"),
			V(0.09, 0.3, 0.3),
			at(0, 5.4, 0.44) * CFrame.Angles(rad(-50), 0, 0) * UPRIGHT
		)
		strand(rig, "Head", "Ponytail", c, {
			V(0, 5.42, 0.46),
			V(0, 5.5, 0.76),
			V(0, 5.1, 0.96),
			V(0, 4.56, 0.94),
			V(0, 4.1, 0.84),
		}, { 0.3, 0.36, 0.4, 0.34, 0.16 }, 0.8, opts)
	end

	-- Jade : coupe asymétrique (court d'un côté, mèche longue de l'autre)
	function Styles.hair.asymmetric(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		cap(rig, c, { line = 5.02, gloss = opts.reflectance })
		-- grande mèche balayée sur le côté gauche du personnage, jusqu'à la mâchoire
		add(
			rig,
			"Head",
			"Sweep",
			"ell",
			c,
			V(0.7, 0.34, 0.5),
			at(-0.2, 5.06, -0.34) * CFrame.Angles(0, 0, rad(18)),
			opts
		)
		strand(rig, "Head", "LongSide", c, {
			V(-0.5, 5.02, -0.2),
			V(-0.56, 4.7, -0.24),
			V(-0.54, 4.38, -0.22),
			V(-0.48, 4.12, -0.2),
		}, { 0.3, 0.32, 0.28, 0.14 }, 0.9, opts)
		add(rig, "Head", "LongBack", "ell", c, V(0.5, 0.9, 0.5), at(-0.3, 4.5, 0.26), opts)
		-- côté droit rasé court : simple plaque
		add(rig, "Head", "ShortSide", "ell", shade(c, 1.5), V(0.1, 0.5, 0.6), at(0.48, 4.74, 0.06))
		if o and o.streak then
			strand(rig, "Head", "Streak", o.streak, {
				V(-0.42, 5.08, -0.36),
				V(-0.58, 4.74, -0.3),
				V(-0.55, 4.4, -0.27),
			}, { 0.1, 0.11, 0.08 }, 0.8)
		end
	end

	-- Iris : longues tresses (§17 « assez simples pour le budget mobile »)
	function Styles.hair.longBraids(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		cap(rig, c, { line = 5.04, gloss = opts.reflectance })
		local bead = (o and o.bead) or hex("#D6336C")
		local braids = {
			{ -0.46, -0.2, 3.5 },
			{ 0.46, -0.2, 3.5 },
			{ -0.52, 0.12, 3.1 },
			{ 0.52, 0.12, 3.1 },
			{ -0.3, 0.46, 2.9 },
			{ 0.3, 0.46, 2.9 },
			{ 0, 0.54, 2.8 },
		}
		for _, braid in braids do
			local x, z, bottom = braid[1], braid[2], braid[3]
			local points, widths = {}, {}
			local steps = 6
			for i = 0, steps do
				local t = i / steps
				local y = 4.9 - (4.9 - bottom) * t
				local wobble = if i % 2 == 0 then 0.03 else -0.03
				-- les tresses s'écartent un peu de la tête en descendant, puis tombent droit
				local spread = 1 + 0.12 * math.min(t * 3, 1)
				table.insert(
					points,
					V(x * spread + wobble, y, z * spread + (if z > 0 then 0.1 * t else -0.02 * t))
				)
				table.insert(widths, 0.15)
			end
			strand(rig, "Head", "Braid", c, points, widths, 1, { reflectance = opts.reflectance })
			local tip = points[#points]
			add(rig, "Head", "Bead", "ball", bead, V(0.13, 0.13, 0.13), at(tip.X, tip.Y - 0.05, tip.Z))
		end
	end

	-- Sienna : cheveux ondulés mi-longs, volume sur les épaules
	function Styles.hair.wavyLong(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		cap(rig, c, { line = 5.02, gloss = opts.reflectance })
		add(
			rig,
			"Head",
			"Fringe",
			"ell",
			c,
			V(0.8, 0.3, 0.4),
			at(0.12, 5.1, -0.36) * CFrame.Angles(0, 0, rad(-12)),
			opts
		)
		for _, side in SIDES do
			local x = side * 0.52
			strand(rig, "Head", "WaveSide", c, {
				V(x, 5.0, -0.12),
				V(x * 1.14, 4.62, -0.14),
				V(x * 1.04, 4.24, -0.1),
				V(x * 1.2, 3.86, -0.06),
				V(x * 1.06, 3.56, -0.04),
			}, { 0.34, 0.4, 0.4, 0.36, 0.2 }, 0.8, opts)
		end
		strand(rig, "Head", "WaveBack", c, {
			V(0, 5.0, 0.46),
			V(0.08, 4.5, 0.56),
			V(-0.08, 4.0, 0.52),
			V(0.06, 3.56, 0.46),
			V(0, 3.3, 0.42),
		}, { 0.9, 1.04, 1.04, 0.9, 0.5 }, 0.5, opts)
	end

	-- Nova : coiffure relevée (chignon haut structuré)
	function Styles.hair.updo(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		cap(rig, c, { line = 5.06, gloss = opts.reflectance })
		add(rig, "Head", "UpdoBase", "ell", c, V(0.66, 0.44, 0.66), at(0, 5.4, 0.1), opts)
		add(rig, "Head", "UpdoBun", "ell", c, V(0.56, 0.6, 0.56), at(0, 5.72, 0.12), opts)
		add(rig, "Head", "UpdoTop", "ball", c, V(0.3, 0.3, 0.3), at(0, 6.02, 0.12), opts)
		if o and o.pin then
			bar(
				rig,
				"Head",
				"HairPin",
				o.pin,
				V(-0.4, 5.6, 0.0),
				V(0.4, 5.86, 0.2),
				0.035,
				0.035,
				Parts.METAL
			)
		end
	end

	-- Zuri : cheveux courts texturés
	function Styles.hair.shortTextured(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		cap(rig, c, { line = 5.06, gloss = opts.reflectance })
		local tufts = {
			{ 0, 5.34, -0.16, 0.34 },
			{ 0.26, 5.3, -0.08, 0.3 },
			{ -0.26, 5.3, -0.08, 0.3 },
			{ 0.14, 5.36, 0.14, 0.32 },
			{ -0.14, 5.36, 0.14, 0.32 },
			{ 0.36, 5.2, 0.16, 0.28 },
			{ -0.36, 5.2, 0.16, 0.28 },
			{ 0, 5.28, 0.36, 0.3 },
			{ 0.2, 5.16, -0.34, 0.24 },
			{ -0.2, 5.16, -0.34, 0.24 },
		}
		for _, t in tufts do
			add(
				rig,
				"Head",
				"Tuft",
				"ball",
				c,
				V(t[4], t[4], t[4]),
				at(t[1], t[2], t[3]),
				{ reflectance = opts.reflectance }
			)
		end
	end

	-- Vega : cheveux argentés stylisés, volumes géométriques (lames relevées)
	function Styles.hair.silverBlades(rig: any, c: Color3, o: any?)
		local opts = hairOpts({ gloss = 0.2 })
		cap(rig, c, { line = 5.04, gloss = 0.2 })
		local accent = (o and o.accent) or hex("#30D5C8")
		for i, blade in { { -0.34, 20 }, { -0.12, 7 }, { 0.12, -7 }, { 0.34, -20 } } do
			local x: number, lean: number = blade[1], blade[2]
			add(
				rig,
				"Head",
				"Blade",
				"ell",
				if i % 2 == 0 then c else shade(c, 0.92),
				V(0.24, 0.9, 0.5),
				at(x, 5.5, 0.08) * CFrame.Angles(rad(-14), 0, rad(lean)),
				opts
			)
		end
		for _, side in SIDES do
			strand(rig, "Head", "SideLock", c, {
				V(side * 0.5, 5.0, -0.16),
				V(side * 0.58, 4.6, -0.2),
				V(side * 0.52, 4.2, -0.16),
			}, { 0.24, 0.26, 0.12 }, 0.8, opts)
			add(
				rig,
				"Head",
				"LockTip",
				"ball",
				accent,
				V(0.1, 0.1, 0.1),
				at(side * 0.52, 4.12, -0.16),
				{ material = Enum.Material.Neon }
			)
		end
		add(rig, "Head", "BackSweep", "ell", c, V(0.9, 1.1, 0.5), at(0, 4.6, 0.36), opts)
	end

	-- Coupes courtes masculines : "fade" (dégradé net), "crop" (dessus texturé), "waves", "buzz"
	function Styles.hair.short(rig: any, c: Color3, o: any?)
		local opts = hairOpts(o)
		local kind = (o and o.kind) or "crop"
		local line = 5.08
		add(rig, "Head", "HairTop", "ell", c, V(1.06, 0.6, 1.04), at(0, line + 0.06, 0.06), opts)
		add(
			rig,
			"Head",
			"HairBack",
			"ell",
			if kind == "fade" then shade(c, 1.35) else c,
			V(1.05, 0.7, 0.66),
			at(0, 4.86, 0.22),
			opts
		)
		if kind == "crop" or kind == "quiff" then
			for _, t in
				{
					{ 0, 5.4, -0.2, 0.36 },
					{ 0.24, 5.36, -0.12, 0.3 },
					{ -0.24, 5.36, -0.12, 0.3 },
					{ 0, 5.4, 0.1, 0.34 },
				}
			do
				add(
					rig,
					"Head",
					"Tuft",
					"ball",
					c,
					V(t[4], t[4], t[4]),
					at(t[1], t[2], t[3]),
					{ reflectance = opts.reflectance }
				)
			end
			if kind == "quiff" then
				add(
					rig,
					"Head",
					"Quiff",
					"ell",
					c,
					V(0.6, 0.4, 0.4),
					at(0, 5.44, -0.3) * CFrame.Angles(rad(20), 0, 0),
					opts
				)
			end
		elseif kind == "waves" then
			for row = 0, 2 do
				add(
					rig,
					"Head",
					"Wave",
					"cyl",
					shade(c, 1.2 + row * 0.1),
					V(0.05, 0.9 - row * 0.2, 0.9 - row * 0.2),
					at(0, 5.22 + row * 0.07, 0.06) * UPRIGHT
				)
			end
		elseif kind == "locs" then
			for i = 0, 7 do
				local a = rad(i * 45)
				strand(rig, "Head", "Loc", c, {
					V(math.sin(a) * 0.3, 5.3, math.cos(a) * 0.3 + 0.06),
					V(math.sin(a) * 0.52, 5.1, math.cos(a) * 0.5 + 0.06),
					V(math.sin(a) * 0.6, 4.84, math.cos(a) * 0.56 + 0.06),
				}, { 0.16, 0.15, 0.13 }, 1)
			end
		end
	end

	----------------------------------------------------------------------------------------------
	-- Hauts
	----------------------------------------------------------------------------------------------

	-- Débardeur court à encolure carrée (Cherry) : ventre visible, bretelles larges, bord côtelé
	function Styles.tops.tankCrop(c: any)
		return {
			pre = function(wear: any)
				wear.chest = c.color
			end,
			post = function(rig: any, b: any)
				local trim = c.trim or shade(c.color, 0.86)
				-- ourlet côtelé au-dessus du nombril
				add(
					rig,
					"UpperTorso",
					"TopHem",
					"ell",
					trim,
					V(b.waistW + 0.12, 0.16, b.waistD + 0.13),
					at(0, 3.33, 0)
				)
				-- bretelles : disque mince qui épouse l'épaule de l'avant vers l'arrière ; l'encolure carrée
				-- naît de la rencontre du buste (haut) et des épaules (peau)
				for _, side in SIDES do
					local x = side * 0.25
					local taper = math.sqrt(1 - (0.25 / (rig.S.shoulderX + 0.02)) ^ 2)
					add(
						rig,
						"UpperTorso",
						"Strap",
						"ell",
						c.color,
						V(0.15, 0.46 * taper + 0.05, b.chestD * 0.8 * taper + 0.05),
						at(x, rig.S.shoulderY - 0.12, 0)
					)
				end
			end,
		}
	end

	-- T-shirt / haut à manches courtes ; long = couvre le ventre
	function Styles.tops.tee(c: any)
		return {
			pre = function(wear: any)
				wear.chest = c.color
				wear.yoke = c.color
				wear.shoulder = c.color
				if c.crop ~= true then
					wear.midriff = c.color
				end
				wear.torsoBulk = math.max(wear.torsoBulk or 0, 0.03)
			end,
			post = function(rig: any, b: any)
				local S = rig.S
				for _, side in SIDES do
					local shoulder, elbow = mirror(S.shoulder, side), mirror(S.elbow, side)
					local stop = shoulder + (elbow - shoulder) * 0.5
					tube(rig, prefix(side) .. "UpperArm", "Sleeve", c.color, shoulder, stop, b.armW + 0.08)
					tube(
						rig,
						prefix(side) .. "UpperArm",
						"SleeveHem",
						c.trim or shade(c.color, 0.86),
						stop,
						stop + (elbow - shoulder).Unit * 0.05,
						b.armW + 0.09
					)
				end
				if c.crop then
					add(
						rig,
						"UpperTorso",
						"TopHem",
						"ell",
						c.trim or shade(c.color, 0.86),
						V(b.waistW + 0.14, 0.14, b.waistD + 0.15),
						at(0, 3.33, 0)
					)
				else
					add(
						rig,
						"UpperTorso",
						"TopHem",
						"ell",
						c.trim or shade(c.color, 0.86),
						V(b.waistW + 0.16, 0.14, b.waistD + 0.17),
						at(0, 3.04, 0)
					)
				end
				add(
					rig,
					"UpperTorso",
					"Collar",
					"cyl",
					c.trim or shade(c.color, 0.86),
					V(0.05, b.neckW + 0.1, b.neckW + 0.1),
					at(0, 4.0, 0) * UPRIGHT
				)
				if c.print then
					add(
						rig,
						"UpperTorso",
						"Print",
						"box",
						c.print,
						V(0.34, 0.2, 0.04),
						at(0, 3.62, -(b.chestD / 2 + 0.005))
					)
				end
			end,
		}
	end

	-- Veste (bomber, survêtement, tailleur, veste structurée) : manches longues, ouverte sur un haut
	-- c = { color, inner (haut dessous), trim?, zip?, collar? ("stand" | "lapel" | "hood"), length?, cuffs?,
	--       stripe? (bande de manche), panel? (empiècement d'épaule), glow? }
	function Styles.tops.jacket(c: any)
		return {
			pre = function(wear: any)
				wear.chest = c.inner or c.color
				wear.midriff = if c.crop then wear.midriff else (c.inner or c.color)
				wear.yoke = c.color
				wear.shoulder = c.panel or c.color
				wear.upperArm = c.color
				wear.lowerArm = c.color
				wear.sleeveBulk = math.max(wear.sleeveBulk or 0, c.bulk or 0.08)
				wear.torsoBulk = math.max(wear.torsoBulk or 0, 0.02)
			end,
			post = function(rig: any, b: any)
				local S = rig.S
				local trim = c.trim or shade(c.color, 0.8)
				local bottom = if c.crop then 3.34 else (c.length or 2.98)
				local halfW = b.chestW / 2 + 0.07
				local depth = b.chestD + 0.14
				-- pans avant : deux panneaux ouverts sur le haut du dessous
				for _, side in SIDES do
					local x = side * (halfW * 0.62)
					add(
						rig,
						"UpperTorso",
						"JacketFront",
						"ell",
						c.color,
						V(halfW * 0.9, 4.02 - bottom + 0.1, depth),
						at(x, (4.02 + bottom) / 2, 0) * CFrame.Angles(0, 0, rad(side * 3)),
						SHADOW
					)
					-- poignet
					local wrist, elbow = mirror(S.wrist, side), mirror(S.elbow, side)
					local dir = (wrist - elbow).Unit
					tube(
						rig,
						prefix(side) .. "LowerArm",
						"Cuff",
						c.cuffs or trim,
						wrist - dir * 0.1,
						wrist + dir * 0.02,
						b.forearmW + 0.13
					)
					if c.stripe then
						local shoulder = mirror(S.shoulder, side)
						bar(
							rig,
							prefix(side) .. "UpperArm",
							"SleeveStripe",
							c.stripe,
							shoulder + V(side * (b.armW / 2 + 0.065), -0.04, 0),
							elbow + V(side * (b.armW / 2 + 0.055), 0.04, 0),
							0.03,
							0.09,
							if c.glow then { material = Enum.Material.Neon } else nil
						)
					end
				end
				-- dos
				add(
					rig,
					"UpperTorso",
					"JacketBack",
					"ell",
					c.color,
					V(halfW * 2, 4.04 - bottom + 0.1, depth * 0.7),
					at(0, (4.04 + bottom) / 2, 0.08),
					SHADOW
				)
				-- bord bas
				add(
					rig,
					"UpperTorso",
					"JacketHem",
					"ell",
					trim,
					V(halfW * 2 + 0.02, 0.14, depth + 0.02),
					at(0, bottom + 0.04, 0.02)
				)
				-- le haut du dessous reste visible au centre
				add(
					rig,
					"UpperTorso",
					"InnerFront",
					"ell",
					c.inner or c.color,
					V(halfW * 0.9, 4.0 - bottom, depth * 0.6),
					at(0, (4.0 + bottom) / 2 + 0.02, -(depth * 0.2 - 0.01))
				)
				if c.zip then
					bar(
						rig,
						"UpperTorso",
						"Zip",
						c.zip,
						V(-0.14, 3.98, -(depth / 2 - 0.01)),
						V(-0.14, bottom + 0.1, -(depth / 2 - 0.01)),
						0.03,
						0.03,
						Parts.METAL
					)
					bar(
						rig,
						"UpperTorso",
						"Zip",
						c.zip,
						V(0.14, 3.98, -(depth / 2 - 0.01)),
						V(0.14, bottom + 0.1, -(depth / 2 - 0.01)),
						0.03,
						0.03,
						Parts.METAL
					)
				end
				if c.collar == "stand" then
					add(
						rig,
						"UpperTorso",
						"Collar",
						"cyl",
						trim,
						V(0.16, b.neckW + 0.2, b.neckW + 0.2),
						at(0, 4.08, 0.01) * UPRIGHT
					)
				elseif c.collar == "lapel" then
					for _, side in SIDES do
						bar(
							rig,
							"UpperTorso",
							"Lapel",
							trim,
							V(side * 0.2, 4.06, -0.2),
							V(side * 0.13, 3.52, -(depth / 2 + 0.01)),
							0.13,
							0.04
						)
					end
				elseif c.collar == "hood" then
					add(rig, "UpperTorso", "Hood", "ell", c.color, V(0.74, 0.5, 0.44), at(0, 4.04, 0.26))
				end
				if c.emblem then
					add(
						rig,
						"UpperTorso",
						"Emblem",
						"ball",
						c.emblem,
						V(0.12, 0.12, 0.12),
						at(0.26, 3.72, -(depth / 2 - 0.02)),
						if c.glow then { material = Enum.Material.Neon } else nil
					)
				end
				if c.backPrint then
					add(
						rig,
						"UpperTorso",
						"BackPrint",
						"box",
						c.backPrint,
						V(0.44, 0.34, 0.04),
						at(0, 3.62, depth * 0.35 + 0.08),
						if c.glow then { material = Enum.Material.Neon } else nil
					)
				end
			end,
		}
	end

	----------------------------------------------------------------------------------------------
	-- Bas
	----------------------------------------------------------------------------------------------

	local function belt(rig: any, b: any, c: any)
		add(
			rig,
			"LowerTorso",
			"Belt",
			"ell",
			c.belt,
			V(b.waistW + 0.13, 0.13, b.waistD + 0.14),
			at(0, 3.01, 0)
		)
		if c.buckle then
			add(
				rig,
				"LowerTorso",
				"Buckle",
				"box",
				c.buckle,
				V(0.15, 0.13, 0.04),
				at(0, 3.01, -(b.waistD / 2 + 0.07)),
				Parts.METAL
			)
			add(
				rig,
				"LowerTorso",
				"BuckleHole",
				"box",
				c.belt,
				V(0.085, 0.07, 0.045),
				at(0, 3.01, -(b.waistD / 2 + 0.072))
			)
		end
	end

	-- Short en jean à revers (Cherry) : ceinture, boucle, passants, poches, revers clairs
	function Styles.bottoms.denimShorts(c: any)
		return {
			pre = function(wear: any)
				wear.hips = c.color
			end,
			post = function(rig: any, b: any)
				local S = rig.S
				local stitch = c.stitch or shade(c.color, 0.78)
				for _, side in SIDES do
					local hip, knee = mirror(S.hip, side), mirror(S.knee, side)
					local dir = (knee - hip).Unit
					local hem = hip + dir * (c.length or 0.3)
					local d = b.thighW + 0.07
					tube(
						rig,
						prefix(side) .. "UpperLeg",
						"ShortLeg",
						c.color,
						hip + V(0, 0.06, 0),
						hem,
						d,
						SHADOW
					)
					-- revers roulé
					tube(
						rig,
						prefix(side) .. "UpperLeg",
						"Cuff",
						c.cuff or shade(c.color, 1.5),
						hem - dir * 0.02,
						hem + dir * 0.1,
						d + 0.035
					)
					-- poche avant (couture en arc) et poche arrière
					bar(
						rig,
						"LowerTorso",
						"PocketFront",
						stitch,
						V(side * 0.14, 2.92, -(b.hipD / 2 - 0.035)),
						V(side * 0.36, 2.76, -(b.hipD / 2 - 0.07)),
						0.022,
						0.022
					)
					add(
						rig,
						"LowerTorso",
						"PocketBack",
						"box",
						stitch,
						V(0.24, 0.24, 0.03),
						at(side * 0.25, 2.66, b.hipD / 2 - 0.03) * CFrame.Angles(rad(-12), 0, rad(side * 4))
					)
					add(
						rig,
						"LowerTorso",
						"PocketBackFill",
						"box",
						c.color,
						V(0.2, 0.2, 0.035),
						at(side * 0.25, 2.665, b.hipD / 2 - 0.028) * CFrame.Angles(rad(-12), 0, rad(side * 4))
					)
					-- passants de ceinture
					add(
						rig,
						"LowerTorso",
						"BeltLoop",
						"box",
						c.color,
						V(0.045, 0.17, 0.03),
						at(side * 0.2, 3.01, -(b.waistD / 2 + 0.068)) * CFrame.Angles(0, rad(-side * 18), 0)
					)
				end
				-- braguette
				bar(
					rig,
					"LowerTorso",
					"Fly",
					stitch,
					V(0.03, 2.93, -(b.hipD / 2 - 0.01)),
					V(0.03, 2.62, -(b.hipD / 2 - 0.06)),
					0.022,
					0.022
				)
				if c.belt then
					belt(rig, b, c)
				end
			end,
		}
	end

	-- Pantalon : "wide" (ample, cargo), "straight" (droit), "slim". Options : stripe (bande latérale),
	-- pockets (cargo), cuff (bas resserré), belt.
	function Styles.bottoms.pants(c: any)
		local bulk = if c.cut == "wide" then 0.12 elseif c.cut == "slim" then 0.02 else 0.06
		return {
			pre = function(wear: any)
				wear.hips = c.color
				wear.thigh = c.color
				wear.calf = c.color
				wear.legBulk = bulk
			end,
			post = function(rig: any, b: any)
				local S = rig.S
				for _, side in SIDES do
					local knee, ankle, hip = mirror(S.knee, side), mirror(S.ankle, side), mirror(S.hip, side)
					local dir = (ankle - knee).Unit
					local legW = b.calfW + bulk + (if c.cut == "wide" then 0.14 else 0.04)
					-- jambe du bas : tube jusqu'à la cheville (silhouette ample ou droite)
					tube(
						rig,
						prefix(side) .. "LowerLeg",
						"PantLeg",
						c.color,
						knee - dir * 0.04,
						ankle + dir * 0.08,
						legW,
						SHADOW
					)
					if c.cuff then
						tube(
							rig,
							prefix(side) .. "LowerLeg",
							"PantCuff",
							c.cuff,
							ankle - dir * 0.02,
							ankle + dir * 0.1,
							legW * (if c.cut == "wide" then 0.8 else 1.04)
						)
					end
					if c.stripe then
						bar(
							rig,
							prefix(side) .. "UpperLeg",
							"LegStripe",
							c.stripe,
							hip + V(side * (b.thighW / 2 + bulk / 2 + 0.005), 0, 0),
							knee + V(side * (legW / 2 + 0.0), 0, 0),
							0.03,
							0.1,
							if c.glow then { material = Enum.Material.Neon } else nil
						)
						bar(
							rig,
							prefix(side) .. "LowerLeg",
							"LegStripe",
							c.stripe,
							knee + V(side * (legW / 2 + 0.005), 0, 0),
							ankle + V(side * (legW / 2 + 0.005), 0.1, 0),
							0.03,
							0.1,
							if c.glow then { material = Enum.Material.Neon } else nil
						)
					end
					if c.pockets then
						add(
							rig,
							prefix(side) .. "UpperLeg",
							"CargoPocket",
							"box",
							c.pockets,
							V(0.08, 0.32, 0.34),
							at(hip.X + side * (b.thighW / 2 + bulk / 2 + 0.01), 2.0, 0)
						)
						add(
							rig,
							prefix(side) .. "UpperLeg",
							"CargoFlap",
							"box",
							shade(c.pockets, 0.85),
							V(0.09, 0.09, 0.36),
							at(hip.X + side * (b.thighW / 2 + bulk / 2 + 0.012), 2.14, 0)
						)
					end
				end
				if c.belt then
					belt(rig, b, c)
				else
					add(
						rig,
						"LowerTorso",
						"Waistband",
						"ell",
						c.waistband or shade(c.color, 0.84),
						V(b.waistW + 0.12, 0.12, b.waistD + 0.13),
						at(0, 3.01, 0)
					)
				end
			end,
		}
	end

	return Styles
end
