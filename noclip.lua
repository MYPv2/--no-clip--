-- ============================================
-- NOCLIP v3.2 PREMIUM | Un solo bind: N
-- Noclip + Speed juntos | Detección de bloqueo
-- ============================================
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- CONFIG
-- ============================================
local CONFIG = {
    keybind = Enum.KeyCode.N,   -- 👈 una sola tecla para todo
    restoreOnDisable = true,
    showIndicator = true,

    -- Velocidad configurable
    speedMultiplier = 1.5,
    speedMin = 16,
    speedMax = 35,
    speedRamp = true,
    rampStep = 1,

    -- Detección de bloqueo
    detectBlock = true,
    blockThreshold = 5,
    blockAction = "warn",   -- "warn" | "disable" | "none"
}

local activo = false
local noclipConn = nil
local speedConn = nil
local partesModificadas = {}
local blockCounter = 0
local currentSpeed = 16
local indicatorGui = nil
local indicatorLabel = nil

-- ============================================
-- INDICADOR
-- ============================================
local function crearIndicador()
    if not CONFIG.showIndicator then return end
    if indicatorGui and indicatorGui.Parent then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NoclipIndicator"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = game:GetService("CoreGui")

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 180, 0, 28)
    label.Position = UDim2.new(0, 10, 0, 10)
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.BackgroundTransparency = 0.5
    label.TextColor3 = Color3.fromRGB(120, 120, 120)
    label.Text = "NOCLIP + SPEED: OFF"
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.5
    label.Parent = gui

    indicatorGui = gui
    indicatorLabel = label
end

local function actualizarIndicador()
    if not indicatorLabel then return end
    if activo then
        indicatorLabel.Text = "NOCLIP + SPEED: ON"
        indicatorLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    else
        indicatorLabel.Text = "NOCLIP + SPEED: OFF"
        indicatorLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    end

    if CONFIG.detectBlock and blockCounter >= CONFIG.blockThreshold then
        indicatorLabel.Text = indicatorLabel.Text .. " [BLOCKED]"
        indicatorLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end

-- ============================================
-- DETECCIÓN DE BLOQUEO
-- ============================================
local function detectarBloqueo()
    if not CONFIG.detectBlock then return end
    if not activo then blockCounter = 0; return end

    local char = LocalPlayer.Character
    if not char then return end

    local revertidos = 0
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") and partesModificadas[v] then
            if v.CanCollide then revertidos = revertidos + 1 end
        end
    end

    if revertidos > 0 then
        blockCounter = blockCounter + 1
        if blockCounter >= CONFIG.blockThreshold then
            if CONFIG.blockAction == "disable" then
                desactivarTodo()
                print("[Noclip] 🚫 Servidor bloqueando. Desactivado.")
            elseif CONFIG.blockAction == "warn" then
                print("[Noclip] ⚠️ Servidor revirtió CanCollide " .. revertidos .. " partes.")
            end
        end
    else
        blockCounter = math.max(0, blockCounter - 1)
    end
end

-- ============================================
-- NOCLIP
-- ============================================
local function aplicarNoclip(char)
    if not char then return end
    pcall(function()
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                local esHerramienta = false
                local parent = v.Parent
                while parent and parent ~= char do
                    if parent:IsA("Tool") then esHerramienta = true; break end
                    parent = parent.Parent
                end
                if not esHerramienta and v.CanCollide then
                    v.CanCollide = false
                    partesModificadas[v] = true
                end
            end
        end
    end)
end

-- ============================================
-- VELOCIDAD
-- ============================================
local function aplicarVelocidad()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local target = CONFIG.speedMin * CONFIG.speedMultiplier
    target = math.clamp(target, CONFIG.speedMin, CONFIG.speedMax)

    if CONFIG.speedRamp then
        if currentSpeed < target then
            currentSpeed = math.min(currentSpeed + CONFIG.rampStep, target)
        elseif currentSpeed > target then
            currentSpeed = math.max(currentSpeed - CONFIG.rampStep, CONFIG.speedMin)
        end
        hum.WalkSpeed = currentSpeed
    else
        hum.WalkSpeed = target
    end
end

-- ============================================
-- ACTIVAR TODO
-- ============================================
local function activarTodo()
    if noclipConn or speedConn then return end

    local char = LocalPlayer.Character
    if char then aplicarNoclip(char) end
    currentSpeed = CONFIG.speedMin

    noclipConn = RunService.Heartbeat:Connect(function()
        if not activo then return end
        local c = LocalPlayer.Character
        if c then aplicarNoclip(c) end
        detectarBloqueo()
    end)

    speedConn = RunService.Heartbeat:Connect(function()
        if not activo then return end
        aplicarVelocidad()
    end)

    actualizarIndicador()
    print("[Noclip+Speed] ✅ ACTIVADO")
end

-- ============================================
-- DESACTIVAR TODO
-- ============================================
function desactivarTodo()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    if speedConn then speedConn:Disconnect(); speedConn = nil end

    -- Restaurar colisiones
    if CONFIG.restoreOnDisable then
        local char = LocalPlayer.Character
        if char then
            pcall(function()
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") and partesModificadas[v] then
                        v.CanCollide = true
                    end
                end
            end)
        end
    end
    partesModificadas = {}

    -- Restaurar velocidad
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = CONFIG.speedMin end
    end
    currentSpeed = CONFIG.speedMin
    blockCounter = 0

    actualizarIndicador()
    print("[Noclip+Speed] ❌ DESACTIVADO")
end

-- ============================================
-- TOGGLE ÚNICO
-- ============================================
local function toggleTodo()
    activo = not activo
    if activo then
        activarTodo()
    else
        desactivarTodo()
    end
end

-- ============================================
-- INPUT
-- ============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.keybind then
        toggleTodo()
    end
end)

-- ============================================
-- RESPAWN
-- ============================================
LocalPlayer.CharacterAdded:Connect(function(char)
    partesModificadas = {}
    currentSpeed = CONFIG.speedMin
    if activo then
        task.wait(0.3)
        aplicarNoclip(char)
        aplicarVelocidad()
    end
end)

-- ============================================
-- INIT
-- ============================================
crearIndicador()
actualizarIndicador()

print("[Noclip v3.2 PREMIUM] Cargado ✅ | Tecla: " .. CONFIG.keybind.Name)
print("  Noclip + Speed juntos en una tecla")
print("  Speed multiplier: " .. CONFIG.speedMultiplier)
print("  Detección de bloqueo: " .. tostring(CONFIG.detectBlock))
