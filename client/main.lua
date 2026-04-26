local menuOpen = false
local loaded = false
local positionKvp = 'menu_position'

local function send(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function requestData()
    TriggerServerEvent('nd_multijob:server:requestData')
end

local function getSavedPosition()
    local raw = GetResourceKvpString(positionKvp)
    if not raw then return nil end

    local ok, position = pcall(json.decode, raw)
    if not ok or type(position) ~= 'table' then return nil end

    local x = tonumber(position.x)
    local y = tonumber(position.y)
    if not x or not y then return nil end

    return {
        x = x,
        y = y
    }
end

local function setOpen(state)
    menuOpen = state == true

    SetNuiFocus(menuOpen, menuOpen)
    SetNuiFocusKeepInput(false)

    send('setOpen', {
        open = menuOpen
    })

    if menuOpen then
        requestData()
    end
end

local function refreshSoon()
    SetTimeout(250, requestData)
end

RegisterCommand(Config.Command, function()
    setOpen(not menuOpen)
end, false)

RegisterKeyMapping(Config.Command, 'Open multijob menu', 'keyboard', Config.Keybind)

RegisterNUICallback('ready', function(_, cb)
    loaded = true
    send('setPosition', {
        position = getSavedPosition()
    })
    requestData()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb({ ok = true })
end)

RegisterNUICallback('switchJob', function(data, cb)
    if type(data) == 'table' and type(data.id) == 'string' then
        TriggerServerEvent('nd_multijob:server:switchJob', data.id)
    end

    cb({ ok = true })
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    TriggerServerEvent('nd_multijob:server:toggleDuty')
    cb({ ok = true })
end)

RegisterNUICallback('leaveJob', function(_, cb)
    TriggerServerEvent('nd_multijob:server:leaveJob')
    cb({ ok = true })
end)

RegisterNUICallback('savePosition', function(data, cb)
    if type(data) == 'table' then
        local x = tonumber(data.x)
        local y = tonumber(data.y)

        if x and y then
            SetResourceKvp(positionKvp, json.encode({
                x = math.floor(x + 0.5),
                y = math.floor(y + 0.5)
            }))
        end
    end

    cb({ ok = true })
end)

RegisterNetEvent('nd_multijob:client:setData', function(payload)
    if not loaded then return end
    send('setData', {
        payload = payload
    })
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', refreshSoon)
RegisterNetEvent('QBCore:Client:OnJobUpdate', refreshSoon)
RegisterNetEvent('QBCore:Client:SetDuty', refreshSoon)
RegisterNetEvent('qbx_core:client:onGroupUpdate', refreshSoon)
RegisterNetEvent('esx:playerLoaded', refreshSoon)
RegisterNetEvent('esx:setJob', refreshSoon)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    refreshSoon()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if menuOpen then
        SetNuiFocus(false, false)
    end
end)
