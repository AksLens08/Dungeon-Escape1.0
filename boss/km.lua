-- km.lua
-- Main boss entity (Killer Master) with custom AI and sprites
local Class = require("system.class")

local KM = Class.define()

KM.HITBOX_W = 15
KM.HITBOX_H = 22
-- Physics boundaries

local SPRITE_PATH_WALK  = "boss/KM_Walk.png"
local SPRITE_PATH_CHASE = "boss/KM_Chase.png"
local SPRITE_ROWS = 1
local SPRITE_COLUMNS = 4
local DEFAULT_ANIMATION_SPEED = 0.10
local TARGET_DRAW_HEIGHT = 60
local CROP_PADDING = 4

local ANIMATIONS = {
    idle   = { row = 0, frames = 4, speed = DEFAULT_ANIMATION_SPEED },
    walk   = { row = 0, frames = 4, speed = 0.18 },
    attack = { row = 0, frames = 4, speed = 0.10 },
    death  = { row = 0, frames = 4, speed = 0.20 }
}

local function loadTexture(path)
    -- Safe load
    if love.filesystem.getInfo(path) then
        return love.image.newImageData(path), love.graphics.newImage(path)
    end
    return nil, nil
end

local function findVisibleBounds(imageData, left, top, width, height)
    -- Alpha cropping
    local minX, minY = left + width, top + height
    local maxX, maxY = left, top
    local foundPixel = false
    for y = top, top + height - 1 do
        for x = left, left + width - 1 do
            local _, _, _, a = imageData:getPixel(x, y)
            if a > 0.05 then
                minX = math.min(minX, x)
                minY = math.min(minY, y)
                maxX = math.max(maxX, x)
                maxY = math.max(maxY, y)
                foundPixel = true
            end
        end
    end
    if not foundPixel then return left, top, width, height end
    minX = math.max(left, minX - CROP_PADDING)
    minY = math.max(top, minY - CROP_PADDING)
    maxX = math.min(left + width - 1, maxX + CROP_PADDING)
    maxY = math.min(top + height - 1, maxY + CROP_PADDING)
    return minX, minY, maxX - minX + 1, maxY - minY + 1
end

local function buildQuads(texture, imageData, frameWidth, frameHeight)
    -- Generate cropped quads
    local quads = {}
    local imageWidth, imageHeight = texture:getDimensions()
    local maxFrameHeight = 1
    for row = 0, SPRITE_ROWS - 1 do
        quads[row] = {}
        for column = 0, SPRITE_COLUMNS - 1 do
            local x, y, w, h = column * frameWidth, row * frameHeight, frameWidth, frameHeight
            if imageData then x, y, w, h = findVisibleBounds(imageData, x, y, frameWidth, frameHeight) end
            quads[row][column + 1] = {
                quad = love.graphics.newQuad(x, y, w, h, imageWidth, imageHeight),
                width = w, height = h, originX = w / 2, originY = h
            }
            maxFrameHeight = math.max(maxFrameHeight, h)
        end
    end
    return quads, maxFrameHeight
end

function KM:init(x, y)
    -- Init KM
    self.name = "KM"
    self.w, self.h = KM.HITBOX_W, KM.HITBOX_H
    self.x, self.y = x - self.w / 2, y - self.h / 2

    self.hp, self.damage, self.speed = 120, 15, 65
    self.chaseSpeed = 100
    self.visionRange, self.attackRange = 220, 35

    self.state, self.direction = "walk", "right"
    self.mode = "wander"  -- "wander" or "chase"
    self.timer, self.frame = 0, 0
    self.deadAnimationComplete, self.hasHit = false, false
    self.wanderDirX, self.wanderDirY = 1, 0
    self.wanderTimer, self.wanderInterval = 0, math.random(2, 4)

    local walkImageData,  walkTexture  = loadTexture(SPRITE_PATH_WALK)
    local chaseImageData, chaseTexture = loadTexture(SPRITE_PATH_CHASE)

    self.walkTexture,  self.walkImageData  = walkTexture,  walkImageData
    self.chaseTexture, self.chaseImageData = chaseTexture, chaseImageData

    if self.walkTexture then
        local iw, ih = self.walkTexture:getDimensions()
        local fw, fh = math.floor(iw / SPRITE_COLUMNS), math.floor(ih / SPRITE_ROWS)
        self.walkQuads, self.walkMaxH = buildQuads(self.walkTexture, self.walkImageData, fw, fh)
    end
    if self.chaseTexture then
        local iw, ih = self.chaseTexture:getDimensions()
        local fw, fh = math.floor(iw / SPRITE_COLUMNS), math.floor(ih / SPRITE_ROWS)
        self.chaseQuads, self.chaseMaxH = buildQuads(self.chaseTexture, self.chaseImageData, fw, fh)
    end

    self:_applyModeSprite()
    self.animations = ANIMATIONS
    self:updateQuad()
end

function KM:_applyModeSprite()
    -- Swap sprites
    if self.mode == "chase" and self.chaseTexture then
        self.texture  = self.chaseTexture
        self.quads    = self.chaseQuads
        self.maxFrameHeight = self.chaseMaxH or 128
    else
        self.texture  = self.walkTexture
        self.quads    = self.walkQuads
        self.maxFrameHeight = self.walkMaxH or 128
    end
    self.displayScale = TARGET_DRAW_HEIGHT / self.maxFrameHeight
end

function KM:updateQuad()
    -- Set frame
    if not self.texture or not self.quads then return end
    local anim = self.animations[self.state] or self.animations.idle
    local maxFrames = math.max(1, math.min(anim.frames, SPRITE_COLUMNS))
    self.frame = self.frame % maxFrames
    self.frameData = self.quads[anim.row] and self.quads[anim.row][self.frame + 1]
    self.quad = self.frameData and self.frameData.quad
end

function KM:takeDamage(amount)
    -- HP and SFX
    if self.hp <= 0 then return end
    self.hp = self.hp - amount
    if Audio and not Audio:isPlaying("knight_hurt") then
        Audio:play("knight_hurt")
    end
end

function KM:update(dt, player, map)
    -- KM Logic
    if self.hp <= 0 then
        if self.state ~= "death" then
            self.state, self.frame, self.timer = "death", 0, 0
            self:updateQuad()
        end
        self:updateAnimation(dt, player)
        return
    end

    local centerX, centerY = self.x + self.w / 2, self.y + self.h / 2
    local playerCenterX, playerCenterY = player.x + player.w / 2, player.y + player.h / 2
    local dx, dy = playerCenterX - centerX, playerCenterY - centerY
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Mode toggle
    local prevMode = self.mode
    if dist <= self.visionRange then
        self.mode = "chase"
    else
        self.mode = "wander"
    end
    if self.mode ~= prevMode then
        self:_applyModeSprite()
        self.frame, self.timer = 0, 0
    end

    local moveX, moveY = 0, 0
    local nextState

    if self.mode == "chase" then
        -- Pursuit
        if dist < self.attackRange then
            nextState = "attack"
        else
            nextState = "walk"
            if playerCenterX > centerX then moveX = 1 elseif playerCenterX < centerX then moveX = -1 end
            if playerCenterY > centerY then moveY = 1 elseif playerCenterY < centerY then moveY = -1 end
            local mag = (moveX ~= 0 and moveY ~= 0) and 0.7071 or 1
            moveX, moveY = moveX * mag, moveY * mag
        end
    else
        -- Roam
        self.wanderTimer = self.wanderTimer + dt
        if self.wanderTimer >= self.wanderInterval then
            self.wanderTimer = 0
            self.wanderInterval = math.random(2, 4)
            local angle = math.random() * math.pi * 2
            self.wanderDirX = math.cos(angle)
            self.wanderDirY = math.sin(angle)
        end
        nextState = "walk"
        moveX, moveY = self.wanderDirX, self.wanderDirY
    end

    if nextState == "walk" and (moveX ~= 0 or moveY ~= 0) then
        -- Movement
        local spd = (self.mode == "chase") and self.chaseSpeed or (self.speed * 0.5)
        local vx, vy = moveX * spd * dt, moveY * spd * dt
        local moved = false
        if not map:isColliding(self.x + vx, self.y, self.w, self.h) then
            self.x = self.x + vx
            moved = true
        end
        if not map:isColliding(self.x, self.y + vy, self.w, self.h) then
            self.y = self.y + vy
            moved = true
        end
        if self.mode == "wander" and not moved then
            local angle = math.random() * math.pi * 2
            self.wanderDirX = math.cos(angle)
            self.wanderDirY = math.sin(angle)
            self.wanderTimer = 0
        end
        if moveX ~= 0 then self.direction = moveX > 0 and "right" or "left" end
    end

    if nextState ~= self.state then
        self.state, self.frame, self.hasHit = nextState, 0, false
        self:updateQuad()
    end

    self:updateAnimation(dt, player)
end

function KM:updateAnimation(dt, player)
    -- Animation
    self.timer = self.timer + dt
    local anim = self.animations[self.state] or self.animations.idle
    local maxFrames = math.max(1, math.min(anim.frames, SPRITE_COLUMNS))

    if self.timer > anim.speed then
        self.timer = 0
        -- Capture
        if self.state == "attack" and self.frame == 1 and not self.hasHit then
            local centerX, centerY = self.x + self.w / 2, self.y + self.h / 2
            local px, py = player:getCenter()
            local dist = math.sqrt((px - centerX)^2 + (py - centerY)^2)
            if dist < self.attackRange then
                player:takeDamage(self.damage)
                self.hasHit, self.caught = true, true
            end
        end

        if self.state == "death" then
            if self.frame < maxFrames - 1 then
                self.frame = self.frame + 1
            else
                self.deadAnimationComplete = true
            end
        else
            self.frame = (self.frame + 1) % maxFrames
        end
        self:updateQuad()
    end
end

function KM:render()
    if self.hp <= 0 then love.graphics.setColor(1, 1, 1, 0.8) else love.graphics.setColor(1, 1, 1) end
    if self.texture and self.quad and self.frameData then
        local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
        local pivotX, pivotY = self.x + self.w / 2, self.y + self.h
        love.graphics.draw(
            self.texture,
            self.quad,
            pivotX,
            pivotY,
            0,
            scaleX,
            self.displayScale,
            self.frameData.originX,
            self.frameData.originY
        )
    else
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    end
    love.graphics.setColor(1, 1, 1)
end

return KM