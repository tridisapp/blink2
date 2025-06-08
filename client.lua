-- client.lua

-- Initialisation ESX pour pouvoir utiliser ESX.ShowHelpNotification
ESX = nil
CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Wait(0)
    end
end)
local stashCoords = {}  -- id → vector3
local stashNames  = {}  -- id → string

-- Charger les points enregistrés quand le joueur se connecte
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    TriggerServerEvent('blanchiment:requestPoints')
end)

local function KeyboardInput(text, example, maxLength)
    AddTextEntry('BLINK_INPUT', text)
    DisplayOnscreenKeyboard(1, 'BLINK_INPUT', '', example or '', '', '', '', maxLength or 30)
    while UpdateOnscreenKeyboard() == 0 do
        Wait(0)
    end
    if GetOnscreenKeyboardResult() then
        return GetOnscreenKeyboardResult()
    end
    return nil
end

-- 1) Initialisation NativeUI
local MenuPool = NativeUI.CreatePool()
local mainMenu = NativeUI.CreateMenu("Blanchiment", "Gestion des points")
MenuPool:Add(mainMenu)

-- Item de création de point
local createItem = NativeUI.CreateItem("Créer un point de blanchiment", "Place un nouveau coffre pour vous.")
mainMenu:AddItem(createItem)
createItem.Activated = function(sender, item)
    local name = KeyboardInput("Nom du point de blanchiment", "", 30)
    if name and name ~= "" then
        local coords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('blanchiment:createPoint', name, coords)
    end
end

MenuPool:RefreshIndex()

-- Commande /blink
RegisterCommand('blink', function()
    MenuPool:RefreshIndex()
    mainMenu:Visible(true)
end, false)

-- Thread pour traiter NativeUI
CreateThread(function()
    while true do
        MenuPool:ProcessMenus()
        Wait(0)
    end
end)

-- 2) Réception d’un point créé : stocke coords + blip privé
RegisterNetEvent('blanchiment:pointCreated')
AddEventHandler('blanchiment:pointCreated', function(id, coords, name)
    stashCoords[id] = vector3(coords.x, coords.y, coords.z)
    stashNames[id]  = name
    -- Création du blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 521)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name or "Point de blanchiment")
    EndTextCommandSetBlipName(blip)
end)

-- Chargement initial de tous les points
RegisterNetEvent('blanchiment:loadPoints')
AddEventHandler('blanchiment:loadPoints', function(points)
    for _, data in ipairs(points) do
        stashCoords[data.id] = vector3(data.x, data.y, data.z)
        stashNames[data.id]  = data.name
        local blip = AddBlipForCoord(data.x, data.y, data.z)
        SetBlipSprite(blip, 521)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(data.name or "Point de blanchiment")
        EndTextCommandSetBlipName(blip)
    end
end)

-- 3) Boucle pour dessiner markers et interaction
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        for id, coords in pairs(stashCoords) do
            local dist = #(pos - coords)
            if dist < 20.0 then
                DrawMarker(1,
                    coords.x, coords.y, coords.z - 1.0,
                    0, 0, 0, 0, 0, 0,
                    1.0, 1.0, 1.0,
                    0, 150, 255, 100,
                    false, true, 2, nil, nil, false
                )
                if dist < 1.5 then
                    ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le coffre")
                    if IsControlJustReleased(0, 38) then  -- touche E
                        exports.ox_inventory:openInventory('stash', {
                            id = 'blanch_' .. id
                        })
                    end
                end
            end
        end

        Wait(0)
    end
end)
