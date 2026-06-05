-- wizard.lua
-- wizard/wizard.lua
local Push = require("push")

local Wizard = {}
Wizard.__index = Wizard

-- Global Constants parsed by main.lua spawners
Wizard.HITBOX_W = 8
Wizard.HITBOX_H = 8

function Wizard:init(x, y)
    -- Movement hitboxes
    self.w, self.h = Wizard.HITBOX_W, Wizard.HITBOX_H
    self.x, self.y = x - self.w / 2, y - self.h / 2
    
    -- Minimap indicators and identification
    self.type = "enemy"
    self.subType = "wizard"
    self.minimapColor = {0.7, 0.3, 1} -- Purple color for wizards on the minimap

    self.hp = 150 
    self.speed = 45 
    self.visionRange = 120 
    
    self.state = "walk"
    self.direction = "right"
    self.timer, self.frame = 0, 0
    self.invuln = 0
    
    self.caught = false 
    self.deadAnimationComplete = false 
    self.hasHit = false 

    self.attackCooldown = 1.5 
    self.attackTimer = 0 

    self.displayScale = 0.45 
    self.frameWidth, self.frameHeight = 128, 128
    self.animations = {
        idle   = { frames = 7, speed = 0.12 }, 
        walk   = { frames = 6, speed = 0.09 }, 
        hurt   = { frames = 4, speed = 0.0875 }, 
        death  = { frames = 6, speed = 0.12 },  
        attack = { frames = 8, speed = 0.10 },  
        charge = { frames = 14, speed = 0.08 }  
    }
    
    self:updateTexture()
end

function Wizard.new(x, y)
    local self = setmetatable({}, Wizard)
    self:init(x, y)
    return self
end

function Wizard:updateTexture()
    local texKey = "wizard_" .. self.state
    if self.state == "attack" then texKey = "wizard_fire" end 
    self.texture = gTextures[texKey] or gTextures["wizard_idle"]
    if self.texture then
        local sw, _ = self.texture:getDimensions()
        local anim = self.animations[self.state] or self.animations.idle
        
        local imageFrames = math.max(1, math.floor(sw / self.frameWidth))
        local maxFrames = math.min(anim.frames, imageFrames)
        self.frame = self.frame % maxFrames
        self.quad = love.graphics.newQuad(self.frame * self.frameWidth, 0, self.frameWidth, self.frameHeight, self.texture:getDimensions())
    end
end

function Wizard:update(dt, player, dungeon, projectiles)
    if self.attackTimer > 0 then self.attackTimer = self.attackTimer - dt end 
    if self.invuln > 0 then self.invuln = self.invuln - dt end

    local pCenterX, pCenterY = player:getCenter()
    local selfCenterX, selfCenterY = self.x + self.w / 2, self.y + self.h / 2
    local dx, dy = pCenterX - selfCenterX, pCenterY - selfCenterY
    local dist = math.sqrt(dx * dx + dy * dy)

    if self.hp <= 0 then
        if self.state ~= "death" then
            self.state, self.frame, self.timer = "death", 0, 0
            self:updateTexture()
        end
    else
        if self.state ~= "hurt" and self.state ~= "attack" and self.state ~= "charge" then
            if dist < 140 then
                if self.attackTimer <= 0 and dungeon:hasLineOfSight(selfCenterX, selfCenterY, pCenterX, pCenterY) then
                    self.state = "attack"
                    self.frame, self.timer, self.hasHit = 0, 0, false
                    self.direction = dx > 0 and "right" or "left" 
                    self:updateTexture()
                else
                    self.state = "idle"
                    self.direction = dx > 0 and "right" or "left"
                    self:updateTexture()
                end
            elseif dist < self.visionRange and dungeon:hasLineOfSight(selfCenterX, selfCenterY, pCenterX, pCenterY) then
                self.state = "walk"
                local vx = (dx / dist) * self.speed * dt
                local vy = (dy / dist) * self.speed * dt
                
                if not dungeon:isColliding(self.x + vx, self.y, self.w, self.h) then self.x = self.x + vx end
                if not dungeon:isColliding(self.x, self.y + vy, self.w, self.h) then self.y = self.y + vy end
                self.direction = vx > 0 and "right" or "left"
                self:updateTexture()
            else
                self.state = "idle"
                self:updateTexture()
            end
        end
    end

    self.timer = self.timer + dt
    local anim = self.animations[self.state] or self.animations.idle
    
    local sw = self.texture and self.texture:getWidth() or (self.frameWidth * anim.frames)
    local imageFrames = math.max(1, math.floor(sw / self.frameWidth))
    local maxFrames = math.min(anim.frames, imageFrames)

    local frameDuration = anim.speed
    if self.timer > frameDuration then
        self.timer = 0

        if self.state == "death" then
            if self.frame < maxFrames - 1 then self.frame = self.frame + 1 else self.deadAnimationComplete = true end
        elseif self.state == "attack" then
            if self.frame < maxFrames - 1 then
                self.frame = self.frame + 1

                if self.state == "attack" and self.frame == 4 and not self.hasHit then
                    local spawnY = selfCenterY - 15
                    local angle = math.atan2(pCenterY - spawnY, pCenterX - selfCenterX)
                    local speed = 240
                    table.insert(projectiles, {
                        x = selfCenterX,
                        y = spawnY,
                        vx = math.cos(angle) * speed,
                        vy = math.sin(angle) * speed,
                        angle = angle,
                        frame = 1,
                        timer = 0
                    })
                    self.hasHit, self.attackTimer = true, self.attackCooldown
                end
            else
                self.state, self.frame = "charge", 0
                self:updateTexture()
            end
        elseif self.state == "charge" or self.state == "hurt" then
            if self.frame < maxFrames - 1 then
                self.frame = self.frame + 1
            else
                self.state, self.frame = "idle", 0
                self:updateTexture()
            end
        else
            self.frame = (self.frame + 1) % maxFrames
        end
        self:updateTexture()
    end
end

function Wizard:takeDamage(amount, attacker, isCritical)
    if self.hp > 0 and self.invuln <= 0 then
        self.hp = math.max(0, self.hp - amount)
        self.invuln = 0.35
        Audio:play("wizard_hurt")
        if self.hp > 0 then self.state, self.frame, self.timer = "hurt", 0, 0 end
        self:updateTexture()

        local isCriticalHit = false
        if isCritical == nil then
            isCriticalHit = math.random() <= 0.15
        else
            isCriticalHit = isCritical
        end

        if attacker and isCriticalHit then
            Push.execute(attacker, self, 10, 0.8, true)
        end
    end
end

function Wizard:render()
    if self.deadAnimationComplete then return end
    
    if self.texture and self.quad then
        local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
        local pivotX = self.x + self.w / 2
        local pivotY = self.y + self.h
        
        love.graphics.setColor(1, 1, 1)

        if self.state == "charge" then
            local idleTex = gTextures["wizard_idle"]
            if idleTex then
                local idleQuad = love.graphics.newQuad(0, 0, 128, 128, idleTex:getDimensions())
                love.graphics.draw(idleTex, idleQuad, pivotX, pivotY, 0, scaleX, self.displayScale, 64, 128)
            end
        end

        if self.invuln > 0 then
            love.graphics.setColor(1, 0.5, 0.5) 
        end

        local oy = (self.state == "charge") and 90 or 128
        love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, scaleX, self.displayScale, 64, oy)
    end
    love.graphics.setColor(1, 1, 1)
end

return Wizard