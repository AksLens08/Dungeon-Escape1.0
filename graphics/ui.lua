-- graphics/ui.lua
-- UI drawing functions
local UI = {}

local function drawPanel(x, y, w, h, fillR, fillG, fillB, fillA, outlineR, outlineG, outlineB)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x + 8, y + 8, w, h, 14)

    love.graphics.setColor(fillR, fillG, fillB, fillA or 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 14)

    love.graphics.setLineWidth(3)
    love.graphics.setColor(outlineR or 0.86, outlineG or 0.69, outlineB or 0.24)
    love.graphics.rectangle("line", x, y, w, h, 14)
    love.graphics.setLineWidth(1)
end

local function drawButton(x, y, w, h, label, fillR, fillG, fillB, textR, textG, textB, accentR, accentG, accentB, fonts, fontName)
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", x + 6, y + 6, w, h, 10)

    love.graphics.setColor(fillR, fillG, fillB, 0.96)
    love.graphics.rectangle("fill", x, y, w, h, 10)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(accentR or 0.95, accentG or 0.85, accentB or 0.45)
    love.graphics.rectangle("line", x, y, w, h, 10)
    love.graphics.setLineWidth(1)

    local fontKey = fontName or "button"
    love.graphics.setFont(fonts[fontKey])
    love.graphics.setColor(textR or 1, textG or 1, textB or 1)
    love.graphics.printf(label, x, y + 20, w, "center")
end

function UI:drawRetryQuitButtons(sw, sh, fonts)
    local panelW, panelH = 420, 240
    local px, py = (sw - panelW) / 2, sh * 0.32
    drawPanel(px, py, panelW, panelH, 0.09, 0.11, 0.15, 0.95, 0.72, 0.55, 0.18)

    love.graphics.setFont(fonts["title"])
    love.graphics.setColor(1, 0.9, 0.6)
    love.graphics.printf("CONTINUE?", 0, py + 24, sw, "center")

    love.graphics.setFont(fonts["hud"])
    love.graphics.setColor(0.86, 0.86, 0.86)
    love.graphics.printf("Choose your next move", 0, py + 96, sw, "center")

    local btnW, btnH = 280, 70
    local bx = (sw - btnW) / 2
    drawButton(bx, py + 124, btnW, btnH, "RETRY", 0.18, 0.26, 0.34, 1, 1, 1, 0.92, 0.74, 0.27, fonts)
    drawButton(bx, py + 206, btnW, btnH, "QUIT", 0.26, 0.16, 0.16, 1, 1, 1, 0.9, 0.5, 0.3, fonts)
end

function UI:drawSelectionButtons(sw, sh, fonts)
    local panelW, panelH = 560, 400
    local px, py = (sw - panelW) / 2, sh * 0.12
    drawPanel(px, py, panelW, panelH, 0.09, 0.11, 0.15, 0.95, 0.72, 0.55, 0.18)

    love.graphics.setFont(fonts["hud"])
    love.graphics.setColor(0.84, 0.84, 0.84)
    love.graphics.printf("Choose a champion to begin your dungeon run", 0, py + 70, sw, "center")

    local btnW, btnH = 320, 82
    local bx = (sw - btnW) / 2
    drawButton(bx, py + 162, btnW, btnH, "KNIGHT", 0.16, 0.2, 0.28, 1, 1, 1, 0.92, 0.74, 0.27, fonts)
    drawButton(bx, py + 262, btnW, btnH, "WIZARD", 0.24, 0.18, 0.3, 1, 1, 1, 0.9, 0.58, 0.95, fonts)
end

function UI:drawTutorialChoiceButtons(sw, sh, fonts)
    local panelW, panelH = 560, 400
    local px, py = (sw - panelW) / 2, sh * 0.12
    drawPanel(px, py, panelW, panelH, 0.08, 0.12, 0.14, 0.95, 0.72, 0.55, 0.18)

    love.graphics.setFont(fonts["hud"])
    love.graphics.setColor(0.84, 0.84, 0.84)
    love.graphics.printf("Practice the basics or jump straight into the dungeon", 0, py + 70, sw, "center")

    local btnW, btnH = 360, 82
    local bx = (sw - btnW) / 2
    drawButton(bx, py + 162, btnW, btnH, "YES, SKIP", 0.24, 0.24, 0.24, 1, 1, 1, 0.9, 0.55, 0.3, fonts, "hud")
    drawButton(bx, py + 262, btnW, btnH, "NO, SHOW TUTORIAL", 0.16, 0.24, 0.18, 1, 1, 1, 0.72, 0.9, 0.5, fonts, "hud")
end

function UI:isWithinRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

return UI