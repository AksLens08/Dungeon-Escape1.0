-- audio.lua
-- Sound manager
local Audio = {}
local sounds = {}
local activeClones = {}
local MAX_ACTIVE_CLONES = 32

-- Heartbeat system variables
local heartbeatTimer = 0
local heartbeatInterval = 1.0
local heartbeatActive = false
local musicVolumeBefore = 1.0

function Audio:load()
    -- Load SFX/Music
    sounds = {
        ["menu_music"]        = love.audio.newSource("Audios/dungeon.mp3", "stream"),
        ["dungeon_music"]     = love.audio.newSource("Audios/dungeon.mp3", "stream"),
        ["background_music"]  = love.audio.newSource("Audios/background_music.mp3", "stream"),
        ["coin_collect"]      = love.audio.newSource("Audios/coin-collect.wav", "static"),
        ["button_click"]      = love.audio.newSource("Audios/click.mp3", "static"),
        ["knight_hurt"]       = love.audio.newSource("Audios/taking_damage.mp3", "static"),
        ["shield_hit"]        = love.audio.newSource("Audios/shield.mp3", "static"),
        ["hurt"]              = love.audio.newSource("Audios/hurt.mp3", "static"),
        ["footsteps"]         = love.audio.newSource("Audios/footsteps.mp3", "static"),
        ["sword_slice"]       = love.audio.newSource("Audios/sword_slice.mp3", "static"),
        ["fireball"]          = love.audio.newSource("Audios/fireball.mp3", "static"),
        ["slime_hurt"]        = love.audio.newSource("Audios/slime_hurt.mp3", "static"),
        ["heartbeat"]         = love.audio.newSource("Audios/heartbeat.mp3", "static")
    }
    
    sounds["menu_music"]:setLooping(true)
    sounds["dungeon_music"]:setLooping(true)
    sounds["background_music"]:setLooping(true)
    sounds["menu_music"]:setVolume(0.8)
    sounds["dungeon_music"]:setVolume(0.8)
    sounds["background_music"]:setVolume(1.0)
    sounds["coin_collect"]:setVolume(0.2)
    sounds["shield_hit"]:setVolume(0.6)
    sounds["hurt"]:setVolume(0.2)
    sounds["fireball"]:setVolume(0.2)
    sounds["slime_hurt"]:setVolume(0.3)
    sounds["footsteps"]:setLooping(true)
    sounds["footsteps"]:setVolume(0.2)
    sounds["heartbeat"]:setVolume(0.8)
end

function Audio:addSound(name, path, type)
    -- Add sound
    local success, source = pcall(love.audio.newSource, path, type or "static")
    if success then
        sounds[name] = source
    else
        print("Warning: Failed to load sound: " .. tostring(path))
    end
end

function Audio:play(name)
    -- SFX instances
    for i = #activeClones, 1, -1 do
        if not activeClones[i]:isPlaying() then
            table.remove(activeClones, i)
        end
    end

    local s = sounds[name]
    if s then
        if s:isLooping() then
            s:play()
        elseif #activeClones < MAX_ACTIVE_CLONES then
            local success, instance = pcall(function() return s:clone() end)
            if not success then return end
            
            instance:setVolume(s:getVolume())
            instance:setPitch(s:getPitch())
            
            table.insert(activeClones, instance)
            instance:play()
        end
    end
end

function Audio:stop(name)
    if sounds[name] then
        sounds[name]:stop()
    end
end

function Audio:isPlaying(name)
    if sounds[name] then
        return sounds[name]:isPlaying()
    end
    return false
end

function Audio:setVolume(name, volume)
    if sounds[name] then
        sounds[name]:setVolume(volume)
    end
end

function Audio:getVolume(name)
    if sounds[name] then
        return sounds[name]:getVolume()
    end
    return 0
end

-- Heartbeat system methods
function Audio:updateHeartbeat(dt, player, gameState)
    if not player then return end
    
    local hpPercent = player.hp / player.maxHp
    
    if hpPercent < 0.3 and hpPercent > 0 and gameState == "play" then
        if not heartbeatActive then
            heartbeatActive = true
            heartbeatTimer = 0
            musicVolumeBefore = self:getVolume("background_music")
            self:setVolume("background_music", 0.3)
        end
        
        local bpm = 60 + ((0.3 - hpPercent) / 0.3) * 80
        heartbeatInterval = 60 / bpm
        heartbeatTimer = heartbeatTimer + dt
        
        if heartbeatTimer >= heartbeatInterval then
            heartbeatTimer = 0
            self:play("heartbeat")
        end
    else
        if heartbeatActive then
            heartbeatActive = false
            heartbeatTimer = 0
            self:setVolume("background_music", musicVolumeBefore)
        end
    end
end

function Audio:stopHeartbeat()
    if heartbeatActive then
        heartbeatActive = false
        heartbeatTimer = 0
        self:setVolume("background_music", musicVolumeBefore)
    end
end

function Audio:resetHeartbeat()
    heartbeatActive = false
    heartbeatTimer = 0
end

return Audio