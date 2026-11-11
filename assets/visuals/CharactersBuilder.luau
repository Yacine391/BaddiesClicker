--[[
	CharactersBuilder : décrit chaque personnage du catalogue (baddies : 3 looks ; compagnons : Base) et
	les construit avec CharacterKit / CharacterParts / CharacterStyles dans un Folder « Characters ».
	Ce n'est PAS un script du jeu : `lune run assets/visuals/export-characters` l'exécute.

	Contrat lu par le client (Logic/VisualsModel, Controllers/Followers, Podium, Combat, Portrait) :
	  Characters.<Code>_<Nom>.Look01 … Look03   baddies (ex. B09_Cherry.Look01)
	  Characters.<Code>_<Nom>.Base              compagnons (ex. C02_Malik.Base)
	  Characters.TEST.TEST_B99                  silhouette de test (Studio)
	  Characters.Minions.<Archétype>            sbires
	Chaque modèle : HumanoidRootPart (PrimaryPart, 3 studs au-dessus des pieds), AnimationController,
	AuraAttachment, NameTagAttachment.

	Identité (§20) : silhouette, coiffure signature, trois couleurs, accessoire marquant. Les looks font
	évoluer tenue et finitions, jamais le visage, la peau ni la coiffure de base.
]]

return function(Kit: any, Parts: any, Styles: any)
	local hex, V, at = Kit.hex, Kit.V, Kit.at
	local add = Kit.add
	local shade = Parts.shade

	local SILVER, GOLD = hex("#C9CCD3"), hex("#D7A746")

	-- Construit un personnage à partir d'une fiche
	local function character(name: string, spec: any): Model
		local b = Parts.build(if spec.male then Parts.BUILD_M else Parts.BUILD_F, spec.build)
		local S = Kit.skeleton(b)
		local rig = Kit.newRig(name, S, spec.skin, spec.scale)
		local wear: any = {}
		local garments = { spec.top, spec.bottom }
		for _, garment in garments do
			if garment and garment.pre then
				garment.pre(wear, b)
			end
		end
		if spec.wear then
			for key, value in spec.wear do
				wear[key] = value
			end
		end
		Parts.body(rig, b, wear)
		Parts.face(rig, spec.face)
		if spec.hair then
			spec.hair(rig)
		end
		for _, garment in garments do
			if garment and garment.post then
				garment.post(rig, b)
			end
		end
		if spec.shoes then
			spec.shoes(rig)
		end
		for _, extra in spec.extras or {} do
			extra(rig, b)
		end
		rig.model:SetAttribute("Parts", rig.count)
		return rig.model
	end

	-- Fiche dérivée : `base` + changements (un look)
	local function with(base: any, changes: any): any
		local spec = table.clone(base)
		for key, value in changes do
			spec[key] = value
		end
		return spec
	end

	local cast: { [string]: { [string]: any } } = {}

	----------------------------------------------------------------------------------------------
	-- B09 · Cherry — référence fournie : « Baddie — Cherry Summer » (face, 3/4, dos, portrait)
	-- Queue de cheval noire très haute et ondulée, lunettes rouges relevées, créoles et colliers
	-- argent, débardeur bordeaux à encolure carrée, short en jean à revers et ceinture noire,
	-- chaussettes blanches, baskets blanches à semelle bordeaux et motif cerise.
	----------------------------------------------------------------------------------------------
	do
		local skin = hex("#E2AD87")
		local hair = hex("#18171B")
		local burgundy = hex("#8A1C2B")
		local denim = hex("#47689E")
		local white = hex("#F6F3EE")
		local face = {
			iris = hex("#6B3F22"),
			brow = hex("#1C191B"),
			lip = hex("#C98876"),
			lipUpper = hex("#B5705F"),
			browTilt = 10,
		}
		local base = {
			skin = skin,
			build = { hipW = 1.26, thighW = 0.6, thighD = 0.58 },
			face = face,
			hair = function(rig)
				Styles.hair.highWavyPonytail(rig, hair, { gloss = 0.08, tie = hex("#2A282E") })
			end,
			top = Styles.tops.tankCrop({ color = burgundy }),
			bottom = Styles.bottoms.denimShorts({
				color = denim,
				cuff = hex("#8FA6CE"),
				belt = hex("#1B1A1F"),
				buckle = SILVER,
			}),
			shoes = function(rig)
				Parts.socks(rig, white, 0.84)
				Parts.sneakers(rig, {
					upper = white,
					sole = hex("#8E1B2A"),
					midsole = white,
					accent = hex("#8E1B2A"),
					lace = hex("#E4E0DA"),
					motif = "cherry",
				})
			end,
			extras = {
				function(rig)
					Parts.glasses(
						rig,
						{ frame = hex("#A3182A"), lens = hex("#5A0A14"), lensTransparency = 0.12 },
						true
					)
					Parts.hoops(rig, SILVER, 0.11)
					Parts.necklace(rig, SILVER, 0.2, nil)
					Parts.necklace(rig, SILVER, 0.3, SILVER)
					Parts.bracelet(rig, 1, SILVER)
				end,
			},
		}
		cast.B09_Cherry = {
			-- Look 1 : la planche de référence
			Look01 = base,
			-- Look 2 : même silhouette, veste courte crème à liseré cerise, bijoux dorés
			Look02 = with(base, {
				top = Styles.tops.jacket({
					color = hex("#F4EEE7"),
					inner = burgundy,
					trim = burgundy,
					cuffs = burgundy,
					crop = true,
					collar = "stand",
					stripe = burgundy,
					emblem = hex("#C4122A"),
				}),
				extras = {
					function(rig)
						Parts.glasses(
							rig,
							{ frame = hex("#A3182A"), lens = hex("#5A0A14"), lensTransparency = 0.12 },
							true
						)
						Parts.hoops(rig, GOLD, 0.11)
						Parts.necklace(rig, GOLD, 0.2, nil)
						Parts.necklace(rig, GOLD, 0.3, hex("#C4122A"))
						Parts.bracelet(rig, 1, GOLD)
						Parts.bracelet(rig, -1, GOLD)
					end,
				},
			}),
			-- Look 3 : signature — veste bordeaux vernie, cerises lumineuses, semelles néon
			Look03 = with(base, {
				top = Styles.tops.jacket({
					color = hex("#6E1220"),
					inner = hex("#F4EEE7"),
					trim = GOLD,
					cuffs = GOLD,
					crop = true,
					collar = "stand",
					stripe = hex("#FF3B5C"),
					glow = true,
					emblem = hex("#FF3B5C"),
					backPrint = hex("#FF3B5C"),
				}),
				bottom = Styles.bottoms.denimShorts({
					color = hex("#2E3F6B"),
					cuff = hex("#8FA6CE"),
					belt = hex("#6E1220"),
					buckle = GOLD,
				}),
				shoes = function(rig)
					Parts.socks(rig, white, 0.84)
					Parts.sneakers(rig, {
						upper = white,
						sole = hex("#FF3B5C"),
						midsole = white,
						accent = hex("#8E1B2A"),
						lace = hex("#E4E0DA"),
						motif = "cherry",
						glowSole = true,
					})
				end,
				extras = {
					function(rig)
						Parts.glasses(
							rig,
							{ frame = hex("#7A0F1C"), lens = hex("#FF3B5C"), lensTransparency = 0.1 },
							true
						)
						Parts.hoops(rig, GOLD, 0.13)
						Parts.necklace(rig, GOLD, 0.2, nil)
						Parts.necklace(rig, GOLD, 0.32, hex("#FF3B5C"))
						Parts.bracelet(rig, 1, GOLD, 0.09)
						Parts.bracelet(rig, -1, GOLD)
					end,
				},
			}),
		}
	end

	----------------------------------------------------------------------------------------------
	-- Outils de fiche
	----------------------------------------------------------------------------------------------
	local NEON = hex("#3EE6C8")

	local function sneakers(c: any, socks: Color3?)
		return function(rig)
			if socks then
				Parts.socks(rig, socks, 0.72)
			end
			Parts.sneakers(rig, c)
		end
	end

	local function extras(list: { any })
		return list
	end

	----------------------------------------------------------------------------------------------
	-- B01 · Maya (§03) : peau brune, carré bouclé ; denim, crème, orange doux
	----------------------------------------------------------------------------------------------
	do
		local denim, cream, orange = hex("#3B5B8C"), hex("#F4EEE7"), hex("#F2A65A")
		local hair = hex("#2A1A14")
		local base = {
			skin = hex("#9A6646"),
			build = {},
			face = {
				iris = hex("#3A2212"),
				brow = hex("#22140E"),
				lip = hex("#A85C4E"),
				browTilt = 6,
				wing = false,
			},
			hair = function(rig)
				Styles.hair.curlyBob(rig, hair, { gloss = 0.04 })
			end,
		}
		cast.B01_Maya = {
			-- Look 1 « Street Start » : veste ample simple, cargo, bracelet simple
			Look01 = with(base, {
				top = Styles.tops.jacket({ color = denim, inner = cream, collar = "stand", bulk = 0.1 }),
				bottom = Styles.bottoms.pants({
					color = hex("#C9BFA8"),
					cut = "wide",
					pockets = hex("#B8AE96"),
				}),
				shoes = sneakers({ upper = cream, sole = hex("#3A3A40") }),
				extras = extras({
					function(rig)
						Parts.bracelet(rig, -1, orange)
						Parts.studs(rig, GOLD)
					end,
				}),
			}),
			-- Look 2 « Street Match » : ensemble denim coordonné, bracelet et baskets assortis
			Look02 = with(base, {
				top = Styles.tops.jacket({
					color = denim,
					inner = cream,
					collar = "stand",
					trim = orange,
					cuffs = orange,
					bulk = 0.1,
				}),
				bottom = Styles.bottoms.pants({
					color = denim,
					cut = "wide",
					cuff = orange,
					waistband = orange,
				}),
				shoes = sneakers({ upper = cream, sole = orange, accent = orange }),
				extras = extras({
					function(rig)
						Parts.bracelet(rig, -1, orange, 0.08)
						Parts.bracelet(rig, 1, cream)
						Parts.studs(rig, GOLD)
					end,
				}),
			}),
			-- Look 3 « Street Signature » : motifs, bijoux géométriques, chaussures signature
			Look03 = with(base, {
				top = Styles.tops.jacket({
					color = denim,
					inner = cream,
					collar = "stand",
					trim = orange,
					cuffs = orange,
					stripe = hex("#FF8A1F"),
					glow = true,
					backPrint = hex("#FF8A1F"),
					emblem = hex("#FF8A1F"),
					bulk = 0.1,
				}),
				bottom = Styles.bottoms.pants({
					color = denim,
					cut = "wide",
					cuff = orange,
					waistband = orange,
					stripe = hex("#FF8A1F"),
					glow = true,
				}),
				shoes = sneakers({ upper = cream, sole = hex("#FF8A1F"), accent = orange, glowSole = true }),
				extras = extras({
					function(rig)
						Parts.bracelet(rig, -1, GOLD, 0.08)
						Parts.bracelet(rig, 1, GOLD)
						Parts.hoops(rig, GOLD, 0.09)
						Parts.geoCollar(rig, GOLD)
					end,
				}),
			}),
		}
	end

	----------------------------------------------------------------------------------------------
	-- B02 · Lina (§17) : sportive, robuste, queue de cheval haute ; vert sauge, blanc cassé, anthracite
	----------------------------------------------------------------------------------------------
	do
		local sage, off, slate = hex("#8FA98B"), hex("#F4F1EA"), hex("#3A3A40")
		local hair = hex("#5A3A22")
		local base = {
			skin = hex("#D9A27C"),
			build = {
				shoulderX = 0.52,
				chestW = 0.94,
				waistW = 0.76,
				armW = 0.29,
				forearmW = 0.24,
				thighW = 0.6,
			},
			face = {
				iris = hex("#4E6B3A"),
				brow = hex("#4A2E1A"),
				lip = hex("#C07A6A"),
				browTilt = 4,
				wing = false,
				lidded = false,
			},
			hair = function(rig)
				Styles.hair.sportPonytail(rig, hair, { tie = off })
			end,
		}
		cast.B02_Lina = {
			Look01 = with(base, {
				top = Styles.tops.jacket({ color = sage, inner = off, collar = "stand", zip = SILVER }),
				bottom = Styles.bottoms.pants({ color = slate, cut = "wide", cuff = slate }),
				shoes = sneakers({ upper = off, sole = slate }),
				extras = extras({
					function(rig)
						Parts.headband(rig, off)
					end,
				}),
			}),
			Look02 = with(base, {
				top = Styles.tops.jacket({
					color = sage,
					inner = off,
					collar = "stand",
					zip = SILVER,
					stripe = off,
					cuffs = off,
					trim = off,
				}),
				bottom = Styles.bottoms.pants({
					color = sage,
					cut = "wide",
					cuff = off,
					stripe = off,
					waistband = off,
				}),
				shoes = sneakers({ upper = off, sole = sage, accent = sage }),
				extras = extras({
					function(rig)
						Parts.headband(rig, sage)
						Parts.bracelet(rig, 1, off, 0.1)
					end,
				}),
			}),
			Look03 = with(base, {
				top = Styles.tops.jacket({
					color = sage,
					inner = slate,
					collar = "stand",
					zip = SILVER,
					stripe = hex("#B7F27A"),
					glow = true,
					cuffs = slate,
					trim = slate,
					backPrint = hex("#B7F27A"),
					panel = slate,
				}),
				bottom = Styles.bottoms.pants({
					color = slate,
					cut = "wide",
					cuff = sage,
					stripe = hex("#B7F27A"),
					glow = true,
					waistband = sage,
				}),
				shoes = sneakers({ upper = off, sole = hex("#B7F27A"), accent = sage, glowSole = true }),
				extras = extras({
					function(rig)
						Parts.headband(rig, hex("#B7F27A"))
						Parts.bracelet(rig, 1, off, 0.1)
						Parts.bracelet(rig, -1, off, 0.1)
					end,
				}),
			}),
		}
	end

	----------------------------------------------------------------------------------------------
	-- B03 · Jade (§17) : urbaine, coupe asymétrique, bomber ; noir, cyan, argent ; lunettes relevées
	----------------------------------------------------------------------------------------------
	do
		local black, cyan = hex("#1B1B1F"), hex("#13A6B5")
		local hair = hex("#101014")
		local base = {
			skin = hex("#F0C9A8"),
			build = { hipW = 1.1 },
			face = { iris = hex("#1F7F8C"), brow = hex("#141416"), lip = hex("#B5606A"), browTilt = 9 },
			hair = function(rig)
				Styles.hair.asymmetric(rig, hair, {})
			end,
		}
		local shades = { frame = black, lens = cyan, lensTransparency = 0.25 }
		cast.B03_Jade = {
			Look01 = with(base, {
				top = Styles.tops.jacket({
					color = black,
					inner = hex("#C0C4CC"),
					collar = "stand",
					cuffs = hex("#2E2E34"),
					trim = hex("#2E2E34"),
				}),
				bottom = Styles.bottoms.pants({ color = hex("#26262B"), cut = "straight" }),
				shoes = sneakers({ upper = black, sole = hex("#C0C4CC") }),
				extras = extras({
					function(rig)
						Parts.studs(rig, SILVER)
					end,
				}),
			}),
			Look02 = with(base, {
				hair = function(rig)
					Styles.hair.asymmetric(rig, hair, { streak = cyan })
				end,
				top = Styles.tops.jacket({
					color = black,
					inner = cyan,
					collar = "stand",
					cuffs = cyan,
					trim = cyan,
					zip = SILVER,
				}),
				bottom = Styles.bottoms.pants({
					color = black,
					cut = "straight",
					belt = hex("#2E2E34"),
					buckle = SILVER,
				}),
				shoes = sneakers({ upper = black, sole = cyan, accent = cyan }),
				extras = extras({
					function(rig)
						Parts.glasses(rig, shades, true)
						Parts.studs(rig, SILVER)
						Parts.necklace(rig, SILVER, 0.22, cyan)
					end,
				}),
			}),
			Look03 = with(base, {
				hair = function(rig)
					Styles.hair.asymmetric(rig, hair, { streak = hex("#5FE2FF") })
				end,
				top = Styles.tops.jacket({
					color = black,
					inner = cyan,
					collar = "stand",
					cuffs = hex("#C0C4CC"),
					trim = hex("#C0C4CC"),
					zip = SILVER,
					stripe = hex("#5FE2FF"),
					glow = true,
					backPrint = hex("#5FE2FF"),
					emblem = hex("#5FE2FF"),
				}),
				bottom = Styles.bottoms.pants({
					color = black,
					cut = "straight",
					belt = hex("#2E2E34"),
					buckle = SILVER,
					stripe = hex("#5FE2FF"),
					glow = true,
				}),
				shoes = sneakers({ upper = black, sole = hex("#5FE2FF"), accent = cyan, glowSole = true }),
				extras = extras({
					function(rig)
						Parts.glasses(rig, shades, true)
						Parts.hoops(rig, SILVER, 0.08)
						Parts.necklace(rig, SILVER, 0.22, hex("#5FE2FF"))
						Parts.bracelet(rig, 1, SILVER, 0.08)
					end,
				}),
			}),
		}
	end

	----------------------------------------------------------------------------------------------
	-- B04 · Iris (§17) : créative, longues tresses, grande ; lilas, crème, rose framboise ; sac en bandoulière
	----------------------------------------------------------------------------------------------
	do
		local lilac, cream, berry = hex("#B9A3D9"), hex("#F4EEE7"), hex("#D6336C")
		local hair = hex("#2B1B2E")
		local base = {
			skin = hex("#7A4E36"),
			scale = 1.05,
			build = { hipW = 1.1, thighW = 0.54 },
			face = {
				iris = hex("#5A3A7A"),
				brow = hex("#1E1420"),
				lip = hex("#B0406A"),
				browTilt = 5,
				eyeshadow = hex("#8E6AA8"),
			},
			hair = function(rig)
				Styles.hair.longBraids(rig, hair, { bead = lilac })
			end,
		}
		local bag = { strap = berry, bag = cream, flap = berry }
		cast.B04_Iris = {
			Look01 = with(base, {
				top = Styles.tops.tee({ color = lilac, crop = true }),
				bottom = Styles.bottoms.pants({ color = lilac, cut = "wide", waistband = cream }),
				shoes = sneakers({ upper = cream, sole = lilac }),
				extras = extras({
					function(rig)
						Parts.crossbody(rig, bag)
					end,
				}),
			}),
			Look02 = with(base, {
				top = Styles.tops.tee({ color = lilac, crop = true, print = berry, trim = berry }),
				bottom = Styles.bottoms.pants({
					color = lilac,
					cut = "wide",
					waistband = berry,
					stripe = cream,
					cuff = berry,
				}),
				shoes = sneakers({ upper = cream, sole = berry, accent = berry }),
				extras = extras({
					function(rig)
						Parts.crossbody(rig, bag)
						Parts.hoops(rig, GOLD, 0.09)
						Parts.bracelet(rig, -1, berry, 0.08)
					end,
				}),
			}),
			Look03 = with(base, {
				hair = function(rig)
					Styles.hair.longBraids(rig, hair, { bead = hex("#FF5FD2") })
				end,
				top = Styles.tops.jacket({
					color = lilac,
					inner = cream,
					crop = true,
					collar = "stand",
					trim = berry,
					cuffs = berry,
					stripe = hex("#FF5FD2"),
					glow = true,
					backPrint = hex("#FF5FD2"),
				}),
				bottom = Styles.bottoms.pants({
					color = lilac,
					cut = "wide",
					waistband = berry,
					stripe = hex("#FF5FD2"),
					glow = true,
					cuff = berry,
				}),
				shoes = sneakers({ upper = cream, sole = hex("#FF5FD2"), accent = berry, glowSole = true }),
				extras = extras({
					function(rig)
						Parts.crossbody(rig, { strap = berry, bag = cream, flap = berry, clasp = GOLD })
						Parts.hoops(rig, GOLD, 0.11)
						Parts.necklace(rig, GOLD, 0.24, berry)
						Parts.bracelet(rig, -1, GOLD, 0.08)
					end,
				}),
			}),
		}
	end

	----------------------------------------------------------------------------------------------
	-- B05 · Sienna (§18) : festival, athlétique, cheveux ondulés, veste métallisée ; cuivre, rose, blanc
	----------------------------------------------------------------------------------------------
	do
		local copper, rose, white = hex("#B87333"), hex("#E8A0A8"), hex("#FFFFFF")
		local hair = hex("#8A4A2A")
		local base = {
			skin = hex("#E6B48E"),
			build = { shoulderX = 0.5, armW = 0.27 },
			face = { iris = hex("#7A5230"), brow = hex("#6A3A20"), lip = hex("#D07A84"), browTilt = 7 },
			hair = function(rig)
				Styles.hair.wavyLong(rig, hair, { gloss = 0.1 })
			end,
		}
		local rounds = { frame = copper, lens = rose, lensTransparency = 0.3, round = true }
		cast.B05_Sienna = {
			Look01 = with(base, {
				top = Styles.tops.jacket({ color = copper, inner = white, crop = true, collar = "stand" }),
				bottom = Styles.bottoms.pants({ color = white, cut = "wide", waistband = rose }),
				shoes = sneakers({ upper = white, sole = copper }),
				extras = extras({
					function(rig)
						Parts.glasses(rig, rounds, false)
					end,
				}),
			}),
			Look02 = with(base, {
				top = Styles.tops.jacket({
					color = copper,
					inner = rose,
					crop = true,
					collar = "stand",
					trim = rose,
					cuffs = rose,
					zip = GOLD,
				}),
				bottom = Styles.bottoms.pants({
					color = white,
					cut = "wide",
					waistband = rose,
					stripe = copper,
					cuff = rose,
				}),
				shoes = sneakers({ upper = white, sole = copper, accent = rose }),
				extras = extras({
					function(rig)
						Parts.glasses(rig, rounds, false)
						Parts.hoops(rig, GOLD, 0.1)
						Parts.necklace(rig, GOLD, 0.24, rose)
						Parts.bracelet(rig, 1, GOLD)
					end,
				}),
			}),
			Look03 = with(base, {
				top = Styles.tops.jacket({
					color = hex("#C98A4A"),
					inner = rose,
					crop = true,
					collar = "stand",
					trim = white,
					cuffs = white,
					zip = GOLD,
					stripe = hex("#FFB36B"),
					glow = true,
					backPrint = hex("#FFB36B"),
					panel = hex("#F0C7A0"),
				}),
				bottom = Styles.bottoms.pants({
					color = white,
					cut = "wide",
					waistband = copper,
					stripe = hex("#FFB36B"),
					glow = true,
					cuff = copper,
				}),
				shoes = sneakers({ upper = white, sole = hex("#FFB36B"), accent = copper, glowSole = true }),
				extras = extras({
					function(rig)
						Parts.glasses(rig, rounds, false)
						Parts.hoops(rig, GOLD, 0.12)
						Parts.necklace(rig, GOLD, 0.2, nil)
						Parts.necklace(rig, GOLD, 0.3, rose)
						Parts.bracelet(rig, 1, GOLD, 0.08)
						Parts.bracelet(rig, -1, GOLD)
					end,
				}),
			}),
		}
	end

	----------------------------------------------------------------------------------------------
	-- B06 · Nova (§18) : rooftop chic, peau foncée, coiffure relevée, tailleur ; bleu nuit, or, ivoire
	----------------------------------------------------------------------------------------------
	do
		local navy, ivory = hex("#1B2A4A"), hex("#FFFFF0")
		local hair = hex("#17110F")
		local base = {
			skin = hex("#5C3A28"),
			build = { hipW = 1.12, shoulderX = 0.48 },
			face = {
				iris = hex("#3A2414"),
				brow = hex("#120C0A"),
				lip = hex("#8E3A44"),
				browTilt = 8,
				eyeshadow = hex("#B8923F"),
			},
			hair = function(rig)
				Styles.hair.updo(rig, hair, {})
			end,
		}
		cast.B06_Nova = {
			Look01 = with(base, {
				top = Styles.tops.jacket({ color = navy, inner = ivory, collar = "lapel", length = 2.86 }),
				bottom = Styles.bottoms.pants({ color = navy, cut = "straight" }),
				shoes = function(rig)
					Parts.boots(rig, { upper = ivory, sole = navy, height = 0.2 })
				end,
				extras = extras({
					function(rig)
						Parts.studs(rig, GOLD)
					end,
				}),
			}),
			Look02 = with(base, {
				hair = function(rig)
					Styles.hair.updo(rig, hair, { pin = GOLD })
				end,
				top = Styles.tops.jacket({
					color = navy,
					inner = ivory,
					collar = "lapel",
					length = 2.86,
					trim = GOLD,
					cuffs = GOLD,
				}),
				bottom = Styles.bottoms.pants({ color = navy, cut = "straight", belt = GOLD, buckle = GOLD }),
				shoes = function(rig)
					Parts.boots(rig, { upper = ivory, sole = navy, height = 0.22, accent = GOLD })
				end,
				extras = extras({
					function(rig)
						Parts.geoCollar(rig, GOLD)
						Parts.hoops(rig, GOLD, 0.09)
						Parts.bracelet(rig, -1, GOLD, 0.08)
					end,
				}),
			}),
			Look03 = with(base, {
				hair = function(rig)
					Styles.hair.updo(rig, hair, { pin = GOLD })
				end,
				top = Styles.tops.jacket({
					color = navy,
					inner = ivory,
					collar = "lapel",
					length = 2.86,
					trim = GOLD,
					cuffs = GOLD,
					stripe = hex("#FFD86B"),
					glow = true,
					emblem = hex("#FFD86B"),
					backPrint = hex("#FFD86B"),
					panel = hex("#24386A"),
				}),
				bottom = Styles.bottoms.pants({
					color = navy,
					cut = "straight",
					belt = GOLD,
					buckle = GOLD,
					stripe = hex("#FFD86B"),
					glow = true,
				}),
				shoes = function(rig)
					Parts.boots(rig, { upper = ivory, sole = hex("#D7A746"), height = 0.24, accent = GOLD })
				end,
				extras = extras({
					function(rig)
						Parts.geoCollar(rig, hex("#FFD86B"), true)
						Parts.hoops(rig, GOLD, 0.12)
						Parts.bracelet(rig, -1, GOLD, 0.08)
						Parts.bracelet(rig, 1, GOLD, 0.08)
					end,
				}),
			}),
		}
	end

	----------------------------------------------------------------------------------------------
	-- B07 · Zuri (§18) : performance musicale, cheveux courts texturés, veste structurée, bottines ;
	-- violet profond, argent, noir ; boucle d'oreille graphique
	----------------------------------------------------------------------------------------------
	do
		local violet, black = hex("#4B1D7A"), hex("#141216")
		local hair = hex("#3A1D5C")
		local base = {
			skin = hex("#8A5A3E"),
			build = { shoulderX = 0.5 },
			face = {
				iris = hex("#8A5AD6"),
				brow = hex("#1A1020"),
				lip = hex("#7A2A6A"),
				browTilt = 11,
				eyeshadow = hex("#5A3A8A"),
			},
			hair = function(rig)
				Styles.hair.shortTextured(rig, hair, { gloss = 0.1 })
			end,
		}
		cast.B07_Zuri = {
			Look01 = with(base, {
				top = Styles.tops.jacket({
					color = violet,
					inner = black,
					collar = "stand",
					panel = hex("#3A1560"),
				}),
				bottom = Styles.bottoms.pants({ color = black, cut = "slim" }),
				shoes = function(rig)
					Parts.boots(rig, { upper = black, sole = hex("#2A2630"), height = 0.42 })
				end,
				extras = extras({
					function(rig)
						Parts.statementEarring(rig, -1, SILVER)
					end,
				}),
			}),
			Look02 = with(base, {
				top = Styles.tops.jacket({
					color = violet,
					inner = black,
					collar = "stand",
					panel = SILVER,
					trim = SILVER,
					cuffs = SILVER,
					zip = SILVER,
				}),
				bottom = Styles.bottoms.pants({
					color = black,
					cut = "slim",
					belt = hex("#2A2630"),
					buckle = SILVER,
				}),
				shoes = function(rig)
					Parts.boots(rig, { upper = black, sole = hex("#2A2630"), height = 0.44, accent = SILVER })
				end,
				extras = extras({
					function(rig)
						Parts.statementEarring(rig, -1, SILVER)
						Parts.chain(rig, SILVER)
						Parts.bracelet(rig, 1, SILVER, 0.1)
					end,
				}),
			}),
			Look03 = with(base, {
				top = Styles.tops.jacket({
					color = violet,
					inner = black,
					collar = "stand",
					panel = SILVER,
					trim = SILVER,
					cuffs = SILVER,
					zip = SILVER,
					stripe = hex("#B48CF0"),
					glow = true,
					backPrint = hex("#B48CF0"),
					emblem = hex("#B48CF0"),
				}),
				bottom = Styles.bottoms.pants({
					color = black,
					cut = "slim",
					belt = hex("#2A2630"),
					buckle = SILVER,
					stripe = hex("#B48CF0"),
					glow = true,
				}),
				shoes = function(rig)
					Parts.boots(rig, { upper = black, sole = hex("#B48CF0"), height = 0.46, accent = SILVER })
				end,
				extras = extras({
					function(rig)
						Parts.statementEarring(rig, -1, hex("#B48CF0"), true)
						Parts.statementEarring(rig, 1, SILVER)
						Parts.chain(rig, SILVER)
						Parts.bracelet(rig, 1, SILVER, 0.1)
						Parts.bracelet(rig, -1, SILVER, 0.1)
					end,
				}),
			}),
		}
	end

	----------------------------------------------------------------------------------------------
	-- B08 · Vega (§18) : grande scène, cheveux argentés stylisés, ensemble blanc et turquoise ;
	-- blanc, turquoise, violet ; serre-tête prismatique. Reconnaissable effets coupés.
	----------------------------------------------------------------------------------------------
	do
		local white, turquoise, violet = hex("#FFFFFF"), hex("#30D5C8"), hex("#7642A3")
		local hair = hex("#D8DCE6")
		local base = {
			skin = hex("#F2D2B8"),
			scale = 1.04,
			build = { shoulderX = 0.5 },
			face = {
				iris = hex("#30D5C8"),
				brow = hex("#8A8E9A"),
				lip = hex("#B56A9A"),
				browTilt = 9,
				eyeshadow = hex("#9A7AC8"),
			},
			hair = function(rig)
				Styles.hair.silverBlades(rig, hair, { accent = turquoise })
			end,
		}
		cast.B08_Vega = {
			Look01 = with(base, {
				top = Styles.tops.jacket({
					color = white,
					inner = turquoise,
					collar = "stand",
					panel = turquoise,
					crop = true,
				}),
				bottom = Styles.bottoms.pants({ color = white, cut = "straight", waistband = turquoise }),
				shoes = function(rig)
					Parts.boots(rig, { upper = white, sole = turquoise, height = 0.3 })
				end,
				extras = extras({
					function(rig)
						Parts.tiara(rig, { band = SILVER, prism = turquoise })
					end,
				}),
			}),
			Look02 = with(base, {
				top = Styles.tops.jacket({
					color = white,
					inner = turquoise,
					collar = "stand",
					panel = turquoise,
					crop = true,
					trim = violet,
					cuffs = violet,
					zip = SILVER,
				}),
				bottom = Styles.bottoms.pants({
					color = white,
					cut = "straight",
					waistband = violet,
					stripe = turquoise,
					cuff = turquoise,
				}),
				shoes = function(rig)
					Parts.boots(rig, { upper = white, sole = turquoise, height = 0.32, accent = violet })
				end,
				extras = extras({
					function(rig)
						Parts.tiara(rig, { band = SILVER, prism = turquoise })
						Parts.geoCollar(rig, turquoise)
						Parts.bracelet(rig, 1, SILVER, 0.1)
						Parts.bracelet(rig, -1, SILVER, 0.1)
					end,
				}),
			}),
			Look03 = with(base, {
				top = Styles.tops.jacket({
					color = white,
					inner = violet,
					collar = "stand",
					panel = turquoise,
					crop = true,
					trim = violet,
					cuffs = turquoise,
					zip = SILVER,
					stripe = hex("#7AF5E8"),
					glow = true,
					backPrint = hex("#7AF5E8"),
					emblem = hex("#B48CF0"),
				}),
				bottom = Styles.bottoms.pants({
					color = white,
					cut = "straight",
					waistband = violet,
					stripe = hex("#7AF5E8"),
					glow = true,
					cuff = turquoise,
				}),
				shoes = function(rig)
					Parts.boots(rig, { upper = white, sole = hex("#7AF5E8"), height = 0.34, accent = violet })
				end,
				extras = extras({
					function(rig)
						Parts.tiara(rig, { band = SILVER, prism = hex("#7AF5E8") })
						Parts.geoCollar(rig, hex("#7AF5E8"), true)
						Parts.statementEarring(rig, 1, hex("#B48CF0"), true)
						Parts.statementEarring(rig, -1, hex("#B48CF0"), true)
						Parts.bracelet(rig, 1, SILVER, 0.1)
						Parts.bracelet(rig, -1, SILVER, 0.1)
					end,
				}),
			}),
		}
	end

	----------------------------------------------------------------------------------------------
	-- Compagnons (§04, §16) : un modèle « Base » chacun, pas d'attaque
	----------------------------------------------------------------------------------------------
	local maleFace = {
		lashes = false,
		lidded = false,
		wing = false,
		browH = 0.07,
		browW = 0.24,
		browTilt = 5,
		eyeW = 0.2,
		eyeH = 0.13,
	}
	local function mface(changes: any): any
		local f = table.clone(maleFace)
		for key, value in changes do
			f[key] = value
		end
		return f
	end

	-- C01 · Enzo, danseur : sweat à capuche corail, jogging gris, casquette à l'envers
	cast.C01_Enzo = {
		Base = {
			male = true,
			skin = hex("#E0B08A"),
			build = { shoulderX = 0.56, chestW = 1.04, armW = 0.31, forearmW = 0.27 },
			face = mface({ iris = hex("#4A6A8A"), brow = hex("#3A2A1E") }),
			hair = function(rig)
				Styles.hair.short(rig, hex("#3A2A1E"), { kind = "fade" })
			end,
			top = Styles.tops.jacket({
				color = hex("#F2684A"),
				inner = hex("#F4EEE7"),
				collar = "hood",
				cuffs = hex("#C94E34"),
				trim = hex("#C94E34"),
			}),
			bottom = Styles.bottoms.pants({
				color = hex("#8A8A94"),
				cut = "wide",
				cuff = hex("#6E6E78"),
				stripe = hex("#F4EEE7"),
			}),
			shoes = sneakers({ upper = hex("#F4EEE7"), sole = hex("#F2684A"), accent = hex("#F2684A") }),
			extras = extras({
				function(rig)
					Parts.capHat(rig, { color = hex("#2B2B30"), brim = hex("#F2684A"), backwards = true })
				end,
			}),
		},
	}

	-- C02 · Malik, DJ (§04) : musclé, épaules larges, coiffure courte, veste streetwear, pantalon ample,
	-- casque identifiable ; anthracite, cyan, argent
	cast.C02_Malik = {
		Base = {
			male = true,
			skin = hex("#6E4630"),
			face = mface({ iris = hex("#2E1E14"), brow = hex("#140E0A"), beard = hex("#1C1410") }),
			hair = function(rig)
				Styles.hair.short(rig, hex("#16100C"), { kind = "waves" })
			end,
			top = Styles.tops.jacket({
				color = hex("#2B2B30"),
				inner = hex("#C0C4CC"),
				collar = "stand",
				cuffs = hex("#13A6B5"),
				trim = hex("#13A6B5"),
				stripe = hex("#3EE6C8"),
				glow = true,
				zip = SILVER,
				bulk = 0.1,
			}),
			bottom = Styles.bottoms.pants({ color = hex("#232327"), cut = "wide", cuff = hex("#13A6B5") }),
			shoes = sneakers({ upper = hex("#E9EBEF"), sole = hex("#13A6B5"), accent = hex("#13A6B5") }),
			extras = extras({
				function(rig)
					Parts.headphones(rig, { band = hex("#2B2B30"), cup = hex("#C0C4CC"), glow = NEON })
					Parts.chain(rig, SILVER, 0.34)
				end,
			}),
		},
	}

	-- C03 · Rafael, sportif : maillot vert et blanc, short long, bandeau
	cast.C03_Rafael = {
		Base = {
			male = true,
			skin = hex("#C68A5E"),
			build = { armW = 0.38, forearmW = 0.31, thighW = 0.56, calfW = 0.44 },
			face = mface({ iris = hex("#3A5A2E"), brow = hex("#2A1A10") }),
			hair = function(rig)
				Styles.hair.short(rig, hex("#2A1A10"), { kind = "crop" })
			end,
			top = Styles.tops.tee({ color = hex("#2E9E5B"), trim = hex("#F4F1EA"), print = hex("#F4F1EA") }),
			bottom = Styles.bottoms.denimShorts({
				color = hex("#F4F1EA"),
				cuff = hex("#2E9E5B"),
				stitch = hex("#D8D4CC"),
				length = 0.62,
			}),
			shoes = sneakers(
				{ upper = hex("#F4F1EA"), sole = hex("#2E9E5B"), accent = hex("#2E9E5B") },
				hex("#F4F1EA")
			),
			extras = extras({
				function(rig)
					Parts.headband(rig, hex("#F4F1EA"))
					Parts.bracelet(rig, 1, hex("#2E9E5B"), 0.12)
					Parts.bracelet(rig, -1, hex("#F4F1EA"), 0.12)
				end,
			}),
		},
	}

	-- C04 · Dario, chic : blazer sable, col roulé noir, pantalon droit, montre dorée
	cast.C04_Dario = {
		Base = {
			male = true,
			skin = hex("#D9A680"),
			build = { shoulderX = 0.58, chestW = 1.06, armW = 0.31, forearmW = 0.26 },
			face = mface({ iris = hex("#5A4028"), brow = hex("#2A1E16"), beard = hex("#3A2A20") }),
			hair = function(rig)
				Styles.hair.short(rig, hex("#2A1E16"), { kind = "quiff", gloss = 0.12 })
			end,
			top = Styles.tops.jacket({
				color = hex("#C9B38A"),
				inner = hex("#17161A"),
				collar = "lapel",
				length = 2.84,
				trim = hex("#B39C72"),
			}),
			wear = { neck = hex("#17161A") },
			bottom = Styles.bottoms.pants({
				color = hex("#2A2830"),
				cut = "straight",
				belt = hex("#17161A"),
				buckle = GOLD,
			}),
			shoes = function(rig)
				Parts.boots(rig, { upper = hex("#3A2A20"), sole = hex("#17161A"), height = 0.18 })
			end,
			extras = extras({
				function(rig)
					Parts.watch(rig, -1, { band = hex("#3A2A20"), face = GOLD })
					Parts.glasses(
						rig,
						{ frame = hex("#17161A"), lens = hex("#3A3A44"), lensTransparency = 0.35 },
						false
					)
				end,
			}),
		},
	}

	-- C05 · Kenji, danseur techno : tenue noire, bandes néon magenta, lunettes visière
	cast.C05_Kenji = {
		Base = {
			male = true,
			skin = hex("#EBC8A4"),
			build = { shoulderX = 0.55, chestW = 1.0, waistW = 0.8, armW = 0.3, forearmW = 0.25 },
			face = mface({ iris = hex("#2A2A30"), brow = hex("#101014") }),
			hair = function(rig)
				Styles.hair.short(rig, hex("#101014"), { kind = "quiff", gloss = 0.15 })
				Kit.add(
					rig,
					"Head",
					"HairStreak",
					"ell",
					hex("#FF5FD2"),
					V(0.16, 0.3, 0.36),
					at(0.14, 5.46, -0.3) * CFrame.Angles(math.rad(20), 0, 0),
					{ material = Enum.Material.Neon }
				)
			end,
			top = Styles.tops.jacket({
				color = hex("#17161C"),
				inner = hex("#2A2830"),
				collar = "stand",
				stripe = hex("#FF5FD2"),
				glow = true,
				cuffs = hex("#FF5FD2"),
				trim = hex("#2A2830"),
				backPrint = hex("#FF5FD2"),
				emblem = hex("#FF5FD2"),
			}),
			bottom = Styles.bottoms.pants({
				color = hex("#17161C"),
				cut = "wide",
				cuff = hex("#2A2830"),
				stripe = hex("#FF5FD2"),
				glow = true,
				pockets = hex("#24222A"),
			}),
			shoes = sneakers({
				upper = hex("#17161C"),
				sole = hex("#FF5FD2"),
				accent = hex("#FF5FD2"),
				glowSole = true,
			}),
			extras = extras({
				function(rig)
					Parts.glasses(
						rig,
						{ frame = hex("#17161C"), lens = hex("#FF5FD2"), lensTransparency = 0.2 },
						false
					)
				end,
			}),
		},
	}

	-- C06 · Amine, scène : veste blanche et or, chaîne dorée, locks courtes
	cast.C06_Amine = {
		Base = {
			male = true,
			skin = hex("#4E3222"),
			scale = 1.03,
			face = mface({ iris = hex("#C8963C"), brow = hex("#0E0A08"), beard = hex("#120C0A") }),
			hair = function(rig)
				Styles.hair.short(rig, hex("#120C0A"), { kind = "locs" })
			end,
			top = Styles.tops.jacket({
				color = hex("#F7F4EC"),
				inner = hex("#17161A"),
				collar = "stand",
				trim = GOLD,
				cuffs = GOLD,
				stripe = hex("#FFD86B"),
				glow = true,
				panel = GOLD,
				backPrint = hex("#FFD86B"),
				emblem = hex("#30D5C8"),
			}),
			bottom = Styles.bottoms.pants({
				color = hex("#F7F4EC"),
				cut = "straight",
				belt = hex("#17161A"),
				buckle = GOLD,
				stripe = hex("#FFD86B"),
				glow = true,
			}),
			shoes = sneakers({
				upper = hex("#F7F4EC"),
				sole = hex("#D7A746"),
				accent = GOLD,
				glowSole = true,
			}),
			extras = extras({
				function(rig)
					Parts.chain(rig, GOLD, 0.34)
					Parts.watch(rig, 1, { band = GOLD, face = hex("#30D5C8") })
					Parts.studs(rig, GOLD)
				end,
			}),
		},
	}

	----------------------------------------------------------------------------------------------
	-- Sbires (§08, §20) : silhouettes masquées, visière néon ; aucun visage ni identité du catalogue
	----------------------------------------------------------------------------------------------
	local function minion(
		name: string,
		male: boolean,
		body: Color3,
		visor: Color3,
		build: any?,
		scale: number?
	): Model
		local b = Parts.build(if male then Parts.BUILD_M else Parts.BUILD_F, build)
		local rig = Kit.newRig(name, Kit.skeleton(b), body, scale)
		Parts.body(
			rig,
			b,
			{
				hips = shade(body, 0.8),
				thigh = shade(body, 0.8),
				calf = shade(body, 0.8),
				chest = shade(body, 1.25),
				legBulk = 0.06,
			}
		)
		add(
			rig,
			"Head",
			"Hood",
			"ell",
			shade(body, 0.7),
			V(1.14, 1.0, 1.12),
			at(0, 4.86, 0.08),
			{ shadow = true }
		)
		add(
			rig,
			"Head",
			"Visor",
			"ell",
			visor,
			V(0.72, 0.2, 0.12),
			at(0, 4.7, -0.5),
			{ material = Enum.Material.Neon }
		)
		for _, side in { 1, -1 } do
			add(
				rig,
				Parts.prefix(side) .. "Foot",
				"Foot",
				"ell",
				shade(body, 0.6),
				V(0.5, 0.44, 0.96),
				at(side * rig.S.ankleX, 0.22, -0.12)
			)
			add(
				rig,
				Parts.prefix(side) .. "Foot",
				"FootGlow",
				"box",
				visor,
				V(0.5, 0.05, 0.7),
				at(side * rig.S.ankleX, 0.03, -0.1),
				{ material = Enum.Material.Neon }
			)
		end
		add(
			rig,
			"UpperTorso",
			"ChestMark",
			"box",
			visor,
			V(0.3, 0.08, 0.04),
			at(0, 3.6, -(b.chestD / 2 + 0.005)),
			{ material = Enum.Material.Neon }
		)
		rig.model:SetAttribute("Parts", rig.count)
		return rig.model
	end

	-- Silhouette grise de test (Studio) : même rig, sans visage ni vêtements
	local function silhouette(name: string, color: Color3): Model
		local b = Parts.build(Parts.BUILD_F, nil)
		local rig = Kit.newRig(name, Kit.skeleton(b), color, nil)
		Parts.body(rig, b, { hips = shade(color, 0.8) })
		for _, side in { 1, -1 } do
			add(
				rig,
				Parts.prefix(side) .. "Foot",
				"Foot",
				"ell",
				shade(color, 0.7),
				V(0.46, 0.4, 0.9),
				at(side * rig.S.ankleX, 0.2, -0.12)
			)
		end
		rig.model:SetAttribute("Parts", rig.count)
		return rig.model
	end

	return function(root: Folder, only: string?): { [string]: number }
		root:ClearAllChildren()
		local counts: { [string]: number } = {}
		for folderName, models in cast do
			if only == nil or only == folderName then
				local folder = Instance.new("Folder")
				folder.Name = folderName
				for modelName, spec in models do
					local model = character(modelName, spec)
					model.Parent = folder
					counts[`{folderName}.{modelName}`] = model:GetAttribute("Parts")
				end
				folder.Parent = root
			end
		end
		if only == nil or only == "Minions" then
			local minions = Instance.new("Folder")
			minions.Name = "Minions"
			local list = {
				minion("Street", true, hex("#2B2440"), hex("#FF5FD2"), nil, 0.94),
				minion("Runner", false, hex("#24303F"), hex("#3EE6C8"), { thighW = 0.5, hipW = 1.0 }, 0.9),
				minion(
					"Heavy",
					true,
					hex("#3A2430"),
					hex("#FFB36B"),
					{ chestW = 1.34, shoulderX = 0.7, armW = 0.44, forearmW = 0.36, waistW = 1.04 },
					1.06
				),
			}
			for _, model in list do
				model.Parent = minions
				counts[`Minions.{model.Name}`] = model:GetAttribute("Parts")
			end
			minions.Parent = root
		end
		if only == nil then
			local test = Instance.new("Folder")
			test.Name = "TEST"
			local model = silhouette("TEST_B99", hex("#9C98A8"))
			model.Parent = test
			counts["TEST.TEST_B99"] = model:GetAttribute("Parts")
			test.Parent = root
		end
		return counts
	end
end
