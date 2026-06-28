-- sprite_anim.lua
-- Cached quad creation for sprite animations
local SpriteAnim = {}

function SpriteAnim.updateQuad(entity, stateKey)
    stateKey = stateKey or entity.state
    if entity._quadFrame == entity.frame and entity._quadState == stateKey and entity.quad then
        return
    end

    if not entity.texture then
        entity.quad = nil
        return
    end

    local sw, sh = entity.texture:getDimensions()
    local frameWidth = entity.frameWidth or 128
    local frameHeight = entity.frameHeight or 128
    entity.quad = love.graphics.newQuad(
        entity.frame * frameWidth,
        0,
        frameWidth,
        frameHeight,
        sw,
        sh
    )
    entity._quadFrame = entity.frame
    entity._quadState = stateKey
end

return SpriteAnim
