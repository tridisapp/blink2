-- client.lua

local stashCoords = {}  -- id → vector3

-- 1) Initialisation NativeUI
local MenuPool = NativeUI.CreatePool()
local mainMenu = NativeUI.CreateMenu("Blanchiment", "Gestion des points")
MenuPool:Add(mainMenu)

-- Item de création de point
local createItem = NativeUI.CreateItem("Créer un point de blanchiment", "Place un nouveau coffre pour vous.")
mainMenu:AddItem(createItem)
createItem:Activated(function(sender, item)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('blanchiment:createPoint', coords)
end)

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
AddEventHandler('blanchiment:pointCreated', function(id, coords)
    stashCoords[id] = vector3(coords.x, coords.y, coords.z)
    -- Création du blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 521)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Point de blanchiment")
    EndTextCommandSetBlipName(blip)
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
                        TriggerEvent('ox_inventory:openStash', 'blanch_'..id)
                    end
                end
            end
        end

        Wait(0)
    end
end)
