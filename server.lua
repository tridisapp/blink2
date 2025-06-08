-- server.lua

ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Référence vers les exports d'ox_inventory
local ox_inventory = exports.ox_inventory

-- Paramètres par défaut
local DEFAULT_CAPACITY   = 50000    -- 50 kg
local DEFAULT_SLOTS      = 16
local DEFAULT_ALLOWED    = 'coca_leaf'
local DEFAULT_OUTPUT     = 'cocaine_bag'
local TRANSFORM_DELAY_MS = 5 * 60 * 1000  -- 5 minutes

-- Stockage en mémoire des coords
local stashCoords = {}
local stashNames  = {}

-- 1) Au démarrage, charger tous les points enregistrés
MySQL.ready(function()
    local rows = MySQL.Sync.fetchAll("SELECT * FROM blanchiment_points")
    for _, row in ipairs(rows) do
        local stashName = 'blanch_' .. row.id
        stashCoords[row.id] = vector3(row.x, row.y, row.z)
        stashNames[row.id]  = row.name
        -- Le label doit être fourni avant les paramètres slots et poids
        -- RegisterStash(name, label, slots, maxWeight)
        ox_inventory:RegisterStash(stashName, row.name, DEFAULT_SLOTS, DEFAULT_CAPACITY)
    end
end)

-- 2) Création d’un point via /blink → NativeUI → client → serveur
RegisterNetEvent('blanchiment:createPoint')
AddEventHandler('blanchiment:createPoint', function(name, coords)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    -- Persister en base
    local insertId = MySQL.Sync.insert([[
        INSERT INTO blanchiment_points
          (owner, name, x, y, z, allowed_item, output_item)
        VALUES
          (@owner, @name, @x, @y, @z, @allowed, @output)
    ]], {
        ['@owner']   = xPlayer.identifier,
        ['@name']    = name,
        ['@x']       = coords.x,
        ['@y']       = coords.y,
        ['@z']       = coords.z,
        ['@allowed'] = DEFAULT_ALLOWED,
        ['@output']  = DEFAULT_OUTPUT
    })
    -- Enregistrer côté serveur
    stashCoords[insertId] = vector3(coords.x, coords.y, coords.z)
    stashNames[insertId]  = name
    -- Utilise l'API RegisterStash(name, label, slots, maxWeight)
    ox_inventory:RegisterStash('blanch_'..insertId, name, DEFAULT_SLOTS, DEFAULT_CAPACITY)
    -- Informer le client
    TriggerClientEvent('blanchiment:pointCreated', src, insertId, coords, name)
end)

-- Envoi des points existants à un joueur
RegisterNetEvent('blanchiment:requestPoints')
AddEventHandler('blanchiment:requestPoints', function()
    local src    = source
    local points = {}
    for id, coords in pairs(stashCoords) do
        points[#points+1] = {
            id   = id,
            x    = coords.x,
            y    = coords.y,
            z    = coords.z,
            name = stashNames[id]
        }
    end
    TriggerClientEvent('blanchiment:loadPoints', src, points)
end)

-- 3) Filtrer l’ajout d’items : seul allowed_item est accepté
AddEventHandler('ox_inventory:beforeItemAdded', function(source, stashName, itemName, count, meta, callback)
    local xPlayer = ESX.GetPlayerFromId(source)
    local prefix  = 'blanch_'
    if stashName:sub(1, #prefix) == prefix then
        -- Extraire l’ID
        local id = tonumber(stashName:sub(#prefix+1))
        -- Seul allowed_item (en base) est accepté
        local row = MySQL.Sync.fetchAll("SELECT allowed_item FROM blanchiment_points WHERE id = @id", { ['@id']=id })[1]
        if row and itemName ~= row.allowed_item then
            return callback(false)
        end
    end
    callback(true)
end)

-- 4) Transformation automatique après délai
AddEventHandler('ox_inventory:itemAdded', function(source, stashName, itemName, count)
    local prefix = 'blanch_'
    if stashName:sub(1, #prefix) == prefix then
        local id  = tonumber(stashName:sub(#prefix+1))
        local row = MySQL.Sync.fetchAll([[
            SELECT output_item FROM blanchiment_points WHERE id = @id
        ]], { ['@id']=id })[1]
        if row and itemName == row.allowed_item then
            SetTimeout(TRANSFORM_DELAY_MS, function()
                if ESX.GetPlayerFromId(source) then
                    local removed = ox_inventory:RemoveItem(source, stashName, itemName, count)
                    if removed then
                        ox_inventory:AddItem(source, stashName, row.output_item, count)
                        TriggerClientEvent('esx:showNotification', source,
                            count .. 'x ' .. row.output_item .. ' prêts à être récupérés')
                    end
                end
            end)
        end
    end
end)
