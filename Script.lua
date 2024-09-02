-- Created by @ScriptBreakpoint
-- Feel free to use this, crediting me is optional but definitely appreciated

local waterModel = script.Parent:WaitForChild("Plane")
local floatingParts = workspace:WaitForChild("FloatingParts"):GetChildren()
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local players = game:GetService("Players")
local hitbox = workspace:WaitForChild("Hitbox")

if not hitbox then
	error("Hitbox is not in workspace according to me")
end

local waveAmplitude = 20
local waveFrequency = 10
local waveSpeed = 1.5
local waveLength = 10
local direction = Vector2.new(1, 0).Unit

-- Physics
local gravity = Vector3.new(0, -392.4, 0)
local buoyancyDensity = 100
local waveHeightClamp = 90
local dampingFactor = 0.1
local dragCoefficient = 0.6
local rotationalDamping = 0.3
local waterViscosity = 0.5

local velocities = {}
local angularVelocities = {}

local bones = {}
local originalPositions = {}

for _, bone in pairs(waterModel:GetChildren()) do
	if bone:IsA("Bone") then
		table.insert(bones, bone)
		originalPositions[bone] = bone.Position
	end
end

local function getWaveHeight(x, z, time)
	local waveOffset = (x * direction.X + z * direction.Y) / waveLength
	local sineWaveValue = math.sin(waveOffset + time * waveSpeed) * waveAmplitude
	local waveHeight = math.clamp(sineWaveValue, -waveAmplitude, waveAmplitude)

	return waveHeight
end


local function getWaveNormal(x, z, time)
	local delta = 0.1

	local heightL = getWaveHeight(x - delta, z, time)
	local heightR = getWaveHeight(x + delta, z, time)
	local heightD = getWaveHeight(x, z - delta, time)
	local heightU = getWaveHeight(x, z + delta, time)

	local normal = Vector3.new(heightL - heightR, 2 * delta, heightD - heightU).Unit
	return normal
end

local function calculateBuoyancy(part, waveHeight)
	local partVolume = part.Size.X * part.Size.Y * part.Size.Z
	local submergedHeight = math.clamp(waveHeight - (part.Position.Y - part.Size.Y / 2), 0, part.Size.Y)
	local submergedVolume = submergedHeight * part.Size.X * part.Size.Z
	local buoyantForce = submergedVolume * buoyancyDensity * Vector3.new(0, 1, 0)
	return buoyantForce
end

local function calculateDrag(part)
	local velocity = velocities[part] or Vector3.new(0, 0, 0)
	local dragForce = -dragCoefficient * velocity * velocity.Magnitude
	return dragForce
end

local function calculateRotationalDrag(part)
	local angularVelocity = angularVelocities[part] or Vector3.new(0, 0, 0)
	local rotationalDrag = -rotationalDamping * angularVelocity * angularVelocity.Magnitude
	return rotationalDrag
end

local function applyForcesAndRotation(part, time)
	local position = part.Position
	local waveHeight = getWaveHeight(position.X, position.Z, time)

	if not velocities[part] then
		velocities[part] = Vector3.new(0, 0, 0)
	end

	if not angularVelocities[part] then
		angularVelocities[part] = Vector3.new(0, 0, 0)
	end

	local gravitationalForce = gravity * part.AssemblyMass
	local buoyantForce = calculateBuoyancy(part, waveHeight)
	local dragForce = calculateDrag(part)
	local rotationalDrag = calculateRotationalDrag(part)

	local netForce = gravitationalForce + buoyantForce + dragForce
	velocities[part] = velocities[part] + (netForce / part.AssemblyMass + waterViscosity) * runService.Heartbeat:Wait()

	position = position + velocities[part] * runService.Heartbeat:Wait()
	if position.Y <= waveHeight then
		velocities[part] = velocities[part] + buoyantForce / part.AssemblyMass * runService.Heartbeat:Wait()
	end

	local waveNormal = getWaveNormal(position.X, position.Z, time)
	local currentUp = part.CFrame.UpVector
	local currentForward = part.CFrame.LookVector
	local newUp = currentUp:Lerp(waveNormal, dampingFactor).Unit
	local newRight = currentForward:Cross(newUp).Unit
	local newForward = newRight:Cross(newUp).Unit
	angularVelocities[part] = angularVelocities[part] + rotationalDrag * runService.Heartbeat:Wait()
	local targetCFrame = CFrame.fromMatrix(position, newRight, newUp, newForward)

	local tweenInfo = TweenInfo.new(dampingFactor * 4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = tweenService:Create(part, tweenInfo, {CFrame = targetCFrame})
	tween:Play()
end

local function moveAnchoredPart(part, time)
	local position = part.Position
	local waveHeight = getWaveHeight(position.X, position.Z, time)
	local newPosition = Vector3.new(position.X, waveHeight, position.Z)
	local waveNormal = getWaveNormal(position.X, position.Z, time)
	local currentUp = part.CFrame.UpVector
	local currentForward = part.CFrame.LookVector

	local newUp = currentUp:Lerp(waveNormal, dampingFactor).Unit
	local newRight = currentForward:Cross(newUp).Unit
	local newForward = newRight:Cross(newUp).Unit

	local targetCFrame = CFrame.fromMatrix(newPosition, newRight, newUp, newForward)

	local tweenInfo = TweenInfo.new(dampingFactor * 4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = tweenService:Create(part, tweenInfo, {CFrame = targetCFrame})
	tween:Play()
end

local function animateWater(time)
	for _, bone in pairs(bones) do
		local originalPosition = originalPositions[bone]
		local waveHeight = getWaveHeight(originalPosition.X, originalPosition.Z, time)

		bone.Position = originalPosition + Vector3.new(0, waveHeight, 0)
	end
end
-- Debugging
local debugEnabled = true
local debugVisuals = true

local function debugPrint(...)
	if debugEnabled then
		print(...)
	end
end

local function createDebugVisual(position)
	if debugVisuals then
		local part = Instance.new("Part")
		part.Size = Vector3.new(1, 1, 1)
		part.Shape = Enum.PartType.Ball
		part.Color = Color3.new(1, 0, 0) 
		part.Position = position
		part.Anchored = true
		part.CanCollide = false
		part.Parent = workspace
		game.Debris:AddItem(part, 0.1)
	end
end


local function isInsideHitbox(position, hitbox)
	local hitboxSize = hitbox.Size / 2
	local hitboxPosition = hitbox.Position

	local minX, maxX = hitboxPosition.X - hitboxSize.X, hitboxPosition.X + hitboxSize.X
	local minY, maxY = hitboxPosition.Y - hitboxSize.Y, hitboxPosition.Y + hitboxSize.Y
	local minZ, maxZ = hitboxPosition.Z - hitboxSize.Z, hitboxPosition.Z + hitboxSize.Z

	return position.X >= minX and position.X <= maxX
		and position.Y >= minY and position.Y <= maxY
		and position.Z >= minZ and position.Z <= maxZ
end

local function syncPlayerWithWater(player)
	local character = player.Character
	if character then
		local humanoid = character:WaitForChild("Humanoid")
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

		if humanoid and humanoidRootPart then
			-- vertical buoyancy
			local bodyPosition = humanoidRootPart:FindFirstChild("WaterFloatPosition") or Instance.new("BodyPosition")
			bodyPosition.Name = "WaterFloatPosition"
			bodyPosition.MaxForce = Vector3.new(0, math.huge, 0)
			bodyPosition.P = 10000 
			bodyPosition.D = 700  --damping
			bodyPosition.Parent = humanoidRootPart

			-- angular control
			local bodyGyro = humanoidRootPart:FindFirstChild("WaterFloatGyro") or Instance.new("BodyGyro")
			bodyGyro.Name = "WaterFloatGyro"
			bodyGyro.MaxTorque = Vector3.new(5000, 5000, 5000)  
			bodyGyro.P = 50000  
			bodyGyro.D = 100 
			bodyGyro.CFrame = humanoidRootPart.CFrame
			bodyGyro.Parent = humanoidRootPart

			local bodyVelocity = humanoidRootPart:FindFirstChild("WaterSwimVelocity") or Instance.new("BodyVelocity")
			bodyVelocity.Name = "WaterSwimVelocity"
			bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
			bodyVelocity.Velocity = Vector3.new(0, 0, 0)
			bodyVelocity.Parent = humanoidRootPart

			local floatingEnabled = false

			runService.Heartbeat:Connect(function(deltaTime)
				local consistentTime = tick() * waveSpeed
				local currentPos = humanoidRootPart.Position

				local insideHitbox = isInsideHitbox(currentPos, hitbox)

				if insideHitbox then
					if not floatingEnabled then
						-- re enable floating when entering the hitbox
						bodyPosition.MaxForce = Vector3.new(0, math.huge, 0)
						bodyGyro.MaxTorque = Vector3.new(5000, 5000, 5000)
						bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
						floatingEnabled = true
					end

					local waveHeight = getWaveHeight(currentPos.X, currentPos.Z, consistentTime)
					local waveNormal = getWaveNormal(currentPos.X, currentPos.Z, consistentTime)
					bodyPosition.Position = Vector3.new(currentPos.X, waveHeight - 3, currentPos.Z)  -- OFFSET

					-- tilt player
					local currentUp = humanoidRootPart.CFrame.UpVector
					local currentRight = humanoidRootPart.CFrame.RightVector
					local newUp = waveNormal.Unit
					local newRight = currentRight:Cross(newUp).Unit
					local newForward = newRight:Cross(newUp).Unit

					bodyGyro.CFrame = CFrame.fromMatrix(humanoidRootPart.Position, newRight, newUp, newForward)

					local moveDirection = humanoid.MoveDirection
					bodyVelocity.Velocity = moveDirection * 8
				else
					if floatingEnabled then
						-- disable the forces when youre outside the hitbox
						bodyPosition.MaxForce = Vector3.new(0, 0, 0) 
						bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
						bodyVelocity.MaxForce = Vector3.new(0, 0, 0)
						floatingEnabled = false
					end
				end
			end)
		else
			warn("Humanoid or HumanoidRootPart doesn't exist")
		end
	end
end

-- floating parts and water animation
runService.Stepped:Connect(function(time, deltaTime)
	local consistentTime = tick() * waveSpeed

	animateWater(consistentTime)
	for _, part in pairs(floatingParts) do
		if part:IsA("BasePart") then
			if part.Anchored then
				moveAnchoredPart(part, consistentTime)
			else
				applyForcesAndRotation(part, consistentTime)
			end
		end
	end
end)

-- player synchronization
players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		syncPlayerWithWater(player)
	end)
end)
