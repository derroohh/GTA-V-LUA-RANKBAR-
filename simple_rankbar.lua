-- simple_rankbar.lua
-- GTA V ScriptHookV Lua rank/XP bar with gradient fill
-- Self-contained: only uses a save file for rank progress.

-- ---------- Utilities ----------
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function lerp(a, b, t) return a + (b - a) * clamp(t, 0, 1) end

-- File helpers
local function fileExists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

local function saveTableLua(path, tbl)
    local f = io.open(path, "w"); if not f then return false end
    f:write("return {\n")
    for k, v in pairs(tbl) do
        f:write(string.format("  %s = %d,\n", k, v))
    end
    f:write("}\n")
    f:close()
    return true
end

local function loadTableLua(path)
    if not fileExists(path) then return nil end
    local ok, tbl = pcall(function() return dofile(path) end)
    return ok and tbl or nil
end

-- ---------- Save ----------
local savePath = "scripts/rankbar_save.lua"
local save = loadTableLua(savePath) or { currentRank = 1, currentXP = 1 }
local function saveProgress() saveTableLua(savePath, save) end

-- ---------- Settings ----------
local cfg = {
    posX = 0.5, posY = 0.03,  -- Y position for texts
    width = 0.3, height = 0.025,
    segments = 10,
    xpPerRank = 100, maxRank = 100,
    timePerRank = 80, animationSpeed = 8.0,
    padding = 0.0015, bgAlpha = 180,
    colorStart = { r = 0, g = 180, b = 255 },
    colorEnd   = { r = 0, g = 110, b = 190 },
    textColor  = { r = 255, g = 255, b = 255 },
    leftRankColor  = { r = 255, g = 255, b = 0 }, -- yellow
    rightRankColor = { r = 255, g = 255, b = 0 },   -- yellow
    rankOffsetX = 0.015,  -- horizontal offset from bar
    rankScale = 0.55,     -- rank text size
    xpScale = 0.45,       -- XP text size
    barOffset = 0.016,    -- move bar slightly down
}

-- ---------- State ----------
local displayedXP = save.currentXP

-- ---------- Drawing ----------
local function drawRect(x,y,w,h,r,g,b,a) GRAPHICS.DRAW_RECT(x,y,w,h,r,g,b,a) end
local function drawText(text,x,y,scale,r,g,b,a,center)
    UI.SET_TEXT_FONT(4)
    UI.SET_TEXT_SCALE(scale, scale)
    UI.SET_TEXT_COLOUR(r, g, b, a)
    UI.SET_TEXT_CENTRE(center or false)
    UI._SET_TEXT_ENTRY("STRING")
    UI._ADD_TEXT_COMPONENT_STRING(tostring(text))
    UI._DRAW_TEXT(x, y)
end

-- ---------- Tick ----------
local function tick()
    local dt = GAMEPLAY.GET_FRAME_TIME()
    local minXP = (save.currentRank-1)*cfg.xpPerRank+1
    local maxXP = save.currentRank*cfg.xpPerRank
    save.currentXP = clamp(save.currentXP,minXP,maxXP)

    if cfg.timePerRank > 0 then
        save.currentXP = save.currentXP + (cfg.xpPerRank/cfg.timePerRank)*dt
    end

    displayedXP = displayedXP + (save.currentXP-displayedXP)*clamp(cfg.animationSpeed*dt,0,1)
    displayedXP = clamp(displayedXP,minXP,maxXP)

    if save.currentXP >= maxXP-0.001 then
        save.currentRank = clamp(save.currentRank+1,1,cfg.maxRank)
        save.currentXP = (save.currentRank-1)*cfg.xpPerRank+1
        displayedXP = save.currentXP; saveProgress()
    end

    -- Bar background (slightly lower than texts)
    local barY = cfg.posY + cfg.barOffset
    drawRect(cfg.posX, barY, cfg.width+0.002, cfg.height+0.004, 0,0,0,cfg.bgAlpha)

    -- Segments
    local segW = cfg.width/cfg.segments
    local fillRatio = (displayedXP - minXP)/cfg.xpPerRank
    local filled = math.floor(fillRatio * cfg.segments)
    local partial = (fillRatio * cfg.segments) - filled

    for i = 0, cfg.segments - 1 do
        local ix = cfg.posX - cfg.width/2 + segW/2 + i*segW
        local t = i/math.max(1,cfg.segments-1)
        local r = math.floor(lerp(cfg.colorStart.r, cfg.colorEnd.r, t))
        local g = math.floor(lerp(cfg.colorStart.g, cfg.colorEnd.g, t))
        local b = math.floor(lerp(cfg.colorStart.b, cfg.colorEnd.b, t))

        if i < filled then
            drawRect(ix, barY, segW - cfg.padding, cfg.height - cfg.padding, r, g, b, 255)
        elseif i == filled and partial > 0 then
            local partW = (segW - cfg.padding) * partial
            drawRect(ix - (segW - partW)/2, barY, partW, cfg.height - cfg.padding, r, g, b, 255)
            drawRect(ix + partW/2, barY, (segW - cfg.padding) - partW, cfg.height - cfg.padding, 50,50,50,150)
        else
            drawRect(ix, barY, segW - cfg.padding, cfg.height - cfg.padding, 50,50,50,150)
        end
    end

    -- XP text (same line as texts)
    drawText(math.floor(save.currentXP).."/"..maxXP,
             cfg.posX, cfg.posY,
             cfg.xpScale,
             cfg.textColor.r, cfg.textColor.g, cfg.textColor.b, 255, true)

    -- Left rank text
    drawText(save.currentRank,
             cfg.posX - cfg.width/2 - cfg.rankOffsetX,
             cfg.posY,
             cfg.rankScale,
             cfg.leftRankColor.r, cfg.leftRankColor.g, cfg.leftRankColor.b, 255, true)

    -- Right rank text
    drawText(save.currentRank+1,
             cfg.posX + cfg.width/2 + cfg.rankOffsetX,
             cfg.posY,
             cfg.rankScale,
             cfg.rightRankColor.r, cfg.rightRankColor.g, cfg.rightRankColor.b, 255, true)
end

return {
    init = function()
        if not fileExists(savePath) then saveProgress() end
    end,
    tick = tick
}
