-- wizard.lua
-- Wizard player
local Push = require("push")

local Wizard = {}
Wizard.__index = Wizard

Wizard.HITBOX_W = 20
Wizard.HITBOX_H = 30

function Wizard:init(x, y)
    -- Setup
    self.w, self.h = Wizard.HITBOX_W, Wizard.HITBOX_H
    self.x, self.y = x - self.w / 2, y - self.h / 2
    
    self.type = "player"
    self.subType = "wizard"
    self.minimapColor = {0.7, 0.3, 1} -- Purple color for wizards on the minimap

    self.hp, self.maxHp, self.mana, self.maxMana, self.damage, self.coins = 100, 100, 100, 100, 20, 0
    self.baseDamage = 20 -- Store base damage for buff calculations
    self.buffTimer = 0
    self.hpRegenTimer, self.hpRegenInterval = 0, 2.5
    self.dx, self.dy, self.speed = 0, 0, 85
    self.slideSide = nil
    
    self.state, self.previousState, self.direction = "idle", "idle", "right"
    self.timer, self.frame = 0, 0
    self.attackTimer, self.attackCooldown = 0, 0
    self.invuln = 0
    
    self.targetHeight = 58
    self.displayScale = 1.0
    self.frameWidth, self.frameHeight = 0, 0
    self.lightCenters = {
        idle   = { x = 64, y = 64 },
        walk   = { x = 64, y = 64 },
        attack = { x = 64, y = 64 },
        flame  = { x = 64, y = 64 },
        death  = { x = 64, y = 64 }
    }

    self.animations = {
        idle   = { frames = 7, speed = 0.12 }, 
        walk   = { frames = 6, speed = 0.09 }, 
        attack = { frames = 4, speed = 0.0875 },
        flame  = { frames = 14, speed = 0.06 },
        death  = { frames = 6, speed = 0.12 },
        hurt   = { frames = 3, speed = 0.1 }
    }
    
    self:updateTexture()
end

function Wizard.new(x, y)
    local self = setmetatable({}, Wizard)
    self:init(x, y)
    return self
end

function Wizard:tryMoveStep(map, stepX, stepY)
    -- Wall slide
    if not map:isColliding(self.x + stepX, self.y + stepY, self.w, self.h) then
        self.x = self.x + stepX
        self.y = self.y + stepY
        self.slideSide = nil
        return true
    end

    local len = math.sqrt(stepX * stepX + stepY * stepY)
    if len == 0 then return false end

    local perpX, perpY = -stepY / len, stepX / len
    local dirX, dirY = stepX / len, stepY / len
    local candidates = {}

    local sideOrder = self.slideSide == -1 and {-1, 1} or {1, -1}
    for offset = 0.5, 4, 0.5 do
        for _, side in ipairs(sideOrder) do
            table.insert(candidates, {
                x = stepX + perpX * offset * side,
                y = stepY + perpY * offset * side,
                penalty = offset * 0.03 + (self.slideSide == side and 0 or 0.2),
                side = side
            })
        end
    end

    local bestMove, bestScore = nil, -math.huge
    for _, move in ipairs(candidates) do
        if not map:isColliding(self.x + move.x, self.y + move.y, self.w, self.h) then
            local score = (move.x * dirX + move.y * dirY) - move.penalty
            if score > bestScore then
                bestMove, bestScore = move, score
            end
        end
    end

    if bestMove then
        self.x, self.y, self.slideSide = self.x + bestMove.x, self.y + bestMove.y, bestMove.side
        return true
    end
    return false
end

function Wizard:moveWithCollision(map, amountX, amountY)
    -- Collision move
    local steps = math.max(1, math.ceil(math.max(math.abs(amountX), math.abs(amountY))))
    local stepX, stepY = amountX / steps, amountY / steps
    local moved = false
    for _ = 1, steps do
        if self:tryMoveStep(map, stepX, stepY) then moved = true end
    end
    if not moved then
        self.dx, self.dy, self.slideSide = 0, 0, nil
    end
end

function Wizard:updateTexture()
    -- Select sprite
    local texKey = "wizard_" .. self.state
    self.texture = gTextures[texKey] or gTextures["wizard_idle"]
    if self.texture then
        local sw, sh = self.texture:getDimensions()
        local anim = self.animations[self.state] or self.animations.idle
        
        self.frameWidth = sw / anim.frames
        self.frameHeight = sh
        self.displayScale = self.targetHeight / self.frameHeight

        self.frame = self.frame % anim.frames
        self.quad = love.graphics.newQuad(self.frame * self.frameWidth, 0, self.frameWidth, self.frameHeight, sw, sh)
    end
end

function Wizard:update(dt, dungeon, gMouse, projectiles, camera, enemies)
    -- Wizard logic
    if self.invuln > 0 then self.invuln = self.invuln - dt end
    if self.attackCooldown > 0 then self.attackCooldown = self.attackCooldown - dt end
    if self.attackTimer > 0 then self.attackTimer = self.attackTimer - dt end

    if self.hp <= 0 then
        self.state = "death"
        self.dx, self.dy = 0, 0
    else
        if self.hp < self.maxHp then
            self.hpRegenTimer = self.hpRegenTimer + dt
            if self.hpRegenTimer >= self.hpRegenInterval then
                self:heal(5)
                self.hpRegenTimer = 0
            end
        end

        if self.buffTimer > 0 then
            self.buffTimer = self.buffTimer - dt
            if self.buffTimer <= 0 then
                self.damage = self.baseDamage
            end
        end

        self.mana = math.min(self.maxMana, self.mana + 1 * dt)

        local inputX, inputY = 0, 0
        -- Freeze movement
        if self.state ~= "flame" then
            if love.keyboard.isDown("w", "up") then inputY = -1 end
            if love.keyboard.isDown("s", "down") then inputY = 1 end
            if love.keyboard.isDown("a", "left") then inputX, self.direction = -1, "left" end
            if love.keyboard.isDown("d", "right") then inputX, self.direction = 1, "right" end
        end

        -- Physics
        local mag = (inputX ~= 0 and inputY ~= 0) and 0.7071 or 1
        local targetDx = inputX * self.speed * mag
        local targetDy = inputY * self.speed * mag

        local isStopping = (inputX == 0 and inputY == 0)
        local weight = isStopping and 12 or 20
        local lerpFactor = 1 - math.exp(-weight * dt)
        self.dx = self.dx + (targetDx - self.dx) * lerpFactor
        self.dy = self.dy + (targetDy - self.dy) * lerpFactor
        if isStopping and math.abs(self.dx) < 1 then self.dx = 0 end
        if isStopping and math.abs(self.dy) < 1 then self.dy = 0 end

        if (math.abs(self.dx) > 5 or math.abs(self.dy) > 5) and self.hp > 0 then
            if not Audio:isPlaying("footsteps") then Audio:play("footsteps") end
        else
            Audio:stop("footsteps")
        end

        if gMouse.rightDown and self.attackCooldown <= 0 and self.mana >= 20 and projectiles then
            self.state = "flame"
            self.mana = self.mana - 20 -- Flame Jet costs 20 Mana
            Audio:play("fireball")
            self.dx, self.dy = 0, 0
            self.attackTimer = 0.84 -- matches the 14-frame animation duration (14 * 0.06)
            self.attackCooldown = 1.0
        elseif gMouse.leftDown and self.attackCooldown <= 0 then
            self.state = "attack"
            if self.attackTimer <= 0 then self.attackTimer = 0.35 end
            Audio:play("sword_slice")
            self.attackCooldown = 1.0
        elseif self.invuln > 0.6 then
            self.state = "hurt"
        elseif self.attackTimer > 0 then
            -- Hold the attack/flame state until the timer expires
        elseif math.abs(self.dx) > 2 or math.abs(self.dy) > 2 then
            self.state = "walk"
        else
            self.state = "idle"
        end
    end

    if self.state ~= self.previousState then
        self.frame, self.timer = 0, 0
        self.previousState = self.state
        self:updateTexture()
    end

    if self.state == "flame" and self.frame >= 6 and self.frame <= 10 and enemies then
        local px, py = self:getCenter()
        for _, enemy in ipairs(enemies) do
            if enemy.hp > 0 then
                local ex, ey = enemy.x + enemy.w / 2, enemy.y + enemy.h / 2
                local dx, dy = ex - px, ey - py
                local distSq = dx * dx + dy * dy
                local isFacing = (self.direction == "right" and dx > 0) or (self.direction == "left" and dx < 0)

                if isFacing and distSq < 3600 then -- 60 pixel range (twice the melee reach)
                    enemy:takeDamage(40, self, dungeon) -- Flame Jet damage set to 40
                end
            end
        end
    end

    self:handleAnimation(dt)
    self:moveWithCollision(dungeon, self.dx * dt, self.dy * dt)
end

function Wizard:handleAnimation(dt)
    -- Animation loop
    self.timer = self.timer + dt
    local anim = self.animations[self.state] or self.animations.idle
    local maxFrames = anim.frames
    local frameDuration = anim.speed
    if self.timer > frameDuration then
        self.timer = 0

        if self.state == "death" then
            if self.frame < maxFrames - 1 then self.frame = self.frame + 1 else self.deadAnimationComplete = true end
        elseif self.state == "flame" or self.state == "attack" or self.state == "hurt" then
            if self.frame < maxFrames - 1 then self.frame = self.frame + 1 end
        else
            self.frame = (self.frame + 1) % maxFrames
        end
        self:updateTexture()
    end
end

function Wizard:takeDamage(amount, attacker, dungeon)
    -- Damage and KB
    if self.invuln <= 0 and self.hp > 0 then
        self.hp = self.hp - amount
        self.invuln = 0.8
        Audio:play("hurt")

        -- Knockback
        if attacker and type(attacker) == "table" then
            local pushDx, pushDy = Push.execute(attacker, self, 10, 0.8, false)
            if pushDx and pushDy and dungeon then
                self:moveWithCollision(dungeon, pushDx, pushDy)
            end
        end
    end
end

function Wizard:heal(amount)
    self.hp = math.min(self.maxHp, self.hp + amount)
end

function Wizard:applyAttackBuff(duration)
    self.buffTimer = duration
    self.damage = self.baseDamage * 2 -- Double the attack power
end

function Wizard:getCenter()
    return self.x + self.w / 2, self.y + self.h / 2 -- World coords
end

function Wizard:getLightPosition()
    -- Light offset
    local pivotX = self.x + self.w / 2
    local pivotY = self.y + self.h
    local center = self.lightCenters[self.state] or self.lightCenters.idle
    local offsetY = (center.y - self.frameHeight) * self.displayScale

    return pivotX, pivotY + offsetY
end

function Wizard:drawHUD()
    -- Draw UI
    local barW, barH = 260, 28
    local margin = 20
    love.graphics.setFont(gFonts["hud"])
    
    local function drawMedievalBar(x, y, current, max, label, color, subLabel)
        love.graphics.setColor(0.05, 0.05, 0.05, 1)
        love.graphics.rectangle("fill", x - 4, y - 4, barW + 8, barH + 8)
        love.graphics.setColor(0.3, 0.3, 0.35, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - 4, y - 4, barW + 8, barH + 8)

        -- 2. Corner Rivets
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.circle("fill", x - 4, y - 4, 3)
        love.graphics.circle("fill", x + barW + 4, y - 4, 3)
        love.graphics.circle("fill", x - 4, y + barH + 4, 3)
        love.graphics.circle("fill", x + barW + 4, y + barH + 4, 3)

        -- 3. Stone Background
        love.graphics.setColor(0.15, 0.15, 0.15, 1)
        love.graphics.rectangle("fill", x, y, barW, barH)

        -- 4. The Fill
        local percent = math.max(0, current / max)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", x, y, barW * percent, barH)

        -- 5. Medieval Bevel
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", x, y + barH * 0.7, barW * percent, barH * 0.3)
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("fill", x, y, barW * percent, 4)

        -- 6. Text
        love.graphics.setColor(0.8, 0.7, 0.5, 1)
        love.graphics.print(label, x, y - 22)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(math.ceil(current) .. " " .. subLabel, x, y + 4, barW, "center")
    end

    -- Draw Health
    local hpX, hpY = margin + 5, margin + 25
    drawMedievalBar(hpX, hpY, self.hp, self.maxHp, "HEALTH", {0.6, 0.1, 0.1}, "/ " .. self.maxHp)

    -- Draw Mana
    local manaX, manaY = margin + 5, hpY + barH + 35
    drawMedievalBar(manaX, manaY, self.mana, self.maxMana, "MANA BAR", {0.3, 0.1, 0.6}, "/ " .. self.maxMana)

    -- Coin Counter
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", margin, manaY + barH + 15, 140, 30, 4)
    love.graphics.setColor(0.9, 0.8, 0.5, 1)
    love.graphics.print("COINS: " .. (self.coins or 0) .. " / 20", margin + 10, manaY + barH + 20)
    
    love.graphics.setLineWidth(1)
    -- Clean up draw state
end

function Wizard:handleInput(key) end

function Wizard:render()
    if self.deadAnimationComplete then return end
    
    if self.texture and self.quad then
        local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
        local pivotX = self.x + self.w / 2
        local pivotY = self.y + self.h
        
        love.graphics.setColor(1, 1, 1)

        if self.invuln > 0 then
            love.graphics.setColor(1, 0.5, 0.5) 
        end

        love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, scaleX, self.displayScale, self.frameWidth / 2, self.frameHeight)
    end
    love.graphics.setColor(1, 1, 1)
end

return Wizard