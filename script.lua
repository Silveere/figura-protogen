-- vim: set foldmethod=marker ts=4 sw=4 :
--- Initial definitions ---
-- Texture dimensions --
TEXTURE_WIDTH = 128
TEXTURE_HEIGHT = 128

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


---@param uv table
function UV(uv)
	return vectors.of({
	uv[1]/TEXTURE_WIDTH,
	uv[2]/TEXTURE_HEIGHT
	})
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
	if group.getType()=="GROUP" then
		for k, v in pairs(group.getChildren()) do
			for _, v2 in pairs(recurseModelGroup(v)) do
				table.insert(t, v2)
			end
		end
	end
	return t
end
-- }}}

-- master state variables and configuration (do not access within pings) -- {{{
do
	local defaults={
		["armor_enabled"]=true,
		["vanilla_enabled"]=false,
		["snore_enabled"]=true,
		["print_settings"]=false,
		["vanilla_partial"]=false,
		["aquatic_enabled"]=false
	}

	skin_state=mergeTable(
		map(unstring,data.loadAll()),
		defaults)
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
	data.save(name, skin_state[name])
end

-- Local State (these are copied by pings at runtime) --
local_state={}
-- }}}

-- PartsManager -- {{{
do
	PartsManager={}
	local pm={}

	--- ensure part is initialized
	local function initPart(part)
		local part_key=tostring(part)
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
		local part_key=tostring(part)
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
		local part_key=tostring(part)
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
		local part_key=tostring(part)
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
		part.setEnabled(part_enabled)
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

-- Parts, groups -- {{{
HEAD=model.Head.Head
VANILLA_PARTIAL={}
VANILLA_GROUPS={
	["HEAD"]={vanilla_model.HEAD, vanilla_model.HAT},
	["TORSO"]={vanilla_model.TORSO, vanilla_model.JACKET},
	["LEFT_ARM"]={vanilla_model.LEFT_ARM, vanilla_model.LEFT_SLEEVE},
	["RIGHT_ARM"]={vanilla_model.RIGHT_ARM, vanilla_model.RIGHT_SLEEVE},
	["LEFT_LEG"]={vanilla_model.LEFT_LEG, vanilla_model.LEFT_PANTS_LEG},
	["RIGHT_LEG"]={vanilla_model.RIGHT_LEG, vanilla_model.RIGHT_PANTS_LEG},
	["OUTER"]={ vanilla_model.HAT, vanilla_model.JACKET, vanilla_model.LEFT_SLEEVE, vanilla_model.RIGHT_SLEEVE, vanilla_model.LEFT_PANTS_LEG, vanilla_model.RIGHT_PANTS_LEG },
	["INNER"]={ vanilla_model.HEAD, vanilla_model.TORSO, vanilla_model.LEFT_ARM, vanilla_model.RIGHT_ARM, vanilla_model.LEFT_LEG, vanilla_model.RIGHT_LEG },
	["ALL"]={},
	["ARMOR"]={}
}

for _, v in pairs(VANILLA_GROUPS.INNER) do table.insert(VANILLA_GROUPS.ALL,v) end
for _, v in pairs(VANILLA_GROUPS.OUTER) do table.insert(VANILLA_GROUPS.ALL,v) end
for _, v in pairs(armor_model) do table.insert(VANILLA_GROUPS.ARMOR, v) end

CUSTOM_GROUPS={} -- RightArm LeftArm RightLeg LeftLeg Body Head
for _, v in pairs(model) do table.insert(CUSTOM_GROUPS, v) end

-- }}}


--  PartsManager rules {{{
-- Vanilla rules

do
	local function aquaticTailVisible()
		return local_state.aquatic_enabled and player.isUnderwater() end

	local function vanillaPartial()
		if local_state.vanilla_enabled then
			return false
		end
		return local_state.vanilla_partial
	end

	-- eventually replace this with an instance once PartsManager becomes a class
	local PM=PartsManager


	--- Vanilla state
	-- Show all in vanilla partial
	PM.addPartGroupFunction(VANILLA_GROUPS.ALL, function() return
		vanillaPartial() end)
	-- no legs in water if tail enabled
	PM.addPartGroupFunction(VANILLA_GROUPS.LEFT_LEG, function(last) return last and not aquaticTailVisible() end)
	PM.addPartGroupFunction(VANILLA_GROUPS.RIGHT_LEG, function(last) return last and not aquaticTailVisible() end)
	-- no vanilla head in partial vanilla
	PM.addPartGroupFunction(VANILLA_GROUPS.HEAD, function(last)
		return last and not vanillaPartial() end)
	-- Always true if vanilla_enabled
	PM.addPartGroupFunction(VANILLA_GROUPS.ALL,
		function(last) return last or local_state.vanilla_enabled end)

	--- Armor state
	PM.addPartGroupFunction(VANILLA_GROUPS.ARMOR,
		function(last) return local_state.armor_enabled end)

	--- Custom state
	-- Disable model in vanilla partial
	PM.addPartGroupFunction(CUSTOM_GROUPS, function(last) return not vanillaPartial() end)
	-- no legs, regular tail in water if tail enabled
	local mtail_mutually_exclusive={model.LeftLeg, model.RightLeg, model.Body_Tail}
	PM.addPartGroupFunction(mtail_mutually_exclusive, function(last) return last and not aquaticTailVisible() end)

	-- Enable certain parts in vanilla partial
	local vanilla_partial_enabled={model.Head, model.Body_Tail}
	PM.addPartGroupFunction(vanilla_partial_enabled, function(last) return last or vanillaPartial() end)
	-- Disable when vanilla_enabled
	PM.addPartGroupFunction(CUSTOM_GROUPS, function(last) return last and not local_state.vanilla_enabled end)
end

SNORES={"snore-1", "snore-2", "snore-3"}
-- }}}

-- Expression change -- {{{
do
	-- Values for UV mappings --
	expr_current={damage=0, expression=0}
	local expr_step={u=32, v=16}
	local expr_offset={u=64, v=0}

	local function getExprUV(damage, expression)
		local u=expr_offset.u+(damage*expr_step.u)
		local v=expr_offset.v+(expression*expr_step.v)
		return UV{u, v}
	end
	function changeExpression(_damage, _expression, ticks)
		-- u is damage, v is expression
		local damage = _damage
		local expression = _expression
		if damage == nil then
			damage = expr_current.damage
		end
		if expression == nil then
			expression = expr_current.expression
		end

		HEAD.setUV(getExprUV(damage,expression))
		namedWait(ticks, resetExpression, "resetExpression")
	end
	function setExpression(damage, expression)
		expr_current.damage=damage
		expr_current.expression=expression
		HEAD.setUV(getExprUV(damage, expression))
	end
	function resetExpression()
		HEAD.setUV(getExprUV(expr_current.damage,expr_current.expression))
	end
end
-- }}}

-- Action Wheel & Pings -- {{{
action_wheel.SLOT_1.setTitle('test expression')
action_wheel.SLOT_1.setFunction(function() ping.expressionTest() end)
function ping.expressionTest()
	setExpression(1,0)
	changeExpression(nil, 1, 10)
end
action_wheel.SLOT_2.setTitle('log health')
action_wheel.SLOT_2.setFunction(function() print(player.getHealth()) end)
action_wheel.SLOT_3.setTitle('Toggle Armor')
action_wheel.SLOT_3.setFunction(function() setArmor() end)

-- Pings --
--- Damage function --
function ping.oof(health) -- This is a replacement for onDamage, that function doesn't sync for some reason
	if health <= 5 then
		setExpression(1,0)
	end
	changeExpression(nil,1,10)
end
--- Heal function (revert expression) --
function ping.healed(health)
	setExpression(0,0)
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
			sound.playCustomSound(SNORES[snore_index],
				player.getPos(), vectors.of{20,1})
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


function syncState()
	ping.setSnoring(skin_state.snore_enabled)
	ping.syncState(skin_state)
end

function ping.syncState(tbl)
	for k, v in pairs(tbl) do
		local_state[k]=v
	end
	PartsManager.refreshAll()
end
-- }}}

-- Timer (not mine lol) -- {{{
do
	local timers = {}
	function wait(ticks,next)
		table.insert(timers, {t=world.getTime()+ticks,n=next})
	end
	function tick()
		for key,timer in pairs(timers) do
			if world.getTime() >= timer.t then
				timer.n()
				table.remove(timers,key)
			end
		end
	end
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
	function tick()
		for key, timer in pairs(timers) do
			if world.getTime() >= timer.t then
				timer.n()
				timers[key]=nil
			end
		end
	end
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
	function tick()
		for key, timer in pairs(timers) do
			if world.getTime() >= timer.t then
				timers[key]=nil
			end
		end
	end
end

-- }}}



-- initialize values -- {{{
function player_init()
	old_state={}
	old_state.health=player.getHealth()
	syncState()
end
-- Initial configuration --
if meta.getCanModifyVanilla() then
	for key, value in pairs(vanilla_model) do
		value.setEnabled(false)
	end
else
	for _, v in pairs(model) do
		v.setEnabled(false)
	end
end
vanilla_model.CAPE.setEnabled(true)

-- }}}

-- Tick function -- {{{
function tick()
	-- optimization, only execute these once a second --
	if world.getTimeOfDay() % 20 == 0 then
		-- if face is cracked
		if expr_current.damage==1 and player.getHealth() > 5 then
			ping.healed()
		end

		if player.getAnimation() == "SLEEPING" then
			if cooldown(20*4, "snore") then
				snore()
			end
		end

		-- Sync state every 10 seconds
		if world.getTimeOfDay() % (20*10) == 0 then
			syncState()
		end
	end

	-- Damage ping (onDamage doesn't work in multiplayer) --
	if old_state.health>player.getHealth() then
		-- debug
		-- print(string.format('old_health=%03.2f, player.getHealth=%03.2f', old_health,player.getHealth()))
		ping.oof(player.getHealth())
	end
	

	if old_state.isUnderwater ~= player.isUnderwater() then syncState() end
	old_state.isUnderwater=player.isUnderwater()
	-- End of tick --
	old_state.health=player.getHealth()
end
-- }}}

-- Enable commands -- {{{
chat_prefix="$"
chat.setFiguraCommandPrefix(chat_prefix)
function onCommand(input)
	input=splitstring(input)
	if input[1] == chat_prefix .. "vanilla" then
		setVanilla()
		print("Vanilla skin is now " .. (skin_state.vanilla_enabled and "enabled" or "disabled"))
	end
	if input[1] == chat_prefix .. "toggle_custom" then
		for key, value in pairs(model) do
			value.setEnabled(not value.getEnabled())
		end
	end
	if input[1] == chat_prefix .. "toggle_outer" then
		for k, v in pairs(VANILLA_GROUPS.OUTER) do
			v.setEnabled(not v.getEnabled())
		end
	end
	if input[1] == chat_prefix .. "toggle_inner" then
		for k, v in pairs(VANILLA_GROUPS.INNER) do
			v.setEnabled(not v.getEnabled())
		end
	end
	if input[1] == chat_prefix .. "test_expression" then
		setExpression(input[2], input[3])
		print(input[2] .. " " .. input[3])
	end
	if input[1] == chat_prefix .. "snore" then
		if input[2] == "toggle" or #input==1 then
			setSnoring()
			log("Snoring is now " .. (skin_state.snore_enabled and "enabled" or "disabled"))
		end
	end
	if input[1] == chat_prefix .. "armor" then
		setArmor()
		log("Armor is now " .. (skin_state.armor_enabled and "enabled" or "disabled"))
	end
	if input[1] == chat_prefix .. "settings" then
		if #input==1 then
			printSettings()
		elseif #input==2 then
			log(tostring(skin_state[input[2]]))
		elseif #input==3 then
			if skin_state[input[2]] ~= nil then
				setState(input[2], unstring(input[3]))
				log(tostring(input[2]) .. " is now " .. tostring(skin_state[input[2]]))
				syncState()
			else
				log(tostring(input[2]) .. ": no such setting")
			end
		end
	end
	if input[1] == chat_prefix .. "pv" then
		setState("vanilla_partial")
		syncState()
	end
end
--}}}
