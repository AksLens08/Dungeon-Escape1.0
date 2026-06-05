-- audio.lua
local Audio = {}
local sounds = {}

function Audio:load()
    sounds = {
        ["menu_music"]        = love.audio.newSource("Audios/dungeon.mp3", "stream"),
        ["dungeon_music"]     = love.audio.newSource("Audios/dungeon.mp3", "stream"),
        ["background_music"]  = love.audio.newSource("Audios/background_music.mp3", "stream"),
        ["coin_collect"]      = love.audio.newSource("Audios/coin-collect.wav", "static"),
        ["button_click"]  = love.audio.newSource("Audios/click.mp3", "static"),
        ["knight_hurt"]   = love.audio.newSource("Audios/taking_damage.mp3", "static"),
        ["shield_hit"]    = love.audio.newSource("Audios/shield.mp3", "static"),
        ["wizard_hurt"]   = love.audio.newSource("Audios/wizard_hurt.mp3", "static"),
        ["footsteps"]     = love.audio.newSource("Audios/footsteps.mp3", "static"),
        ["sword_slice"]   = love.audio.newSource("Audios/sword_slice.mp3", "static")
    }
    
    sounds["menu_music"]:setLooping(true)
    sounds["dungeon_music"]:setLooping(true)
    sounds["background_music"]:setLooping(true)
    sounds["menu_music"]:setVolume(0.8)
    sounds["dungeon_music"]:setVolume(0.8)
    sounds["background_music"]:setVolume(1.0)
    sounds["coin_collect"]:setVolume(0.2)
    sounds["shield_hit"]:setVolume(0.6) -- Ensure shield hit is audible
    sounds["wizard_hurt"]:setVolume(0.2)

    sounds["footsteps"]:setLooping(true)
    sounds["footsteps"]:setVolume(0.2)
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
