-- system/camera.lua
-- Heavy camera system with drag and breathing effects
local Camera = {}

local cameraTarget = { x = 0, y = 0 }
local cameraBreathTimer = 0
local cameraBreathIntensity = 0
local playerIsMoving = false
local lastPlayerX = 0
local lastPlayerY = 0

local camera = { x = 0, y = 0 }

function Camera:init(startX, startY)
    camera.x = startX
    camera.y = startY
    cameraTarget.x = startX
    cameraTarget.y = startY
    lastPlayerX = 0
    lastPlayerY = 0
    cameraBreathTimer = 0
    cameraBreathIntensity = 0
end

function Camera:update(dt, player)
    if not player then return end
    
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local worldScale = 3
    local px, py = player:getCenter()
    
    cameraTarget.x = (px * worldScale) - sw / 2
    cameraTarget.y = (py * worldScale) - sh / 2
    
    local moveThreshold = 2
    local dx = px - lastPlayerX
    local dy = py - lastPlayerY
    local dist = math.sqrt(dx*dx + dy*dy)
    playerIsMoving = dist > moveThreshold
    
    lastPlayerX = px
    lastPlayerY = py
    
    local followSpeed = playerIsMoving and 8 or 3
    
    camera.x = camera.x + (cameraTarget.x - camera.x) * followSpeed * dt
    camera.y = camera.y + (cameraTarget.y - camera.y) * followSpeed * dt
    
    if not playerIsMoving then
        cameraBreathTimer = cameraBreathTimer + dt * 0.5
        cameraBreathIntensity = math.min(cameraBreathIntensity + dt * 0.3, 1.5)
    else
        cameraBreathIntensity = math.max(cameraBreathIntensity - dt * 2, 0)
    end
    
    local breathOffsetX = math.sin(cameraBreathTimer) * cameraBreathIntensity * 2
    local breathOffsetY = math.cos(cameraBreathTimer * 0.7) * cameraBreathIntensity * 1.5
    
    camera.x = camera.x + breathOffsetX
    camera.y = camera.y + breathOffsetY
end

function Camera:getPosition()
    return camera.x, camera.y
end

return Camera