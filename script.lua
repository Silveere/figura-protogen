-- vim: set foldmethod=marker :
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
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dumpTable(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
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

--- Unordered reduction, only use when working with dictionaries and
--- execution order does not matter
---@param tbl table Table to reduce
---@param func function Function used to reduce table
---@param init any Initial operand for reduce function
function reduce(tbl, func, init)
	local result = init
	local first_loop = true
	for _, v in pairs(table) do
		if first_loop and init ~= nil then
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
function ireduce(tbl, func, init)
	local result = init
	local first_loop = true
	for _, v in ipairs(table) do
		if first_loop and init ~= nil then
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

-- }}}

-- master state variables and configuration (do not access within pings) -- {{{
do
	local defaults={
		["armor_enabled"]=true,
		["vanilla_enabled"]=false,
		["snore_enabled"]=true,
		["print_settings"]=false
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
-- }}}


-- Parts, groups -- {{{
HEAD=model.Head.Head
VANILLA_OUTER={ vanilla_model.HAT, vanilla_model.JACKET, vanilla_model.LEFT_SLEEVE, vanilla_model.RIGHT_SLEEVE, vanilla_model.LEFT_PANTS_LEG, vanilla_model.RIGHT_PANTS_LEG }
VANILLA_INNER={
    vanilla_model.HEAD,
    vanilla_model.TORSO,
    vanilla_model.LEFT_ARM,
    vanilla_model.RIGHT_ARM,
    vanilla_model.LEFT_LEG,
    vanilla_model.RIGHT_LEG
}
VANILLA_ALL={}
for _, v in pairs(VANILLA_INNER) do table.insert(VANILLA_ALL,v) end
for _, v in pairs(VANILLA_OUTER) do table.insert(VANILLA_ALL,v) end

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
	ping.setArmor(skin_state.armor_enabled)
end
function ping.setArmor(state)
	for key, value in pairs(armor_model) do
		value.setEnabled(state)
	end
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
	ping.setVanilla(skin_state.vanilla_enabled)
end

function ping.setVanilla(state)
	if not meta.getCanModifyVanilla() then return end
	for _, v in pairs(VANILLA_ALL) do
		v.setEnabled(state)
	end
	for _, v in pairs(model) do
		v.setEnabled(not state)
	end
end

function syncState()
	ping.setArmor(skin_state.armor_enabled)
	ping.setVanilla(skin_state.vanilla_enabled)
	ping.setSnoring(skin_state.snore_enabled)
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
	old_health=player.getHealth()
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
	if old_health>player.getHealth() then
		-- debug
		-- print(string.format('old_health=%03.2f, player.getHealth=%03.2f', old_health,player.getHealth()))
		ping.oof(player.getHealth())
	end

	-- End of tick --
	old_health=player.getHealth()
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
		for k, v in pairs(VANILLA_OUTER) do
			v.setEnabled(not v.getEnabled())
		end
	end
	if input[1] == chat_prefix .. "toggle_inner" then
		for k, v in pairs(VANILLA_INNER) do
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
			else
				log(tostring(input[2]) .. ": no such setting")
			end
		end
	end
end
--}}}
