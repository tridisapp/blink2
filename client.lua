-- client.lua

-- Initialisation ESX pour pouvoir utiliser ESX.ShowHelpNotification
ESX = nil
CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Wait(0)
    end
end)
local stashCoords    = {}  -- id → vector3
local stashNames     = {}  -- id → string
local stashPedModels = {}  -- id → string
local stashPeds      = {}  -- id → ped handle
local chefCoords     = {}
local chefNames      = {}
local chefPedModels  = {}
local chefPeds       = {}

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

-- Spawn a ped used for interaction
local function SpawnStashPed(id, coords, pedModel)
    local model = GetHashKey(pedModel or 'u_m_y_smugmech_01')
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, 0.0, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    stashPeds[id] = ped

    -- Automatically remove the ped after one minute
    CreateThread(function()
        Wait(60000)
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
        stashPeds[id] = nil
    end)
end

local function SpawnChefPed(id, coords, pedModel)
    local model = GetHashKey(pedModel or 'u_m_y_smugmech_01')
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, 0.0, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    chefPeds[id] = ped
end

-- 1) Initialisation NativeUI
local MenuPool = NativeUI.CreatePool()
local mainMenu = NativeUI.CreateMenu("Blanchiment", "Gestion des points")
MenuPool:Add(mainMenu)
local chefMenu = NativeUI.CreateMenu("Chef", "Choisissez un coffre")
MenuPool:Add(chefMenu)

local function OpenChefMenu()
    chefMenu:Clear()
    for id, name in pairs(stashNames) do
        local item = NativeUI.CreateItem(name, '')
        chefMenu:AddItem(item)
        item.Activated = function()
            exports.ox_inventory:openInventory('stash', { id = 'blanch_' .. id })
        end
    end
    MenuPool:RefreshIndex()
    chefMenu:Visible(true)
end

-- Item de création de point (renommé)
local createItem = NativeUI.CreateItem("Envoyer un coursier", "Place un nouveau coffre pour vous.")
mainMenu:AddItem(createItem)
createItem.Activated = function(sender, item)
    local name = KeyboardInput("Nom du point de blanchiment", "", 30)
    if name and name ~= "" then
        TriggerServerEvent('blanchiment:createPoint', name)
    end
end

-- Item pour ajouter un point de rendez-vous
local addPointItem = NativeUI.CreateItem("Ajouter un point de rendez-vous", "Enregistre la position actuelle")
mainMenu:AddItem(addPointItem)
addPointItem.Activated = function(sender, item)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('blanchiment:addPedPoint', coords)
    ESX.ShowNotification(('l\'emplacement %.2f %.2f %.2f a été ajouté'):format(coords.x, coords.y, coords.z))
end

-- Item pour recruter un coursier
local recruitItem = NativeUI.CreateItem("Recruter un coursier", "Ajoute un nouveau ped")
mainMenu:AddItem(recruitItem)
recruitItem.Activated = function(sender, item)
    local pedName = KeyboardInput("Nom du coursier", "", 30)
    if pedName and pedName ~= "" then
        TriggerServerEvent('blanchiment:addPed', pedName)
    end
end

-- Item pour placer ton homme de main
local chefItem = NativeUI.CreateItem("Placer ton homme de main", "Place ton homme de main a votre position")
mainMenu:AddItem(chefItem)
chefItem.Activated = function(sender, item)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local spawn = vector3(
        coords.x + forward.x * 1.5,
        coords.y + forward.y * 1.5,
        coords.z
    )
    TriggerServerEvent('blanchiment:placeChef', spawn)
end

MenuPool:RefreshIndex()

-- Commande /blink (verification serveur)
RegisterCommand('blink', function()
    TriggerServerEvent('blanchiment:requestOpenMenu')
end, false)

RegisterNetEvent('blanchiment:openMenu')
AddEventHandler('blanchiment:openMenu', function()
    MenuPool:RefreshIndex()
    mainMenu:Visible(true)
end)

-- Thread pour traiter NativeUI
CreateThread(function()
    while true do
        MenuPool:ProcessMenus()
        Wait(0)
    end
end)

-- 2) Réception d’un point créé : stocke coords + blip privé
RegisterNetEvent('blanchiment:pointCreated')
AddEventHandler('blanchiment:pointCreated', function(id, coords, name, pedModel)
    stashCoords[id]    = vector3(coords.x, coords.y, coords.z)
    stashNames[id]     = name
    stashPedModels[id] = pedModel or 'u_m_y_smugmech_01'
    SpawnStashPed(id, coords, stashPedModels[id])
    -- Création du blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 521)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name or "Point de blanchiment")
    EndTextCommandSetBlipName(blip)
end)

-- Réception de la création d'un chef
RegisterNetEvent('blanchiment:chefPlaced')
AddEventHandler('blanchiment:chefPlaced', function(id, coords, name, pedModel)
    chefCoords[id]    = vector3(coords.x, coords.y, coords.z)
    chefNames[id]     = name
    chefPedModels[id] = pedModel or 'u_m_y_smugmech_01'
    SpawnChefPed(id, coords, chefPedModels[id])
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 521)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name or 'Chef de blanchiment')
    EndTextCommandSetBlipName(blip)
end)

-- Chargement initial de tous les points
RegisterNetEvent('blanchiment:loadPoints')
AddEventHandler('blanchiment:loadPoints', function(points)
    for _, data in ipairs(points) do
        stashCoords[data.id]    = vector3(data.x, data.y, data.z)
        stashNames[data.id]     = data.name
        stashPedModels[data.id] = data.ped or 'u_m_y_smugmech_01'
        SpawnStashPed(data.id, vector3(data.x, data.y, data.z), stashPedModels[data.id])
        local blip = AddBlipForCoord(data.x, data.y, data.z)
        SetBlipSprite(blip, 521)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(data.name or "Point de blanchiment")
        EndTextCommandSetBlipName(blip)
    end
end)

-- Chargement initial des chefs
RegisterNetEvent('blanchiment:loadChefs')
AddEventHandler('blanchiment:loadChefs', function(chefs)
    for _, data in ipairs(chefs) do
        chefCoords[data.id]    = vector3(data.x, data.y, data.z)
        chefNames[data.id]     = data.name
        chefPedModels[data.id] = data.ped or 'u_m_y_smugmech_01'
        SpawnChefPed(data.id, vector3(data.x, data.y, data.z), chefPedModels[data.id])
        local blip = AddBlipForCoord(data.x, data.y, data.z)
        SetBlipSprite(blip, 521)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(data.name or 'Chef de blanchiment')
        EndTextCommandSetBlipName(blip)
    end
end)

-- 3) Boucle pour dessiner markers et interaction
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        for id, pedHandle in pairs(stashPeds) do
            if DoesEntityExist(pedHandle) then
                local dist = #(pos - GetEntityCoords(pedHandle))
                if dist < 2.0 then
                    ESX.ShowHelpNotification("Appuyer sur ~INPUT_CONTEXT~ pour parler au coursier")
                    if IsControlJustReleased(0, 38) then  -- touche E
                        local playerName = GetPlayerName(PlayerId())
                        local dialog = {
                            header = 'Coursier',
                            content = ("Salut %s, il faut qu’on se dépêche, il ne nous reste pas plus de deux minutes. Après ça, je serai obligé de filer. Glisse la liasse dans ma poche, mon chef s’occupera du reste et te recontactera."):format(playerName),
                            centered = true
                        }
                        local response
                        if lib and lib.alertDialog then
                            response = lib.alertDialog(dialog)
                        else
                            response = exports.ox_lib:alertDialog(dialog)
                        end
                        if response == true or response == 'confirm' then
                            exports.ox_inventory:openInventory('stash', {
                                id = 'blanch_' .. id
                            })
                        end
                    end
                end
            end
        end

        for id, pedHandle in pairs(chefPeds) do
            if DoesEntityExist(pedHandle) then
                local dist = #(pos - GetEntityCoords(pedHandle))
                if dist < 2.0 then
                    ESX.ShowHelpNotification("Appuyer sur ~INPUT_CONTEXT~ pour parler a ton homme de main")
                    if IsControlJustReleased(0, 38) then
                        OpenChefMenu()
                    end
                end
            end
        end

        Wait(0)
    end
end)
