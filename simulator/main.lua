if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

---@type love.World
local world
---@type { body: love.Body; shape: love.CircleShape; fixture: love.Fixture; }
local ball = {}
---@type { body: love.Body; shape: love.PolygonShape; fixture: love.Fixture; }
local rightFlipper = {}
---@type { body: love.Body; shape: love.PolygonShape; fixture: love.Fixture; }
local leftFlipper = {}
---@type { left: { body: love.Body; shape: love.EdgeShape; fixture: love.Fixture; }; right: { body: love.Body; shape: love.EdgeShape; fixture: love.Fixture; }; top: { body: love.Body; shape: love.EdgeShape; fixture: love.Fixture; }; bottom: { body: love.Body; shape: love.EdgeShape; fixture: love.Fixture; }; }
local walls = {
    left = {},
    right = {},
    top = {},
    bottom = {},
}

--[[
Durante el load se construyen todos los objetos físicos del mundo, entre ellos:
- La pelota, la cual se hace que rebote
- Los dos flippers, posicionados a -120 y 120 pixeles del centro del escenario y tienen 100 pixeles de ancho
- Las paredes del escenario, el cual tiene 500 px de ancho

El mundo tiene gravedad de 980 px/s^2
]]
function love.load()
    local sx, sy = love.graphics.getDimensions()

    world = love.physics.newWorld(0, 980)

    ball.body = love.physics.newBody(world, sx / 2, 100, "dynamic")
    ball.shape = love.physics.newCircleShape(10)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape)
    ball.body:setLinearVelocity(math.random(-50000, 50000) / 100, math.random(-10000, 0) / 100)
    ball.fixture:setRestitution(0.6)

    rightFlipper.body = love.physics.newBody(world, sx / 2 + 120, sy - 100, "kinematic")
    rightFlipper.shape = love.physics.newPolygonShape(-100, 20, 0, 0, 100, 20)
    rightFlipper.fixture = love.physics.newFixture(rightFlipper.body, rightFlipper.shape)

    leftFlipper.body = love.physics.newBody(world, sx / 2 - 120, sy - 100, "kinematic")
    leftFlipper.shape = love.physics.newPolygonShape(-100, 20, 0, 0, 100, 20)
    leftFlipper.fixture = love.physics.newFixture(leftFlipper.body, leftFlipper.shape)

    walls.left.body = love.physics.newBody(world, sx / 2 - 250, 10, "static")
    walls.left.shape = love.physics.newEdgeShape(0, 0, 0, sy - 20)
    walls.left.fixture = love.physics.newFixture(walls.left.body, walls.left.shape)

    walls.right.body = love.physics.newBody(world, sx / 2 + 250, 10, "static")
    walls.right.shape = love.physics.newEdgeShape(0, 0, 0, sy - 20)
    walls.right.fixture = love.physics.newFixture(walls.right.body, walls.right.shape)

    walls.top.body = love.physics.newBody(world, sx / 2, 10, "static")
    walls.top.shape = love.physics.newEdgeShape(-250, 0, 250, 0)
    walls.top.fixture = love.physics.newFixture(walls.top.body, walls.top.shape)
end

--[[
El motor de física puede utilizar y retornar angulos fuera del rango 0-359
Esta función lo normaliza todo al rango -179-180
]]
local function normalizeAngle(angle)
    local limited = math.deg(angle) % 360
    if limited > 180 then
        return math.rad(limited - 360)
    else
        return math.rad(limited)
    end
end

-- Tiempo desde que inicio el programa
local timer = 0
-- 80 grados en 0.1 segundos
local flipperSpeed = math.rad(80 / 0.1)
-- Posiciones de los sensores de distancia
local predictorTh1 = 300
local predictorTh2 = 330
-- Visual
local triggerTh1 = 400
local triggerTh2 = 430


-- Posición y tiempo en el que se registró la pelota según los sensores
local registeredDistance1 = 0
local registeredAt1 = 0
local registeredDistance2 = 0
local registeredAt2 = 0
-- Según la predicción, en qué X va a terminar la pelota, y en qué tiempo (según timer) va a llegar a esa X
local flipperTime = 0
local flipperPos = 0
function love.update(dt)
    timer = timer + dt

    --[[ Si la pelota se sale del mundo, se pone de regreso en la parte superior con
         velocidad aleatoria ]]
    local bx, by = ball.body:getPosition()
    local sx, sy = love.graphics.getDimensions()
    if bx < 0 or by < 0 or bx > sx or by > sy then
        ball.body:setPosition(sx / 2, 100)
        ball.body:setLinearVelocity(math.random(-50000, 50000) / 100, math.random(-10000, 0) / 100)
    end
    bx, by = ball.body:getPosition()

    -- Se dan 0.2 segundos de golpe a las pelotas
    -- Se divide el escenario en cuatro secciones y según la posición se mueven los flipper
    if (flipperPos >= 240 and flipperPos < 360 and timer - flipperTime > 0 and timer - flipperTime < 0.2) then
        local cangle = normalizeAngle(rightFlipper.body:getAngle())
        if cangle < math.rad(80) then
            rightFlipper.body:setAngularVelocity(-math.min((cangle - math.rad(80)) / 0.05, flipperSpeed))
        elseif cangle > math.rad(80) then
            rightFlipper.body:setAngularVelocity(math.min((cangle - math.rad(80)) / 0.05, flipperSpeed))
        else
            rightFlipper.body:setAngularVelocity(0)
        end
    elseif (flipperPos >= 360 and timer - flipperTime > 0 and timer - flipperTime < 0.2) then
        local cangle = normalizeAngle(rightFlipper.body:getAngle())
        if cangle > math.rad(-80) then
            rightFlipper.body:setAngularVelocity(-math.min((cangle - math.rad(-80)) / 0.05, flipperSpeed))
        elseif cangle < math.rad(-80) then
            rightFlipper.body:setAngularVelocity(math.min((cangle - math.rad(-80)) / 0.05, flipperSpeed))
        else
            rightFlipper.body:setAngularVelocity(0)
        end
    else
        local cangle = normalizeAngle(rightFlipper.body:getAngle())
        if cangle > math.rad(0) then
            rightFlipper.body:setAngularVelocity(-math.min((cangle - math.rad(0)) / 0.05, flipperSpeed))
        elseif cangle < math.rad(0) then
            rightFlipper.body:setAngularVelocity(math.min((cangle - math.rad(0)) / 0.05, flipperSpeed))
        else
            rightFlipper.body:setAngularVelocity(0)
        end
    end

    if (flipperPos >= 120 and flipperPos < 240 and timer - flipperTime > 0 and timer - flipperTime < 0.2) then
        local cangle = normalizeAngle(leftFlipper.body:getAngle())
        if cangle > math.rad(-80) then
            leftFlipper.body:setAngularVelocity(-math.min((cangle - math.rad(-80)) / 0.05, flipperSpeed))
        elseif cangle < math.rad(-80) then
            leftFlipper.body:setAngularVelocity(math.min((cangle - math.rad(-80)) / 0.05, flipperSpeed))
        else
            leftFlipper.body:setAngularVelocity(0)
        end
    elseif (flipperPos < 120 and timer - flipperTime > 0 and timer - flipperTime < 0.2) then
        local cangle = normalizeAngle(leftFlipper.body:getAngle())
        if cangle < math.rad(80) then
            leftFlipper.body:setAngularVelocity(-math.min((cangle - math.rad(80)) / 0.05, flipperSpeed))
        elseif cangle > math.rad(80) then
            leftFlipper.body:setAngularVelocity(math.min((cangle - math.rad(80)) / 0.05, flipperSpeed))
        else
            leftFlipper.body:setAngularVelocity(0)
        end
    else
        local cangle = normalizeAngle(leftFlipper.body:getAngle())
        if cangle > math.rad(0) then
            leftFlipper.body:setAngularVelocity(math.min((cangle - math.rad(0)) / 0.05, flipperSpeed))
        elseif cangle < math.rad(0) then
            leftFlipper.body:setAngularVelocity(-math.min((cangle - math.rad(0)) / 0.05, flipperSpeed))
        else
            leftFlipper.body:setAngularVelocity(0)
        end
    end

    -- Lógica para los sensores.
    -- Debido a que el radio de la pelota son 10px, se hace una diferencia absoluta para detectar la
    -- colisión con la línea de detección de los sensores
    if math.abs(by - predictorTh1) < 10 then
        registeredDistance1 = bx - (sx / 2 - 250)
        registeredAt1 = timer
    end
    if math.abs(by - predictorTh2) < 10 then
        registeredDistance2 = bx - (sx / 2 - 250)
        registeredAt2 = timer
        -- Velocidad calculada según el movimiento rectilíneo uniforme
        local xvel = (registeredDistance2 - registeredDistance1) / (registeredAt2 - registeredAt1)
        local yvel = (predictorTh2 - predictorTh1) / (registeredAt2 - registeredAt1)
        -- La posición y deseada está 150px arriba del fondo del escenario
        local flipperTimeOffset = ((sy - 150) - predictorTh2) / yvel
        flipperTime = timer + flipperTimeOffset
        flipperPos = registeredDistance2 + xvel * flipperTimeOffset
    end

    world:update(dt)
end

--[[ Visualización del mundo, los sensores y la predicción ]]
function love.draw()
    local sx, sy = love.graphics.getDimensions()

    -- ***** Objetos físicos del mundo *****
    local bx, by = ball.body:getPosition()
    local ba = ball.body:getAngle()
    love.graphics.push()
    love.graphics.translate(bx, by)
    love.graphics.rotate(ba)
    local sbx, sby = ball.shape:getPoint()
    love.graphics.circle("fill", sbx, sby, ball.shape:getRadius())
    love.graphics.pop()

    local rx, ry = rightFlipper.body:getPosition()
    local ra = rightFlipper.body:getAngle()
    love.graphics.push()
    love.graphics.translate(rx, ry)
    love.graphics.rotate(ra)
    love.graphics.polygon("fill", rightFlipper.shape:getPoints())
    love.graphics.pop()

    local lx, ly = leftFlipper.body:getPosition()
    local la = leftFlipper.body:getAngle()
    love.graphics.push()
    love.graphics.translate(lx, ly)
    love.graphics.rotate(la)
    love.graphics.polygon("fill", leftFlipper.shape:getPoints())
    love.graphics.pop()

    local wlx, wly = walls.left.body:getPosition()
    local wla = walls.left.body:getAngle()
    love.graphics.push()
    love.graphics.translate(wlx, wly)
    love.graphics.rotate(wla)
    love.graphics.line(walls.left.shape:getPoints())
    love.graphics.pop()

    local wrx, wry = walls.right.body:getPosition()
    local wra = walls.right.body:getAngle()
    love.graphics.push()
    love.graphics.translate(wrx, wry)
    love.graphics.rotate(wra)
    love.graphics.line(walls.right.shape:getPoints())
    love.graphics.pop()

    local wtx, wty = walls.top.body:getPosition()
    local wta = walls.top.body:getAngle()
    love.graphics.push()
    love.graphics.translate(wtx, wty)
    love.graphics.rotate(wta)
    love.graphics.line(walls.top.shape:getPoints())
    love.graphics.pop()

    -- ***** Sensores *****
    love.graphics.line(sx / 2 - 250, predictorTh1, sx / 2 + 250, predictorTh1)
    love.graphics.line(sx / 2 - 250, predictorTh2, sx / 2 + 250, predictorTh2)
    love.graphics.line(sx / 2 - 250, triggerTh1, sx / 2 + 250, triggerTh1)
    love.graphics.line(sx / 2 - 250, triggerTh2, sx / 2 + 250, triggerTh2)

    -- ***** Predicción *****
    love.graphics.line(sx / 2 - 250 + registeredDistance2, predictorTh2, sx / 2 - 250 + flipperPos, sy - 150)
end
