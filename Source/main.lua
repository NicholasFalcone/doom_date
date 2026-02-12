import "CoreLibs/graphics"
import "CoreLibs/timer"

local gfx = playdate.graphics

-- Configurazione Gioco
local screenWidth = 400
local screenHeight = 240
local playerRotation = 0 
local rotationSpeed = 4
local rotationLimit = 40 -- Limite di rotazione a sinistra e destra (gradi)

-- Configurazione Strada
local roadScrollOffset = 0
local roadSpeed = 4

-- Configurazione Arma (Gatling)
local weaponState = "idle" 
local windUpTime = 0
local maxWindUp = 25 
local firingFrame = 0

-- Configurazione Nemici
local enemies = {}
local spawnTimer = 0
local spawnRate = 60

-- Inizializzazione
function init()
    gfx.setFont(gfx.font.new('font/Asheville-Sans-14-Bold'))
end

init()

-- Sistema Nemici
function spawnEnemy()
    local enemy = {}
    -- Limitiamo lo spawn all'area della strada (±15 gradi)
    enemy.angle = math.random(-15, 15)
    enemy.distance = 1.0  
    enemy.isDead = false
    enemy.deathTimer = 0
    table.insert(enemies, enemy)
end

function updateEnemies()
    spawnTimer += 1
    if spawnTimer >= spawnRate then
        spawnEnemy()
        spawnTimer = 0
    end
    
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        
        if not e.isDead then
            e.distance -= 0.005 
            if e.distance <= 0 then
                table.remove(enemies, i)
            else
                if weaponState == "firing" then
                    local relAngle = (e.angle - playerRotation)
                    if math.abs(relAngle) < 5 then
                        e.isDead = true
                        e.deathTimer = 10
                    end
                end
            end
        else
            e.deathTimer -= 1
            if e.deathTimer <= 0 then
                table.remove(enemies, i)
            end
        end
    end
end

function drawEnemies()
    local horizonY = 120
    local groundY = 240
    
    for _, e in ipairs(enemies) do
        local relAngle = (e.angle - playerRotation)
        
        -- Rispetto ai limiti di rotazione, relAngle sarà sempre nel campo visivo
        local x = 200 + relAngle * 6
        local scale = 1.0 - e.distance
        local y = horizonY + (scale * scale) * (groundY - horizonY)
        local size = 10 + scale * 80
        
        if e.isDead then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(x, y - size/2, size * 1.5)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(x, y - size/2, size)
        else
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(x - size/4, y - size, size/2, size)
            gfx.fillRect(x - size/2, y - size * 0.7, size, size/5)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(x - size/8, y - size * 0.8, size/10)
            gfx.fillCircleAtPoint(x + size/8, y - size * 0.8, size/10)
        end
    end
end

-- Ambientazione
function drawDesert()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, screenWidth, 120)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
    gfx.fillRect(0, 120, screenWidth, 120)
    
    -- Montagne (Orizzonte)
    local numMountains = 12
    for i = 0, numMountains do
        local xPos = (i * 150 - playerRotation * 2) % (numMountains * 150)
        local finalX = xPos - 100 
        if finalX < screenWidth then
             gfx.setColor(gfx.kColorBlack)
             gfx.fillTriangle(finalX, 120, finalX + 50, 80, finalX + 100, 120)
        end
    end
end

function drawRoad()
    -- La strada è ora fissa a 0 gradi rispetto al suo asse
    local relX = (0 - playerRotation)
    
    local centerX = 200 + relX * 5
    local horizonY = 120
    local groundY = 240
    gfx.setColor(gfx.kColorBlack)
    local topW = 30
    local botW = 400
    gfx.fillPolygon(centerX - topW, horizonY, centerX + topW, horizonY, centerX + botW, groundY, centerX - botW, groundY)
    gfx.setColor(gfx.kColorWhite)
    for i = 0, 10 do
        local lineZ = (i * 0.2 + (roadScrollOffset / 100)) % 1.0
        local y = horizonY + (lineZ * lineZ) * (groundY - horizonY)
        local w = topW + (lineZ * lineZ) * (botW - topW)
        gfx.drawLine(centerX - w, y, centerX + w, y)
    end
end

-- Weapon & UI
function drawGatling()
    local cx = screenWidth / 2
    local baseHeight = 200
    local gunWidth = 80
    local bx, by = 0, 0
    
    if weaponState == "idle" then
        by = math.sin(playdate.getElapsedTime() * 4) * 2
    elseif weaponState == "firing" then
        bx, by = math.random(-3, 3), math.random(-3, 3)
    end
    
    local gy = baseHeight + by
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(cx - 30 + bx, gy, 60, 60)
    
    local rotationOffset = (weaponState ~= "idle") and firingFrame * 15 or 0
    for i = 0, 3 do
        local angle = math.rad(i * 90 + rotationOffset)
        local ox, oy = math.cos(angle) * 15, math.sin(angle) * 15
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(cx + bx + ox, gy + 30 + oy, 5)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawCircleAtPoint(cx + bx + ox, gy + 30 + oy, 5)
    end
    
    if weaponState == "firing" and firingFrame % 2 == 0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(cx + bx, gy + 10, 25)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(cx + bx, gy + 10, 12)
    end
end

function drawCrosshair()
    local cx, cy = screenWidth / 2, screenHeight / 2
    gfx.setLineWidth(1)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(cx - 10, cy, cx + 10, cy)
    gfx.drawLine(cx, cy - 10, cx, cy + 10)
    gfx.drawCircleAtPoint(cx, cy, 2)
end

function playdate.update()
    -- Input Rotazione Limitata
    if playdate.buttonIsPressed(playdate.kButtonLeft) then 
        playerRotation -= rotationSpeed 
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then 
        playerRotation += rotationSpeed 
    end
    
    -- Clamp rotazione
    if playerRotation < -rotationLimit then playerRotation = -rotationLimit end
    if playerRotation > rotationLimit then playerRotation = rotationLimit end
    
    roadScrollOffset = (roadScrollOffset - roadSpeed) % 100
    
    local change = playdate.getCrankChange()
    if math.abs(change) > 1 then
        if windUpTime < maxWindUp then weaponState = "winding"; windUpTime += 1 else weaponState = "firing" end
        firingFrame += math.floor(math.abs(change) / 2) + 1
    else
        weaponState = "idle"; windUpTime = math.max(0, windUpTime - 2)
    end
    
    -- Update Nemici
    updateEnemies()
    
    -- Rendering
    gfx.clear()
    drawDesert()
    drawRoad()
    drawEnemies()
    drawCrosshair()
    drawGatling()
end
