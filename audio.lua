-- audio.lua
local Audio = {}
local sounds = {}

function Audio:load()
    sounds = {
        ["menu_music"]    = love.audio.newSource("song1.mp3", "stream"),
        ["dungeon_music"] = love.audio.newSource("dungeon.mp3", "stream"),
        ["coin_collect"]  = love.audio.newSource("coin-collect.wav", "static"),
        ["button_click"]  = love.audio.newSource("click.mp3", "static"),
        ["knight_hurt"]   = love.audio.newSource("taking_damage.mp3", "static"), -- Mapped to taking_damage.mp3
        ["shield_hit"]    = love.audio.newSource("shield.mp3", "static"),        -- Mapped to shield.mp3
        ["wizard_hurt"]   = love.audio.newSource("wizard_hurt.mp3", "static"),
        ["footsteps"]     = love.audio.newSource("footsteps.mp3", "static")
    }
    
    sounds["menu_music"]:setLooping(true)
    sounds["dungeon_music"]:setLooping(true)
    sounds["menu_music"]:setVolume(0.5)
    sounds["dungeon_music"]:setVolume(0.5)
    sounds["coin_collect"]:setVolume(0.5)
    sounds["shield_hit"]:setVolume(0.8) -- Ensure shield hit is audible

    sounds["footsteps"]:setLooping(true)
end

function Audio:play(name)
    local s = sounds[name]
    if s then
        if s:isLooping() then
            s:play()
        else
            -- Clone the source for SFX to allow overlapping and prevent cutoff
            local instance = s:clone()
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

return Audio