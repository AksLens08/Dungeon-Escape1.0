-- knight.lua
local Class = require("system.class")
local Knight = Class.define()
Knight.HITBOX_W = 20
Knight.HITBOX_H = 30

function Knight:init(x, y)
    -- Collision box covers the visible knight body, not just the feet.
    self.w, self.h = Knight.HITBOX_W, Knight.HITBOX_H
    -- Set spawn position (default to middle if none given)
    self.x = (x or 0) - self.w / 2
    self.y = (y or 0) - self.h / 2

    self.hp, self.maxHp, self.armor, self.damage, self.coins = 100, 100, 100, 20, 0
    self.invuln, self.hasKey = 0, false
        self.hpRegenTimer = 0
        self.hpRegenInterval = 2.5
    self.dx, self.dy, self.speed = 0, 0, 85
    self.slideSide = nil
    self.state, self.previousState, self.direction = "idle", "idle", "right"
    self.attackVariant = nil
    self.timer, self.frame = 0, 0
    self.attackTimer, self.attackCooldown = 0, 0
    self.deadAnimationComplete = false

    -- Animation settings
    self.frameWidth, self.frameHeight = 128, 128
    self.animationFrames = { idle = 4, walk = 8, attack = 5, hurt = 2, death = 6, defend = 1 }
    self.animationSpeeds = { idle = 0.12, walk = 0.08, attack = 0.07, hurt = 0.1, death = 0.15, defend = 0.1 }
    self.lightCenters = {
        idle = { x = 33, y = 95.5 },
        walk = { x = 32.5, y = 95.5 },
        attack = { x = 54, y = 95.5 },
        hurt = { x = 37.5, y = 98 },
        death = { x = 35, y = 98.5 },
        defend = { x = 33, y = 95.5 }
    }

    self.displayScale, self.visualOffsetX = 1.0, 0
    self.visualScaleX = 1
    self:updateTexture()
end

function Knight:updateTexture()
    local texKey = "knight_" .. self.state
    if self.state == "attack" then
        if self.attackVariant then
            texKey = "knight_" .. self.attackVariant
        else
            texKey = "knight_attack"
        end
    end
    self.texture = gTextures[texKey] or gTextures["knight_idle"]

    if self.texture then
        local sw, sh = self.texture:getDimensions()
        local maxFrames = math.max(1, math.floor(sw / self.frameWidth))
        self.animationFrames[self.state] = maxFrames
        self.frame = self.frame % maxFrames
        -- Scale it so it's roughly 60px high
        self.displayScale = 60 / self.frameHeight
        self.quad = love.graphics.newQuad(self.frame * self.frameWidth, 0, self.frameWidth, self.frameHeight, sw, sh)
    end
end

function Knight:tryMoveStep(map, stepX, stepY)
    if not map:isColliding(self.x + stepX, self.y + stepY, self.w, self.h) then
        self.x = self.x + stepX
        self.y = self.y + stepY
        self.slideSide = nil
        return true
    end

    local len = math.sqrt(stepX * stepX + stepY * stepY)
    if len == 0 then return false end

    local perpX = -stepY / len
    local perpY = stepX / len
    local dirX = stepX / len
    local dirY = stepY / len
    local candidates = {}

    local sideOrder = self.slideSide == -1 and {-1, 1} or {1, -1}
    for offset = 0.5, 4, 0.5 do
        for _, side in ipairs(sideOrder) do
            local sidePenalty = self.slideSide == side and 0 or 0.2
            table.insert(candidates, {
                x = stepX + perpX * offset * side,
                y = stepY + perpY * offset * side,
                penalty = offset * 0.03 + sidePenalty,
                side = side
            })
        end
    end

    local bestMove, bestScore = nil, -math.huge
    for _, move in ipairs(candidates) do
        local nextX = self.x + move.x
        local nextY = self.y + move.y
        if not map:isColliding(nextX, nextY, self.w, self.h) then
            local forward = move.x * dirX + move.y * dirY
            local score = forward - move.penalty
            if score > bestScore then
                bestMove = move
                bestScore = score
            end
        end
    end

    if bestMove then
        self.x = self.x + bestMove.x
        self.y = self.y + bestMove.y
        self.slideSide = bestMove.side or self.slideSide
        return true
    end

    return false
end

function Knight:moveWithCollision(map, amountX, amountY)
    local steps = math.max(1, math.ceil(math.max(math.abs(amountX), math.abs(amountY))))
    local stepX = amountX / steps
    local stepY = amountY / steps
    local moved = false

    for _ = 1, steps do
        if self:tryMoveStep(map, stepX, stepY) then
            moved = true
        end
    end

    if not moved then
        self.dx = 0
        self.dy = 0
        self.slideSide = nil
    end
end

function Knight:update(dt, map, gMouse)
    if self.invuln > 0 then self.invuln = self.invuln - dt end
    if self.attackCooldown > 0 then self.attackCooldown = self.attackCooldown - dt end

    if self.hp <= 0 then
        self.state = "death"
        self.dx, self.dy = 0, 0
    else
        -- Armor regeneration logic
            -- Health regeneration logic (replaces previous armor regen)
            if self.hp < self.maxHp then
                self.hpRegenTimer = self.hpRegenTimer + dt
                if self.hpRegenTimer >= self.hpRegenInterval then
                    self:heal(10) -- Regenerate 10 HP
                    self.hpRegenTimer = 0
            end
        end

        -- Check movement keys
        local inputX, inputY = 0, 0
        if not (gMouse and gMouse.rightDown) then
            if love.keyboard.isDown("w", "up") then inputY = -1 end
            if love.keyboard.isDown("s", "down") then inputY = 1 end
            if love.keyboard.isDown("a", "left") then inputX, self.direction = -1, "left" end
            if love.keyboard.isDown("d", "right") then inputX, self.direction = 1, "right" end
        end

        -- Fix diagonal speed
        local mag = (inputX ~= 0 and inputY ~= 0) and 0.7071 or 1
        local targetDx = inputX * self.speed * mag
        local targetDy = inputY * self.speed * mag

        -- Smooth movement
        local isStopping = (inputX == 0 and inputY == 0)
        local weight = isStopping and 12 or 20
        
        local lerpFactor = 1 - math.exp(-weight * dt)
        self.dx = self.dx + (targetDx - self.dx) * lerpFactor
        self.dy = self.dy + (targetDy - self.dy) * lerpFactor
        if isStopping and math.abs(self.dx) < 1 then self.dx = 0 end
        if isStopping and math.abs(self.dy) < 1 then self.dy = 0 end

        -- Figure out what the player is doing
        if self.invuln > 0.7 then
            self.state = "hurt"
        elseif (gMouse and gMouse.rightDown) then
            self.state = "defend"
        elseif (gMouse and gMouse.leftDown) and self.attackCooldown <= 0 then
            self.state = "attack"
            if inputX ~= 0 or inputY ~= 0 then
                self.attackVariant = "run_attack"
            else
                local variants = {"attack", "attack2", "attack3"}
                self.attackVariant = variants[math.random(#variants)]
            end
            if self.attackTimer <= 0 then self.attackTimer = 0.35 end
            Audio:play("sword_slice")
            self.attackCooldown = 1 -- Cooldown aligned with enemy hurt animation (0.35s)
        elseif self.attackTimer > 0 then
            self.state = "attack"
        elseif inputX ~= 0 or inputY ~= 0 then
            self.state = "walk"
        else
            self.state = "idle"
        end
    end

    if self.state == "attack" then self.attackTimer = self.attackTimer - dt end

    -- Reset frame if we changed state
    if self.state ~= self.previousState then
        self.frame, self.timer = 0, 0
        self.previousState = self.state
        if self.state ~= "attack" then
            self.attackVariant = nil
        end
        self:updateTexture()
    end

    self.timer = self.timer + dt
    local frameDuration = self.animationSpeeds[self.state] or 0.1
    local maxFrames = self.animationFrames[self.state] or 1
    if self.timer > frameDuration then
        self.timer = 0

        if self.state == "death" then
            if self.frame < maxFrames - 1 then
                self.frame = self.frame + 1
            else
                self.deadAnimationComplete = true
            end
        else
            self.frame = (self.frame + 1) % maxFrames
        end

        self:updateTexture()
    end

    self.visualScaleX = (self.direction == "right" and 1 or -1) * self.displayScale

    -- Handle footstep sounds based on movement state
    if self.state == "walk" and self.hp > 0 then
        if not Audio:isPlaying("footsteps") then
            Audio:play("footsteps")
        end
    else
        Audio:stop("footsteps")
    end

    self:moveWithCollision(map, self.dx * dt, self.dy * dt)
end

function Knight:takeDamage(amount)
    -- Play shield.mp3 if in defend state
    if self.state == "defend" then
        Audio:play("shield_hit") 
        return
    end

    -- Only take damage if not currently invulnerable
    if self.invuln <= 0 and self.hp > 0 then
        -- Damage reduces armor first
        if self.armor > 0 then
            self.armor = self.armor - amount
            -- If armor is depleted by this hit, carry over remaining damage to HP
            if self.armor < 0 then
                self.hp = self.hp + self.armor -- Adding negative armor to HP
                self.armor = 0
            end
        else
            self.hp = self.hp - amount
        end

        self.invuln = 0.8 -- This triggers the "hurt" state visual and prevents spamming
        Audio:play("knight_hurt") -- Play taking_damage.mp3
    end
end

function Knight:heal(amount)
    self.hp = math.min(self.maxHp, self.hp + amount)
end

function Knight:handleInput(key)
end

function Knight:getCenter()
    return self.x + self.w / 2, self.y + self.h / 2
end

function Knight:getLightPosition()
    local pivotX = self.x + self.w / 2
    local pivotY = self.y + self.h
    local center = self.lightCenters[self.state] or self.lightCenters.idle
    local offsetY = (center.y - self.frameHeight) * self.displayScale

    return pivotX, pivotY + offsetY
end

function Knight:drawHUD()
    local sw = love.graphics.getWidth()
    local barW, barH = 200, 20
    local margin = 20

    love.graphics.setFont(gFonts["hud"])

    -- Draw HP Bar (Red)
    love.graphics.setColor(0.2, 0, 0, 0.8)
    love.graphics.rectangle("fill", margin, margin, barW, barH)
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", margin, margin, barW * (self.hp / 100), barH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. math.ceil(self.hp), margin, margin - 20)

    -- Draw Armor Bar (Blue)
    love.graphics.setColor(0, 0, 0.2, 0.8)
    love.graphics.rectangle("fill", margin, margin + 40, barW, barH)
    love.graphics.setColor(0, 0.6, 1)
    love.graphics.rectangle("fill", margin, margin + 40, barW * (self.armor / 100), barH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("ARMOR: " .. math.ceil(self.armor), margin, margin + 20)
    love.graphics.print("COINS: " .. self.coins, margin, margin + 62)
end

function Knight:render()
    -- Pivot points for drawing
    local pivotX = self.x + self.w / 2
    local pivotY = self.y + self.h

    -- Flash/Change color based on state
    if self.hp <= 0 then
        love.graphics.setColor(0.3, 0, 0)
    elseif self.attackTimer > 0 then
        love.graphics.setColor(1, 1, 0.7)
    elseif self.invuln > 0 then
        local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 25)
        love.graphics.setColor(1, pulse, pulse)
    else
        love.graphics.setColor(1, 1, 1)
    end

    if self.texture and self.quad then
        local center = self.lightCenters[self.state] or self.lightCenters.idle
        love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, self.visualScaleX, self.displayScale, center.x, self.frameHeight)
    else
        -- Backup box if image is missing
        local size = 16
        local centerY = math.floor(self.y + self.h / 2)
        love.graphics.rectangle("fill", pivotX - size / 2, centerY - size / 2, size, size)
    end
    love.graphics.setColor(1, 1, 1)
end

return Knight