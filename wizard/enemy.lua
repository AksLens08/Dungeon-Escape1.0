-- simple_enemy.lua
local Class = require("system.class")
local SimpleEnemy = Class.define()

local wizardTextures

local function loadWizardTextures()
    if wizardTextures then return wizardTextures end

    local function loadImage(path)
        if love.filesystem.getInfo(path) then
            return love.graphics.newImage(path)
        end
        return nil
    end

    wizardTextures = {
        idle = loadImage("wizard/Idle.png"),
        walk = loadImage("wizard/Walk.png")
    }

    return wizardTextures
end

function SimpleEnemy:init(x, y)
    self.x = x
    self.y = y
    self.w = 18
    self.h = 28
    self.speed = 40
    self.state = "idle"
    self.direction = "right"
    self.timer = 0
    self.frame = 0
    self.frameWidth = 128
    self.frameHeight = 128
    self.displayScale = 0.45
    self.animationFrames = { idle = 7, walk = 6 }
    self.animationSpeeds = { idle = 0.12, walk = 0.09 }
    self.textures = loadWizardTextures()
    self.texture = self.textures.idle
    self.quad = nil
    self:updateTexture()
end

function SimpleEnemy:updateTexture()
    self.texture = self.textures[self.state] or self.textures.idle

    if self.texture then
        local sw, sh = self.texture:getDimensions()
        local maxFrames = math.max(1, math.floor(sw / self.frameWidth))
        self.animationFrames[self.state] = maxFrames
        self.frame = self.frame % maxFrames
        self.quad = love.graphics.newQuad(self.frame * self.frameWidth, 0, self.frameWidth, self.frameHeight, sw, sh)
    end
end

function SimpleEnemy:update(dt, player)
    local moved = false

    if player.x > self.x then
        self.x = self.x + self.speed * dt
        self.direction = "right"
        moved = true
    end
    if player.x < self.x then
        self.x = self.x - self.speed * dt
        self.direction = "left"
        moved = true
    end
    if player.y > self.y then
        self.y = self.y + self.speed * dt
        moved = true
    end
    if player.y < self.y then
        self.y = self.y - self.speed * dt
        moved = true
    end

    local nextState = moved and "walk" or "idle"
    if nextState ~= self.state then
        self.state = nextState
        self.frame = 0
        self.timer = 0
        self:updateTexture()
    end

    self.timer = self.timer + dt
    local frameDuration = self.animationSpeeds[self.state] or 0.1
    if self.timer > frameDuration then
        self.timer = 0
        self.frame = (self.frame + 1) % (self.animationFrames[self.state] or 1)
        self:updateTexture()
    end
end

function SimpleEnemy:render()
    love.graphics.setColor(1, 1, 1)
    if self.texture and self.quad then
        local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
        local pivotX = self.x + self.w / 2
        local pivotY = self.y + self.h
        love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, scaleX, self.displayScale, 64, self.frameHeight)
    else
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    end
    love.graphics.setColor(1, 1, 1)
end

return SimpleEnemy