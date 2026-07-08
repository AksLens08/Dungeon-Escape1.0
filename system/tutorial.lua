-- system/tutorial.lua
-- Two-stage tutorial controller for static linear dungeon rooms
local Tutorial = {}
Tutorial.__index = Tutorial

local function makeRoom(x, y, w, h)
    return {x = x, y = y, w = w, h = h}
end

local function makeLayout(rooms, connections, exitRoom)
    return {
        rooms = rooms,
        connections = connections or {},
        exitRoom = exitRoom or 1,
    }
end

function Tutorial:new(heroType)
    local self = setmetatable({}, Tutorial)
    self.heroType = heroType or "knight"
    self.active = false
    self.finished = false
    self.currentStageIndex = 1
    self.promptTimer = 0
    self.promptText = ""
    self.stages = {
        {
            id = "intro",
            title = "First Steps",
            prompt = "Use WASD to move around the room. Left click to attack, and defeat the slime before you step through the portal.",
            layout = makeLayout({makeRoom(220, 240, 320, 260)}, {}, nil),
            enemies = {
                {type = "blue_slime", x = 380, y = 340},
            },
            portalUnlocked = false,
        },
        {
            id = "red_slime",
            title = "Red Slime",
            prompt = "The red slime is more aggressive. Keep your footing and punish it when it commits to a charge.",
            layout = makeLayout({makeRoom(760, 240, 320, 260)}, {}, nil),
            enemies = {
                {type = "red_slime", x = 900, y = 340},
            },
            portalUnlocked = false,
        },
        {
            id = "green_slime",
            title = "Green Slime",
            prompt = "The green slime is patient. Wait for a clean opening and strike once it gives you one.",
            layout = makeLayout({makeRoom(220, 240, 320, 260)}, {}, nil),
            enemies = {
                {type = "green_slime", x = 380, y = 340},
            },
            portalUnlocked = false,
        },
        {
            id = "archer",
            title = self.heroType == "wizard" and "Wizard Ranged Trial" or "Archer Trial",
            prompt = self.heroType == "wizard"
                and "This foe fights from range. Keep moving, time your sword swing, and press the attack when the opening appears."
                or "This archer fights from range. Keep moving, time your attack, and punish the opening after its shot.",
            layout = makeLayout({makeRoom(760, 240, 320, 260)}, {}, nil),
            enemies = {
                {type = "skeleton_archer", x = 900, y = 340},
            },
            portalUnlocked = false,
        },
        {
            id = "warrior",
            title = "Warrior",
            prompt = "The warrior is sturdy. Stay mobile and strike after its swings so you do not get pinned down.",
            layout = makeLayout({makeRoom(220, 240, 320, 260)}, {}, nil),
            enemies = {
                {type = "skeleton_warrior", x = 380, y = 340},
            },
            portalUnlocked = false,
        },
        {
            id = "spearman",
            title = "Spearman",
            prompt = "The spearman controls space with reach. Keep your movement tight and punish the moment it overcommits.",
            layout = makeLayout({makeRoom(760, 240, 320, 260)}, {}, nil),
            enemies = {
                {type = "skeleton_spearman", x = 900, y = 340},
            },
            portalUnlocked = false,
        },
    }
    return self
end

function Tutorial:start()
    self.currentStageIndex = 1
    self.active = true
    self.finished = false
    self.promptTimer = 4.5
    self.promptText = self:getCurrentStage().prompt or ""
    return self:getCurrentStage()
end

function Tutorial:getCurrentStage()
    return self.stages[self.currentStageIndex]
end

function Tutorial:getCurrentStageIndex()
    return self.currentStageIndex
end

function Tutorial:getStage(index)
    return self.stages[index]
end

function Tutorial:isActive()
    return self.active and not self.finished
end

function Tutorial:advance()
    if self.currentStageIndex >= #self.stages then
        self.active = false
        self.finished = true
        self.promptText = "Tutorial complete."
        self.promptTimer = 3.5
        return false
    end

    self.currentStageIndex = self.currentStageIndex + 1
    self.promptTimer = 4.5
    self.promptText = self:getCurrentStage().prompt or ""
    return true
end

function Tutorial:update(dt)
    if self.promptTimer and self.promptTimer > 0 then
        self.promptTimer = self.promptTimer - dt
    end
end

function Tutorial:drawOverlay(font)
    if not self.active or not self.promptText or self.promptTimer <= 0 then return end

    local sw, sh = love.graphics.getDimensions()
    local boxX, boxY = 44, math.max(20, sh - 172)
    local boxW, boxH = sw - 88, 128
    local title = self:getCurrentStage().title or "Tutorial"
    local prompt = self.promptText or ""

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 12)
    love.graphics.setColor(0.95, 0.8, 0.25, 0.95)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 12)

    love.graphics.setColor(1, 1, 1, 1)
    if font then love.graphics.setFont(font) end
    love.graphics.printf(string.format("[%s/%s] %s", self.currentStageIndex, #self.stages, title), boxX + 20, boxY + 20, boxW - 40, "center")

    love.graphics.setColor(0.92, 0.92, 0.92, 1)
    love.graphics.printf(prompt, boxX + 24, boxY + 58, boxW - 48, "center")
end

return Tutorial
