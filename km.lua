-- km.lua
local Class = require("class")

local km = Class.define()
km.HITBOX_W = 20 -- Adjusted to be more appropriate for visual size, matching Knight
km.HITBOX_H = 30 -- Adjusted to be more appropriate for visual size, matching Knight

function km:init(x, y)
    self.w, self.h = km.HITBOX_W, km.HITBOX_H
    self.x, self.y = x - self.w / 2, y - self.h / 2

    -- Stats: Slightly different from the Wizard for variety
    self.hp = 120           
    self.damage = 15
    self.speed = 65         -- Increased speed to make movement more noticeable
    self.visionRange = 220  
    self.attackRange = 35   
    
    -- AI State
    self.state = "idle" 
    self.targetX = x        
    self.targetY = y
    self.aiTimer = 0        
    self.deadAnimationComplete = false
    self.hasHit = false

    self.direction = "right"
    self.timer = 0
    self.frame = 0
    self.frameWidth = 128   
    self.frameHeight = 128  -- This matches the strip height in your KM.png
    self.displayScale = 0.5 -- Slightly increased for better visibility and to match Knight's scale more closely

    -- Use the global texture table for consistency with the Knight
    self.texture = gTextures["km"]

    -- Define animation rows in the sprite sheet
    -- Updated to 5 frames per row to match your KM.png
    self.animations = { -- Corrected frames to 4 to match KM.png
        idle   = { row = 0, frames = 4, speed = 0.12 },
        walk   = { row = 0, frames = 4, speed = 0.07 }, -- Slightly faster walk animation
        attack = { row = 0, frames = 4, speed = 0.10 },
        death  = { row = 0, frames = 4, speed = 0.15 }
    }

    self:updateQuad()
end

function km:updateQuad()
    if not self.texture then return end
    
    local anim = self.animations[self.state] or self.animations.idle
    local sw, sh = self.texture:getDimensions()
    
    -- Calculate X position based on frame, and Y based on the animation row
    local qx = self.frame * self.frameWidth
    local qy = anim.row * self.frameHeight
    
    self.quad = love.graphics.newQuad(qx, qy, self.frameWidth, self.frameHeight, sw, sh)
end

function km:takeDamage(amount)
    if self.hp <= 0 then return end
    self.hp = self.hp - amount
    if not Audio:isPlaying("knight_hurt") then
        Audio:play("knight_hurt") -- Reusing knight sound for impact
    end
end

function km:update(dt, player, map)
    if self.hp <= 0 then
        if self.state ~= "death" then
            self.state, self.frame, self.timer = "death", 0, 0
            self:updateQuad()
        end
        self:updateAnimation(dt)
        return
    end

    local centerX, centerY = self.x + self.w / 2, self.y + self.h / 2
    local playerCenterX, playerCenterY = player.x + player.w / 2, player.y + player.h / 2
    local dx = playerCenterX - centerX
    local dy = playerCenterY - centerY
    local dist = math.sqrt(dx * dx + dy * dy)

    local moveX, moveY = 0, 0
    local nextState = "idle"

    if dist < self.attackRange then
        nextState = "attack"
    elseif dist < self.visionRange and map:hasLineOfSight(centerX, centerY, playerCenterX, playerCenterY) then
        nextState = "walk"
        if playerCenterX > centerX then moveX = 1 elseif playerCenterX < centerX then moveX = -1 end
        if playerCenterY > centerY then moveY = 1 elseif playerCenterY < centerY then moveY = -1 end
        
        -- Normalize diagonal speed
        local mag = (moveX ~= 0 and moveY ~= 0) and 0.7071 or 1
        moveX, moveY = moveX * mag, moveY * mag
    else
        nextState = "idle"
        self.aiTimer = self.aiTimer - dt
        if self.aiTimer <= 0 then
            self.targetX = self.x + math.random(-80, 80)
            self.targetY = self.y + math.random(-80, 80)
            self.aiTimer = math.random(2, 4)
        end
        if math.abs(self.targetX - self.x) > 5 or math.abs(self.targetY - self.y) > 5 then
            nextState = "walk"
            if self.targetX > self.x then moveX = 1 else moveX = -1 end
            if self.targetY > self.y then moveY = 1 else moveY = -1 end
            
            -- Normalize diagonal speed
            local mag = (moveX ~= 0 and moveY ~= 0) and 0.7071 or 1
            moveX, moveY = moveX * mag, moveY * mag
        end
    end

    if nextState ~= "attack" and (moveX ~= 0 or moveY ~= 0) then
        local vx = moveX * self.speed * dt
        local vy = moveY * self.speed * dt
        if not map:isColliding(self.x + vx, self.y, self.w, self.h) then self.x = self.x + vx end
        if not map:isColliding(self.x, self.y + vy, self.w, self.h) then self.y = self.y + vy end
        if moveX ~= 0 then self.direction = moveX > 0 and "right" or "left" end
    end

    if nextState ~= self.state then
        self.state = nextState
        self.frame = 0
        self.hasHit = false
        self:updateQuad()
    end

    self:updateAnimation(dt, player)
end

function km:updateAnimation(dt, player)
    self.timer = self.timer + dt
    local anim = self.animations[self.state] or self.animations.idle

    if self.timer > anim.speed then
        self.timer = 0

        -- Check for damage on the 'hit' frame (assuming frame 2 is the impact)
        if self.state == "attack" and self.frame == 2 and not self.hasHit then
            -- Re-check distance to ensure player hasn't moved away
            local centerX, centerY = self.x + self.w / 2, self.y + self.h / 2
            local px, py = player:getCenter()
            local dist = math.sqrt((px - centerX)^2 + (py - centerY)^2)
            
            if dist < self.attackRange then
                player:takeDamage(self.damage)
                self.hasHit = true
                self.caught = true -- Trigger the jumpscare death state in main.lua
            end
        end

        if self.state == "death" then
            if self.frame < anim.frames - 1 then
                self.frame = self.frame + 1
            else
                self.deadAnimationComplete = true
            end
        else
            self.frame = (self.frame + 1) % anim.frames
        end
        self:updateQuad()
    end
end

function km:render()
    if self.hp <= 0 then love.graphics.setColor(1, 1, 1, 0.8) else love.graphics.setColor(1, 1, 1) end

    if self.texture and self.quad then
        local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
        local pivotX = self.x + self.w / 2
        local pivotY = self.y + self.h
        -- originX = 64 (center of 128), originY = 92 (approx. feet position for the sprites at the top of the frame)
        love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, scaleX, self.displayScale, 64, 92)
    else
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    end
    love.graphics.setColor(1, 1, 1)
end

return km