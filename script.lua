-- vim: set foldmethod=marker ts=4 sw=4 :
-- TODO rewrite variables: armor_model, model
--- Initial definitions ---
-- player model backwards compatibility
MODEL_NAME="player_model"
model=models[MODEL_NAME]
ping=pings
-- Texture dimensions --
TEXTURE_WIDTH = 256
TEXTURE_HEIGHT = 256

local optrequire
do
	local fallback=setmetatable({}, {__index=function() return function() end end})
	function optrequire(...)
		local status, req=pcall(require, ...)
		if status then return req end
		return fallback
	end
end

util = require("nulllib.util")
logging = optrequire("nulllib.logging")
timers=require("nulllib.timers")
nmath=require("nulllib.math")
PartsManager=require("nulllib.PartsManager")
UVManager=require("nulllib.UVManager")
sharedstate=require("nulllib.sharedstate")
sharedconfig=require("nulllib.sharedconfig")
statemonitor=require("nulllib.statemonitor")

---Set optimal settings for random player sounds
---@param sound Sound
---@return Sound
function sound_settings(sound)
	return sound:volume(1):pitch(1):pos(player:getPos())
end

-- shortcuts for /figura run so i don't have to type so much
C={}

-- math functions
lerp=math.lerp -- this is implemented in figura now
wave=nmath.wave

-- for global state tracking, post syncState era
-- this isn't entirely necessary but it's good to know what has and hasn't been
-- migrated yet. I should probably rewrite stuff that uses it, but most of it
-- isn't nearly as bad as the old syncState/setLocalState/etc. It's currently
-- only used for a somewhat scattered color check funciton.
STATE={
	["current"]={},
	["old"]={}
}

-- (the last remnants of) syncState {{{
do
	local pm_refresh=false
	function pmRefresh()
		logging.debug([[part refresh queued
		]], util.traceback())
		pm_refresh=true
	end

	function doPmRefresh()
		if pm_refresh then
			PartsManager.refreshAll()
			pm_refresh=false
		end
	end
end
-- }}}

-- Master configuration -- {{{

-- master state variables and configuration (do not access within pings) --
do
	local is_host=host:isHost()
	local defaults={
		["armor_enabled"]=true,
		["vanilla_enabled"]=false,
		["snore_enabled"]=true,
		["snore_augh"]=false,
		["print_settings"]=false,
		["vanilla_partial"]=false,
		["tail_enabled"]=true,
		["aquatic_enabled"]=true,
		["aquatic_override"]=false,
		["is_cat"]=true
	}
	local function armor_refresh_callback()
		if player:isLoaded() then pmRefresh() end
	end
	local callbacks={
		["armor_enabled"]=armor_refresh_callback
	}
	sharedconfig.load_defaults(defaults, callbacks)
end

local function printSettings()
	print("Settings:")
	printTable(sharedconfig.load())
end
if sharedconfig.load("print_settings") then
	printSettings()
end

--- Convenience, manipulate settings
---@param key? string Key to access
---@param value? any Value to set
function C.set(key, value)
	if value ~= nil and key ~= nil then
		sharedconfig.save(key, value)
	elseif key ~= nil then
		print(sharedconfig.load(key))
	else
		printSettings()
	end
end
-- }}}

-- Parts, groups, other constants -- {{{
HEAD=model.Head.Head
FACE=model.Head.Face
SHATTER=model.Head.Shatter
TAIL=model.Body_Tail.Tail_L1
VANILLA_PARTIAL={}
VANILLA_GROUPS={
	["HEAD"]={vanilla_model.HEAD, vanilla_model.HAT},
	["BODY"]={vanilla_model.BODY, vanilla_model.JACKET},
	["LEFT_ARM"]={vanilla_model.LEFT_ARM, vanilla_model.LEFT_SLEEVE},
	["RIGHT_ARM"]={vanilla_model.RIGHT_ARM, vanilla_model.RIGHT_SLEEVE},
	["LEFT_LEG"]={vanilla_model.LEFT_LEG, vanilla_model.LEFT_PANTS},
	["RIGHT_LEG"]={vanilla_model.RIGHT_LEG, vanilla_model.RIGHT_PANTS},
	["OUTER"]={ vanilla_model.HAT, vanilla_model.JACKET, vanilla_model.LEFT_SLEEVE, vanilla_model.RIGHT_SLEEVE, vanilla_model.LEFT_PANTS, vanilla_model.RIGHT_PANTS },
	["INNER"]={ vanilla_model.HEAD, vanilla_model.BODY, vanilla_model.LEFT_ARM, vanilla_model.RIGHT_ARM, vanilla_model.LEFT_LEG, vanilla_model.RIGHT_LEG },
	["ALL"]={ vanilla_model.HEAD, vanilla_model.BODY, vanilla_model.LEFT_ARM, vanilla_model.RIGHT_ARM, vanilla_model.LEFT_LEG, vanilla_model.RIGHT_LEG, vanilla_model.HAT, vanilla_model.JACKET, vanilla_model.LEFT_SLEEVE, vanilla_model.RIGHT_SLEEVE, vanilla_model.LEFT_PANTS, vanilla_model.RIGHT_PANTS },
	["ARMOR"]={vanilla_model.LEGGINGS, vanilla_model.BOOTS, vanilla_model.CHESTPLATE, vanilla_model.HELMET}
}

-- these are inefficient, redundancy is better in this case
-- for _, v in pairs(VANILLA_GROUPS.INNER) do table.insert(VANILLA_GROUPS.ALL,v) end
-- for _, v in pairs(VANILLA_GROUPS.OUTER) do table.insert(VANILLA_GROUPS.ALL,v) end
-- for _, v in pairs(armor_model) do table.insert(VANILLA_GROUPS.ARMOR, v) end

MAIN_GROUPS={model.Head, model.RightArm, model.LeftArm, model.RightLeg, model.LeftLeg, model.Body } -- RightArm LeftArm RightLeg LeftLeg Body Head

TAIL_LEGGINGS={
	model.Body.LeggingsTop,
	model.Body.LeggingsTopTrimF,
	model.Body.LeggingsTopTrimB,
	model.Body.MTail1.Leggings,
	model.Body.MTail1.LeggingsTrim,
	model.Body.MTail1.MTail2.LeggingsBottom
}
TAIL_LEGGINGS_COLOR={
	model.Body.LeggingsTopTrimF,
	model.Body.LeggingsTopTrimB,
	model.Body.MTail1.Leggings,
	model.Body.MTail1.LeggingsTrim,
	model.Body.MTail1.MTail2.LeggingsBottom
}
TAIL_BOOTS={
	model.Body.MTail1.MTail2.MTail3.Boot,
	model.Body.MTail1.MTail2.MTail3.LeatherBoot
}
TAIL_BONES={
	model.Body.MTail1,
	model.Body.MTail1.MTail2,
	model.Body.MTail1.MTail2.MTail3,
	model.Body.MTail1.MTail2.MTail3.MTail4
}
REG_TAIL_BONES={
	TAIL,
	TAIL.Tail_L2,
	TAIL.Tail_L2.Tail_L3,
	TAIL.Tail_L2.Tail_L3.fin
}
BODY_EMISSIVES={
	model.Body.MTail1.MTailDots1,
	model.Body.MTail1.MTail2.MTailDots2,
	model.Body.MTail1.MTail2.MTail3.MTailDots3,
	model.Body.MTail1.MTail2.MTail3.MTail4.MTailDots4,
	TAIL.TailDots1,
	TAIL.Tail_L2.TailDots2,
	TAIL.Tail_L2.Tail_L3.TailDots3,
	TAIL.Tail_L2.Tail_L3.fin.TailDots4,
	model.Head.EmDots,
	model.LeftArm.LeftArmEm,
	model.RightArm.RightArmEm,
	model.LeftLeg.LeftLegEm,
	model.RightLeg.RightLegEm
}
FACE_EMISSIVES={
	model.Head.Face
}
EMISSIVES=util.mergeTable(BODY_EMISSIVES, FACE_EMISSIVES)
COLORS={}
COLORS.neutral=vec(127/255,127/255,255/255)
COLORS.hurt=   vec(1, 0, 63/255)
COLORS.lava=   vec(1, 128/255, 64/255)
-- prev 255 160 192
COLORS.owo=    vec(1, 128/255, 160/255)
COLORS["end"]="end"
for _, v in pairs(EMISSIVES) do
	v:setColor(COLORS.neutral)
end

local gay_idiot_uuid="3dad78e8-6979-404f-820e-952ce20964a0" -- boy fren
--gay_idiot_uuid="468554f1-27cd-4ea1-9308-3dd14a9b1a12" -- alt account (testing)

-- }}}

--  PartsManager rules {{{
-- Vanilla rules

do
	-- TODO
	function getVanillaVisible()
		return (not avatar:canEditVanillaModel()) or vanilla_model.PLAYER:getVisible()
	end

	local function vanillaPartial()
		if sharedconfig.load("vanilla_enabled") then
			return false
		end
		return sharedconfig.load("vanilla_partial")
	end

	local function forceVanilla()
		print(vanilla_model.PLAYER:getVisible())
		return not avatar:canEditVanillaModel() or sharedconfig.load("vanilla_enabled") or vanilla_model.PLAYER:getVisible()
	end

	-- eventually replace this with an instance once PartsManager becomes a class
	local PM=PartsManager


	--- Vanilla state
	-- no cape if tail enabled (it clips)
	PM.addPartFunction(vanilla_model.CAPE, function(last) logging.trace("pm tail enabled func", sharedconfig.load("tail_enabled")) return last and not sharedconfig.load("tail_enabled") end)

	--- Custom state
	-- local tail_parts=util.mergeTable({model.Body.TailBase}, TAIL_BONES)
	local tail_parts={model.Body.MTail1, model.Body.TailBase}
	
	-- TODO: old vanilla_partial groups, use these for texture swap
	-- local vanilla_partial_disabled=util.mergeTable(MAIN_GROUPS, {model.Body.Body, model.Body.BodyLayer})
	-- local vanilla_partial_enabled={model.Head, model.Body}

	-- Show shattered only at low health
	PM.addPartFunction(SHATTER, function(last) return last and sharedstate.get("health") <= 5 end)

	-- Enable tail setting
	PM.addPartFunction(TAIL, function(last) return last and sharedconfig.load("tail_enabled") end)
	-- no legs, regular tail in water if tail enabled
	local mtail_mutually_exclusive={model.LeftLeg, model.RightLeg, TAIL, vanilla_model.LEGGINGS, vanilla_model.BOOTS}
	PM.addPartListFunction(mtail_mutually_exclusive, function(last) return last and not aquaticTailVisible() end)
	-- aquatic tail in water
	PM.addPartListFunction(tail_parts, function(last) return last and aquaticTailVisible() end)

	--- Armor state
	local all_armor=util.reduce(util.mergeTable, {VANILLA_GROUPS.ARMOR, TAIL_LEGGINGS, TAIL_BOOTS})
	PM.addPartListFunction(all_armor, function(last) return last and sharedconfig.load("armor_enabled") end)
	-- Only show armor if equipped
	PM.addPartFunction(model.Body.MTail1.MTail2.MTail3.Boot, function(last) return last and armor_state.boots end)
	PM.addPartFunction(model.Body.MTail1.MTail2.MTail3.LeatherBoot, function(last) return last and armor_state.leather_boots end)
	PM.addPartListFunction(TAIL_LEGGINGS, function(last) return last and armor_state.leggings end)


	-- Disable when vanilla_enabled
	PM.addPartListFunction(MAIN_GROUPS, function(last) return last and not getVanillaVisible() end)
end

SNORES={"snore-1", "snore-2", "snore-3"}
-- }}}

-- Expression change -- {{{
do
	local expressions={}
	expressions.neutral=vec(0,0)
	expressions["end"]=expressions.neutral
	expressions.hurt=vec(0,1)
	expressions.owo=vec(0,2)
	local expruvm=UVManager.new(vec(8, 8), nil, expressions, FACE)
	current_expression="neutral"

	-- color/expression rules
	function getBestColor()
		if current_expression=="owo" then
			return COLORS.owo
		elseif player:isInLava() or player:getDimensionName()=="minecraft:the_nether" then
			return COLORS.lava
		else
			return COLORS.neutral
		end
	end
	function getBestExpression()
		return "neutral"
	end
	function setColor(col)
		if not lock_color then
			col=(col~=nil) and col or getBestColor()
			for _, v in pairs(EMISSIVES) do
				v:setColor(col)
				-- TODO
				-- v:setShader("None")
			end
		end
	end

	-- Expression change code
	function setExpression(expression)
		current_expression=expression
		expruvm:setUV(current_expression)
		-- This expression sticks, so do not set color explicitly
		setColor()
	end
	function changeExpression(expression, ticks)
		expruvm:setUV(expression)
		-- This one is for more explicit "flashes" such as player hurt
		-- animations, get color explicitly
		setColor(COLORS[expression])
		timers.namedWait(ticks, resetExpression, "resetExpression")
	end
	function resetExpression()
		lock_color=false
		expruvm:setUV(current_expression)
		setColor()
	end

	function hurt()
		if sharedconfig.load("is_cat") then
			sound_settings(sounds["entity.cat.hurt"]):play() end
		lock_color=false
		changeExpression("hurt", 10)
		lock_color=true
		PartsManager.refreshPart(SHATTER)
	end
end
-- }}}

-- Action Wheel & Pings -- {{{
-- TODO
do
	wheel={}
	local wheel_index=1
	function wheelScroll(change)
		wheel_index=((wheel_index-1)+change)%#wheel+1
		action_wheel:setPage(wheel[wheel_index])
		print("page: " .. wheel_index)
	end

	wheel[1]=action_wheel:newPage()

	action_wheel:setPage(wheel[1])
	action_wheel.scroll=wheelScroll
end



wheel[1]:newAction():title('test expression'):onLeftClick(function() ping.expressionTest() end)
function ping.expressionTest()
	logging.debug("ping.expressionTest")
	changeExpression("hurt", 10)
end
wheel[1]:newAction():title('log health'):onLeftClick(function() print(player:getHealth()) end)
wheel[1]:newAction():title('Toggle Armor'):onLeftClick(function() setArmor() end)
wheel[1]:newAction():title('T-Pose'):onLeftClick(function() ping.tPose() end)
wheel[1]:newAction():title('UwU'):onLeftClick(function() ping.expr("owo") end)
-- action_wheel.SLOT_8.setTitle('sssss...')
-- action_wheel.SLOT_8.setItem("minecraft:creeper_head")
-- action_wheel.SLOT_8.setFunction(function() switch_model('misc/Creeper') end)

-- Pings --
--- Damage function --
function ping.expr(expr)
	logging.debug("ping.expr")
	local val=(expr==current_expression) and "neutral" or expr
	setExpression(val)
end


function ping.oof(health) -- This is a replacement for onDamage, that function doesn't sync for some reason
	logging.debug("ping.oof")
	hurt()
end

--- Toggle Armor ---
function setArmor(state)
	sharedconfig.save("armor_enabled", state)
end

do
	local purr_sound

	---@param state boolean
	function purr(state)
		if state and not purr_sound then
			purr_sound=sound_settings(sounds["entity.cat.purr"]):loop(true):play()
		elseif not state and purr_sound then
			purr_sound:stop()
			purr_sound=nil
		end
		return purr_sound
	end
end

local snore
do
	local snores={sounds["sounds.snore-1"], sounds["sounds.snore-2"], sounds["sounds.snore-3"]}
	
	local snore_index=1
	local is_snoring=false

	local function state_not_sleeping()
		-- return not player:getPose() ~= "SLEEPING"
		return player:getPose() ~= "SLEEPING"
	end

	local function snore_purr()
		purr(true)
		statemonitor.register("snore", state_not_sleeping, function() purr(false) end, 5, true)
	end

	local function snore_augh()
		if sharedconfig.load("snore_enabled") then
			if timers.cooldown(20*4, "snore") then
				sound_settings(snores[snore_index]):stop():play()
				snore_index=snore_index%#snores+1
				print(snore_index)
			end
		end
	end
	function snore()
		if sharedconfig.load("snore_augh") then
			snore_augh()
		else
			snore_purr()
		end
	end

end

-- meow
function pings.meow()
	sound_settings(sounds["entity.cat.ambient"]):play()
end
events.CHAT_SEND_MESSAGE:register(function(msg)
		if sharedconfig.load("is_cat") and string.match(msg, '^/') == nil then
			pings.meow() end
		return msg end,
	"chat_meow")

--- Toggle Vanilla ---
function setVanilla(state)
	sharedconfig.save("vanilla_enabled", state)
end


function ping.tPose()
	logging.debug("ping.tPose")
	-- TODO
	-- local_state.emote_vector=player:getPos()
	-- animation.tpose.start()
end
-- }}}

-- Tail stuff {{{
local tail_cooldown
function aquaticTailVisible()
	tail_cooldown=tail_cooldown or 0
	return (sharedconfig.load("aquatic_enabled") and (player:isInWater() or player:isInLava()) or sharedconfig.load("aquatic_override") or tail_cooldown>0) and not getVanillaVisible()
end

local function updateTailVisibility()
	local anim=player:getPose()
	local water=player:isInWater()
	local lava=player:isInLava()
	tail_cooldown=(tail_cooldown and tail_cooldown > 0) and tail_cooldown-1 or 0
	if aquaticTailVisible() and (anim=="SLEEPING" or anim=="SPIN_ATTACK" or anim=="FALL_FLYING" or water or lava) then
		tail_cooldown=anim=="SPIN_ATTACK" and 60 or (tail_cooldown >= 10 and tail_cooldown or 10)
	end
	if STATE.old.aquatic_tail_visible ~= aquaticTailVisible() then pmRefresh() end
	STATE.old.aquatic_tail_visible=aquaticTailVisible()
	renderer.forcePaperdoll=aquaticTailVisible()
end

-- armor {{{
armor_color={}
armor_color['leather'] = {131 /255 , 84  /255 , 50  /255}
armor_glint={}
armor_state={}
armor_state['leggings']=false
armor_state['boots']=false
armor_state['leather_boots']=false

do
	local positions={}
	positions['leather']=vec(0, 0)
	positions['iron']=vec(0, 1)
	positions['chainmail']=vec(0, 2)
	positions['golden']=vec(0, 3)
	positions['diamond']=vec(0, 4)
	positions['netherite']=vec(0, 5)
	tailuvm=UVManager.new(vec(0, 19), nil, positions)
end

-- TODO fix code after optimization in prewrite
-- function armor()
-- 	if true then return nil end
-- 	-- ^ hacky way to disable a function without uncommenting the entire thing to not break git vcs
-- 
-- 	-- Get equipped armor, extract name from item ID
-- 	local leggings_item = player.getEquipmentItem(4)
-- 	local boots_item    = player.getEquipmentItem(3)
-- 	local leggings     = string.sub(leggings_item.getType(), 11, -10)
-- 	local boots        = string.sub(boots_item.getType(),    11, -7)
-- 
-- 	if local_state.armor_enabled then
-- 		if old_state.leggings ~= leggings or old_state.armor_enabled ~= local_state.armor_enabled  then
-- 			-- leggings
-- 			armor_glint.leggings=leggings_item.hasGlint()
-- 			local leggings_color=colorArmor(leggings_item) or armor_color[leggings]
-- 			local uv=tailuvm:getUV(leggings)
-- 			if uv ~= nil then
-- 				armor_state.leggings=true
-- 				for k, v in pairs(TAIL_LEGGINGS) do
-- 					v.setUV(uv)
-- 				end
-- 				if leggings=="leather" then
-- 					for k, v in pairs(TAIL_LEGGINGS_COLOR) do
-- 						v.setColor(leggings_color)
-- 					end
-- 				else
-- 					for k, v in pairs(TAIL_LEGGINGS) do
-- 						v.setColor({1, 1, 1})
-- 					end
-- 				end
-- 			else
-- 				armor_state.leggings=false
-- 			end
-- 			pmRefresh()
-- 		end
-- 
-- 		if old_state.boots ~= boots or old_state.armor_enabled ~= local_state.armor_enabled  then
-- 			-- boots
-- 			armor_glint.boots=boots_item.hasGlint()
-- 			local boots_color=colorArmor(boots_item) or armor_color[boots]
-- 			local uv_boots=tailuvm:getUV(boots)
-- 			if uv_boots ~= nil then
-- 				armor_state.boots=true
-- 				for k, v in pairs(TAIL_BOOTS) do
-- 					v.setUV(uv_boots)
-- 				end
-- 				if boots=="leather" then
-- 					model.Body.MTail1.MTail2.MTail3.Boot.setColor(boots_color)
-- 					armor_state.leather_boots=true
-- 				else
-- 					model.Body.MTail1.MTail2.MTail3.Boot.setColor({1, 1, 1})
-- 					armor_state.leather_boots=false
-- 				end
-- 			else
-- 				armor_state.boots=false
-- 			end
-- 			pmRefresh()
-- 		end
-- 	else
-- 		armor_glint.leggings=false
-- 		armor_glint.boots=false
-- 	end
-- 
-- 	if armor_glint.leggings then
-- 		for _, v in pairs(TAIL_LEGGINGS) do
-- 			v.setShader("Glint")
-- 		end
-- 	else
-- 		for _, v in pairs(TAIL_LEGGINGS) do
-- 			v.setShader("None")
-- 		end
-- 	end
-- 	if armor_glint.boots then
-- 		for _, v in pairs(TAIL_BOOTS) do
-- 			v.setShader("Glint")
-- 		end
-- 	else
-- 		for _, v in pairs(TAIL_BOOTS) do
-- 			v.setShader("None")
-- 		end
-- 	end
-- 
-- 	old_state.boots=boots
-- 	old_state.leggings=leggings
-- 	old_state.armor_enabled=local_state.armor_enabled
-- end

function colorArmor(item)
	local tag = item.tag
	if tag ~= nil and tag.display ~= nil and tag.display.color ~= nil then
		return vectors.intToRGB(tag.display.color)
	end
end
-- }}}

function resetAngles(part)
	part:setRot(vec(0,0,0))
end

--- Get the vertical distance between a position and the block hitbox directly below it
-- @param block BlockState
-- @param pos Vec3
function getVerticalBlockOffset(block, pos)
	local relative_pos=pos-block:getPos()
	local absolute_offset=0
	-- print(relative_pos)
	-- iterates over collision shapes in block
	for k, shape_corners in ipairs(block:getCollisionShape()) do
		-- printTable(shape_corners)
		local above=true
		for _, axis in ipairs({"x", "z"}) do
			if not (relative_pos[axis] >= shape_corners[1][axis] and relative_pos[axis] <= shape_corners[2][axis]) then
				above=false
			end
		end
		-- print("above for shape " .. tostring(k) .. " is " .. tostring(above))
		absolute_offset=(above and shape_corners[2]["y"] >= absolute_offset) and shape_corners[2]["y"] or absolute_offset
	end
	return relative_pos.y-absolute_offset
end

function curveMTail(delta)
	local max_curve=-28
	local block_offset=0.6 -- extra length of tail compared to vanilla model
	local pos=player:getPos(delta)
	local block=world.getBlockState(pos)
	-- if block has a "level" property (this applies to fluids only)
	if block:getProperties().level or block:isAir() then
		block=world.getBlockState(pos+vec(0,-1,0))
	end
	local block_offset_lerp=1-(math.min(1, math.max(0, getVerticalBlockOffset(block,pos)/block_offset)))
	return math.lerp(0, max_curve, block_offset_lerp)

end

function animateMTail(val, delta)
	local chest_rot = 3
	local period=3*math.pi
	local amplitude_multiplier=1
	local curve=0
	-- TODO vanilla model manipulation broke, add chestplate model
	-- armor_model.CHESTPLATE:setRot(vec( -wave(val, period, math.rad(3)), 0, 0 ))
	-- this makes it work with partial vanilla
	-- vanilla_model.BODY:setRot(vec( -wave(val, period, math.rad(3)), 0, 0 ))
	-- vanilla_model.JACKET:setRot(vec( -wave(val, period, math.rad(3)), 0, 0 ))

	local vehicle = player:getVehicle()
	if vehicle then
		if vehicle:getType() ~= "create:seat" then
			curve=22
		end
		period=4*math.pi
		amplitude_multiplier=0.33
		TAIL_BONES[1]:setRot(vec(80,0,0))
	else
		local pose=player:getPose()
		if pose ~= "SWIMMING" and pose ~= "SLEEPING" then
			curve=curveMTail(delta)
		end
		if pose == "SLEEPING" then
			period=6*math.pi
			amplitude_multiplier=0.3
		end
		resetAngles(model.Body)
		model.Body:setRot(vec( wave(val, period, 3*amplitude_multiplier), 0, 0 ))
		model.Body.LeggingsTopTrimF:setRot(vec( wave(val-1, period, 4*amplitude_multiplier), 0, 0 ))
		model.Body.LeggingsTopTrimB:setRot(vec( wave(val-1, period, 4*amplitude_multiplier), 0, 0 ))
		TAIL_BONES[1]:setRot(vec( wave(val-1, period, 7*amplitude_multiplier) + curve, 0, 0 ))
	end

	TAIL_BONES[2]:setRot(vec( wave(val-2, period,  8*amplitude_multiplier) + curve, 0, 0 ))
	TAIL_BONES[3]:setRot(vec( wave(val-3, period, 12*amplitude_multiplier) + curve, 0, 0 ))
	TAIL_BONES[4]:setRot(vec( wave(val-4, period, 15*amplitude_multiplier) + curve, 0, 0 ))
end
tail_original_rot={}
for k, v in ipairs(REG_TAIL_BONES) do
	tail_original_rot[k]=v:getRot()
end
function animateTail(val)
	local per_y=20*4
	local per_x=20*6
	for k, _ in ipairs(REG_TAIL_BONES) do
		local cascade=(k-1)*12
		REG_TAIL_BONES[k]:setRot(vec( tail_original_rot[k].x + wave(val-cascade, per_x, 3), wave(val-cascade, per_y, 12), tail_original_rot[k].z ))
	end
end

STATE.current.anim_tick=0
STATE.current.anim_cycle=0
STATE.old.anim_cycle=0

local function animateTick()
	STATE.current.anim_tick = STATE.current.anim_tick + 1
	if aquaticTailVisible() then
		local velocity = player:getVelocity()

		if aquaticTailVisible() then
			STATE.old.anim_cycle=STATE.current.anim_cycle
			local player_speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
			local animation=player:getPose()
			local factor=(not player:isInWater() and (animation=="FALL_FLYING" or animation=="SPIN_ATTACK")) and 0.5 or 5
			STATE.current.anim_cycle=STATE.current.anim_cycle + (player_speed*factor+0.75)
			-- bubble animation would go here but i don't have that (yet)
		end

	else
		STATE.old.anim_cycle=STATE.current.anim_cycle
		STATE.current.anim_cycle=STATE.current.anim_cycle+1
	end
end



-- }}}

-- Wipers {{{
do
	local wiper_state="STOPPED" -- valid states are "STOPPED", "STARTING", "STARTED", "STOPPING"
	local wiper_wipe=animations[MODEL_NAME].wiper_wipe
	local wiper_target_state=false
	local wiper_deploy=animations[MODEL_NAME].wiper_deploy
	local wiper=model.Head_Accessory.Wiper
	assert(type(wiper_wipe)=="Animation")
	assert(type(wiper_deploy)=="Animation")
	assert(type(wiper)=="ModelPart")

	wiper_wipe:setPriority(1)
	wiper_deploy:setPriority(0)
	wiper:setVisible(false)

	---Check if a HOLD type animation is currently held
	---@param animation Animation Check if an animation is waiting at the end of a hold
	local function hold_ended(animation)
		local anim_time=animation:getTime()
		local anim_length=animation:getLength()
		
		return animation:getLoop()=="HOLD" and
			(anim_time==anim_length or anim_time==0)
	end

	---Finish and hold an animation on the last frame
	---@return boolean Whether or not the animation has reached the end of the hold
	function stop_and_wait(animation)
		if hold_ended(animation) then
			return true
		end
		animation:setLoop("HOLD")
		return false
	end

	-- steps to stop:
	-- stop wiping animation
	-- (set to hold, wait for time)
	-- start retract animation (wiper_deploy, speed: -1)
	-- wait for end
	-- finalize state, hide part
	--
	-- steps to start:
	-- show part
	-- start animation (wiper_deploy, speed: 1)
	-- wait for end
	-- start wipe animation, loop
	local wiper_run_deploy_switch={
		STOPPED=function(state)
			if state then
				wiper_state="STARTING"
				wiper_deploy:setSpeed(1):stop():play()
				wiper:setVisible(true)
			end
		end,
		STARTING=function(state)
			if wiper_deploy:getTime()==wiper_deploy:getLength() then
				wiper_deploy:stop()
				wiper_wipe:play():setLoop("LOOP")
				wiper_state="STARTED"
			end
		end,
		STARTED=function(state)
			if not state then
				wiper_state="STOPPING"
				stop_and_wait(wiper_wipe)
			end
		end,
		STOPPING=function(state)
			-- stop process has concluded
			if wiper_deploy:getPlayState() == "PLAYING" and wiper_deploy:getTime()==0 then
				wiper_state="STOPPED"
				wiper:setVisible(false)
				wiper_deploy:stop()
			elseif stop_and_wait(wiper_wipe) then
				wiper_wipe:stop()
				wiper_deploy:setSpeed(-1):play()
			end
		end,
	}

	--- Run deploy action
	---@param state boolean Should the wiper be deployed?
	local function wiper_run_deploy(state)
		wiper_run_deploy_switch[wiper_state](state)
	end

	local function wiper_sync_state()
		wiper_run_deploy(wiper_target_state)
	end
	--- Set wiper state. Ignores subsequent calls
	---@param state boolean true to start wiper, false to stop wiper
	function set_wiper(state)
		if state ~= wiper_target_state then
			wiper_target_state=state
		end
	end

	function wiper_tick()
		set_wiper(player:isInRain())
		wiper_sync_state()
	end

	events.TICK:register(wiper_tick, "wiper")
end
-- }}}

-- initialize values -- {{{
function player_init()
	local function health_callback(new, old)
		if old > new then
			hurt()
		end
		PartsManager.refreshPart(SHATTER)
	end

	sharedstate.init("health", player:getHealth(), health_callback)
	-- TODO set part visibility in avatar.json
	-- actually it's probably fine, it's jsut here because i forget visibility settings
	-- local all_parts=util.recurseModelGroup(model)

	-- for k, v in pairs(all_parts) do
	-- 	v:setVisible(nil)
	-- end
	pmRefresh()
	events.ENTITY_INIT:remove("player_init")
end

events.ENTITY_INIT:register(function() return player_init() end, "player_init")

-- Initial configuration --
-- TODO x2 fix below, this entire block may not be needed with PartsManager
if avatar:canEditVanillaModel() then
	vanilla_model.PLAYER:setVisible(false)
else
	model:setVisible(false)
end
STATE.current.anim_tick=0
-- }}}

-- Tick function -- {{{
function hostTick()
	sharedstate.set("health", player:getHealth())
end

local gay_idiot_check
do
	local nearby=false
	local nearby_ticks=0
	function pings.set_gay_idiot_nearby(state)
		if state then
			pings.expr("owo")
			purr(true)
		else
			pings.expr("neutral")
			purr(false)
		end
	end

	local function set_gay_idiot_nearby(state)
		if state ~= nearby then
			nearby=state
			pings.set_gay_idiot_nearby(state)
		end
	end

	---@param frequency? integer time since last check, default 1
	function gay_idiot_check(frequency)
		frequency=frequency or 1
		nearby_ticks=nearby_ticks or 0
		local gay_idiot=world.getEntity(gay_idiot_uuid)

		-- if exists
		if gay_idiot ~= nil then
			-- if nearby then add to timer
			local distance = (gay_idiot:getPos() - player:getPos()):length()
			if distance <= 1 then
				nearby_ticks=nearby_ticks+frequency
			else
				nearby_ticks=0
			end

			set_gay_idiot_nearby(nearby_ticks>=5*20)
		else
			set_gay_idiot_nearby(false)
		end
	end
end

function tick()
	STATE.current.color_check=player:isInLava() ~=
		(player:getDimensionName()=="minecraft:the_nether")
	if STATE.old.color_check~=STATE.current.color_check then
		setColor()
	end
	-- optimization, only execute these with certain frequency --
	if world.getTime() % 5 == 0 then -- 1/4 second
		if player:getPose() == "SLEEPING" then
			snore()
		end

		if host:isHost() then gay_idiot_check(5) end

		-- unneeded for now but can uncomment if needed
		--if world.getTime() % 20 == 0 then -- 1 second
			-- Sync state every 10 seconds
			if world.getTime() % (20*10) == 0 then
				sharedstate.sync()
			end
		--end
	end

	hostTick()

	-- TODO
	-- if animation.tpose.isPlaying() and local_state.emote_vector.distanceTo(player.getPos()) >= 0.5 then
	-- 	animation.tpose.stop()
	-- end


	-- Refresh tail armor state
	-- TODO re add armor stuff
	--armor()
	-- Implements tail cooldown conditions
	updateTailVisibility()

	-- Animation code resides in this function
	animateTick()

	-- Check for queued PartsManager refresh
	doPmRefresh()
	-- End of tick --
	STATE.old.color_check=STATE.current.color_check
end
events.TICK:register(function() if player then tick() end end, "main_tick")
-- }}}

-- Render function {{{
local function render(delta)
	if aquaticTailVisible() then
		animateMTail((lerp(STATE.old.anim_cycle, STATE.current.anim_cycle, delta) * 0.2), delta)
	else
		resetAngles(model.Body)
		-- resetAngles(vanilla_model.BODY)
		-- resetAngles(vanilla_model.JACKET)
		-- resetAngles(armor_model.CHESTPLATE)
		animateTail((lerp(STATE.old.anim_cycle, STATE.current.anim_cycle, delta)))
	end
end
-- TODO this may break animation during death
events.RENDER:register(function(delta) if player then render(delta) end end, "main_render")
-- }}}
