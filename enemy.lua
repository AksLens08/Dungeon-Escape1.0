-- enemy.lua
local Class = require("class")
local Enemy = Class.define()

-- Global Constants parsed by main.lua spawners
Enemy.HITBOX_W = 8
Enemy.HITBOX_H = 8

function Enemy:init(x, y)
    -- Movement hitboxes
    self.w, self.h = Enemy.HITBOX_W, Enemy.HITBOX_H
    self.x, self.y = x - self.w / 2, y - self.h / 2
    
    self.hp = 150 -- Keep HP at 150 as previously set
    self.speed = 45 -- New speed from your provided code
    self.visionRange = 250 -- Increased to ensure they start moving before attacking
    
    self.state = "walk"
    self.direction = "right"
    self.timer, self.frame = 0, 0
    self.invuln = 0
    
    self.caught = false -- Retain for potential future use
    self.deadAnimationComplete = false -- Retain for death animation handling
    self.hasHit = false -- Retain for attack damage synchronization

    self.attackCooldown = 1.5 -- Retain attack cooldown
    self.attackTimer = 0 -- Retain attack timer

    self.displayScale = 0.45 -- New display scale from your provided code
    self.frameWidth, self.frameHeight = 128, 128
    self.animations = {
        idle   = { frames = 7, speed = 0.12 }, -- Merged from new animationFrames/Speeds
        walk   = { frames = 6, speed = 0.09 }, -- Merged from new animationFrames/Speeds
        hurt   = { frames = 4, speed = 0.0875 }, -- Matched to Knight attack duration (0.35s)
        death  = { frames = 6, speed = 0.12 },  -- Retained from previous
        attack = { frames = 8, speed = 0.10 },  -- Casting animation using Fireball.png
        charge = { frames = 14, speed = 0.08 }  -- Recovery/Charge animation after firing
    }
    
    self:updateTexture()
end

function Enemy:updateTexture()
    local texKey = "wizard_" .. self.state
    if self.state == "attack" then texKey = "wizard_fire" end -- Use Fireball.png for the attack state
    self.texture = gTextures[texKey] or gTextures["wizard_idle"]
    if self.texture then
        local sw, _ = self.texture:getDimensions()
        local anim = self.animations[self.state] or self.animations.idle
        
        -- Prevent rendering "empty" frames if the image file is shorter than the animation definition
        local imageFrames = math.max(1, math.floor(sw / self.frameWidth))
        local maxFrames = math.min(anim.frames, imageFrames)

        self.frame = self.frame % maxFrames
        self.quad = love.graphics.newQuad(self.frame * self.frameWidth, 0, self.frameWidth, self.frameHeight, self.texture:getDimensions())
    end
end

function Enemy:update(dt, player, dungeon, projectiles)
    if self.attackTimer > 0 then self.attackTimer = self.attackTimer - dt end -- Decrement cooldown timer
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
        -- AI state machine: Ensure we don't interrupt an ongoing attack
        if self.state ~= "hurt" and self.state ~= "attack" and self.state ~= "charge" then
            if dist < 140 then
                -- Within range: check if cooldown is ready and we have Line of Sight
                if self.attackTimer <= 0 and dungeon:hasLineOfSight(selfCenterX, selfCenterY, pCenterX, pCenterY) then
                    self.state = "attack"
                    self.frame, self.timer, self.hasHit = 0, 0, false
                    self.direction = dx > 0 and "right" or "left" -- Face the player immediately
                    self:updateTexture()
                else
                    -- Stationary while waiting for cooldown or if LoS is blocked while in range
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

    -- Animation Logic
    self.timer = self.timer + dt
    local anim = self.animations[self.state] or self.animations.idle
    
    -- Sync logic with actual image width to prevent invisibility on shorter sprite sheets
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

                -- Spawn fireball at frame 4 (release frame)
                if self.state == "attack" and self.frame == 4 and not self.hasHit then
                    -- Spawn at chest height (-15) to avoid floor collision and match visual hands
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
                -- Transition to charge state after the cast is finished
                self.state, self.frame = "charge", 0
                self:updateTexture()
            end
        elseif self.state == "charge" or self.state == "hurt" then
            if self.frame < maxFrames - 1 then
                self.frame = self.frame + 1
            else
                -- Return to idle once charge or hurt animation is done
                self.state, self.frame = "idle", 0
                self:updateTexture()
            end
        else
            self.frame = (self.frame + 1) % maxFrames
        end
        self:updateTexture()
    end
end

function Enemy:takeDamage(amount)
    if self.hp > 0 and self.invuln <= 0 then
        self.hp = math.max(0, self.hp - amount)
        self.invuln = 0.35 -- Matched to Knight attack duration
        Audio:play("wizard_hurt")
        if self.hp > 0 then self.state, self.frame, self.timer = "hurt", 0, 0 end
        self:updateTexture()
    end
end

-- Ensure method name is 'render' to match main.lua expectations
function Enemy:render()
    if self.deadAnimationComplete then return end
    
    if self.texture and self.quad then
        local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
        local pivotX = self.x + self.w / 2
        local pivotY = self.y + self.h
        
        love.graphics.setColor(1, 1, 1)

        -- If in charge state, draw the idle wizard as a base so he doesn't disappear
        if self.state == "charge" then
            local idleTex = gTextures["wizard_idle"]
            if idleTex then
                -- Draw frame 0 of idle as the base
                local idleQuad = love.graphics.newQuad(0, 0, 128, 128, idleTex:getDimensions())
                love.graphics.draw(idleTex, idleQuad, pivotX, pivotY, 0, scaleX, self.displayScale, 64, 128)
            end
        end

        if self.invuln > 0 then
            love.graphics.setColor(1, 0.5, 0.5) -- Flash red when hurt
        end

        -- For the charge effect, use a higher origin (90) so it appears on the body, not the feet
        local oy = (self.state == "charge") and 90 or 128
        love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, scaleX, self.displayScale, 64, oy)
    end
    love.graphics.setColor(1, 1, 1)
end

return Enemy
