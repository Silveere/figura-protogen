--- Initial definitions ---
-- Texture dimensions --
size = 128
factor = size / 64
-- Values for UV mappings --
face_damage=0
face_expr=0
step_u_face=32
step_v_face=16
offset_u_face=64
offset_v_face=0
armor_enabled=true
vanilla_enabled=true

-- initialize values --
function player_init()
	old_health=player.getHealth()
end
expr_cooldown=0

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

-- Expression change --
function getExprUV(damage, expression)
	local u=offset_u_face+(damage*step_u_face)
	local v=offset_v_face+(expression*step_v_face)
	return {u/size,v/size}
end
function changeExpression(_damage, _expression, ticks)
	-- u is damage, v is expression
	local damage = _damage
	local expression = _expression
	if damage == nil then
		damage = face_damage
	end
	if expression == nil then
		expression = face_expr
	end

	HEAD.setUV(getExprUV(damage,expression))
	expr_cooldown=ticks
end
function setExpression(damage, expression)
	face_damage=damage
	face_expr=expression
	HEAD.setUV(getExprUV(damage, expression))
end
function resetExpression()
	HEAD.setUV(getExprUV(face_damage,face_expr))
end

function setVanilla(state)

end

-- Initial configuration --
for key, value in pairs(vanilla_model) do
    value.setEnabled(false)
end
vanilla_model.CAPE.setEnabled(true)

-- Action Wheel --
action_wheel.SLOT_1.setTitle('test expression')
action_wheel.SLOT_1.setFunction(function() ping.expressionTest() end)
function ping.expressionTest()
	setExpression(1,0)
	changeExpression(nil, 1, 10)
end
action_wheel.SLOT_2.setTitle('log health')
action_wheel.SLOT_2.setFunction(function() print(player.getHealth()) end)
action_wheel.SLOT_3.setTitle('Toggle Armor')
action_wheel.SLOT_3.setFunction(function() ping.setArmor() end)

-- Pings --
--- Damage function --
function ping.oof(health)
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
function ping.setArmor(enabled)
	if enabled == nil then
		armor_enabled=not armor_enabled
	else
		armor_enabled=enabled
	end

	for key, value in pairs(armor_model) do
		value.setEnabled(armor_enabled)
	end
end

--- Toggle Vanilla ---
function ping.setVanilla(state)
	if state == nil then
		vanilla_enabled=not vanilla_enabled
	else
		vanilla_enabled=state
	end
end



-- does not work on multiplayer, use ping.oof()
function onDamage(amount, source)
end

-- Tick function --
function tick()
	-- expression reset spaghetti code --
	if expr_cooldown > 0 then
		expr_cooldown = expr_cooldown-1
		if expr_cooldown <= 0 then
			resetExpression()
		end
	end

	-- optimization, only execute these once a second --
	if world.getTimeOfDay() % 20 then
		-- if face is cracked
		if face_damage==1 and player.getHealth() > 5 then
			ping.healed()
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
	if input == chat_prefix .. "vanilla" then
		ping.setVanilla()
		print("Toggled vanilla skin")
	end
	if input == chat_prefix .. "toggle_custom" then
		for key, value in pairs(model) do
			value.setEnabled(not value.getEnabled())
		end
	end
	if input == chat_prefix .. "toggle_outer" then
		for k, v in pairs(VANILLA_OUTER) do
			v.setEnabled(not v.getEnabled())
		end
	end
	if input == chat_prefix .. "toggle_inner" then
		for k, v in pairs(VANILLA_INNER) do
			v.setEnabled(not v.getEnabled())
		end
	end
end

