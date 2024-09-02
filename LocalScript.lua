-- Created by @ScriptBreakpoint
-- Feel free to use this, crediting me is optional but definitely appreciated

local lighting = game:GetService("Lighting")
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local splashPartTemplate = ReplicatedStorage:WaitForChild("Splash")
local hitbox = workspace:WaitForChild("Hitbox") 

local CameraShaker = require(ReplicatedStorage:WaitForChild("CameraShaker"))

local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
	camera.CFrame = camera.CFrame * shakeCFrame
end)
camShake:Start()

local waveAmplitude = 10
local waveFrequency = 10
local waveSpeed = 1.5
local waveLength = 10
local direction = Vector2.new(1, 0).Unit -- direction of the waves

local colorCorrection = lighting:FindFirstChild("ColorCorrection") or Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "ColorCorrection"
colorCorrection.Parent = lighting

local blurEffect = lighting:FindFirstChild("Blur") or Instance.new("BlurEffect")
blurEffect.Name = "Blur"
blurEffect.Parent = lighting

local Rain = workspace:FindFirstChild("Rain") or workspace.Sound
local Hum = workspace:FindFirstChild("Hum") or workspace.Hum

colorCorrection.TintColor = Color3.new(0.929412, 0.984314, 1)  -- Neutral color
colorCorrection.Contrast = 1
blurEffect.Size = 0  

local fastTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local smoothTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function getWaveHeight(x, z, time)
	local waveOffset = (x * direction.X + z * direction.Y) / waveLength
	local sineWaveValue = math.sin(waveOffset + time * waveSpeed) * waveAmplitude
	local waveHeight = math.clamp(sineWaveValue, -waveAmplitude, waveAmplitude)
	return waveHeight
end

local splashCooldown = false
local splashActive = false
local splashClone
local effectsActive = false

local function updateSplashEffect(position, waveHeight)
	if splashActive and splashClone then
		splashClone.Position = Vector3.new(position.X, waveHeight, position.Z)
	else
		if splashCooldown then return end
		splashCooldown = true
		splashActive = true

		splashClone = splashPartTemplate:Clone()
		splashClone.Position = Vector3.new(position.X, waveHeight, position.Z)
		splashClone.Parent = workspace

		local splashEffect = splashClone:FindFirstChildOfClass("ParticleEmitter")
		local splashSound = splashClone:FindFirstChildOfClass("Sound")

		if splashEffect then
			splashEffect:Emit(1)
			task.wait(0.55)
			splashEffect.Enabled = false
		end

		if splashSound then
			splashSound:Play()
		end

		task.delay(1, function()
			splashCooldown = false
		end)

		task.delay(2, function()
			if splashClone then
				splashClone:Destroy()
			end
			splashActive = false
		end)
	end
end

local function playEffects()
	local tintTween = tweenService:Create(colorCorrection, fastTweenInfo, {
		TintColor = Color3.fromRGB(100, 150, 255), -- somewhat strong blueish
		Contrast = 2
	})
	local blurTween = tweenService:Create(blurEffect, fastTweenInfo, { Size = 15 })
	tintTween:Play()
	blurTween:Play()

	Rain.Playing = false
	Hum.Playing = true

	camShake:Shake(CameraShaker.Presets.Bump)
end

local function stopEffects()
	local tintTween = tweenService:Create(colorCorrection, fastTweenInfo, {
		TintColor = Color3.new(1, 1, 1), -- normal color
		Contrast = 1
	})
	local blurTween = tweenService:Create(blurEffect, fastTweenInfo, { Size = 0 })
	tintTween:Play()
	blurTween:Play()

	Rain.Playing = true
	Hum.Playing = false
end

local function updateScreenEffects(cameraHeight, waveHeight)
	task.spawn(function()
		if cameraHeight < waveHeight then
			if not effectsActive then
				playEffects()
				effectsActive = true
			end
		else
			if effectsActive then
				stopEffects()
				effectsActive = false
			end
		end

		local heightDifference = cameraHeight - waveHeight
		if heightDifference >= 0 and math.abs(heightDifference) < 1 then
			local character = player.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local splashPosition = Vector3.new(rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z)
					updateSplashEffect(splashPosition, waveHeight)
				end
			end
		end
	end)
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

runService.Heartbeat:Connect(function()
	task.spawn(function()
		local consistentTime = tick() * waveSpeed
		local cameraPosition = camera.CFrame.Position
		local waveHeight = getWaveHeight(cameraPosition.X, cameraPosition.Z, consistentTime)

		local insideHitbox = isInsideHitbox(cameraPosition, hitbox)
		if insideHitbox then
			updateScreenEffects(cameraPosition.Y, waveHeight)
		elseif effectsActive then
			stopEffects()
			effectsActive = false
		end

		if splashActive and splashClone then
			local character = player.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local splashPosition = Vector3.new(rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z)
					splashClone.Position = Vector3.new(splashPosition.X, waveHeight, splashPosition.Z)
				end
			end
		end
	end)
end)
