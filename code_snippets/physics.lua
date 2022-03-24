--by Bonk#2965
lastDegree = 0
function newPhysics(part, crouchTog, amp, onHead)
	local lerpAmount = 0.96
	local onHeadd = onHead or false
	local crouchToggle = crouchTog or false
	local parte = part
	local weightReduc = amp or 1
	--set initial amount
	local degree = lerp((playerSpeed() *-100),lastDegree,lerpAmount)
	lastDegree = degree
	--remove head rotation
	if onHeadd then
		degree = degree + getHeadRot()[1]
	end

	--add crouch rotation
	if crouchToggle then
		if player.isSneaky() then
			degree = degree - 30
		end
	end

	--amplify
	degree = degree * weightReduc

	--whole number-ify
	degree = math.floor(degree+0.5)

	--set it
	parte.setRot({degree,0,0})
end

--assists to the physics
function lerp(a, b, t) -- smoothing
	return a + (b - a) * t
end

function getHeadRot() -- Gets the rotation of the player's head
	local x = vanilla_model.HEAD.getOriginRot()
	x = {x[1]*(180/math.pi),x[2]*(180/math.pi),0}
	return x
end

playerVelocity = 0
function player_init()
	pos = player.getPos()
	_pos = pos
	playerVelocity = vectors.of({0})
end
function tick()
	_pos = pos
	pos = player.getPos()
	playerVelocity = pos - _pos
end
function playerSpeed() -- returns the player's horizontal speed, positive if moving forwards, negative if backwards
	return (vectors.of({1, 0, 1})*playerVelocity).getLength()*(movingForwards() and 1 or -1)
end

function movingForwards() -- returns a bool, true if moving forwards, false if moving backwards or stationary
	local bodyDir = vectors.of({math.sin(math.rad(-player.getBodyYaw())), 0, math.cos(math.rad(-player.getBodyYaw()))}) -- a unit vector pointing the same way as the body
	local dotProduct = playerVelocity.z*bodyDir.z + playerVelocity.x*bodyDir.x -- the dot product of the velocity vector and a vector pointing the same way as the body
	return dotProduct > 0
end
