-- main.lua
-- Main entry point

local Menu     = require("graphics.background")
local Knight   = require("knight.knight")
local Dungeon  = require("graphics.dungeon")
local Lighting = require("graphics.lighting")
local Wizard   = require("wizard.wizard")
local Coin     = require("collectables.coin")
local BlueSlime  = require("Blue_slime.blue_slime")
local RedSlime   = require("Red_slime.red_slime")
local GreenSlime = require("Green_slime.green_slime")
local SkeletonArcher = require("Skeleton_Archer.skeleton_archer")
local SkeletonWarrior = require("Skeleton_Warrior.skeleton_warrior")
local SkeletonSpearman = require("Skeleton_Spearman.skeleton_spearman")
local Minimap  = require("graphics.minimap")
local Spawner  = require("system.spawner")
Audio = require("Audios.audio")
local Tutorial = require("system.tutorial")

-- Modular systems
Effect = require("system.effect")
local Camera = require("system.camera")
local UI = require("graphics.ui")
local Movement = require("system.movement")

-- Ensure nearest-neighbor scaling for crisp pixel art
if love and love.graphics and love.graphics.setDefaultFilter then
    love.graphics.setDefaultFilter("nearest", "nearest", 0)
end

-- Game state variables
gameState = "menu"
local mainMenu, player, dungeon, lighting, coins, isPaused, enemies, jumpScareSounds, projectiles, minimap, selectedClass, corpses
local tutorialController = nil
-- Selected dungeon index (1 = tutorial, 2 = easy, 3 = medium, 4 = hard)
local selectedDungeonIndex = 1
local floorSpawnColors = {
    [1] = {154/255, 154/255, 154/255},
    [2] = {172/255, 172/255, 172/255},
    [3] = {136/255, 136/255, 136/255},
    [4] = {130/255, 130/255, 130/255},
}
local COINS_REQUIRED = 20
local SPAWN_PADDING = 24
local coinsCollected = 0
gTextures, gFrames, gFonts = {}, {}, {}
gMouse = { leftDown = false, rightDown = false }

-- Initialize game world
local function startGame()
    if player then return end
    projectiles = {}
    corpses = {}
    coinsCollected = 0
    
    -- Initialize Dungeon (tileset disabled; use procedural renderer)
    if selectedDungeonIndex == 1 then
        tutorialController = Tutorial:new(selectedClass)
        tutorialController:start()
        dungeon = Dungeon:new(nil, 16, nil, nil, selectedDungeonIndex)
    else
        dungeon = Dungeon:new(nil, 16, nil, nil, selectedDungeonIndex)
    end
    
    local playerHitboxW = (selectedClass == "wizard") and Wizard.HITBOX_W or Knight.HITBOX_W
    local playerHitboxH = (selectedClass == "wizard") and Wizard.HITBOX_H or Knight.HITBOX_H

    local spawnX, spawnY = nil, nil
    -- For tutorial stages, prefer a spawn point far from the portal so the player
    -- doesn't immediately trigger the exit. Otherwise use leftmost/default.
    if selectedDungeonIndex == 1 and dungeon and dungeon.enderPortal then
        local bestRoom, bestDist = nil, -1
        for _, room in ipairs(dungeon.rooms) do
            local dx = (room.cx or (room.x + room.w/2)) - dungeon.enderPortal.x
            local dy = (room.cy or (room.y + room.h/2)) - dungeon.enderPortal.y
            local d = dx*dx + dy*dy
            if d > bestDist then bestDist = d; bestRoom = room end
        end
        if bestRoom then
            local bx, by = bestRoom.cx, bestRoom.cy
            if dungeon:canFitAtCenter(bx, by, playerHitboxW, playerHitboxH, SPAWN_PADDING) then
                spawnX, spawnY = bx, by
            end
        end
    end

    if dungeon and dungeon.getSpawnPointByImageColor then
        local spawnColor = floorSpawnColors[selectedDungeonIndex] or {154/255, 154/255, 154/255}
        local cx, cy = dungeon:getSpawnPointByImageColor(playerHitboxW, playerHitboxH, SPAWN_PADDING, spawnColor)
        if cx and cy then
            spawnX, spawnY = cx, cy
        end
    end
    if not spawnX then
        spawnX, spawnY = dungeon:getLeftmostSpawnPoint(playerHitboxW, playerHitboxH, SPAWN_PADDING)
    end
    if not spawnX then
        spawnX, spawnY = dungeon:getRandomSpawnPoint(playerHitboxW, playerHitboxH, SPAWN_PADDING)
    end
    if not spawnX then
        spawnX, spawnY = dungeon.width / 2, dungeon.height / 2
    end
    if not spawnX then
        print("Warning: Could not find a walkable spawn point.")
        return
    end

    spawnX, spawnY = dungeon:clampSpawnPoint(spawnX, spawnY, playerHitboxW, playerHitboxH, SPAWN_PADDING)

    if selectedClass == "wizard" then
        player = Wizard.new(spawnX, spawnY)
    else
        player = Knight:new(spawnX, spawnY)
    end

    local spawnColor = {154/255, 154/255, 154/255}
    local function getEnemySpawns(count, w, h)
        local spawnColor = floorSpawnColors[selectedDungeonIndex] or {154/255, 154/255, 154/255}
        if dungeon and dungeon.getSpawnPointsByImageColor then
            local spawns = dungeon:getSpawnPointsByImageColor(count, w, h, SPAWN_PADDING, spawnColor, spawnX, spawnY)
            if #spawns > 0 then
                return spawns
            end
        end
        return dungeon:getSpawnPointsOutsideSafeRoom(count, w, h, SPAWN_PADDING, spawnX, spawnY)
    end

    enemies = {}

    if selectedDungeonIndex == 1 and tutorialController and tutorialController:isActive() then
        -- spawn tutorial-specific enemies from the current stage
        local stage = tutorialController:getCurrentStage()
        if stage and stage.enemies then
            for _, e in ipairs(stage.enemies) do
                local ex, ey = e.x or 0, e.y or 0
                if e.type == "blue_slime" then table.insert(enemies, BlueSlime.new(ex, ey))
                elseif e.type == "red_slime" then table.insert(enemies, RedSlime.new(ex, ey))
                elseif e.type == "green_slime" then table.insert(enemies, GreenSlime.new(ex, ey))
                elseif e.type == "skeleton_archer" then table.insert(enemies, SkeletonArcher:new(ex, ey))
                elseif e.type == "skeleton_warrior" then table.insert(enemies, SkeletonWarrior:new(ex, ey))
                elseif e.type == "skeleton_spearman" then table.insert(enemies, SkeletonSpearman:new(ex, ey))
                end
            end
        end
    else
        local difficultyMultiplier = 1.0
        local hpMultiplier = 1.0
        if selectedDungeonIndex == 2 then difficultyMultiplier, hpMultiplier = 0.6, 0.9
        elseif selectedDungeonIndex == 3 then difficultyMultiplier, hpMultiplier = 1.0, 1.0
        elseif selectedDungeonIndex == 4 then difficultyMultiplier, hpMultiplier = 1.4, 1.25 end

        local slimeCount = math.max(1, math.floor(18 * difficultyMultiplier))
        local slimeSpawns = getEnemySpawns(slimeCount, BlueSlime.HITBOX_W, BlueSlime.HITBOX_H)
        local slimeClasses = { BlueSlime, RedSlime, GreenSlime }
        for i, pos in ipairs(slimeSpawns) do
            local classIndex = math.min(#slimeClasses, math.floor((i - 1) / math.max(1, math.floor(slimeCount / #slimeClasses))) + 1)
            local s = slimeClasses[classIndex].new(pos.x, pos.y)
            if s.hp then s.hp = math.floor((s.hp or 100) * hpMultiplier); s.maxHp = s.hp end
            table.insert(enemies, s)
        end

        local archerCount = math.max(1, math.floor(6 * difficultyMultiplier))
        local archerSpawns = getEnemySpawns(archerCount, SkeletonArcher.HITBOX_W, SkeletonArcher.HITBOX_H)
        for _, pos in ipairs(archerSpawns) do
            local s = SkeletonArcher:new(pos.x, pos.y)
            s.hp, s.maxHp = math.floor(250 * hpMultiplier), math.floor(250 * hpMultiplier)
            table.insert(enemies, s)
        end

        local warriorCount = math.max(1, math.floor(6 * difficultyMultiplier))
        local warriorSpawns = getEnemySpawns(warriorCount, SkeletonWarrior.HITBOX_W, SkeletonWarrior.HITBOX_H)
        for _, pos in ipairs(warriorSpawns) do
            local s = SkeletonWarrior:new(pos.x, pos.y)
            if s.hp then s.hp = math.floor((s.hp or 200) * hpMultiplier); s.maxHp = s.hp end
            table.insert(enemies, s)
        end

        local spearmanCount = math.max(1, math.floor(6 * difficultyMultiplier))
        local spearmanSpawns = getEnemySpawns(spearmanCount, SkeletonSpearman.HITBOX_W, SkeletonSpearman.HITBOX_H)
        for _, pos in ipairs(spearmanSpawns) do
            local s = SkeletonSpearman:new(pos.x, pos.y)
            s.hp, s.maxHp = math.floor(250 * hpMultiplier), math.floor(250 * hpMultiplier)
            table.insert(enemies, s)
        end
    end

    coins = {}
    local attemptedCoins = 0
    local roomThreshold = dungeon.tileSize * 5

    while #coins < COINS_REQUIRED and attemptedCoins < COINS_REQUIRED * 10 do
        attemptedCoins = attemptedCoins + 1
        local x, y = Spawner.getValidSpawnPoint(dungeon, Coin.w, Coin.h, SPAWN_PADDING, 50)
        if x and y then
            if x > roomThreshold and x < (dungeon.width - roomThreshold) then
                local duplicate = false
                for _, coin in ipairs(coins) do
                    if math.abs(coin.x - (x - Coin.w / 2)) < Coin.w and math.abs(coin.y - (y - Coin.h / 2)) < Coin.h then
                        duplicate = true
                        break
                    end
                end
                if not duplicate then table.insert(coins, Coin:new(x, y)) end
            end
        end
    end

    minimap = Minimap:new(dungeon)
    lighting = Lighting:new(player, dungeon)

    -- Initialize camera
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local worldScale = 3
    local playerCenterX, playerCenterY = player:getCenter()
    local startX = (playerCenterX * worldScale) - sw / 2
    local startY = (playerCenterY * worldScale) - sh / 2
    Camera:init(startX, startY)
    
    Audio:resetHeartbeat()

    if Audio:isPlaying("menu_music") then Audio:stop("menu_music") end
    Audio:play("background_music")
end

function love.load()
    math.randomseed(os.time())
    love.window.setFullscreen(true)
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    local function safelyLoadImage(path)
        if love.filesystem.getInfo(path) then return love.graphics.newImage(path) end
        return nil
    end

    isPaused = false
    projectiles = {}
    enemies = {}
    corpses = {}
    
    gFonts = {
        ["title"]  = love.graphics.newFont(120),
        ["button"] = love.graphics.newFont(40),
        ["hud"]    = love.graphics.newFont(20)
    }

    gTextures = {
        ["background"]     = safelyLoadImage("graphics/main-menu.png"),
        ["dungeon_layout"] = safelyLoadImage("graphics/dungeon.png"),
        ["knight_idle"]    = safelyLoadImage("knight/Idle.png"),
        ["knight_walk"]    = safelyLoadImage("knight/Walk.png"),
        ["knight_attack"]    = safelyLoadImage("knight/Attack 1.png"),
        ["knight_attack2"]   = safelyLoadImage("knight/Attack 2.png"),
        ["knight_attack3"]   = safelyLoadImage("knight/Attack 3.png"),
        ["knight_run_attack"] = safelyLoadImage("knight/Run+Attack.png"),
        ["knight_run"]       = safelyLoadImage("knight/Run.png"),
        ["knight_jump"]      = safelyLoadImage("knight/Jump.png"),
        ["knight_protect"]   = safelyLoadImage("knight/Protect.png"),
        ["knight_hurt"]      = safelyLoadImage("knight/Hurt.png"),
        ["knight_death"]     = safelyLoadImage("knight/Dead.png"),
        ["knight_defend"]    = safelyLoadImage("knight/Defend.png"),
        ["game_won"]       = safelyLoadImage("graphics/Game_Won.png"),
        ["wizard_idle"]    = safelyLoadImage("wizard/Idle.png"),
        ["wizard_walk"]    = safelyLoadImage("wizard/Walk.png"),
        ["wizard_attack"]  = safelyLoadImage("wizard/Attack_1.png"),
        ["wizard_death"]   = safelyLoadImage("wizard/Dead.png"),
        ["wizard_flame"]   = safelyLoadImage("wizard/Flame_jet.png"),
        ["wizard_fire"]    = safelyLoadImage("wizard/Fireball.png"),
        ["wizard_charge"]  = safelyLoadImage("wizard/Charge.png"),
        ["wizard_hurt"]    = safelyLoadImage("wizard/Hurt.png"),
        ["wizard_run"]     = safelyLoadImage("wizard/Run.png"),
        ["blue_slime_idle"]   = safelyLoadImage("Blue_slime/Idle.png"),
        ["blue_slime_walk"]   = safelyLoadImage("Blue_slime/Walk.png") or safelyLoadImage("Blue_slime/Hop.png"),
        ["blue_slime_attack"] = safelyLoadImage("Blue_slime/Attack_1.png"),
        ["blue_slime_hurt"]   = safelyLoadImage("Blue_slime/Hurt.png"),
        ["blue_slime_death"]  = safelyLoadImage("Blue_slime/Dead.png"),
        ["red_slime_idle"]    = safelyLoadImage("Red_slime/Idle.png"),
        ["red_slime_walk"]    = safelyLoadImage("Red_slime/Walk.png") or safelyLoadImage("Red_slime/Hop.png"),
        ["red_slime_attack"]  = safelyLoadImage("Red_slime/Attack_1.png"),
        ["red_slime_hurt"]    = safelyLoadImage("Red_slime/Hurt.png"),
        ["red_slime_death"]   = safelyLoadImage("Red_slime/Dead.png"),
        ["green_slime_idle"]  = safelyLoadImage("Green_slime/Idle.png"),
        ["green_slime_walk"]  = safelyLoadImage("Green_slime/Walk.png") or safelyLoadImage("Green_slime/Hop.png"),
        ["green_slime_attack"]= safelyLoadImage("Green_slime/Attack_1.png"),
        ["green_slime_hurt"]  = safelyLoadImage("Green_slime/Hurt.png"),
        ["green_slime_death"] = safelyLoadImage("Green_slime/Dead.png"),
        ["skeleton_archer_idle"]   = safelyLoadImage("Skeleton_Archer/Idle.png"),
        ["skeleton_archer_walk"]   = safelyLoadImage("Skeleton_Archer/Walk.png"),
        ["skeleton_archer_attack"] = safelyLoadImage("Skeleton_Archer/Shot_1.png"),
        ["skeleton_archer_death"]  = safelyLoadImage("Skeleton_Archer/Dead.png"),
        ["arrow"]                  = safelyLoadImage("Skeleton_Archer/arrow.png"),
        ["skeleton_warrior_idle"]   = safelyLoadImage("Skeleton_Warrior/Idle.png"),
        ["skeleton_warrior_walk"]   = safelyLoadImage("Skeleton_Warrior/Walk.png"),
        ["skeleton_warrior_attack"] = safelyLoadImage("Skeleton_Warrior/Attack_2.png"),
        ["skeleton_warrior_death"]  = safelyLoadImage("Skeleton_Warrior/Dead.png"),
        ["skeleton_spearman_idle"]   = safelyLoadImage("Skeleton_Spearman/Idle.png"),
        ["skeleton_spearman_walk"]   = safelyLoadImage("Skeleton_Spearman/Walk.png"),
        ["skeleton_spearman_attack"] = safelyLoadImage("Skeleton_Spearman/Attack_1.png") or safelyLoadImage("Skeleton_Spearman/Attack1.png"),
        ["skeleton_spearman_death"]  = safelyLoadImage("Skeleton_Spearman/Dead.png")
    }

    Coin.load()

    if gTextures["wizard_fire"] then
        gFrames["fireball_anim"] = {}
        for i = 0, 7 do
            table.insert(gFrames["fireball_anim"], love.graphics.newQuad(i * 128 + 80, 0, 48, 128, gTextures["wizard_fire"]:getDimensions()))
        end
    end

    jumpScareSounds = {}
    local jsFiles = { "Audios/Jumpscare1.mp3", "Audios/Jumpscare2.mp3" }
    for _, path in ipairs(jsFiles) do
        if love.filesystem.getInfo(path) then
            table.insert(jumpScareSounds, love.audio.newSource(path, "static"))
        end
    end
    Audio:load()
    Audio:addSound("victory_song", "Audios/victory_song.mp3", "static")

    mainMenu = Menu:new()
    Audio:play("menu_music")
end

-- Check win condition (Ender Portal)
function love.update(dt)
    -- Clamp dt to avoid huge jumps during window drag or load spikes.
    if dt > 0.1 then dt = 0.1 end
    Effect:update(dt)

    local hitstopActive = Effect:isHitstopActive()
    local updateDt = hitstopActive and dt * 0.25 or dt

    -- Allow the encounter to continue during hitstop so a single hit does not
    -- freeze the player and every other enemy in the room.
    if gameState == "play" and not player then
        startGame()
    end

    if gameState == "dead" then
        if player then
            player:update(updateDt, dungeon, gMouse, projectiles, {x = Camera:getPosition()}, enemies)
            Camera:update(updateDt, player)
            Audio:stopHeartbeat()
            if player.deadAnimationComplete then gameState = "gameover" end
        end
        return
    end

    if gameState == "play" and player and not isPaused then
        if minimap then minimap:update(player, enemies, coins, {x = Camera:getPosition()}, updateDt) end

        local projCountBefore = #projectiles
        player:update(updateDt, dungeon, gMouse, projectiles, {x = Camera:getPosition()}, enemies)

        for i = projCountBefore + 1, #projectiles do
            local p = projectiles[i]
            if p.type ~= "arrow" and (p.owner == "player" or p.owner == player) then
                Audio:play("fireball")
            end
        end

        Camera:update(updateDt, player)
        Audio:updateHeartbeat(dt, player, gameState)
        if lighting then lighting:update(updateDt) end

        if enemies then
            for i = #enemies, 1, -1 do
                local enemy = enemies[i]
                local projectileCountBefore = #projectiles
                enemy:update(updateDt, player, dungeon, projectiles)
                
                for pIdx = projectileCountBefore + 1, #projectiles do
                    local p = projectiles[pIdx]
                    if p.type ~= "arrow" and (p.owner == "player" or p.owner == player) then
                        Audio:play("fireball")
                    end
                end
                
                if enemy.caught and gameState == "play" then
                    gameState = "dead"
                    Audio:stop("background_music")
                    if #jumpScareSounds > 0 then
                        local s = jumpScareSounds[math.random(#jumpScareSounds)]
                        s:stop()
                        love.audio.play(s)
                    end
                end

                local shouldApplyMeleeHit = false
                if player and player.state and (player.state == "attack" or player.state == "run_attack") and enemy.hp > 0 then
                    if selectedClass == "wizard" then
                        if player.attackHitDone == nil then player.attackHitDone = false end
                        if player.frame >= 2 and not player.attackHitDone then
                            shouldApplyMeleeHit = true
                            player.attackHitDone = true
                        end
                    elseif player.frame == 2 then
                        shouldApplyMeleeHit = true
                    end
                elseif player and player.attackHitDone and player.state ~= "attack" and player.state ~= "run_attack" then
                    player.attackHitDone = false
                end

                if shouldApplyMeleeHit then
                    local px, py = player:getCenter()
                    local ex, ey = enemy.x + (enemy.w or 0) / 2, enemy.y + (enemy.h or 0) / 2
                    if enemy.getCenter then ex, ey = enemy:getCenter() end

                    local dx, dy = px - ex, py - ey
                    local distSq = dx*dx + dy*dy
                    if distSq < 1000 then
                        local kbMult = (selectedClass == "wizard") and 0.5 or 1.0
                        enemy:takeDamage(player.damage, player, dungeon, kbMult)

                        Effect:triggerHitstop(0.06)
                        Effect:triggerShake(0.15, 2)
                        Effect:spawnParticles(ex, ey, {1, 0.2, 0.2, 1}, 6)
                    end
                end

                local isDeadAnimComplete = enemy.deadAnimationComplete
                if type(isDeadAnimComplete) == "boolean" and isDeadAnimComplete then
                    local _, _, qw, qh = 0, 0, 0, 0
                    if enemy.quad then _, _, qw, qh = enemy.quad:getViewport() end

                    table.insert(corpses, {
                        texture = enemy.texture, quad = enemy.quad,
                        x = enemy.x, y = enemy.y,
                        w = enemy.w or 20, h = enemy.h or 30,
                        direction = enemy.direction,
                        displayScale = enemy.displayScale or 1.0,
                        frameWidth = enemy.frameWidth or qw,
                        frameHeight = enemy.frameHeight or qh,
                    })
                    
                    Effect:triggerShake(0.2, 3)
                    Effect:spawnParticles(enemy.x + (enemy.w or 20)/2, enemy.y + (enemy.h or 30)/2, {0.5, 0.1, 0.1, 1}, 12)
                    
                    table.remove(enemies, i)
                end
            end
        end

        if player then
            local dynamicEntities = {player}
            if enemies then
                for _, enemy in ipairs(enemies) do
                    table.insert(dynamicEntities, enemy)
                end
            end
            Movement.resolveAabbCollisions(dynamicEntities, 2)
        end

        local coinsBefore = player.coins
        Coin.updateAll(coins, dt, player)
        if player.coins ~= coinsBefore then
            coinsCollected = math.min(player.coins, COINS_REQUIRED)
            player.coins = coinsCollected
        end

        for i = #projectiles, 1, -1 do
            local p = projectiles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.life = (p.life or 3) - dt
            
            p.timer = (p.timer or 0) + dt
            if p.frame and p.timer > 0.08 then
                p.timer = 0
                p.frame = (p.frame % 8) + 1
            end

            if p.life <= 0 or dungeon:isBlocked(p.x, p.y) or p.x < 0 or p.y < 0 or p.x > dungeon.width or p.y > dungeon.height then
                table.remove(projectiles, i)
            else
                local removed = false
                
                if p.owner ~= "player" then
                    local ppx, ppy = player:getCenter()
                    local pdx = p.x - ppx
                    local pdy = p.y - ppy
                    if pdx*pdx + pdy*pdy < 100 and player.hp > 0 and (player.invuln or 0) <= 0 then
                        player:takeDamage(15, p.owner, dungeon)
                        
                        Effect:triggerHitstop(0.1)
                        Effect:triggerShake(0.3, 4)
                        Effect:spawnParticles(ppx, ppy, {1, 0, 0, 1}, 10)
                        
                        table.remove(projectiles, i)
                        removed = true
                    end
                end

                if not removed and p.owner == "player" then
                    for j = #enemies, 1, -1 do
                        local e = enemies[j]
                        local ex, ey = e.x + (e.w or 0) / 2, e.y + (e.h or 0) / 2
                        if e.getCenter then ex, ey = e:getCenter() end
                        
                        local pdx = p.x - ex
                        local pdy = p.y - ey
                        if pdx*pdx + pdy*pdy < 400 and e.hp > 0 and (e.invuln or 0) <= 0 then
                            local kbMult = (selectedClass == "wizard") and 1.5 or 1.0
                            e:takeDamage(player.damage or 40, player, dungeon, kbMult)
                            
                            Effect:triggerHitstop(0.03)
                            Effect:triggerShake(0.1, 1)
                            Effect:spawnParticles(ex, ey, {1, 0.5, 0, 1}, 5)
                            
                            table.remove(projectiles, i)
                            removed = true
                            break
                        end
                    end
                end
            end
        end

        if player and player.hp <= 0 and gameState == "play" then
            gameState = "dead"
            Audio:stop("background_music")
            Audio:stopHeartbeat()
            
            if #jumpScareSounds > 0 then
                local s = jumpScareSounds[math.random(#jumpScareSounds)]
                s:play()
            end
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        if gameState == "play" then
            isPaused = not isPaused
        else
            love.event.quit()
        end
    elseif key == "p" and gameState == "play" then
        isPaused = not isPaused
    elseif key == "x" and gameState == "play" and minimap then
        minimap:setPositionNext()
    elseif key == "c" and gameState == "play" and player then
        coinsCollected = math.min(coinsCollected + 1, COINS_REQUIRED)
        player.coins = coinsCollected
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and not isPaused then gMouse.leftDown = true end
    if button == 2 then gMouse.rightDown = true end

    if gameState == "play" and isPaused and button == 1 then
        local sw, sh = love.graphics.getDimensions()
        local btnW, btnH = 300, 68
        local bx = (sw - btnW) / 2
        local py = sh * 0.18
        local resumeY = py + 140
        local restartY = py + 218
        local changeRoleY = py + 296
        local quitY = py + 374

        if UI:isWithinRect(x, y, bx, resumeY, btnW, btnH) then
            isPaused = false
            return
        elseif UI:isWithinRect(x, y, bx, restartY, btnW, btnH) then
            isPaused = false
            player = nil
            dungeon = nil
            enemies = {}
            coins = {}
            corpses = {}
            projectiles = {}
            startGame()
            return
        elseif UI:isWithinRect(x, y, bx, changeRoleY, btnW, btnH) then
            isPaused = false
            gameState = "selection"
            player = nil
            dungeon = nil
            enemies = {}
            coins = {}
            corpses = {}
            projectiles = {}
            return
        elseif UI:isWithinRect(x, y, bx, quitY, btnW, btnH) then
            love.event.quit()
            return
        end
    end

    if gameState == "menu" and button == 1 then
        local choice = mainMenu:checkClick(x, y)
        if choice and mainMenu:handleInput(choice) then
            gameState = "selection" 
        end
    elseif gameState == "selection" and button == 1 then
        local sw, sh = love.graphics.getDimensions()
        local diffW, diffH = 120, 50
        local diffSpacing = 16
        local diffX = (sw - (4 * diffW + 3 * diffSpacing)) / 2
        local diffY = sh * 0.08 + 130

        for i = 1, 4 do
            local bx = diffX + (i - 1) * (diffW + diffSpacing)
            if UI:isWithinRect(x, y, bx, diffY, diffW, diffH) then
                Audio:play("button_click")
                selectedDungeonIndex = i
                return
            end
        end

        local btnW, btnH = 320, 82
        local bx = (sw - btnW) / 2
        local py = sh * 0.08

        if UI:isWithinRect(x, y, bx, py + 240, btnW, btnH) then
            Audio:play("button_click")
            selectedClass = "knight"
            gameState = "play"
            startGame()
        elseif UI:isWithinRect(x, y, bx, py + 340, btnW, btnH) then
            Audio:play("button_click")
            selectedClass = "wizard"
            gameState = "play"
            startGame()
        end
    elseif (gameState == "gameover" or gameState == "dead") and button == 1 then
        local sw, sh = love.graphics.getDimensions()
        local btnW, btnH = 320, 80
        local bx = (sw - btnW) / 2
        local ry = sh * 0.5

        if UI:isWithinRect(x, y, bx, ry, btnW, btnH) then
            Audio:play("button_click")
            Audio:stop("background_music")
            player = nil
            dungeon = nil
            enemies = {}
            coins = {}
            corpses = {}
            projectiles = {}
            isPaused = false
            coinsCollected = 0
            gameState = "play"
        elseif UI:isWithinRect(x, y, bx, ry + 100, btnW, btnH) then
            Audio:play("button_click")
            love.event.quit()
        end
    end
end

function love.mousereleased(_, _, button)
    if button == 1 then gMouse.leftDown = false end
    if button == 2 then gMouse.rightDown = false end
end

function love.draw()
    love.graphics.clear(0.05, 0.05, 0.05)
    love.graphics.setColor(1, 1, 1, 1)

    if gameState == "menu" then
        if mainMenu then mainMenu:render() end
    elseif gameState == "selection" then
        local sw, sh = love.graphics.getDimensions()
        UI:drawSelectionButtons(sw, sh, gFonts, selectedDungeonIndex)
    elseif gameState == "play" or gameState == "dead" then
        
        local sx, sy = Effect:getShakeOffset()
        local camX, camY = Camera:getPosition()

        love.graphics.push()
        love.graphics.scale(3, 3)
        love.graphics.translate(math.floor(-camX / 3 + sx + 0.5), math.floor(-camY / 3 + sy + 0.5))

        if dungeon and type(dungeon.render) == "function" then dungeon:render() end
        if coins then Coin.drawAll(coins) end

        love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
        for _, c in ipairs(corpses) do
            if c.texture and c.quad then
                local scaleX = (c.direction == "right" and 1 or -1) * c.displayScale
                local pivotX = c.x + c.w / 2
                local pivotY = c.y + c.h
                local ox = (c.frameWidth and c.frameWidth > 0) and (c.frameWidth / 2) or 0
                local oy = (c.frameHeight and c.frameHeight > 0) and c.frameHeight or 0
                if c.frameData then ox, oy = c.frameData.originX, c.frameData.originY end
                love.graphics.draw(c.texture, c.quad, pivotX, pivotY, 0, scaleX, c.displayScale, ox, oy)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)

        if enemies then
            for _, e in ipairs(enemies) do
                if e and type(e.render) == "function" then
                    e:render()
                    if e.subType ~= "slime" and e.subType ~= "skeleton" and e.hp and e.maxHp and e.hp < e.maxHp and e.hp > 0 then
                        love.graphics.setColor(0, 0, 0, 0.5)
                        love.graphics.rectangle("fill", e.x, e.y - 10, e.w or 20, 3)
                        love.graphics.setColor(0, 1, 0)
                        love.graphics.rectangle("fill", e.x, e.y - 10, (e.w or 20) * (e.hp / e.maxHp), 3)
                        love.graphics.setColor(1, 1, 1)
                    end
                end
            end
        end

        if player and type(player.render) == "function" then player:render() end

        for _, p in ipairs(projectiles) do
            local tex, anim = gTextures["wizard_fire"], gFrames["fireball_anim"]
            if p.type == "arrow" then
                local arrowTex = gTextures["arrow"]
                if arrowTex then
                    love.graphics.draw(arrowTex, p.x, p.y, p.angle, 0.2, 0.2, arrowTex:getWidth() / 2, arrowTex:getHeight() / 2)
                end
            else
                if tex and anim and anim[p.frame] then
                    love.graphics.draw(tex, anim[p.frame], p.x, p.y, p.angle, 0.5, 0.5, 24, 64)
                end
            end
        end

        Effect:drawParticles()

        love.graphics.pop()

        if lighting and player then lighting:render(camX, camY, 3) end

        if player then player:drawHUD() end
        if minimap and player then minimap:draw() end

        if isPaused then
            local sw, sh = love.graphics.getDimensions()
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("fill", 0, 0, sw, sh)
            UI:drawPauseMenu(sw, sh, gFonts)
        end
    end

    if gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setFont(gFonts["title"])
        love.graphics.printf("YOU DIED", 0, love.graphics.getHeight()*0.2, love.graphics.getWidth(), "center")
        local sw, sh = love.graphics.getDimensions()
        UI:drawRetryQuitButtons(sw, sh, gFonts)
    end
end