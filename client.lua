local RSGCore = exports['rsg-core']:GetCoreObject()
local RouletteTable = {}
local isRouletteTurning = false

Citizen.CreateThread(function()
    -- Wait for the world to load
    Citizen.Wait(2000)
    
    -- Target all roulette tables in the world
    local rouletteModel = GetHashKey("p_roulettetable01x")
    exports.ox_target:addModel(rouletteModel, {
        {
            name = 'roulette_place_bet',
            icon = 'fas fa-coins',
            label = 'Place Bet',
            onSelect = function()
                OpenBetMenu()
            end
        },
        {
            name = 'roulette_spin',
            icon = 'fas fa-spinner',
            label = 'Spin Roulette',
            onSelect = function()
                TriggerServerEvent('rsg-roulette:server:spinRoulette')
            end
        }
    })
end)

-- Check if player is near a roulette table
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local nearTable = false
        
        for id, table in pairs(RouletteTable) do
            local distance = #(coords - table.position.coords)
            if distance < 2.5 then
                nearTable = true
                if not table.players[GetPlayerServerId(PlayerId())] then
                    table.players[GetPlayerServerId(PlayerId())] = true
                    TriggerEvent('rsg-roulette:client:nearTable', id)
                end
            else
                if table.players[GetPlayerServerId(PlayerId())] then
                    table.players[GetPlayerServerId(PlayerId())] = nil
                    TriggerEvent('rsg-roulette:client:leaveTable', id)
                end
            end
        end
        
        if nearTable and not isRouletteTurning then
            showRouletteInteraction()
        end
    end
end)

function showRouletteInteraction()
    lib.showTextUI('[B] Place Bet | [G] Spin Roulette', {
        position = "top-center",
        icon = 'fa-solid fa-coins',
        style = {
            borderRadius = 0,
            backgroundColor = '#3f3f3f',
            color = 'white'
        }
    })
    
    if IsControlJustPressed(0, 0xE8342FF2) then -- B key
        lib.hideTextUI()
        OpenBetMenu()
    elseif IsControlJustPressed(0, 0x760A9C6F) then -- G key
        lib.hideTextUI()
        TriggerServerEvent('rsg-roulette:server:spinRoulette')
    end
end

RegisterNetEvent('rsg-roulette:client:spinAnimation')
AddEventHandler('rsg-roulette:client:spinAnimation', function(tableId, result)
    -- Get the closest roulette table
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local closestTable = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, GetHashKey("p_roulettetable01x"), false, false, false)
    
    if closestTable ~= 0 then
        isRouletteTurning = true
        
        -- Get table coords
        local tableCoords = GetEntityCoords(closestTable)
        
        -- Simulate wheel spinning with a sequence of notifications
        local spinDuration = 5000 -- Total spin duration in milliseconds
        local interval = 500 -- Interval between "spin" updates in milliseconds
        local steps = math.floor(spinDuration / interval)
        local sampleNumbers = { "0", "32", "15", "19", "4", "21", "2", "25", "17", "34" } -- Sample roulette numbers for effect
        local sampleColors = { "green", "red", "black", "red", "black", "red", "black", "red", "black", "red" } -- Corresponding colors
        
        for i = 1, steps do
            -- Pick a random number and color for the spinning effect
            local randomIndex = math.random(1, #sampleNumbers)
            local displayNumber = sampleNumbers[randomIndex]
            local displayColor = sampleColors[randomIndex]
            
            -- Show spinning notification
            lib.notify({
                title = 'ð° Roulette Spinning ð°',
                description = 'Ball passing: ' .. displayNumber .. ' (' .. string.upper(displayColor) .. ')',
                type = 'inform',
                duration = interval,
                position = 'top-center',
                icon = 'fa-solid fa-spinner'
            })
            
            -- Wait for the interval
            Citizen.Wait(interval)
        end
        
        -- Show final result
        lib.notify({
            title = 'ð° Roulette Result ð°',
            description = 'The ball landed on ' .. result.number .. ' (' .. string.upper(result.color) .. ')',
            type = 'success',
            duration = 5000,
            position = 'top-center'
        })
        
        isRouletteTurning = false
    end
end)


RegisterNetEvent('rsg-roulette:client:leaveTable')
AddEventHandler('rsg-roulette:client:leaveTable', function(tableId)
    lib.hideTextUI()
end)

RegisterNetEvent('rsg-roulette:client:showWinnings')
AddEventHandler('rsg-roulette:client:showWinnings', function(winningBets)
    local winDescription = ''
    
    for i, bet in ipairs(winningBets) do
        winDescription = winDescription .. '- ' .. bet.type .. ' ' .. tostring(bet.value) .. ': $' .. bet.winnings .. '\n'
    end
    
    lib.notify({
        title = 'ð° Roulette Winnings ð°',
        description = winDescription,
        type = 'success',
        duration = 7000
    })
end)


function OpenBetMenu()
    lib.registerContext({
        id = 'roulette_bet_menu',
        title = 'Roulette Betting',
        options = {
            {
                title = 'Bet on Color',
                description = 'ð° Bet on Red or Black ð°',
                icon = 'palette',
                onSelect = function()
                    BetOnColor()
                end
            }
            
        }
    })
    
    lib.showContext('roulette_bet_menu')
end



function BetOnColor()
    lib.registerContext({
        id = 'roulette_color_menu',
        title = 'Bet on Color',
        menu = 'roulette_bet_menu',
        options = {
            {
                title = 'Red',
                description = 'ð°Bet on Red numbers',
                icon = 'circle',
                iconColor = 'red',
                onSelect = function()
                    PlaceBetOnColor('red')
                end
            },
            {
                title = 'Black',
                description = 'ð°Bet on Black numbers',
                icon = 'circle',
                iconColor = 'black',
                onSelect = function()
                    PlaceBetOnColor('black')
                end
            }
        }
    })
    
    lib.showContext('roulette_color_menu')
end

function PlaceBetOnColor(color)
    local input = lib.inputDialog('Bet on ' .. string.upper(color), {
        {type = 'number', label = 'Bet Amount ($)', description = 'Enter your bet amount', icon = 'dollar-sign', min = 1, required = true}
    })
    
    if input then
        local amount = tonumber(input[1])
        if amount > 0 then
            TriggerServerEvent('rsg-roulette:server:placeBet', 'color', color, amount)
        else
            lib.notify({
                title = '?? Invalid Bet',
                description = 'Please enter a valid amount',
                type = 'error'
            })
        end
    end
end
