-- vim: set foldmethod=marker ts=4 sw=4 :
-- TODO rewrite variables: armor_model, ping, model
--- Initial definitions ---
-- player model backwards compatibility
model=models.player_model
armor_model={
	["BOOTS"]=vanilla_model.BOOTS,
	["LEGGINGS"]=vanilla_model.LELGGINGS,
	["CHESTPLATE"]=vanilla_model.CHESTPLATE,
	["HELMET"]=vanilla_model.HELMET
}
-- TODO remove placeholder table when pings are implemented
ping={}
-- Texture dimensions --
TEXTURE_WIDTH = 256
TEXTURE_HEIGHT = 256

-- utility functions -- {{{

--- Create a string representation of a table
--- @param o table
function dumpTable(o)
	if type(o) == 'table' then
		local s = '{ '
		local first_loop=true
		for k,v in pairs(o) do
			if not first_loop then
				s = s .. ', '
			end
			first_loop=false
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dumpTable(v)
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

do
	local function format_any_value(obj, buffer)
		local _type = type(obj)
		if _type == "table" then
			buffer[#buffer + 1] = '{"'
			for key, value in next, obj, nil do
				buffer[#buffer + 1] = tostring(key) .. '":'
				format_any_value(value, buffer)
				buffer[#buffer + 1] = ',"'
			end
			buffer[#buffer] = '}' -- note the overwrite
		elseif _type == "string" then
			buffer[#buffer + 1] = '"' .. obj .. '"'
		elseif _type == "boolean" or _type == "number" then
			buffer[#buffer + 1] = tostring(obj)
		else
			buffer[#buffer + 1] = '"???' .. _type .. '???"'
		end
	end
	--- Dumps object as UNSAFE json, i stole this from stackoverflow so i could use json.tool to format it so it's easier to read
	function dumpJSON(obj)
		if obj == nil then return "null" else
			local buffer = {}
			format_any_value(obj, buffer)
			return table.concat(buffer)
		end
	end
end


-- TODO: accept model part to determine texture width and height
---@param uv table
function UV(uv)
	return vec(
	uv[1]/TEXTURE_WIDTH,
	uv[2]/TEXTURE_HEIGHT
	)
end


---@param inputstr string
---@param sep string
function splitstring (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

---@param input string
function unstring(input)
	if input=="nil" then
		return nil
	elseif input == "true" or input == "false" then
		return input=="true"
	elseif tonumber(input) ~= nil then
		return tonumber(input)
	else
		return input
	end
end

---@param func function
---@param table table
function map(func, table)
	local t={}
	for k, v in pairs(table) do
		t[k]=func(v)
	end
	return t
end


---@param func function
---@param table table
function filter(func, table)
	local t={}
	for k, v in pairs(table) do
		if func(v) then
			t[k]=v
		end
	end
	return t
end

---@param tbl table
---@param val any
function has_value(tbl, val)
	for _, v in pairs(tbl) do
		if v==val then return true end
	end
	return false
end

--- Unordered reduction, only use when working with dictionaries and
--- execution order does not matter
---@param tbl table Table to reduce
---@param func function Function used to reduce table
---@param init any Initial operand for reduce function
function reduce(func, tbl, init)
	local result = init
	local first_loop = true
	for _, v in pairs(tbl) do
		if first_loop and init == nil then
			result=v
		else
			result = func(result, v)
		end
		first_loop=false
	end
	return result
end

--- Ordered reduction, does not work with dictionaries
---@param tbl table Table to reduce
---@param func function Function used to reduce table
---@param init any Initial operand for reduce function
function ireduce(func, tbl, init)
	local result = init
	local first_loop = true
	for _, v in ipairs(tbl) do
		if first_loop and init == nil then
			result=v
		else
			result = func(result, v)
		end
		first_loop=false
	end
	return result
end

--- Merge two tables. First table value takes precedence when conflict occurs.
---@param tb1 table
---@param tb2 table
function mergeTable(tb1, tb2)
	local t={}
	for k, v in pairs(tb1) do
		t[k]=v
	end
	for k, v in pairs(tb2) do
		if type(k)=="number" then
			table.insert(t, v)
		else
			if t[k]==nil then
				t[k]=v
			end
		end
	end
	return t
end

function debugPrint(var)
	print(dumpTable(var))
	return var
end

--- Recursively walk a model tree and return a table containing the group and each of its sub-groups
--- @param group table The group to recurse
--- @return table Resulting table
function recurseModelGroup(group)
	local t={}
	table.insert(t, group)
	if group:getType()=="GROUP" then
		for k, v in pairs(group:getChildren()) do
			for _, v2 in pairs(recurseModelGroup(v)) do
				table.insert(t, v2)
			end
		end
	end
	return t
end
-- }}}

-- Timer (not mine lol) -- {{{
-- TODO investigate if events can replace some of this
do
	local timers = {}
	function wait(ticks,next)
		table.insert(timers, {t=world.getTime()+ticks,n=next})
	end
	local function tick()
		for key,timer in pairs(timers) do
			if world.getTime() >= timer.t then
				timer.n()
				table.remove(timers,key)
			end
		end
	end

	events.TICK:register(function() if player then tick() end end, "timer")
end

-- named timers (this one is mine but heavily based on the other) --
-- if timer is armed twice before expiring it will only be called once) --
do
	local timers = {}
	function namedWait(ticks, next, name)
		-- main difference, this will overwrite an existing timer with
		-- the same name
		timers[name]={t=world.getTime()+ticks,n=next}
	end
	local function tick()
		for key, timer in pairs(timers) do
			if world.getTime() >= timer.t then
				timer.n()
				timers[key]=nil
			end
		end
	end
	events.TICK:register(function() if player then tick() end end, "named_timer")
end

-- named cooldowns
do
	local timers={}
	function cooldown(ticks, name)
		if timers[name] == nil then
			timers[name]={t=world.getTime()+ticks}
			return true
		end
		return false
	end
	local function tick()
		for key, timer in pairs(timers) do
			if world.getTime() >= timer.t then
				timers[key]=nil
			end
		end
	end
	events.TICK:register(function() if player then tick() end end, "cooldown")
end

function rateLimit(ticks, next, name)
	if cooldown(ticks+1, name) then
		namedWait(ticks, next, name)
	end
end

-- }}}

-- syncState {{{
function syncState()
	ping.setSnoring(skin_state.snore_enabled)
	ping.syncState(setLocalState())
end

do
	local pm_refresh=false
	function pmRefresh()
		pm_refresh=true
	end

	function doPmRefresh()
		if pm_refresh then
			PartsManager.refreshAll()
			pm_refresh=false
		end
	end
end

function ping.syncState(tbl)
	for k, v in pairs(tbl) do
		local_state[k]=v
	end
	pmRefresh()
end
-- }}}

-- Math {{{
--- Sine function with period and amplitude
--- @param x number Input value
--- @param period number Period of sine wave
--- @param amp number Peak amplitude of sine wave
function wave(x, period, amp) return math.sin((2/period)*math.pi*(x%period))*amp end
function lerp(a, b, t) return a + ((b - a) * t) end
-- }}}

-- Master and local state variables -- {{{
-- Local State (these are copied by pings at runtime) --
local_state={}
old_state={}
-- master state variables and configuration (do not access within pings) --
do
	local is_host=host:isHost()
	local defaults={
		["armor_enabled"]=true,
		["vanilla_enabled"]=false,
		["snore_enabled"]=true,
		["print_settings"]=false,
		["vanilla_partial"]=false,
		["tail_enabled"]=true,
		["aquatic_enabled"]=true,
		["aquatic_override"]=false
	}
	function setLocalState()
		if is_host then
			for k, v in pairs(skin_state) do
				local_state[k]=v
			end
		else
			for k, v in pairs(defaults) do
				if local_state[k] == nil then local_state[k]=v end
			end
		end
		return local_state
	end
	-- TODO reimplement with new data API
	-- if is_host then
	if false then
		local savedData=data.loadAll()
		if savedData == nil then
			for k, v in pairs(defaults) do
				data.save(k, v)
			end
			savedData=data.loadAll()
		end
		skin_state=mergeTable(
		map(unstring,data.loadAll()),
		defaults)
	else
		skin_state=defaults
	end
	setLocalState()
end

function printSettings()
	print("Settings:")
	for k, v in pairs(skin_state) do
		print(tostring(k)..": "..tostring(v))
	end
end
if skin_state.print_settings==true then
	printSettings()
end

function setState(name, state)
	if state == nil then
		skin_state[name]=not skin_state[name]
	else
		skin_state[name]=state
	end
	-- TODO
	-- data.save(name, skin_state[name])
end

-- }}}

-- PartsManager -- {{{
do
	PartsManager={}
	local pm={}

	--- ensure part is initialized
	local function initPart(part)
		local part_key=part
		if pm[part_key] == nil then
			pm[part_key]={}
		end
		pm[part_key].part=part
		if pm[part_key].functions == nil then
			pm[part_key].functions = {}
		end
		if pm[part_key].init==nil then
			pm[part_key].init="true"
		end
	end
	--- Add function to part in PartsManager.
	--- @param part table Any object with a setEnabled() method.
	--- @param func function Function to add to model part's function chain.
	--- @param init? boolean Default value for chain. Should only be set once, subsequent uses overwrite the entire chain's initial value.
	function PartsManager.addPartFunction(part, func, init)
		initPart(part)
		local part_key=part
		if init ~= nil then
			pm[part_key].init=init
		end
		table.insert(pm[part_key]["functions"], func)
	end

	--- Set initial value for chain.
	--- @param part table Any object with a setEnabled() method.
	--- @param init? boolean Default value for chain. Should only be set once, subsequent uses overwrite the entire chain's initial value.
	function PartsManager.setInitialValue(part, init)
		assert(init~=nil)
		initPart(part)
		local part_key=part
		pm[part_key].init=init
	end

	--- Set initial value for chain on all objects in table.
	--- @param group table A table containing objects with a setEnabled() method.
	--- @param init? boolean Default value for chain. Should only be set once, subsequent uses overwrite the entire chain's initial value.
	function PartsManager.setGroupInitialValue(group, init)
		assert(init~=nil)
		for _, v in pairs(group) do
			PartsManager.setInitialValue(v, init)
		end
	end

	--- Evaluate a part's chain to determine if it should be visible.
	--- @param part table An object managed by PartsManager.
	function PartsManager.evaluatePart(part)
		local part_key=part
		assert(pm[part_key] ~= nil)

		local evalFunc=function(x, y) return y(x) end
		local init=pm[part_key].init
		return ireduce(evalFunc, pm[part_key].functions, true)
	end
	local evaluatePart=PartsManager.evaluatePart

	--- Refresh (enable or disable) a part based on the result of it's chain.
	--- @param part table An object managed by PartsManager.
	function PartsManager.refreshPart(part)
		local part_enabled=evaluatePart(part)
		part:setVisible(part_enabled)
		return part_enabled
	end

	--- Refresh all parts managed by PartsManager.
	function PartsManager.refreshAll()
		for _, v in pairs(pm) do
			PartsManager.refreshPart(v.part)
		end
	end

	--- Add function to list of parts in PartsManager
	--- @param group table A table containing objects with a setEnabled() method.
	--- @param func function Function to add to each model part's function chain.
	--- @param default? boolean Default value for chain. Should only be set once, subsequent uses overwrite the entire chain's initial value.
	function PartsManager.addPartGroupFunction(group, func, default)
		for _, v in ipairs(group) do
			PartsManager.addPartFunction(v, func, default)
		end
	end
end
-- }}}

-- UVManager {{{
--
-- TODO: accept model part for built-in UV management, automatic texture size
do
	local mt={}
	--- @class UVManager
	UVManager = {
		step=vec(0,0),
		offset=vec(0,0),
		positions={},
		part=nil,
		dimensions=nil
	}
	mt.__index=UVManager
	--- @return UVManager
	--- @param step Vector2 A vector representing the distance between UVs
	--- @param offset Vector2 A vector represnting the starting point for UVs, or nil
	--- @param positions table A dictionary of names and offset vectors
	--- @param part ModelPart Model part to manage
	function UVManager.new(self, step, offset, positions, part)
		local t={}
		if step ~= nil then t.step=step end
		if offset ~= nil then t.offset=offset end
		if positions ~= nil then t.positions=positions end

		if part ~= nil then
			UVManager.setPart(t, part)
		end

		t=setmetatable(t, mt)
		return t
	end

	--- @param part ModelPart Model part to manage
	function UVManager.setPart(self, part)
		self.part=part
		self.dimensions=part:getTextureSize()
	end

	function UVManager.getUV(self, input)
		local vect={}
		local stp=self.step
		local offset=self.offset
		if type(input) == "string" then
			if self.positions[input] == nil then return nil end
			vect=self.positions[input]
		else
			vect=vectors.of(input)
		end
		local u=offset.x+(vect.x*stp.x)
		local v=offset.y+(vect.y*stp.y)
		if self.dimensions ~= nil then
			-- TODO override for my specific texture, replace this with matrix stuff
			-- (get rid of division once you figure out how setUVMatrix works)
			return vec(u/(self.dimensions.x/2), v/(self.dimensions.y/2))
		else
			return UV{u, v}
		end
	end

	function UVManager.setUV(self, input)
		if self.part == nil then return false end
		self.part:setUV(self:getUV(input))
	end
end
-- }}}

-- Parts, groups, other constants -- {{{
HEAD=model.Head.Head
FACE=model.Head.Face
SHATTER=model.Head.Shatter
VANILLA_PARTIAL={}
VANILLA_GROUPS={
	["HEAD"]={vanilla_model.HEAD, vanilla_model.HAT},
	["BODY"]={vanilla_model.BODY, vanilla_model.JACKET},
	["LEFT_ARM"]={vanilla_model.LEFT_ARM, vanilla_model.LEFT_SLEEVE},
	["RIGHT_ARM"]={vanilla_model.RIGHT_ARM, vanilla_model.RIGHT_SLEEVE},
	["LEFT_LEG"]={vanilla_model.LEFT_LEG, vanilla_model.LEFT_PANTS_LEG},
	["RIGHT_LEG"]={vanilla_model.RIGHT_LEG, vanilla_model.RIGHT_PANTS_LEG},
	["OUTER"]={ vanilla_model.HAT, vanilla_model.JACKET, vanilla_model.LEFT_SLEEVE, vanilla_model.RIGHT_SLEEVE, vanilla_model.LEFT_PANTS_LEG, vanilla_model.RIGHT_PANTS_LEG },
	["INNER"]={ vanilla_model.HEAD, vanilla_model.BODY, vanilla_model.LEFT_ARM, vanilla_model.RIGHT_ARM, vanilla_model.LEFT_LEG, vanilla_model.RIGHT_LEG },
	["ALL"]={ vanilla_model.HEAD, vanilla_model.BODY, vanilla_model.LEFT_ARM, vanilla_model.RIGHT_ARM, vanilla_model.LEFT_LEG, vanilla_model.RIGHT_LEG, vanilla_model.HAT, vanilla_model.JACKET, vanilla_model.LEFT_SLEEVE, vanilla_model.RIGHT_SLEEVE, vanilla_model.LEFT_PANTS_LEG, vanilla_model.RIGHT_PANTS_LEG },
	["ARMOR"]=armor_model
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
	model.Body_Tail,
	model.Body_Tail.Tail_L2,
	model.Body_Tail.Tail_L2.Tail_L3,
	model.Body_Tail.Tail_L2.Tail_L3.fin
}
BODY_EMISSIVES={
	model.Body.MTail1.MTailDots1,
	model.Body.MTail1.MTail2.MTailDots2,
	model.Body.MTail1.MTail2.MTail3.MTailDots3,
	model.Body.MTail1.MTail2.MTail3.MTail4.MTailDots4,
	model.Body_Tail.TailDots1,
	model.Body_Tail.Tail_L2.TailDots2,
	model.Body_Tail.Tail_L2.Tail_L3.TailDots3,
	model.Body_Tail.Tail_L2.Tail_L3.fin.TailDots4,
	model.Head.EmDots,
	model.LeftArm.LeftArmEm,
	model.RightArm.RightArmEm,
	model.LeftLeg.LeftLegEm,
	model.RightLeg.RightLegEm
}
FACE_EMISSIVES={
	model.Head.Face
}
EMISSIVES=mergeTable(BODY_EMISSIVES, FACE_EMISSIVES)
COLORS={}
COLORS.neutral=vec(127/255,127/255,255/255)
COLORS.hurt=   vec(1, 0, 63/255)
COLORS.lava=   vec(1, 128/255, 64/255)
-- prev 255 160 192
COLORS.owo=    vec(1, 128/255, 160/255)
COLORS["end"]="end"
for k, v in pairs(EMISSIVES) do
	v:setColor(COLORS.neutral)
end

-- }}}

--  PartsManager rules {{{
-- Vanilla rules

do
	-- TODO
	local can_modify_vanilla=avatar.canEditVanillaModel

	local function vanillaPartial()
		if local_state.vanilla_enabled then
			return false
		end
		return local_state.vanilla_partial
	end

	local function forceVanilla()
		return not can_modify_vanilla or local_state.vanilla_enabled
	end

	-- eventually replace this with an instance once PartsManager becomes a class
	local PM=PartsManager


	--- Vanilla state
	-- Show all in vanilla partial
	PM.addPartGroupFunction(VANILLA_GROUPS.ALL, function() return vanillaPartial() end)
	-- no cape if tail enabled (it clips)
	PM.addPartFunction(vanilla_model.CAPE, function(last) return last and not local_state.tail_enabled end)
	-- no legs in water if mtail enabled
	PM.addPartGroupFunction(VANILLA_GROUPS.LEFT_LEG, function(last) return last and not aquaticTailVisible() end)
	PM.addPartGroupFunction(VANILLA_GROUPS.RIGHT_LEG, function(last) return last and not aquaticTailVisible() end)
	-- no vanilla head in partial vanilla
	PM.addPartGroupFunction(VANILLA_GROUPS.HEAD, function(last)
		return last and not vanillaPartial() end)
	-- Always true if vanilla_enabled
	PM.addPartGroupFunction(VANILLA_GROUPS.ALL, function(last) return last or forceVanilla() end)


	--- Custom state
	local tail_parts=mergeTable({model.Body.TailBase}, TAIL_BONES)
	-- Disable model in vanilla partial
	local vanilla_partial_disabled=mergeTable(MAIN_GROUPS, {model.Body.Body, model.Body.BodyLayer})
	local vanilla_partial_enabled={model.Head, model.Body}
	PM.addPartGroupFunction(vanilla_partial_disabled, function(last) return not vanillaPartial() end)
	-- Enable certain parts in vanilla partial
	PM.addPartGroupFunction(vanilla_partial_enabled, function(last) return last or vanillaPartial() end)
	PM.addPartGroupFunction(tail_parts, function(last) return last or vanillaPartial() end)

	-- Show shattered only at low health
	PM.addPartFunction(SHATTER, function(last) return last and local_state.health <= 5 end)

	-- Enable tail setting
	PM.addPartFunction(model.Body_Tail, function(last) return last and local_state.tail_enabled end)
	-- no legs, regular tail in water if tail enabled
	local mtail_mutually_exclusive={model.LeftLeg, model.RightLeg, model.Body_Tail, armor_model.LEGGINGS, armor_model.BOOTS}
	PM.addPartGroupFunction(mtail_mutually_exclusive, function(last) return last and not aquaticTailVisible() end)
	-- aquatic tail in water
	PM.addPartGroupFunction(tail_parts, function(last) return last and aquaticTailVisible() end)

	--- Armor state
	local all_armor=reduce(mergeTable, {VANILLA_GROUPS.ARMOR, TAIL_LEGGINGS, TAIL_BOOTS})
	PM.addPartGroupFunction(all_armor, function(last) return last and local_state.armor_enabled end)
	-- Only show armor if equipped
	PM.addPartFunction(model.Body.MTail1.MTail2.MTail3.Boot, function(last) return last and armor_state.boots end)
	PM.addPartFunction(model.Body.MTail1.MTail2.MTail3.LeatherBoot, function(last) return last and armor_state.leather_boots end)
	PM.addPartGroupFunction(TAIL_LEGGINGS, function(last) return last and armor_state.leggings end)


	-- Disable when vanilla_enabled
	PM.addPartGroupFunction(MAIN_GROUPS, function(last) return last and not forceVanilla() end)
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
	local expruvm=UVManager:new(vec(8, 8), nil, expressions, FACE)
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
		namedWait(ticks, resetExpression, "resetExpression")
	end
	function resetExpression()
		lock_color=false
		expruvm:setUV(current_expression)
		setColor()
	end

	function hurt()
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

	wheel[1]=action_wheel:createPage()

	action_wheel:setPage(wheel[1])
	action_wheel.scroll=wheelScroll
end



wheel[1]:newAction():title('test expression'):onLeftClick(function() ping.expressionTest() end)
function ping.expressionTest()
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
	local val=(expr==current_expression) and "neutral" or expr
	setExpression(val)
end


function ping.oof(health) -- This is a replacement for onDamage, that function doesn't sync for some reason
	hurt()
end

--- Toggle Armor ---
function setArmor(state)
	setState("armor_enabled", state)
	syncState()
end

do
	local snore_enabled=false
	local snore_index=1
	function snore()
		if snore_enabled then
			-- TODO
			-- sound.playCustomSound(SNORES[snore_index],
			-- 	player.getPos(), vectors.of{20,1})
			snore_index=snore_index%#SNORES+1
		end
	end

	function setSnoring(state)
		setState("snore_enabled", state)
		ping.setSnoring(skin_state.snore_enabled)
	end

	function ping.setSnoring(state)
		snore_enabled=state
	end
end

--- Toggle Vanilla ---
function setVanilla(state)
	setState("vanilla_enabled", state)
	syncState()
end


function ping.tPose()
	local_state.emote_vector=player:getPos()
	-- TODO
	-- animation.tpose.start()
end
-- }}}

-- Tail stuff {{{
function aquaticTailVisible()
	tail_cooldown=tail_cooldown or 0
	return local_state.aquatic_enabled and (player:isInWater() or player:isInLava()) or local_state.aquatic_override or tail_cooldown>0 end

function updateTailVisibility()
	local anim=player:getPose()
	local water=player:isInWater()
	local lava=player:isInLava()
	tail_cooldown=(tail_cooldown and tail_cooldown > 0) and tail_cooldown-1 or 0
	if aquaticTailVisible() and (anim=="SLEEPING" or anim=="SPIN_ATTACK" or anim=="FALL_FLYING" or water or lava) then
		tail_cooldown=anim=="SPIN_ATTACK" and 60 or (tail_cooldown >= 10 and tail_cooldown or 10)
	end
	if old_state.aquaticTailVisible ~= aquaticTailVisible() then pmRefresh() end
	old_state.aquaticTailVisible=aquaticTailVisible()
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
	tailuvm=UVManager:new(vec(0, 19), nil, positions)
end

-- TODO fix code after optimization in prewrite
function armor()
	if true then return nil end
	-- ^ hacky way to disable a function without uncommenting the entire thing to not break git vcs

	-- Get equipped armor, extract name from item ID
	local leggings_item = player.getEquipmentItem(4)
	local boots_item    = player.getEquipmentItem(3)
	local leggings     = string.sub(leggings_item.getType(), 11, -10)
	local boots        = string.sub(boots_item.getType(),    11, -7)

	if local_state.armor_enabled then
		if old_state.leggings ~= leggings or old_state.armor_enabled ~= local_state.armor_enabled  then
			-- leggings
			armor_glint.leggings=leggings_item.hasGlint()
			local leggings_color=colorArmor(leggings_item) or armor_color[leggings]
			local uv=tailuvm:getUV(leggings)
			if uv ~= nil then
				armor_state.leggings=true
				for k, v in pairs(TAIL_LEGGINGS) do
					v.setUV(uv)
				end
				if leggings=="leather" then
					for k, v in pairs(TAIL_LEGGINGS_COLOR) do
						v.setColor(leggings_color)
					end
				else
					for k, v in pairs(TAIL_LEGGINGS) do
						v.setColor({1, 1, 1})
					end
				end
			else
				armor_state.leggings=false
			end
			pmRefresh()
		end

		if old_state.boots ~= boots or old_state.armor_enabled ~= local_state.armor_enabled  then
			-- boots
			armor_glint.boots=boots_item.hasGlint()
			local boots_color=colorArmor(boots_item) or armor_color[boots]
			local uv_boots=tailuvm:getUV(boots)
			if uv_boots ~= nil then
				armor_state.boots=true
				for k, v in pairs(TAIL_BOOTS) do
					v.setUV(uv_boots)
				end
				if boots=="leather" then
					model.Body.MTail1.MTail2.MTail3.Boot.setColor(boots_color)
					armor_state.leather_boots=true
				else
					model.Body.MTail1.MTail2.MTail3.Boot.setColor({1, 1, 1})
					armor_state.leather_boots=false
				end
			else
				armor_state.boots=false
			end
			pmRefresh()
		end
	else
		armor_glint.leggings=false
		armor_glint.boots=false
	end

	if armor_glint.leggings then
		for _, v in pairs(TAIL_LEGGINGS) do
			v.setShader("Glint")
		end
	else
		for _, v in pairs(TAIL_LEGGINGS) do
			v.setShader("None")
		end
	end
	if armor_glint.boots then
		for _, v in pairs(TAIL_BOOTS) do
			v.setShader("Glint")
		end
	else
		for _, v in pairs(TAIL_BOOTS) do
			v.setShader("None")
		end
	end

	old_state.boots=boots
	old_state.leggings=leggings
	old_state.armor_enabled=local_state.armor_enabled
end

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

function animateMTail(val)
	local chest_rot = 3
	local per=2*math.pi
	model.Body:setRot(vec( wave(val, per, 3), 0, 0 ))
	-- TODO vanilla model manipulation broke, add chestplate model
	-- armor_model.CHESTPLATE:setRot(vec( -wave(val, per, math.rad(3)), 0, 0 ))
	-- this makes it work with partial vanilla
	-- vanilla_model.BODY:setRot(vec( -wave(val, per, math.rad(3)), 0, 0 ))
	-- vanilla_model.JACKET:setRot(vec( -wave(val, per, math.rad(3)), 0, 0 ))

	model.Body.LeggingsTopTrimF:setRot(vec( wave(val-1, per, 4), 0, 0 ))
	model.Body.LeggingsTopTrimB:setRot(vec( wave(val-1, per, 4), 0, 0 ))
	TAIL_BONES[1]:setRot(vec( wave(val-1, per, 7), 0, 0 ))
	TAIL_BONES[2]:setRot(vec( wave(val-2, per, 8), 0, 0 ))
	TAIL_BONES[3]:setRot(vec( wave(val-3, per, 12), 0, 0 ))
	TAIL_BONES[4]:setRot(vec( wave(val-4, per, 15), 0, 0 ))
end
tail_original_rot={}
for k, v in ipairs(REG_TAIL_BONES) do
	tail_original_rot[k]=v:getRot()
end
function animateTail(val)
	local per_y=20*4
	local per_x=20*6
	for k, v in ipairs(REG_TAIL_BONES) do
		local cascade=(k-1)*12
		REG_TAIL_BONES[k]:setRot(vec( tail_original_rot[k].x + wave(val-cascade, per_x, 3), wave(val-cascade, per_y, 12), tail_original_rot[k].z ))
	end
end

anim_tick=0
anim_cycle=0
old_state.anim_cycle=0

function animateTick()
	anim_tick = anim_tick + 1
	if aquaticTailVisible() then
		local velocity = player:getVelocity()

		if aquaticTailVisible() then
			old_state.anim_cycle=anim_cycle
			local player_speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
			local animation=player:getPose()
			local factor=(not player:isInWater() and (animation=="FALL_FLYING" or animation=="SPIN_ATTACK")) and 0.5 or 5
			anim_cycle=anim_cycle + (player_speed*factor+0.75)
			-- bubble animation would go here but i don't have that (yet)
		end

	else
		old_state.anim_cycle=anim_cycle
		anim_cycle=anim_cycle+1
	end
end



-- }}}

-- initialize values -- {{{
function player_init()
	local_state.health=player:getHealth()
	old_state.health=local_state.health
	-- TODO possibly reconsider if this should be redone
	-- actually it's probably fine, it's jsut here because i forget visibility settings
	local all_parts=recurseModelGroup(model)

	for k, v in pairs(all_parts) do
		v:setVisible(nil)
	end
	setLocalState()
	pmRefresh()
	syncState()
	events.ENTITY_INIT:remove("player_init")
end

events.ENTITY_INIT:register(function() return player_init() end, "player_init")

-- Initial configuration --
-- TODO x2 fix below, this entire block may not be needed with PartsManager
if avatar.canEditVanillaModel then
	vanilla_model.PLAYER:setVisible(false)
else
	model:setVisible(false)
end
anim_tick=0
-- }}}

-- Tick function -- {{{
function hostTick()
	local_state.health=player:getHealth()
	if local_state.health ~= old_state.health then
		if local_state.health < old_state.health then
			ping.oof(local_state.health)
		end
		syncState()
	end
end

function tick()
	color_check=player:isInLava() ~= (player:getDimensionName()=="minecraft:the_nether")
	if old_state.color_check~=color_check then
		setColor()
	end
	-- optimization, only execute these once a second --
	if world.getTimeOfDay() % 20 == 0 then

		if player:getPose() == "SLEEPING" then
			if cooldown(20*4, "snore") then
				snore()
			end
		end

		-- Sync state every 10 seconds
		if world.getTimeOfDay() % (20*10) == 0 then
			syncState()
		end
	end

	hostTick()

	-- TODO
	-- if animation.tpose.isPlaying() and local_state.emote_vector.distanceTo(player.getPos()) >= 0.5 then
	-- 	animation.tpose.stop()
	-- end


	-- Refresh tail armor state
	armor()
	-- Implements tail cooldown conditions
	updateTailVisibility()

	-- Animation code resides in this function
	animateTick()

	-- Check for queued PartsManager refresh
	doPmRefresh()
	-- End of tick --
	old_state.health=player:getHealth()
	old_state.color_check=color_check
	local_state.anim=player:getPose()
end
events.TICK:register(function() if player then tick() end end, "main_tick")
-- }}}

-- Render function {{{
function render(delta)
	if aquaticTailVisible() then
		animateMTail((lerp(old_state.anim_cycle, anim_cycle, delta) * 0.2))
	else
		resetAngles(model.Body)
		-- resetAngles(vanilla_model.BODY)
		-- resetAngles(vanilla_model.JACKET)
		-- resetAngles(armor_model.CHESTPLATE)
		animateTail((lerp(old_state.anim_cycle, anim_cycle, delta)))
	end
end
-- TODO this may break animation during death
events.RENDER:register(function(delta) if player then render(delta) end end, "main_render")
-- }}}
