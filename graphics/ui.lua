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
    local panelW, panelH = 520, 360
    local px, py = (sw - panelW) / 2, sh * 0.28
    drawPanel(px, py, panelW, panelH, 0.09, 0.11, 0.15, 0.95, 0.72, 0.55, 0.18)

    -- Panel heading: confined to the panel and use a smaller font
    love.graphics.setFont(fonts["hud"])
    love.graphics.setColor(1, 0.9, 0.6)
    love.graphics.printf("CONTINUE?", px, py + 28, panelW, "center")

    love.graphics.setFont(fonts["hud"])
    love.graphics.setColor(0.86, 0.86, 0.86)
    love.graphics.printf("Choose your next move", px, py + 84, panelW, "center")

    local btnW, btnH = 340, 84
    local bx = px + (panelW - btnW) / 2
    drawButton(bx, py + 140, btnW, btnH, "RETRY", 0.18, 0.26, 0.34, 1, 1, 1, 0.92, 0.74, 0.27, fonts)
    drawButton(bx, py + 236, btnW, btnH, "QUIT", 0.26, 0.16, 0.16, 1, 1, 1, 0.9, 0.5, 0.3, fonts)
    return px, py, panelW, panelH
end

function UI:drawPauseMenu(sw, sh, fonts)
    local panelW, panelH = 420, 450
    local px, py = (sw - panelW) / 2, sh * 0.18
    drawPanel(px, py, panelW, panelH, 0.08, 0.09, 0.12, 0.96, 0.72, 0.55, 0.18)

    -- Confine heading and subtitle inside the panel to avoid overlapping
    love.graphics.setFont(fonts["hud"])
    love.graphics.setColor(1, 0.9, 0.6)
    love.graphics.printf("PAUSED", px, py + 20, panelW, "center")

    love.graphics.setFont(fonts["hud"])
    love.graphics.setColor(0.86, 0.86, 0.86)
    love.graphics.printf("Choose an option", px, py + 64, panelW, "center")

    local btnW, btnH = 300, 68
    local bx = (sw - btnW) / 2
    drawButton(bx, py + 140, btnW, btnH, "RESUME", 0.2, 0.4, 0.2, 1, 1, 1, 0.6, 0.9, 0.6, fonts)
    drawButton(bx, py + 218, btnW, btnH, "RESTART", 0.18, 0.26, 0.34, 1, 1, 1, 0.92, 0.74, 0.27, fonts)
    drawButton(bx, py + 296, btnW, btnH, "CHANGE ROLE", 0.24, 0.18, 0.28, 1, 1, 1, 0.9, 0.58, 0.95, fonts)
    drawButton(bx, py + 374, btnW, btnH, "QUIT", 0.26, 0.16, 0.16, 1, 1, 1, 0.9, 0.5, 0.3, fonts)
end

function UI:drawSelectionButtons(sw, sh, fonts, selectedDungeonIndex)
    local panelW, panelH = 560, 460
    local px, py = (sw - panelW) / 2, sh * 0.08
    drawPanel(px, py, panelW, panelH, 0.09, 0.11, 0.15, 0.95, 0.72, 0.55, 0.18)

    love.graphics.setFont(fonts["hud"])
    love.graphics.setColor(0.84, 0.84, 0.84)
    love.graphics.printf("Choose a difficulty and champion to begin", 0, py + 60, sw, "center")

    local levels = {"TUTORIAL", "EASY", "MEDIUM", "HARD"}
    local diffW, diffH = 120, 50
    local diffSpacing = 16
    local diffX = (sw - (#levels * diffW + (#levels - 1) * diffSpacing)) / 2
    local diffY = py + 130

    for i, label in ipairs(levels) do
        local bx = diffX + (i - 1) * (diffW + diffSpacing)
        local isActive = (selectedDungeonIndex == i)
        local fillR, fillG, fillB = 0.12, 0.14, 0.18
        local accentR, accentG, accentB = 0.7, 0.6, 0.3
        if isActive then
            fillR, fillG, fillB = 0.24, 0.28, 0.37
            accentR, accentG, accentB = 0.96, 0.82, 0.42
        end
        drawButton(bx, diffY, diffW, diffH, label, fillR, fillG, fillB, 1, 1, 1, accentR, accentG, accentB, fonts, "hud")
    end

    local btnW, btnH = 320, 82
    local bx = (sw - btnW) / 2
    drawButton(bx, py + 240, btnW, btnH, "KNIGHT", 0.16, 0.2, 0.28, 1, 1, 1, 0.92, 0.74, 0.27, fonts)
    drawButton(bx, py + 340, btnW, btnH, "WIZARD", 0.24, 0.18, 0.3, 1, 1, 1, 0.9, 0.58, 0.95, fonts)
end

function UI:isWithinRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

return UI