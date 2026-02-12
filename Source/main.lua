import "CoreLibs/graphics"
import "CoreLibs/timer"

local gfx = playdate.graphics

-- Configurazione Gioco
local screenWidth = 400
local screenHeight = 240
local playerRotation = 0 
local rotationSpeed = 4
local rotationLimit = 40 

-- Configurazione Strada
local roadScrollOffset = 0
local roadSpeed = 4

-- Configurazione Arma (Gatling)
local weaponState = "idle" 
local windUpTime = 0
local maxWindUp = 25 
local firingFrame = 0
local cooldownTime = 0
local maxCooldown = 30

-- Configurazione Nemici
local enemies = {}
local spawnTimer = 0
local spawnRate = 60

-- Suoni e Asset
local sfxLoading = nil
local sfxShooting = nil
local sfxDeath = nil
local bgLoadError = nil

-- Inizializzazione
function init()
    gfx.setFont(gfx.font.new('font/Asheville-Sans-14-Bold'))
    
    cooldownTime = maxCooldown

    -- Caricamento Suoni
    sfxLoading = playdate.sound.fileplayer.new("audio/loading")
    sfxShooting = playdate.sound.fileplayer.new("audio/shooting")
    sfxDeath = playdate.sound.fileplayer.new("audio/death")
    
    -- Caricamento Immagine di Sfondo (versione 500px)
    backgroundImage = gfx.image.new("background_500")
    
    if not backgroundImage then
        bgLoadError = "Img non caricata!"
    else
        local w, h = backgroundImage:getSize()
        bgLoadError = "Caricata: " .. w .. "x" .. h
    end
end

init()

-- Sistema Nemici
function spawnEnemy()
    local enemy = {}
    enemy.angle = math.random(-15, 15)
    enemy.distance = 1.0  
    enemy.isDead = false
    enemy.isHitted = false
    enemy.hitTimer = 0  -- Timer per l'effetto hit
    enemy.deathTimer = 0
    enemy.health = 3  -- Richiede 3 colpi per morire
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
        
        -- Countdown del timer di hit
        if e.hitTimer > 0 then
            e.hitTimer -= 1
            if e.hitTimer <= 0 then
                e.isHitted = false
            end
        end
        
        if not e.isDead then
            e.distance -= 0.005 
            if e.distance <= 0 then
                table.remove(enemies, i)
            else
                if weaponState == "firing" then
                    local relAngle = (e.angle - playerRotation)
                    if math.abs(relAngle) < 5 then
                        if e.isHitted == false then
                            e.isHitted = true
                            e.hitTimer = 10  -- Mostra l'effetto per 10 frame (~0.16 sec)
                            e.health -= 1  -- Riduce la salute di 1
                            
                            -- Muore solo quando la salute arriva a 0
                            if e.health <= 0 then
                                e.isDead = true
                                e.deathTimer = 10
                                -- Suono morte
                                if sfxDeath then sfxDeath:play() end
                            end
                        end
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
        local x = 200 + relAngle * 6
        local scale = 1.0 - e.distance
        local y = horizonY + (scale * scale) * (groundY - horizonY)
        local size = 10 + scale * 80
        
        if e.isDead then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(x, y - size/2, size * 1.5)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(x, y - size/2, size)
        elseif e.isHitted then
            -- Effetto sangue (splash)
            gfx.setColor(gfx.kColorWhite)
            -- Linee radiali (schizzi)
            for i = 0, 7 do
                local angle = math.rad(i * 45 + math.random(-10, 10))
                local len = size * 0.3 + math.random(0, math.max(1, math.floor(size * 0.2)))
                local startX = x + math.cos(angle) * size * 0.3
                local startY = (y - size/2) + math.sin(angle) * size * 0.3
                local endX = startX + math.cos(angle) * len
                local endY = startY + math.sin(angle) * len
                gfx.drawLine(startX, startY, endX, endY)
            end
            -- Gocce sparse
            for i = 1, 5 do
                local maxOffset = math.max(1, math.floor(size/2))
                local dropX = x + math.random(-maxOffset, maxOffset)
                local dropY = (y - size/2) + math.random(-maxOffset, maxOffset)
                gfx.fillCircleAtPoint(dropX, dropY, 1 + math.random(0, 2))
            end
            -- e.isHitted = false
        else
            -- Outline thickness
            local outlineW = 1
            
            -- Disegno outline bianco (più grande)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(x - size/4 - outlineW, y - size - outlineW, size/2 + outlineW*2, size + outlineW)
            gfx.fillRect(x - size/2 - outlineW, y - size * 0.7 - outlineW, size + outlineW*2, size/5 + outlineW*2)
            
            -- Disegno corpo nero (normale)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(x - size/4, y - size, size/2, size)
            gfx.fillRect(x - size/2, y - size * 0.7, size, size/5)
            
            -- Disegno occhi bianchi
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(x - size/8, y - size * 0.8, size/10)
            gfx.fillCircleAtPoint(x + size/8, y - size * 0.8, size/10)
        end
    end
end

-- Funzione per disegnare il deserto con immagine di sfondo
function drawDesert()
    -- Pulizia (Bianco)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, screenWidth, screenHeight)
    
    -- Disegno Immagine di Sfondo
    if backgroundImage then
        local bgW, bgH = backgroundImage:getSize()
        
        -- Calcoliamo l'offset orizzontale (Parallasse)
        -- Con un'immagine da 500px e schermo da 400px, abbiamo 100px di margine totale.
        -- ±40 gradi * 1.25 = ±50px di scorrimento, perfetto per coprire tutto.
        local bgX = (screenWidth / 2) - (bgW / 2) - (playerRotation * 1.25)
        
        -- Centramento verticale sull'orizzonte
        local bgY = 120 - (bgH / 2) * 1.5
        
        backgroundImage:draw(bgX, bgY)
    else
        -- Fallback: Sabbia ditherizzata
        gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
        gfx.fillRect(0, 120, screenWidth, 120)
    end
end

function drawRoad()
    local relX = (0 - playerRotation)
    local centerX = 200 + relX * 5
    local horizonY = 120
    local groundY = 240
    gfx.setColor(gfx.kColorBlack)
    local topW = 30
    local botW = 400
    gfx.fillPolygon(centerX - topW, horizonY, centerX + topW, horizonY, centerX + botW, groundY, centerX - botW, groundY)
    
    -- Disegna linee stradali e cactus integrati
    gfx.setColor(gfx.kColorWhite)
    for i = 0, 10 do
        local lineZ = (i * 0.2 + (roadScrollOffset / 100)) % 1.0
        local y = horizonY + (lineZ * lineZ) * (groundY - horizonY)
        local w = topW + (lineZ * lineZ) * (botW - topW)
        
        -- Disegna linea stradale
        gfx.drawLine(centerX - w, y, centerX + w, y)
        
        -- Disegna cactus ogni 10 tiles
        if i % 10 == 0 and i > 0 then
            -- Dimensione del cactus basata sulla profondità
            local cactusHeight = 10 + lineZ * 40
            local cactusWidth = 3 + lineZ * 8
            
            -- Calcola valore di dithering (vicino = solido, lontano = trasparente)
            local ditherValue = 1.0 - (lineZ * 0.7)
            
            -- Posiziona i cactus sui bordi della strada
            local leftCactusX = centerX - w - cactusWidth * 2
            local rightCactusX = centerX + w + cactusWidth * 2
            
            -- Disegna cactus sinistro
            if leftCactusX > 0 and leftCactusX < screenWidth then
                drawSingleCactus(leftCactusX, y, cactusWidth, cactusHeight, ditherValue)
            end
            
            -- Disegna cactus destro
            if rightCactusX > 0 and rightCactusX < screenWidth then
                drawSingleCactus(rightCactusX, y, cactusWidth, cactusHeight, ditherValue)
            end
        end
    end
end

function drawSingleCactus(x, y, w, h, ditherValue)
    -- Applica dithering per l'effetto di dissolvenza
    if ditherValue < 0.9 then
        gfx.setDitherPattern(ditherValue, gfx.image.kDitherTypeBayer8x8)
    else
        gfx.setColor(gfx.kColorWhite)
    end
    
    -- Tronco principale
    gfx.fillRect(x - w/2, y - h, w, h)
    
    -- Braccia (se il cactus è abbastanza grande)
    if h > 20 then
        -- Braccio sinistro
        local armY = y - h * 0.6
        local armLen = w * 1.5
        gfx.fillRect(x - w/2 - armLen, armY, armLen, w * 0.6)
        gfx.fillRect(x - w/2 - armLen, armY - h * 0.2, w * 0.6, h * 0.2)
        
        -- Braccio destro
        gfx.fillRect(x + w/2, armY, armLen, w * 0.6)
        gfx.fillRect(x + w/2 + armLen - w * 0.6, armY - h * 0.3, w * 0.6, h * 0.3)
    end
    
    -- Ripristina colore solido
    gfx.setColor(gfx.kColorWhite)
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
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(cx - 10, cy, cx + 10, cy)
    gfx.drawLine(cx, cy - 10, cx, cy + 10)
    gfx.drawCircleAtPoint(cx, cy, 2)
end

function updateWeaponState(newState)
    if weaponState == newState then return end
    
    local oldState = weaponState
    weaponState = newState
    
    -- Gestione Suoni
    if oldState == "winding" and sfxLoading then sfxLoading:stop() end
    if oldState == "firing" and sfxShooting then sfxShooting:stop() end
    
    if newState == "winding" and sfxLoading then sfxLoading:play(0) end
    if newState == "firing" and sfxShooting then sfxShooting:play(0) end
end

function playdate.update()
    -- Input
    if playdate.buttonIsPressed(playdate.kButtonLeft) then 
        playerRotation -= rotationSpeed 
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then 
        playerRotation += rotationSpeed 
    end
    
    if playerRotation < -rotationLimit then playerRotation = -rotationLimit end
    if playerRotation > rotationLimit then playerRotation = rotationLimit end
    
    roadScrollOffset = (roadScrollOffset - roadSpeed) % 100
    

    
    local change = playdate.getCrankChange()
    if math.abs(change) > 1 then
        if windUpTime < maxWindUp then 
            updateWeaponState("winding")
            windUpTime += 1 
        else 
            if cooldownTime <= 0 then
                updateWeaponState("firing")
                cooldownTime = maxCooldown
            else
                cooldownTime -= 1 
            end
        end
        firingFrame += math.floor(math.abs(change) / 2) + 1
    else
        updateWeaponState("idle")
        windUpTime = math.max(0, windUpTime - 2)
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
