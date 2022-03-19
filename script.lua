-- vim: set foldmethod=marker :
--- Initial definitions ---
-- Texture dimensions --
TEXTURE_WIDTH = 128
TEXTURE_HEIGHT = 128

-- local state variables (do not access within pings) --
armor_enabled=data.load("armor_enabled")
if armor_enabled==nil then
	armor_enabled=true
else
	armor_enabled=armor_enabled=="true"
end
vanilla_enabled=data.load("vanilla_enabled")
if vanilla_enabled==nil then
	vanilla_enabled=false
else
	vanilla_enabled=vanilla_enabled=="true"
end

-- utility functions -- {{{
--- dump table --
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

function UV(uv)
	return vectors.of({
	uv[1]/TEXTURE_WIDTH,
	uv[2]/TEXTURE_HEIGHT
	})
end


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
-- }}}


-- Parts --
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
	if state == nil then
		armor_enabled=not armor_enabled
	else
		armor_enabled=state
	end
	data.save("armor_enabled", armor_enabled)
	ping.setArmor(armor_enabled)
end
function ping.setArmor(state)
	for key, value in pairs(armor_model) do
		value.setEnabled(state)
	end
end
-- }}}

function syncState()
	ping.setArmor(armor_enabled)
	ping.setVanilla(vanilla_enabled)
end

--- Toggle Vanilla ---
function setVanilla(state)
	if state == nil then
		vanilla_enabled=not vanilla_enabled
	else
		vanilla_enabled=state
	end
	data.save("vanilla_enabled", vanilla_enabled)
	ping.setVanilla(vanilla_enabled)
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

-- }}}



-- initialize values --
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


-- Tick function --
function tick()
	-- optimization, only execute these once a second --
	if world.getTimeOfDay() % 20 == 0 then
		-- if face is cracked
		if expr_current.damage==1 and player.getHealth() > 5 then
			ping.healed()
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

-- Enable commands --
chat_prefix="./"
chat.setFiguraCommandPrefix(chat_prefix)
function onCommand(input)
	input=splitstring(input)
	if input[1] == chat_prefix .. "vanilla" then
		setVanilla()
		print("Toggled vanilla skin")
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
end

