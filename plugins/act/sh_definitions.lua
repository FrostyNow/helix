
local function FacingWall(client, pos, ang)
	local data = {}
	data.start = pos and (pos + Vector(0, 0, 48)) or client:EyePos()
	data.endpos = data.start + (ang and ang:Forward() or client:GetForward()) * 25
	data.filter = client

	if (!util.TraceLine(data).Hit) then
		return "@faceWall"
	end
end

local function FacingWallBack(client, pos, ang)
	local data = {}
	data.start = pos and (pos + Vector(0, 0, 48)) or client:LocalToWorld(client:OBBCenter())
	data.endpos = data.start - (ang and ang:Forward() or client:GetForward()) * 25
	data.filter = client

	if (!util.TraceLine(data).Hit) then
		return "@faceWallBack"
	end
end

function PLUGIN:SetupActs()
	-- sit
	ix.act.Register("Sit", {"citizen_male", "citizen_female"}, {
		start = {"idle_to_sit_ground", "idle_to_sit_chair"},
		sequence = {"sit_ground", {"sit_chair", ignoreCollision = true}},
		finish = {
			{"sit_ground_to_idle", duration = 2.1},
			""
		},
		untimed = true,
		idle = true
	})

	ix.act.Register("SitWall", {"citizen_male", "citizen_female"}, {
		sequence = {
			{"plazaidle4", check = FacingWallBack},
			{"injured1", check = FacingWallBack, offset = function(client)
				return client:GetForward() * 14
			end}
		},
		untimed = true,
		idle = true,
		noGhost = true
	})

	ix.act.Register("Sit", "vortigaunt", {
		sequence = "chess_wait",
		untimed = true,
		idle = true
	})

	-- stand
	ix.act.Register("Stand", "citizen_male", {
		sequence = {"lineidle01", "lineidle02", "lineidle03", "lineidle04"},
		untimed = true,
		idle = true,
		noGhost = true
	})

	ix.act.Register("Stand", "citizen_female", {
		sequence = {"lineidle01", "lineidle02", "lineidle03"},
		untimed = true,
		idle = true,
		noGhost = true
	})

	ix.act.Register("Stand", "metrocop", {
		sequence = "plazathreat2",
		noGhost = true
	})

	-- cheer
	ix.act.Register("Cheer", "citizen_male", {
		sequence = {{"cheer1", duration = 1.6}, "cheer2", "wave_smg1"},
		noGhost = true
	})

	ix.act.Register("Cheer", "citizen_female", {
		sequence = {"cheer1", "wave_smg1"},
		noGhost = true
	})

	-- lean
	ix.act.Register("Lean", {"citizen_male", "citizen_female"}, {
		start = {"idle_to_lean_back", "", ""},
		sequence = {
			{"lean_back", check = FacingWallBack},
			{"plazaidle1", check = FacingWallBack},
			{"plazaidle2", check = FacingWallBack}
		},
		untimed = true,
		idle = true,
		noGhost = true
	})

	ix.act.Register("Lean", {"metrocop"}, {
		sequence = {{"idle_baton", check = FacingWallBack}, "busyidle2"},
		untimed = true,
		idle = true,
		noGhost = true
	})

	-- injured
	ix.act.Register("Injured", "citizen_male", {
		sequence = {"d1_town05_wounded_idle_1", "d1_town05_wounded_idle_2", "d1_town05_winston_down"},
		untimed = true,
		idle = true
	})

	ix.act.Register("Injured", "citizen_female", {
		sequence = "d1_town05_wounded_idle_1",
		untimed = true,
		idle = true
	})

	-- arrest
	ix.act.Register("ArrestWall", "citizen_male", {
		sequence = {
			{"apcarrestidle",
			check = FacingWall,
			offset = function(client)
				return -client:GetForward() * 23
			end},
			"spreadwallidle"
		},
		untimed = true,
		noGhost = true
	})

	ix.act.Register("Arrest", "citizen_male", {
		sequence = "arrestidle",
		untimed = true
	})

	-- threat
	ix.act.Register("Threat", "metrocop", {
		sequence = "plazathreat1",
		noGhost = true
	})

	-- deny
	ix.act.Register("Deny", "metrocop", {
		sequence = "harassfront2",
		noGhost = true
	})

	-- motion
	ix.act.Register("Motion", "metrocop", {
		sequence = {"motionleft", "motionright", "luggagewarn"},
		noGhost = true
	})

	-- wave
	ix.act.Register("Wave", {"citizen_male", "citizen_female"}, {
		sequence = {{"wave", duration = 2.75}, {"wave_close", duration = 1.75}},
		noGhost = true
	})

	-- pant
	ix.act.Register("Pant", {"citizen_male", "citizen_female"}, {
		start = {"d2_coast03_postbattle_idle02_entry", "d2_coast03_postbattle_idle01_entry"},
		sequence = {"d2_coast03_postbattle_idle02", {"d2_coast03_postbattle_idle01", check = FacingWall}},
		untimed = true,
		noGhost = true
	})

	-- window
	ix.act.Register("Window", "citizen_male", {
		sequence = "d1_t03_tenements_look_out_window_idle",
		untimed = true
	})

	ix.act.Register("Window", "citizen_female", {
		sequence = "d1_t03_lookoutwindow",
		untimed = true
	})

	ix.act.Register("Salute", "player", {
		sequence = "ACT_GMOD_TAUNT_SALUTE",
		noGhost = true
	})

	ix.act.Register("Advance", "player", {
		sequence = "ACT_SIGNAL_ADVANCE",
		noGhost = true
	})

	ix.act.Register("Foward", "player", {
		sequence = "ACT_SIGNAL_FOWARD",
		noGhost = true
	})

	ix.act.Register("Regroup", "player", {
		sequence = "ACT_SIGNAL_GROUP",
		noGhost = true
	})

	ix.act.Register("Halt", "player", {
		sequence = "ACT_SIGNAL_HALT",
		noGhost = true
	})

	ix.act.Register("Left", "player", {
		sequence = "ACT_SIGNAL_LEFT",
		noGhost = true
	})

	ix.act.Register("Right", "player", {
		sequence = "ACT_SIGNAL_RIGHT",
		noGhost = true
	})

	ix.act.Register("Cover", "player", {
		sequence = "ACT_SIGNAL_TAKECOVER",
		noGhost = true
	})
	
	ix.act.Register("Sit", "player", {
		start = "ACT_BUSY_SIT_GROUND_ENTRY",
		sequence = "ACT_BUSY_SIT_GROUND",
		finish = {"ACT_BUSY_SIT_GROUND_EXIT", duration = 2.1},
		untimed = true,
		idle = true
	})

	ix.act.Register("Lean", "player", {
		start = "ACT_BUSY_LEAN_BACK_ENTRY",
		sequence = {"ACT_BUSY_LEAN_BACK", check = FacingWallBack},
		finish = {"ACT_BUSY_LEAN_BACK_EXIT", duration = 2.1},
		untimed = true,
		idle = true,
		noGhost = true
	})

	ix.act.Register("TypeConsole", "overwatch", {
		sequence = "console_type_loop",
		untimed = true,
		noGhost = true
	})

	ix.act.Register("Advance", "overwatch", {
		sequence = "signal_advance",
		noGhost = true
	})

	ix.act.Register("Forward", "overwatch", {
		sequence = "signal_forward",
		noGhost = true
	})

	ix.act.Register("Regroup", "overwatch", {
		sequence = "signal_group",
		noGhost = true
	})

	ix.act.Register("Halt", "overwatch", {
		sequence = "signal_halt",
		noGhost = true
	})

	ix.act.Register("Left", "overwatch", {
		sequence = "signal_left",
		noGhost = true
	})

	ix.act.Register("Right", "overwatch", {
		sequence = "signal_right",
		noGhost = true
	})

	ix.act.Register("Cover", "overwatch", {
		sequence = "signal_takecover",
		noGhost = true
	})

	ix.act.Register("Point", "metrocop", {
		sequence = "point",
		noGhost = true
	})

	ix.act.Register("Block", "metrocop", {
		sequence = "blockentry",
		untimed = true,
		noGhost = true
	})

	ix.act.Register("Startle", "metrocop", {
		sequence = "canal5breact1",
		noGhost = true
	})

	ix.act.Register("Warn", "metrocop", {
		sequence = "luggagewarn",
		noGhost = true
	})
end
