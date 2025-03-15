local RSGCore = exports['rsg-core']:GetCoreObject()
local Bets = {}

-- Server Events
RegisterServerEvent('rsg-roulette:server:placeBet')
AddEventHandler('rsg-roulette:server:placeBet', function(betType, betValue, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local cash = Player.Functions.GetMoney('cash')
    if cash < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🔴 Not enough money!',
            description = 'You need $' .. amount .. ' to place this bet',
            type = 'error'
        })
        return
    end
    
    -- Check if bet is valid
    if not Config.BetTypes[betType] and betType ~= "number" then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '⚠️ Invalid bet type!',
            type = 'error'
        })
        return
    end
    
    -- Take money from player
    Player.Functions.RemoveMoney('cash', amount)
    
    -- Register bet
    if not Bets[src] then
        Bets[src] = {}
    end
    
    table.insert(Bets[src], {
        type = betType,
        value = betValue,
        amount = amount
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '✅ Bet Placed',
        description = '$' .. amount .. ' on ' .. betType .. ' ' .. tostring(betValue),
        type = 'success'
    })
end)

RegisterServerEvent('rsg-roulette:server:spinRoulette')
AddEventHandler('rsg-roulette:server:spinRoulette', function()
    local src = source
    local tableId = 1 -- This should be determined based on which table the player is at
    
    -- Check if there are any bets
    local hasBets = false
    for _, bets in pairs(Bets) do
        if #bets > 0 then
            hasBets = true
            break
        end
    end
    
    if not hasBets then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '⚠️ No bets placed!',
            description = 'Place bets before spinning the wheel',
            type = 'error'
        })
        return
    end
    
    -- Generate a random result
    local resultIndex = math.random(0, 36)
    local result = Config.RouletteNumbers[resultIndex]
    
    -- Broadcast spin animation to all players near the table
    TriggerClientEvent('rsg-roulette:client:spinAnimation', -1, tableId, result)
    
    -- Process winnings after animation delay
    Citizen.Wait(6000)
    ProcessWinnings(result)
end)

function ProcessWinnings(result)
    for playerId, bets in pairs(Bets) do
        local totalWinnings = 0
        local winningBets = {}
        
        for _, bet in ipairs(bets) do
            local win = 0
            
            -- Check if bet won
            if bet.type == "number" and bet.value == result.number then
                win = bet.amount * 36 -- 35 to 1 + original bet
            elseif bet.type == "color" and bet.value == result.color then
                win = bet.amount * 2 -- 1 to 1 + original bet
            elseif bet.type == "even" and result.number % 2 == 0 and result.number > 0 then
                win = bet.amount * 2
            elseif bet.type == "odd" and result.number % 2 == 1 then
                win = bet.amount * 2
            elseif bet.type == "low" and result.number >= 1 and result.number <= 18 then
                win = bet.amount * 2
            elseif bet.type == "high" and result.number >= 19 and result.number <= 36 then
                win = bet.amount * 2
            elseif bet.type == "dozen1" and result.number >= 1 and result.number <= 12 then
                win = bet.amount * 3 -- 2 to 1 + original bet
            elseif bet.type == "dozen2" and result.number >= 13 and result.number <= 24 then
                win = bet.amount * 3
            elseif bet.type == "dozen3" and result.number >= 25 and result.number <= 36 then
                win = bet.amount * 3
            elseif bet.type == "column1" and result.number % 3 == 1 then
                win = bet.amount * 3
            elseif bet.type == "column2" and result.number % 3 == 2 then
                win = bet.amount * 3
            elseif bet.type == "column3" and result.number % 3 == 0 and result.number > 0 then
                win = bet.amount * 3
            end
            
            if win > 0 then
                totalWinnings = totalWinnings + win
                table.insert(winningBets, {type = bet.type, value = bet.value, amount = bet.amount, winnings = win})
            end
        end
        
        local Player = RSGCore.Functions.GetPlayer(playerId)
        if Player and totalWinnings > 0 then
            Player.Functions.AddMoney('cash', totalWinnings)
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = '🎉 Roulette Win!',
                description = 'You won $' .. totalWinnings .. '!',
                type = 'success'
            })
            
            -- Send detailed winning information
            TriggerClientEvent('rsg-roulette:client:showWinnings', playerId, winningBets)
        elseif Player then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = '🎲 Better luck next time!',
                type = 'inform'
            })
        end
    end
    
    -- Clear all bets
    Bets = {}
end

