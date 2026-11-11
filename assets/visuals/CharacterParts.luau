--[[
	CharacterParts : corps, visage, chaussures et accessoires communs, construits avec CharacterKit.
	Chargé par export-characters.luau (pas un script du jeu). Toutes les cotes sont en repère modèle,
	pour un personnage de 5,3 studs (voir CharacterKit.skeleton).
]]

return function(Kit: any)
	local add, limb, tube, bar, ring = Kit.add, Kit.limb, Kit.tube, Kit.bar, Kit.ring
	local V, at, UPRIGHT, mirror, hex = Kit.V, Kit.at, Kit.UPRIGHT, Kit.mirror, Kit.hex
	local rad = math.rad

	local Parts = {}

	local SHADOW = { shadow = true }
	local SIDES = { 1, -1 }

	local function prefix(side: number): string
		return if side == 1 then "Right" else "Left"
	end
	Parts.prefix = prefix

	local function shade(color: Color3, factor: number): Color3
		return Color3.new(
			math.clamp(color.R * factor, 0, 1),
			math.clamp(color.G * factor, 0, 1),
			math.clamp(color.B * factor, 0, 1)
		)
	end
	Parts.shade = shade

	-- Carrures de référence (§20 : rig commun, silhouettes distinctes)
	Parts.BUILD_F = {
		shoulderX = 0.47,
		hipX = 0.29,
		kneeX = 0.33,
		ankleX = 0.4,
		armSpread = 11,
		chestW = 0.86,
		chestD = 0.54,
		waistW = 0.68,
		waistD = 0.44,
		hipW = 1.12,
		hipD = 0.64,
		thighW = 0.58,
		thighD = 0.56,
		calfW = 0.38,
		armW = 0.25,
		forearmW = 0.21,
		neckW = 0.25,
	}
	Parts.BUILD_M = {
		shoulderX = 0.62,
		hipX = 0.27,
		kneeX = 0.3,
		ankleX = 0.36,
		armSpread = 12,
		chestW = 1.16,
		chestD = 0.62,
		waistW = 0.9,
		waistD = 0.52,
		hipW = 0.96,
		hipD = 0.58,
		thighW = 0.5,
		thighD = 0.5,
		calfW = 0.4,
		armW = 0.36,
		forearmW = 0.3,
		neckW = 0.32,
		male = true,
	}

	function Parts.build(base: any, changes: any?): any
		local b = table.clone(base)
		for key, value in changes or {} do
			b[key] = value
		end
		return b
	end

	----------------------------------------------------------------------------------------------
	-- Corps. `wear` : couleur par zone (nil = peau) et surépaisseur des vêtements.
	--   yoke, chest, midriff, hips, shoulder, upperArm, lowerArm, thigh, calf : Color3?
	--   sleeveBulk, legBulk, torsoBulk : nombre (studs ajoutés aux largeurs)
	----------------------------------------------------------------------------------------------
	function Parts.body(rig: any, b: any, wear: any)
		local S = rig.S
		local skin = rig.skin
		local torsoBulk = wear.torsoBulk or 0
		local sleeveBulk = wear.sleeveBulk or 0
		local legBulk = wear.legBulk or 0

		-- Tête : cylindre + calottes (silhouette « tête Roblox » arrondie)
		local r2 = S.headR * 2
		add(
			rig,
			"Head",
			"Head",
			"cyl",
			skin,
			V(S.headCylTop - S.headCylBottom, r2, r2),
			at(0, (S.headCylTop + S.headCylBottom) / 2, 0) * UPRIGHT,
			SHADOW
		)
		add(rig, "Head", "Skull", "ell", skin, V(r2, S.headTopH * 2, r2), at(0, S.headCylTop, 0))
		add(rig, "Head", "Chin", "ell", skin, V(r2, S.headBottomH * 2, r2), at(0, S.headCylBottom, 0))
		local mask = S.face
		add(rig, "Head", "Face", "ell", skin, V(mask.a * 2, mask.b * 2, mask.c * 2), at(0, mask.y, mask.z))
		for _, side in SIDES do
			add(rig, "Head", "Ear", "ell", skin, V(0.1, 0.22, 0.15), at(side * (S.headR - 0.005), 4.62, 0.04))
		end
		tube(rig, "UpperTorso", "Neck", wear.neck or skin, V(0, 3.9, 0), V(0, 4.26, 0), b.neckW)

		-- Torse
		add(
			rig,
			"UpperTorso",
			"Yoke",
			"ell",
			wear.yoke or skin,
			V(S.shoulderX * 2 + 0.04 + torsoBulk, 0.46 + torsoBulk * 0.4, b.chestD * 0.8 + torsoBulk),
			at(0, S.shoulderY - 0.12, 0)
		)
		add(
			rig,
			"UpperTorso",
			"Chest",
			"ell",
			wear.chest or skin,
			V(b.chestW + torsoBulk, 0.72, b.chestD + torsoBulk),
			at(0, 3.54, 0),
			SHADOW
		)
		add(
			rig,
			"UpperTorso",
			"Midriff",
			"ell",
			wear.midriff or skin,
			V(
				b.waistW + (if wear.midriff then torsoBulk else 0),
				0.66,
				b.waistD + (if wear.midriff then torsoBulk else 0)
			),
			at(0, 3.22, 0)
		)
		add(
			rig,
			"LowerTorso",
			"Hips",
			"ell",
			wear.hips or skin,
			V(b.hipW + legBulk, 0.72, b.hipD + legBulk),
			at(0, 2.66, 0),
			SHADOW
		)

		for _, side in SIDES do
			local p = prefix(side)
			local shoulder, elbow, wrist =
				mirror(S.shoulder, side), mirror(S.elbow, side), mirror(S.wrist, side)
			local upper = wear.upperArm
			local lower = wear.lowerArm
			local upperW = b.armW + (if upper then sleeveBulk else 0)
			local lowerW = b.forearmW + (if lower then sleeveBulk else 0)
			add(
				rig,
				p .. "UpperArm",
				"Shoulder",
				"ball",
				wear.shoulder or upper or skin,
				V(1, 1, 1) * (upperW + 0.02),
				at(shoulder.X, shoulder.Y, shoulder.Z)
			)
			limb(rig, p .. "UpperArm", "UpperArm", upper or skin, shoulder, elbow, upperW, upperW, 0.42)
			add(
				rig,
				p .. "LowerArm",
				"Elbow",
				"ball",
				lower or upper or skin,
				V(1, 1, 1) * (lowerW - 0.02),
				at(elbow.X, elbow.Y, elbow.Z)
			)
			limb(rig, p .. "LowerArm", "LowerArm", lower or skin, elbow, wrist, lowerW, lowerW, 0.36)

			-- Main « pince » : paume, doigts repliés, pouce
			local hand = mirror(S.handCenter, side)
			local glove = wear.hand or skin
			add(rig, p .. "Hand", "Palm", "ell", glove, V(0.19, 0.3, 0.25), at(hand.X, hand.Y, hand.Z))
			add(
				rig,
				p .. "Hand",
				"Fingers",
				"ell",
				glove,
				V(0.17, 0.2, 0.13),
				at(hand.X + side * 0.01, hand.Y - 0.14, hand.Z - 0.07)
			)
			add(
				rig,
				p .. "Hand",
				"Thumb",
				"ell",
				glove,
				V(0.09, 0.17, 0.1),
				at(hand.X - side * 0.07, hand.Y - 0.05, hand.Z - 0.1)
			)

			-- Jambe
			local hip, knee, ankle = mirror(S.hip, side), mirror(S.knee, side), mirror(S.ankle, side)
			local thighW = b.thighW + (if wear.thigh then legBulk else 0)
			local thighD = b.thighD + (if wear.thigh then legBulk else 0)
			local calfW = b.calfW + (if wear.calf then legBulk else 0)
			limb(
				rig,
				p .. "UpperLeg",
				"Thigh",
				wear.thigh or skin,
				hip + V(0, 0.08, 0),
				knee,
				thighW,
				thighD,
				0.52,
				SHADOW
			)
			add(
				rig,
				p .. "LowerLeg",
				"Knee",
				"ball",
				wear.calf or wear.knee or skin,
				V(1, 1, 1) * (calfW - 0.03),
				at(knee.X, knee.Y, knee.Z)
			)
			limb(
				rig,
				p .. "LowerLeg",
				"Calf",
				wear.calf or skin,
				knee,
				ankle,
				calfW,
				calfW * 1.06,
				0.5,
				SHADOW
			)
		end
	end

	----------------------------------------------------------------------------------------------
	-- Visage (§03 : visage cohérent entre les looks, lisible dans le Book)
	----------------------------------------------------------------------------------------------
	function Parts.face(rig: any, f: any)
		local patch = Kit.facePatch
		local skin = rig.skin
		local black = f.liner or hex("#141114")
		local eyeX, eyeY = f.eyeX or 0.2, f.eyeY or 4.68
		local w, h = f.eyeW or 0.235, f.eyeH or 0.165
		local tilt = f.eyeTilt or 7

		for _, side in SIDES do
			local x = side * eyeX
			if f.lashes ~= false then
				patch(rig, "Lash", black, x, eyeY, w + 0.055, h + 0.04, 0.03, -side * tilt)
			end
			patch(rig, "EyeWhite", hex("#FBF7F2"), x, eyeY - 0.01, w, h, 0.05, -side * tilt)
			local ix = x - side * 0.012
			patch(rig, "Iris", f.iris or hex("#6B3F22"), ix, eyeY - 0.012, h * 0.86, h * 0.92, 0.066)
			patch(rig, "Pupil", hex("#170D08"), ix, eyeY - 0.014, h * 0.44, h * 0.48, 0.08)
			patch(rig, "Glint", hex("#FFFFFF"), ix + 0.03, eyeY + 0.012, 0.04, 0.04, 0.092)
			if f.lidded ~= false then
				-- paupière : peau au-dessus, trait de cils épais dessous (regard mi-clos)
				patch(
					rig,
					"Eyelid",
					f.eyeshadow or shade(skin, 0.93),
					x,
					eyeY + h * 0.62,
					w + 0.03,
					h * 0.5,
					0.072,
					-side * tilt
				)
				patch(rig, "LashLine", black, x, eyeY + h * 0.4, w + 0.07, h * 0.24, 0.08, -side * tilt)
			end
			if f.wing ~= false and f.lashes ~= false then
				patch(
					rig,
					"Wing",
					black,
					x + side * (w / 2 + 0.012),
					eyeY + h * 0.44,
					0.11,
					0.04,
					0.074,
					-side * 30
				)
			end
			patch(
				rig,
				"Brow",
				f.brow or hex("#1E1A1C"),
				side * (f.browX or 0.205),
				f.browY or (eyeY + 0.185),
				f.browW or 0.25,
				f.browH or 0.062,
				0.05,
				-side * (f.browTilt or 12)
			)
		end

		patch(rig, "Nose", shade(skin, 0.88), 0, 4.53, 0.07, 0.05, 0.07)
		if f.lip then
			patch(rig, "LipUpper", f.lipUpper or shade(f.lip, 0.86), 0, 4.39, f.lipW or 0.2, 0.058, 0.05)
			patch(rig, "LipLower", f.lip, 0, 4.345, (f.lipW or 0.2) * 0.86, 0.075, 0.066)
		else
			patch(rig, "Mouth", shade(skin, 0.62), 0, 4.37, f.lipW or 0.15, 0.03, 0.04)
		end
		if f.beard then
			add(rig, "Head", "Beard", "ell", f.beard, V(0.86, 0.36, 0.5), at(0, 4.3, -0.2))
		end
	end

	----------------------------------------------------------------------------------------------
	-- Chaussures
	----------------------------------------------------------------------------------------------

	-- Basket épaisse : semelle d'usure, semelle intermédiaire, tige, col, lacets, languette de talon
	-- c = { upper, sole, midsole?, accent?, lace?, motif? ("cherry"), glowSole? }
	function Parts.sneakers(rig: any, c: any)
		local S = rig.S
		for _, side in SIDES do
			local boneName = prefix(side) .. "Foot"
			local x = side * S.ankleX
			local soleOpts = if c.glowSole then { material = Enum.Material.Neon } else nil
			-- semelle d'usure : pavé + bouts arrondis
			add(rig, boneName, "Outsole", "box", c.sole, V(0.52, 0.13, 0.66), at(x, 0.065, -0.1), soleOpts)
			add(
				rig,
				boneName,
				"OutsoleToe",
				"cyl",
				c.sole,
				V(0.13, 0.52, 0.52),
				at(x, 0.065, -0.43) * UPRIGHT,
				soleOpts
			)
			add(
				rig,
				boneName,
				"OutsoleHeel",
				"cyl",
				c.sole,
				V(0.13, 0.52, 0.52),
				at(x, 0.065, 0.23) * UPRIGHT,
				soleOpts
			)
			local mid = c.midsole or c.upper
			add(rig, boneName, "Midsole", "box", mid, V(0.5, 0.15, 0.66), at(x, 0.2, -0.1))
			add(rig, boneName, "MidsoleToe", "cyl", mid, V(0.15, 0.5, 0.5), at(x, 0.2, -0.43) * UPRIGHT)
			add(rig, boneName, "MidsoleHeel", "cyl", mid, V(0.15, 0.5, 0.5), at(x, 0.2, 0.23) * UPRIGHT)
			-- tige
			add(rig, boneName, "Upper", "ell", c.upper, V(0.5, 0.5, 0.98), at(x, 0.36, -0.1), SHADOW)
			add(rig, boneName, "ToeBox", "ell", c.upper, V(0.47, 0.3, 0.42), at(x, 0.36, -0.42))
			add(rig, boneName, "Collar", "cyl", c.upper, V(0.2, 0.44, 0.44), at(x, 0.52, 0.06) * UPRIGHT)
			add(
				rig,
				boneName,
				"Tongue",
				"ell",
				c.upper,
				V(0.26, 0.3, 0.2),
				at(x, 0.56, -0.16) * CFrame.Angles(rad(-25), 0, 0)
			)
			-- lacets
			local lace = c.lace or shade(c.upper, 0.9)
			for i = 0, 2 do
				add(
					rig,
					boneName,
					"Lace",
					"box",
					lace,
					V(0.3, 0.035, 0.05),
					at(x, 0.5 - i * 0.045, -0.26 - i * 0.07)
						* CFrame.Angles(rad(-32), 0, rad(if i % 2 == 0 then 8 else -8))
				)
			end
			add(rig, boneName, "Bow", "ell", lace, V(0.22, 0.07, 0.07), at(x, 0.56, -0.2))
			-- touches de couleur : talon et flanc
			local accent = c.accent or c.sole
			add(
				rig,
				boneName,
				"HeelTab",
				"box",
				accent,
				V(0.24, 0.2, 0.05),
				at(x, 0.42, 0.405) * CFrame.Angles(rad(8), 0, 0)
			)
			add(
				rig,
				boneName,
				"SideStripe",
				"ell",
				accent,
				V(0.04, 0.12, 0.3),
				at(x + side * 0.235, 0.33, 0.16)
			)
			if c.motif == "cherry" then
				-- deux cerises et leurs tiges sur le flanc extérieur
				local mx = x + side * 0.245
				local red, green = hex("#C4122A"), hex("#3F7D3A")
				add(rig, boneName, "CherryA", "ell", red, V(0.05, 0.105, 0.105), at(mx, 0.3, -0.16))
				add(rig, boneName, "CherryB", "ell", red, V(0.05, 0.105, 0.105), at(mx, 0.31, -0.03))
				bar(rig, boneName, "Stem", green, V(mx, 0.34, -0.16), V(mx, 0.45, -0.07), 0.022)
				bar(rig, boneName, "Stem", green, V(mx, 0.35, -0.03), V(mx, 0.45, -0.07), 0.022)
				add(
					rig,
					boneName,
					"Leaf",
					"ell",
					green,
					V(0.03, 0.04, 0.09),
					at(mx, 0.455, -0.11) * CFrame.Angles(rad(20), 0, 0)
				)
			end
		end
	end

	-- Chaussettes : bourrelets empilés au-dessus de la chaussure (côtes)
	function Parts.socks(rig: any, color: Color3, top: number?)
		local S = rig.S
		local high = top or 0.86
		for _, side in SIDES do
			local boneName = prefix(side) .. "LowerLeg"
			local ankle, knee = mirror(S.ankle, side), mirror(S.knee, side)
			local dir = (knee - ankle).Unit
			local steps = math.max(2, math.floor((high - 0.5) / 0.12 + 0.5))
			for i = 0, steps - 1 do
				local y = 0.56 + i * ((high - 0.56) / math.max(1, steps - 1))
				local p = ankle + dir * ((y - ankle.Y) / dir.Y)
				add(
					rig,
					boneName,
					"Sock",
					"ell",
					if i % 2 == 0 then color else shade(color, 0.95),
					V(0.42 + (i % 2) * 0.015, 0.17, 0.44 + (i % 2) * 0.015),
					at(p.X, p.Y, p.Z)
				)
			end
		end
	end

	-- Bottines / chaussures montantes simples : semelle + tige haute
	function Parts.boots(rig: any, c: any)
		local S = rig.S
		for _, side in SIDES do
			local boneName = prefix(side) .. "Foot"
			local x = side * S.ankleX
			add(rig, boneName, "Sole", "box", c.sole, V(0.5, 0.16, 0.66), at(x, 0.08, -0.1))
			add(rig, boneName, "SoleToe", "cyl", c.sole, V(0.16, 0.5, 0.5), at(x, 0.08, -0.43) * UPRIGHT)
			add(rig, boneName, "SoleHeel", "cyl", c.sole, V(0.16, 0.5, 0.5), at(x, 0.08, 0.23) * UPRIGHT)
			add(rig, boneName, "Upper", "ell", c.upper, V(0.48, 0.5, 0.96), at(x, 0.32, -0.1), SHADOW)
			add(rig, boneName, "ToeBox", "ell", c.upper, V(0.46, 0.32, 0.42), at(x, 0.3, -0.42))
			local ankle, knee = mirror(S.ankle, side), mirror(S.knee, side)
			local dir = (knee - ankle).Unit
			tube(
				rig,
				prefix(side) .. "LowerLeg",
				"Shaft",
				c.upper,
				ankle - dir * 0.1,
				ankle + dir * (c.height or 0.4),
				0.46
			)
			if c.accent then
				tube(
					rig,
					prefix(side) .. "LowerLeg",
					"ShaftTrim",
					c.accent,
					ankle + dir * ((c.height or 0.4) - 0.03),
					ankle + dir * ((c.height or 0.4) + 0.05),
					0.6
				)
			end
		end
	end

	----------------------------------------------------------------------------------------------
	-- Accessoires
	----------------------------------------------------------------------------------------------
	local METAL = { material = Enum.Material.Metal, reflectance = 0.25 }
	Parts.METAL = METAL

	-- Créoles sous les oreilles, face à la caméra
	function Parts.hoops(rig: any, color: Color3, radius: number?)
		local S = rig.S
		local r = radius or 0.1
		for _, side in SIDES do
			local cf = at(side * (S.headR - 0.01), 4.52 - r, 0.0) * CFrame.Angles(0, rad(side * 14), 0)
			ring(rig, "Head", "Hoop", color, cf, r, 0.03, 8, METAL)
		end
	end

	-- Petites boucles (clous)
	function Parts.studs(rig: any, color: Color3)
		local S = rig.S
		for _, side in SIDES do
			add(
				rig,
				"Head",
				"Stud",
				"ball",
				color,
				V(0.07, 0.07, 0.07),
				at(side * (S.headR + 0.03), 4.54, 0.02),
				METAL
			)
		end
	end

	-- Collier(s) : polyligne en U posée sur le haut du buste ; pendentif optionnel
	function Parts.necklace(rig: any, color: Color3, drop: number, pendant: Color3?, depth: number?)
		local z0 = -(depth or 0.2)
		local points = {
			V(-0.15, 4.0, z0 + 0.1),
			V(-0.1, 4.0 - drop * 0.6, z0 - 0.02),
			V(0, 4.0 - drop, z0 - 0.05),
			V(0.1, 4.0 - drop * 0.6, z0 - 0.02),
			V(0.15, 4.0, z0 + 0.1),
		}
		for i = 1, #points - 1 do
			bar(rig, "UpperTorso", "Necklace", color, points[i], points[i + 1], 0.018, 0.018, METAL)
		end
		if pendant then
			add(
				rig,
				"UpperTorso",
				"Pendant",
				"ball",
				pendant,
				V(0.055, 0.055, 0.055),
				at(0, 4.0 - drop - 0.03, z0 - 0.06),
				METAL
			)
		end
	end

	-- Bracelet au poignet (1 = droit, -1 = gauche)
	function Parts.bracelet(rig: any, side: number, color: Color3, width: number?)
		local S = rig.S
		local wrist = mirror(S.wrist, side)
		local dir = mirror(S.armDir, side)
		tube(
			rig,
			prefix(side) .. "LowerArm",
			"Bracelet",
			color,
			wrist - dir * 0.09,
			wrist - dir * (0.09 - (width or 0.045)),
			0.245,
			METAL
		)
	end

	-- Lunettes : sur le nez (onHead = false) ou relevées sur le dessus de la tête (onHead = true)
	-- c = { frame, lens, lensTransparency?, round? }
	function Parts.glasses(rig: any, c: any, onHead: boolean)
		local base
		if onHead then
			base = at(0, 5.2, -0.43) * CFrame.Angles(rad(36), 0, 0)
		else
			base = at(0, 4.69, -0.57)
		end
		local lensOpts = { transparency = c.lensTransparency or 0.2, reflectance = 0.3 }
		for _, side in SIDES do
			local lensCF = base * at(side * 0.19, 0, 0) * CFrame.Angles(0, rad(-side * 12), 0)
			if c.round then
				add(
					rig,
					"Head",
					"Frame",
					"cyl",
					c.frame,
					V(0.03, 0.26, 0.26),
					lensCF * CFrame.Angles(0, rad(90), 0)
				)
				add(
					rig,
					"Head",
					"Lens",
					"cyl",
					c.lens,
					V(0.034, 0.2, 0.2),
					lensCF * CFrame.Angles(0, rad(90), 0),
					lensOpts
				)
			else
				-- monture « œil de chat » : contour, verre légèrement en avant, pointe relevée
				add(rig, "Head", "Frame", "ell", c.frame, V(0.36, 0.2, 0.05), lensCF)
				add(rig, "Head", "Lens", "ell", c.lens, V(0.29, 0.135, 0.07), lensCF, lensOpts)
				add(
					rig,
					"Head",
					"FrameTip",
					"ell",
					c.frame,
					V(0.13, 0.06, 0.04),
					lensCF * at(side * 0.15, 0.07, 0) * CFrame.Angles(0, 0, rad(side * 22))
				)
			end
			-- branche
			local hinge = (base * at(side * 0.37, 0.02, 0.03)).Position
			local tip = (base * at(side * 0.45, 0.0, 0.5)).Position
			bar(rig, "Head", "Temple", c.frame, hinge, tip, 0.03, 0.04)
		end
		add(rig, "Head", "Bridge", "box", c.frame, V(0.1, 0.035, 0.03), base * at(0, 0.02, 0.01))
	end

	-- Casque audio (Malik) : arceau + écouteurs
	function Parts.headphones(rig: any, c: any)
		local S = rig.S
		ring(rig, "Head", "Band", c.band, at(0, 4.74, 0.02), S.headR + 0.1, 0.07, 14)
		for _, side in SIDES do
			add(
				rig,
				"Head",
				"Cup",
				"cyl",
				c.cup,
				V(0.14, 0.42, 0.42),
				at(side * (S.headR + 0.08), 4.64, 0.02)
			)
			add(
				rig,
				"Head",
				"CupGlow",
				"cyl",
				c.glow,
				V(0.03, 0.26, 0.26),
				at(side * (S.headR + 0.16), 4.64, 0.02),
				{ material = Enum.Material.Neon }
			)
		end
	end

	-- Bandeau (Lina) autour du front
	function Parts.headband(rig: any, color: Color3)
		local S = rig.S
		add(
			rig,
			"Head",
			"Headband",
			"cyl",
			color,
			V(0.12, S.headR * 2 + 0.07, S.headR * 2 + 0.07),
			at(0, 4.98, 0) * UPRIGHT
		)
	end

	-- Sac en bandoulière (Iris) : sangle en diagonale + sac sur la hanche
	function Parts.crossbody(rig: any, c: any)
		bar(rig, "UpperTorso", "Strap", c.strap, V(-0.42, 3.98, -0.2), V(0.42, 3.12, -0.24), 0.07, 0.03)
		bar(rig, "UpperTorso", "Strap", c.strap, V(-0.42, 3.98, 0.2), V(0.42, 3.12, 0.24), 0.07, 0.03)
		bar(rig, "UpperTorso", "Strap", c.strap, V(-0.42, 3.98, -0.2), V(-0.42, 3.98, 0.2), 0.07, 0.03)
		add(rig, "LowerTorso", "Bag", "box", c.bag, V(0.2, 0.34, 0.44), at(0.6, 2.95, 0))
		add(rig, "LowerTorso", "BagFlap", "box", c.flap or c.strap, V(0.22, 0.14, 0.46), at(0.6, 3.07, 0))
		add(
			rig,
			"LowerTorso",
			"BagClasp",
			"ball",
			c.clasp or hex("#D7A746"),
			V(0.07, 0.07, 0.07),
			at(0.71, 3.0, 0),
			METAL
		)
	end

	-- Casquette (visière vers l'avant ou l'arrière)
	function Parts.capHat(rig: any, c: any)
		local S = rig.S
		add(
			rig,
			"Head",
			"CapCrown",
			"ell",
			c.color,
			V(S.headR * 2 + 0.1, 0.62, S.headR * 2 + 0.1),
			at(0, 5.08, 0.02),
			{ shadow = true }
		)
		local dir = if c.backwards then 1 else -1
		add(
			rig,
			"Head",
			"CapBrim",
			"ell",
			c.brim or c.color,
			V(0.74, 0.07, 0.56),
			at(0, 5.0, dir * 0.58) * CFrame.Angles(rad(dir * 6), 0, 0)
		)
		add(rig, "Head", "CapButton", "ball", c.brim or c.color, V(0.1, 0.1, 0.1), at(0, 5.4, 0.02))
	end

	-- Bonnet
	function Parts.beanie(rig: any, c: any)
		local S = rig.S
		add(
			rig,
			"Head",
			"Beanie",
			"ell",
			c.color,
			V(S.headR * 2 + 0.12, 0.84, S.headR * 2 + 0.12),
			at(0, 5.1, 0.04),
			{ shadow = true }
		)
		add(
			rig,
			"Head",
			"BeanieFold",
			"cyl",
			c.fold or shade(c.color, 0.82),
			V(0.16, S.headR * 2 + 0.16, S.headR * 2 + 0.16),
			at(0, 4.98, 0.03) * UPRIGHT
		)
	end

	-- Serre-tête prismatique (Vega) : arceau + prismes lumineux
	function Parts.tiara(rig: any, c: any)
		local S = rig.S
		ring(
			rig,
			"Head",
			"Tiara",
			c.band,
			at(0, 5.1, 0.02) * CFrame.Angles(rad(72), 0, 0),
			S.headR + 0.06,
			0.05,
			12,
			METAL
		)
		for i, x in { -0.24, 0, 0.24 } do
			local h = if i == 2 then 0.3 else 0.2
			add(
				rig,
				"Head",
				"Prism",
				"wedge",
				c.prism,
				V(0.06, h, 0.12),
				at(x, 5.36 + h / 2 - math.abs(x) * 0.25, -0.34 + math.abs(x) * 0.3)
					* CFrame.Angles(0, rad(90), 0),
				{ material = Enum.Material.Neon }
			)
			add(
				rig,
				"Head",
				"Prism",
				"wedge",
				c.prism,
				V(0.06, h, 0.12),
				at(x, 5.36 + h / 2 - math.abs(x) * 0.25, -0.34 + math.abs(x) * 0.3)
					* CFrame.Angles(0, rad(-90), 0),
				{ material = Enum.Material.Neon }
			)
		end
	end

	-- Boucle d'oreille graphique (Zuri) : barre + losange d'un seul côté
	function Parts.statementEarring(rig: any, side: number, color: Color3, glow: boolean?)
		local S = rig.S
		local x = side * (S.headR + 0.02)
		bar(rig, "Head", "EarBar", color, V(x, 4.52, 0.02), V(x, 4.26, 0.02), 0.03, 0.03, METAL)
		add(
			rig,
			"Head",
			"EarGem",
			"box",
			color,
			V(0.04, 0.13, 0.13),
			at(x, 4.2, 0.02) * CFrame.Angles(rad(45), 0, 0),
			if glow then { material = Enum.Material.Neon } else METAL
		)
	end

	-- Collier géométrique (Nova) : plastron en triangles
	function Parts.geoCollar(rig: any, color: Color3, glow: boolean?)
		local opts = if glow then { material = Enum.Material.Neon } else METAL
		for _, x in { -0.16, 0, 0.16 } do
			add(
				rig,
				"UpperTorso",
				"GeoCollar",
				"box",
				color,
				V(0.12, 0.12, 0.03),
				at(x, 3.86 - math.abs(x) * 0.3, -0.225 + math.abs(x) * 0.12) * CFrame.Angles(0, 0, rad(45)),
				opts
			)
		end
	end

	-- Montre au poignet
	function Parts.watch(rig: any, side: number, c: any)
		local S = rig.S
		local wrist = mirror(S.wrist, side)
		local dir = mirror(S.armDir, side)
		tube(
			rig,
			prefix(side) .. "LowerArm",
			"WatchBand",
			c.band,
			wrist - dir * 0.11,
			wrist - dir * 0.03,
			0.25
		)
		add(
			rig,
			prefix(side) .. "LowerArm",
			"WatchFace",
			"cyl",
			c.face,
			V(0.04, 0.14, 0.14),
			at(wrist.X + side * 0.125, wrist.Y + 0.07, wrist.Z),
			METAL
		)
	end

	-- Chaîne épaisse (compagnons)
	function Parts.chain(rig: any, color: Color3, depth: number?)
		local z0 = -(depth or 0.26)
		local points = {
			V(-0.2, 4.02, z0 + 0.12),
			V(-0.14, 3.8, z0 - 0.02),
			V(0, 3.68, z0 - 0.05),
			V(0.14, 3.8, z0 - 0.02),
			V(0.2, 4.02, z0 + 0.12),
		}
		for i = 1, #points - 1 do
			bar(rig, "UpperTorso", "Chain", color, points[i], points[i + 1], 0.045, 0.045, METAL)
		end
	end

	return Parts
end
