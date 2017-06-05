-- ~~~~~~
-- Script by dzikakulka
-- Issues, history at: https://github.com/tjakubo2/TTS_xwing
-- ~~~~~~

--[[
                                                 ,  ,
                                               / \/ \
                                              (/ //_ \_
     .-._                                      \||  .  \
      \  '-._                            _,:__.-"/---\_ \
 ______/___  '.    .--------------------'~-'--.)__( , )\ \
`'--.___  _\  /    |             Here        ,'    \)|\ `\|
     /_.-' _\ \ _:,_          Be Dragons           " ||   (
   .'__ _.' \'-/,`-~`                                |/
       '. ___.> /=,|  Abandon hope all ye who enter  |
        / .-'/_ )  '---------------------------------'
        )'  ( /(/
             \\ "
              '=='

This bag serves as a main source for list spawner and item browser with kind of piggybacked
functionaliy for collection generation. Includes how to (not really) do a state machine, give
up on it halfway and *still* make it work. I could really use someone deleting all of it
and forcing me to rewrite this from scratch.
For the most part though, it works out just fine.
--]]

--------
-- SPAWNER MODULE

-- Items available for spawn are added buy passing bags (gets their contents)
-- Items added once can be spawned any number of times, as long as previously spawned
--  items are not deleted
-- Allows for a search it item is avaialable for spawn
-- Items are keyed by name, case-indifferent
-- Passing items with same names not allowed - modify names if necesary (e.g. prefix option)

-- No connection to builder module, no elaborate error handling ( <- I wish this was still true )

Spawner = {}

-- Key: raw name, Value: {source='bag'|'obj', ref=objRef|bagRef, bGUID=bagGuid}
Spawner.items = {}

-- Add all contents of bagRef bag for spawning
-- If prefix is provided, concatenate added items names with it
Spawner.Fill = function(bagRef, prefix)
    if prefix == nil then prefix = '' end -- prefix the names
    local items = bagRef.getObjects()
    for k,info in pairs(items) do
        -- Add item with LOWERCASE name, warn and replace if it's double
        if Spawner.items[string.lower(prefix .. info.name)] ~= nil then
            print('WARNING: Double item \'' .. string.lower(prefix .. info.name) .. '\' from \'' .. bagRef.getName() .. '\' bag')
        end
        local desc = nil
        --if Spawner.extraInfo[info.name] ~= nil then
        --    desc = Spawner.extraInfo[info.name]
        --end
        Spawner.items[string.lower(prefix .. info.name)] = {source='bag', ref=bagRef, bGUID=info.guid, name=info.name}--, desc=info.description}
    end
end

-- Spawn an item keyed as itemName at provided postion and rotation
-- Return the spawned item reference, nil if not found
Spawner.Spawn = function(itemName, pos, rot)
    -- Item not found
    if Spawner.items[string.lower(itemName)] == nil then
        print('ERROR: Attempt to spawn unknown item \'' .. string.lower(itemName) .. '\'')
        return nil
    end
    -- Fill variables
    if pos == nil then pos = {0, 0, 0} end
    if rot == nil then
        rot = {0, 0, 0}
    elseif type(rot) == 'number' then
        rot = {0, rot, 0}
    end
    -- Take LOWERCASE name
    local item = Spawner.items[string.lower(itemName)]
    local newObj = nil
    -- If it was not yet spawned (still in bag)
    if item.source == 'bag' then
        -- Take the object
        newObj = item.ref.takeObject({guid=item.bGUID, position=pos, rotation=rot})
        -- Set its origin to the newly spawned object
        Spawner.items[string.lower(itemName)].source = 'obj'
        Spawner.items[string.lower(itemName)].ref = newObj
        Spawner.items[string.lower(itemName)].bGUID = nil
    else
        -- If origin object was deleted
        if item.ref == nil then
            print('ERROR: Origin item \'' .. string.lower(itemName) .. '\' ref nil')
            return nil
        else
        -- If origin object exists, clone it
            newObj = item.ref.clone({position=pos})
        end
    end
    newObj.setPosition(pos)
    newObj.setRotation(rot)
    return newObj
end

-- Spawn an item keyed as itemName at provided postion and rotation
-- Return the spawned item reference, nil if not found
-- Instead of switching the item to object source mode, put it back in the bag if taken from bag
Spawner.SpawnReturn = function(itemName, pos, rot)
    -- Item not found
    if Spawner.items[string.lower(itemName)] == nil then
        print('ERROR: Attempt to spawn unknown item \'' .. string.lower(itemName) .. '\'')
        return nil
    end
    -- Fill variables
    if pos == nil then pos = {0, 0, 0} end
    if rot == nil then
        rot = {0, 0, 0}
    elseif type(rot) == 'number' then
        rot = {0, rot, 0}
    end
    -- Take LOWERCASE name
    local item = Spawner.items[string.lower(itemName)]
    local newObj = nil
    -- If it was not yet spawned (still in bag)
    if item.source == 'bag' then
        -- Take the object
        newObj = item.ref.takeObject({guid=item.bGUID, position=pos, rotation=rot})
        local cloneObj = newObj.clone({})
        cloneObj.lock()
        cloneObj.setPosition(Builder.LocalPos({0, -3, 0}, item.ref))
        item.ref.putObject(cloneObj)
    else
        -- If origin object was deleted
        if item.ref == nil then
            print('ERROR: Origin item \'' .. string.lower(itemName) .. '\' ref nil')
            return nil
        else
        -- If origin object exists, clone it
            newObj = item.ref.clone({position=pos})
        end
    end
    newObj.setPosition(pos)
    newObj.setRotation(rot)
    return newObj
end

-- Return true if queried name exists, false if it doesn't
Spawner.Find = function(itemName)
    if Spawner.items[string.lower(itemName)] == nil then return false
    else return true end
end

-- Return item matches
-- Arg: {word1, word2, ... , wordN}
-- Return: {ships={entry1, entry2, ...}, upgrades={entry1, entry2, ...}, misc={entry1, entry2, ...}}
-- Entry: {name=prettyItemName, key=itemSpawnKey}
Spawner.ReturnMatches = function(searchWords)
    local matches = {ships={}, upgrades={}, misc={}}

    for itemName,itemInfo in pairs(Spawner.items) do
        for k,word in pairs(searchWords) do
            local acronym = true
            for i=1,word:len() do
                if word:sub(i,i) ~= string.upper(word:sub(i,i)) or tonumber(word:sub(i,i)) ~= nil then
                    acronym = false
                end
            end
            if acronym then
                local nameWords = {}
                for nameWord in itemInfo.name:gmatch('[^%s]+') do
                    table.insert(nameWords, nameWord)
                end
                local match = true
                if #nameWords ~= word:len() then
                    match = false
                end
                if match then
                    for k,nameWord in pairs(nameWords) do
                        if string.lower(nameWord:sub(1,1)) ~= string.lower(word:sub(k,k)) then
                            match = false
                            break
                        end
                    end
                end
                if match then
                    if itemName:sub(1,8) == 'upgrade:' then
                        table.insert(matches.upgrades, {name=itemInfo.name, key=itemName})
                    elseif itemName:sub(1,5) == 'ship:' then
                        local listName = itemInfo.name
                        --print(itemName)
                        --if itemName:find(' v[1-9]') ~= nil then
                        --    listName = listName:sub(1, -3) .. '(' .. itemInfo.desc .. ')'
                        --    print('hit')
                        --end
                        table.insert(matches.ships, {name=listName, key=itemName})
                    elseif itemName:find('refcard') ~= nil or itemName:find('dials') ~= nil then
                        table.insert(matches.misc, {name=itemInfo.name, key=itemName})
                    end
                end
            elseif word:len() > 2 then
                if itemName:find(string.lower(word)) ~= nil then
                    if itemName:sub(1,8) == 'upgrade:' then
                        table.insert(matches.upgrades, {name=itemInfo.name, key=itemName})
                    elseif itemName:sub(1,5) == 'ship:' then
                        local listName = itemInfo.name
                        --print(itemName)
                        --if itemName:find(' v[1-9]') ~= nil then
                        --    listName = listName:sub(1, -3) .. '(' .. itemInfo.desc .. ')'
                        --    print('hit')
                        --end
                        table.insert(matches.ships, {name=listName, key=itemName})
                    elseif itemName:find('refcard') ~= nil or itemName:find('dials') ~= nil then
                        table.insert(matches.misc, {name=itemInfo.name, key=itemName})
                    end
                end
            end
        end
    end

    return matches
end

-- END SPAWNER MODULE
--------

--------
-- BUILDER MODULE

-- Builds lists, usually.

Builder = {}


-- Initialize this bag in squadron builder mode
function startAsBuilder()
    init()
    local rot = {self.getRotation()[1], self.getRotation()[2]+180, self.getRotation()[3]}
    Builder.noteObj = Spawner.Spawn('Spawn Me', Builder.LocalPos({-15, 0.5, 2}), rot)

    -- Change button to spawning function:
    self.clearButtons()
    Builder.generalButton.click_function = 'start'
    Builder.generalButton.label = 'Spawn it!'
    Builder.generalButton.width = 3500
    self.createButton(Builder.generalButton)
end

-- Start the spawn routine
function start()
    self.clearButtons()
    Builder.ParseInput(note)
end

-- Elements placement config
Builder.config = {
    -- TOP VIEW
    --  ?? (y axis)
    --  |
    -- ??? --- > (x axis)
    -- (z axis)

    -- Cards dimensions WxH:
    -- 2.35 x 3.25 -- (1.175 x 1.625) PC
    -- 2.1 x 1.4   -- (1.05 x 0.7)    UG
    global_z = 0.5,
    refcardOffset_y = 0,
    refcardOffset_x = -12,
    refcardSpacing_x = 3,
    dialOffset_y = -3,
    dialOffset_x = -12,
    dialSpacing_x = 3,
    shipOffset_y = -4,
    shipSpacing_x = 5.5,
    pilotOffset_y = -4,
    pilotSpacing_x = 5.5,
    upgOffset_y = -1*((3.25/2)+(2.1/2)),
    upgSpacing_x = 1.4,
    upgSpacing_y = -2.1,
    upgRowCount = 3,
    shieldInitOffset = {1.65, 0.1, 1},
    shieldColCount = 3,
    shieldSpacing_x = 0.8,
    shieldSpacing_y = -0.9,
    shieldEvenColInset_y = -0.45
}
-- Shorthand for accesing config elements
local BC = Builder.config

-- Initial position for refcards
Builder.RefcardInitPos = function(refcardCount)
    return {-1*(BC.refcardSpacing_x/2)*(refcardCount-1)+BC.refcardOffset_x, BC.global_z, BC.refcardOffset_y}
end
-- Step refcard position
Builder.RefcardStep = function(currPos)
    return {currPos[1]+BC.refcardSpacing_x, currPos[2], currPos[3]}
end

-- Initial position for dial bags
Builder.DialInitPos = function(dialCount)
    return {-1*(BC.dialSpacing_x/2)*(dialCount-1)+BC.dialOffset_x, BC.global_z, BC.refcardOffset_y+BC.dialOffset_y}
end
-- Step dial bag position
Builder.DialStep = function(currPos)
    return {currPos[1]+BC.dialSpacing_x, currPos[2], currPos[3]}
end

-- Initial position for ship models
Builder.ShipInitPos = function(shipCount)
    return {-1*(BC.shipSpacing_x/2)*(shipCount-1), BC.global_z, BC.refcardOffset_y+BC.dialOffset_y+BC.shipOffset_y}
end
-- Step ship model position
Builder.ShipStep = function(currPos)
    return {currPos[1]+BC.shipSpacing_x, currPos[2], currPos[3]}
end

-- Pilot card position for given ship model position
Builder.PilotForShip = function(shipPos)
    return {shipPos[1], shipPos[2], shipPos[3]+BC.pilotOffset_y}
end

-- Initial upgrade card position for given pilot cad position
Builder.UpgForPilotInit = function(pilotPos, upgCount)
    if upgCount > 3 then upgCount = 3 end
    return {pilotPos[1]-(BC.upgSpacing_x/2)*(upgCount-1), pilotPos[2], pilotPos[3]+BC.upgOffset_y}
end
-- Step upgrade card position
Builder.UpgStep = function(currPos, upgNumber)
    if upgNumber%BC.upgRowCount == 0 then
        return {currPos[1]-(2*BC.upgSpacing_x), currPos[2], currPos[3]+BC.upgSpacing_y}
    else
        return {currPos[1]+BC.upgSpacing_x, currPos[2], currPos[3]}
    end
end

-- Initial shield token position in the pilot card frame
Builder.ShieldInPilotFrameInit = function()
    return BC.shieldInitOffset
end
-- Step shield position
Builder.ShieldInPilotFrameStep = function(currPos, shieldNumber)
    if shieldNumber%BC.shieldColCount == 0 then
        local column = math.floor(shieldNumber/BC.shieldColCount)+1
        local colOffset_y = 0
        if column%2 == 0 then
            colOffset_y = BC.shieldEvenColInset_y
        end
        return {currPos[1]+BC.shieldSpacing_x, currPos[2], currPos[3]-2*BC.shieldSpacing_y+colOffset_y}
    else
        return {currPos[1], currPos[2], currPos[3]+BC.shieldSpacing_y}
    end
end

-- Main pilots table
-- Key: numerical, Value:{name=pilotName, pRef=pilotRef, sRef=shipRef, upgrades=upgTable, shipName=shipName}
-- [[upgTable]] Key: numerical, Value: {name=upgName, ref=upgRef}
Builder.pilots = {}

-- Table containing pilots indexes grouped by name
-- Key: pilotName, Value:{keyInPilots1, keyInPilots2, ... , keyInPilotsN}
Builder.pilotCount = {}

-- Table containing pilots indexes grouped by ship type
-- Key: shipName, Value:{keyInPilots1, keyInPilots2, ... , keyInPilotsN}
Builder.ships = {}
-- Above table entry count (it's string keyed so # operator doesn't work)
Builder.shipsCount = 0

-- Table containing references for accesories per each ship type
-- Key: shipName, Value:{dRef=dialRef, rcRef=refcardRef}
Builder.accesories = {}

-- Table with miscellaneous items spawned (subclasses)
Builder.misc = {}
-- Table with spawned shield sets refs
-- Key: numericalFromPilots {sRefs={shRef1, shRef2, ... , shRefN}}
Builder.misc.shields = {}
-- Table with any tokens spawned + parent item if applicable
-- Key: numerical {pRef=parentRef, tRef=tokenRef}
Builder.misc.tokens = {}
-- Table for any other spawned items
-- Key: numerical {ref=object, com=comment}
Builder.misc.other = {}

-- Table with user choices between same name pilot spawns
-- Key: numerical, Value:{cName=commonName, pCards={pilotCard1ref, pilotCard2ref, ... , pilotCardNref},
--                        pilotsIndex=indexInPilotsTable, sPos=shipPos, pPos=pilotPos, resolved=true/false}}
Builder.choices = {}

-- Create an interactive user choice - spawn cards with buttons, fill choices table
Builder.CreateChoice = function(commonName, shipPos, pilotsIndex)
    -- Create a new choice table
    local cTable = {}
    cTable.resolved = false
    cTable.pilotsIndex = pilotsIndex
    cTable.cName = commonName
    cTable.sPos = shipPos
    cTable.pPos = Builder.PilotForShip(shipPos)
    cTable.rot = self.getRotation()
    cTable.pCards = {}

    local choiceButton = {
        click_function = 'Click_resolveChoice',
        function_owner = self,
        label = 'Choose',
        position = {0, 0.5, 2},
        rotation = {0, 0, 0},
        width = 1000,
        height = 400,
        font_size = 200
    }

    -- Get all the choice possibilities
    local choiceNames = {}
    for k=1,3,1 do
        if Spawner.Find(commonName .. ' v' .. k) then
            table.insert(choiceNames, commonName .. ' v' .. k)
            if Spawner.Find('Ship: ' .. commonName .. ' v' .. k) ~= true then
                Builder.Log('Ship model \'' .. commonName .. ' v' .. k .. '\' not found... Stop')
                Builder.DisplayLog()
                return
            end
        end
    end
    -- Spawn choice cards, create buttons, tag with choice ID
    for k,name in pairs(choiceNames) do
        local newCardPos = {cTable.sPos[1]-(2.35/2)*(#choiceNames-1)+(k-1)*(2.35), cTable.sPos[2], cTable.sPos[3]}
        local newCard = Spawner.Spawn(name, Builder.LocalPos(newCardPos), cTable.rot)
        table.insert(cTable.pCards, newCard)
        newCard.setVar('choiceID', #Builder.choices+1)
        newCard.createButton(choiceButton)
    end
    table.insert(Builder.choices, cTable)
end

-- Resolve choice avaialble as click function
function Click_resolveChoice(object, dummy)
    Builder.ResolveChoice(object)
end

-- Called when one of the choice cards is clicked
Builder.ResolveChoice = function(clickedCard)
    local corrPilot = clickedCard
    local corrShip = nil
    local cTable = Builder.choices[corrPilot.getVar('choiceID')]
    for k,choice in pairs(cTable.pCards) do
        -- Delete other choice cards
        if choice ~= corrPilot then
            choice.destruct()
        else
        -- Set this card in correst position, spawn its ship
            choice.clearButtons()
            choice.setPosition(Builder.LocalPos(cTable.pPos))
            if Spawner.Find('Ship: ' .. corrPilot.getName()) == true then
                corrShip = Spawner.Spawn('Ship: ' .. corrPilot.getName(), Builder.LocalPos(cTable.sPos), cTable.rot)
            else
                Builder.Die('B26', 'Spawn choice \'' .. corrPilot.getName() .. '\' ship not found')
            end
        end
    end
    -- Fill pilots table, rename correctly
    Builder.pilots[cTable.pilotsIndex].pRef = corrPilot
    Builder.pilots[cTable.pilotsIndex].sRef = corrShip
    corrPilot.setName(Builder.pilots[cTable.pilotsIndex].name)
    corrShip.setName(Builder.pilots[cTable.pilotsIndex].name)
    --corrShip.setDescription('')
    cTable.resolved = true

    -- Advance spawn state if that was the last choice
    if Builder.AllResolved() == true then Builder.AdvanceState(Builder.states.CoreSpawned) end
end

-- Are all choices resolved? Returns true/false
Builder.AllResolved = function()
    local allResolved = true
    for k,cInfo in pairs(Builder.choices) do
        if cInfo.resolved ~= true then allResolved = false end
    end
    return allResolved
end

-- Small logging module for user-friendly errors
-- Log string
Builder.log = ''
-- Add some message (new line) to the log
Builder.Log = function(logMsg)
    Builder.log = Builder.log .. logMsg .. '\n'
end
-- Display the log on note if it exists, highlight it
Builder.DisplayLog = function(color)
    if color == nil then color = {1, 0, 0} end
    if Builder.noteObj ~= nil then
        Builder.noteObj.setDescription(Builder.log)
        Builder.noteObj.highlightOn(color, 6)
    end
end

-- Add a blank (name only) entry to the main pilots table
Builder.AddPilot = function(pilotName)
    pilotName = Builder.ErrataPass(pilotName)
    if Builder.pilotCount[pilotName] == nil then
        Builder.pilotCount[pilotName] = {}
    end
    table.insert(Builder.pilotCount[pilotName], #Builder.pilots + 1)
    table.insert(Builder.pilots, {name = pilotName, pRef = nil, sRef = nil, upgrades = {}, count = #Builder.pilotCount[pilotName]})
end
-- Duplicate some pilot with his upgrades
-- No index passed = last pilot duplicated
Builder.DuplicatePilot = function(pilotIndex)
    if pilotIndex == nil or pilotIndex > #Builder.pilots then
        pilotIndex = #Builder.pilots
    end
    local origPilot = Builder.pilots[pilotIndex]
    Builder.AddPilot(origPilot.name)
    for k,uTable in pairs(origPilot.upgrades) do
        Builder.AddUpgrade(uTable.name)
    end
end
-- Add an empty upgrade entry (name only) to the pilot at given index
-- If index not provided, adds to the last pilot
Builder.AddUpgrade = function(upgName, pilotIndex)
    upgName = Builder.ErrataPass(upgName)
    if pilotIndex == nil or pilotIndex > #Builder.pilots then
        pilotIndex = #Builder.pilots
    end
    table.insert(Builder.pilots[pilotIndex].upgrades, {name=upgName, ref=nil})
end
-- Get the upgrade table for pilot of given index
Builder.GetUpgrades = function(pilotIndex)
    if Builder.pilots[pilotIndex] ~= nil then
        return Builder.pilots[pilotIndex].upgrades
    end
end
-- Check if pilot at some index has specified upgrade (not neccesarily spawned already)
-- pilotIndex can be 'any' to check all pilots
-- Returns false/true
Builder.HasUpgrade = function(upgName, pilotIndex)
    if type(pilotIndex) == 'number' then
        local upgrades = Builder.GetUpgrades(pilotIndex)
        local found = false
        for k,uTable in pairs(upgrades) do
            if string.lower(uTable.name) == string.lower(upgName) then found = true end
        end
        return found
    elseif string.lower(pilotIndex) == 'any' then
        local found = false
        for k=1,#Builder.pilots,1 do
            if Builder.HasUpgrade(upgName, k) == true then found = true end
        end
        return found
    end
end

-- Prints squad, judt for debugging
Builder.PrintSquad = function()
    print('--- SQUAD ---')
    for k,pilotTable in pairs(Builder.pilots) do
        print(' - P: \'' .. pilotTable.name .. '\'')
        for k2,upgTable in pairs(pilotTable.upgrades) do
            print(' - - U: \'' .. upgTable.name .. '\'')
        end
    end
    print('--- END SQUAD ---')
end

-- Trim a string of whitespaces
Builder.TrimWord = function(word)
    return word:match("^%s*(.-)%s*$")
end

-- Create notebook "Spawn Me" tab for parsing long lists
-- Removes any that already exist
Builder.CreateNotebookTab = function(playerName)
    Builder.RemoveNotebookTab()
    local tabBody = 'Delete all this, paste your list here and press the "Parse Notebook" button'
    if playerName ~= nil and type(playerName) == 'string' then
        tabBody = tabBody .. '\nThis tab was created by ' .. playerName ..  '\'s too long list snippet spawn attempt'
    end
    addNotebookTab({title='Spawn Me', body=tabBody})
end

-- Parse the text from created "Spawn Me" notebook tab
-- If it still contains initial message, return empty string
-- If none exists, return empty string
Builder.ParseFromNotebookTab = function()
    local tabs = getNotebookTabs()
    local body = ''
    for k,tTable in pairs(tabs) do
        if tTable.title == 'Spawn Me' then
            body = tTable.body
        end
    end
    if body:sub(1,15) == 'Delete all this' then
        body = ''
    end
    return body
end

-- Remove all created "Spawn Me" notebook tabs
Builder.RemoveNotebookTab = function()
    local tabs = getNotebookTabs()
    local tabsToRemove = {}
    for k, tTable in pairs(tabs) do
        if tTable.title == 'Spawn Me' then
            table.insert(tabsToRemove, tTable.index)
        end
    end
    for k,ind in pairs(tabsToRemove) do
        removeNotebookTab(ind)
    end
end

-- Button definition for the main bag
-- Lacks click_function, width, label
Builder.generalButton = {
    function_owner = self,
    position = {0, 0.5, 3},
    rotation = {0, 0, 0},
    height = 800,
    font_size = 20000,
    click_function='dummy'
}

-- Click function for the "Parse notebook" button
function Click_ParseNotebook()
    Builder.ParseInput()
end

-- Are we waiting for user to paste his list in the notebook?
Builder.waitingForNotebook = false

-- Note object
Builder.noteObj = nil

-- Text set on the note if we need to parse through notebook
Builder.waitForNotebookNote =
[[The list you have pasted is too long to be parsed through notecard descripton.
Please open the Notebook (button in top bar), select the "Spawn Me" tab, delete all the text there, paste your list (just as you did there) and click 'Parse Notebook' button.

If that notebook tab is initially empty and/or you can't paste into it, switch to another notebook tab and back to it.]]

-- Parse the text list - first from the note, it it is too long, switch to notebook parsing
Builder.ParseInput = function()
    -- If we're parsing from the note
    if Builder.waitingForNotebook == false then
        local input = Builder.noteObj.getDescription()
        -- If the note text is close to character limit, switch to notebook parsing
        if input:len() > 360 then
            Builder.noteObj.setDescription(Builder.waitForNotebookNote)
            Builder.noteObj.highlightOn({0, 1, 0}, 6)
            printToAll('Built list too long, follow instructions on the notecard you pasted to', {1, 1, 0})
            Builder.waitingForNotebook = true
            Builder.CreateNotebookTab()
            Builder.generalButton.click_function = 'Click_ParseNotebook'
            Builder.generalButton.label = 'Parse notebook'
            Builder.generalButton.width = 5500
            self.createButton(Builder.generalButton)
        else
        -- If text is reasonably short, proceed with processing
            Builder.ProcessInput(input)
        end
    else
    -- If we're already parsing from the notebook
        local input = Builder.ParseFromNotebookTab()
        -- Prompt empty or unchanged tab or delete it and proceed with processing
        if input == '' then
            printToAll('Notebook \'Spawn Me\' tab unchanged or empty!', {1, 1, 0})
            return
        else
            Builder.RemoveNotebookTab()
            Builder.Log('Notebook parse succesful')
            Builder.ProcessInput(input)
        end
    end

end

-- Check what format the processed list is in
-- SUPPORTED FORMATS:
-- xwing-builder.co.uk/browse - uk_browse
-- xwing-builder.co.uk/build, Forum or email -> Plain text - uk_Plain
-- xwing-builder.co.uk/build, Forum or email -> Plain text (brief) - uk_PlainBrief
-- geordanr.github.io/xwing, Print/View as text -> BB Code - geordanr_BB
Builder.CheckListFormat = function(input)
    -- Geordanr builder is identified by his website in footer
    if input:find('geordanr.github.io') ~= nil then
        if input:find('<a href=') ~= nil then
            return ''
        else
            return 'geordanr_BB'
        end
    end
    -- co.uk builder "Forum or email" formats contain a
    --> Pilots
    --> ------
    -- snippet, brief has brackets
    if input:find('Pilots[%s]+%-%-%-%-%-%-') ~= nil then
        if input:find('%] %(') ~= nil then
            return 'uk_PlainBrief'
        else
            return 'uk_Plain'
        end
    else
    -- If there's no Pilots-dashes snippet but there are numbers
    -- in parentheses, we take it as a co.uk browse format
        if input:find('%([%d]+%)') ~= nil then
            return 'uk_Browse'
        end
    end
    return ''
end

-- Check list format, parse squad using an approriate function, advance spawn state
Builder.ProcessInput = function(input)
    self.clearButtons()
    Builder.Log('Input parsed')
    local listFormat = Builder.CheckListFormat(input)
    if listFormat ~= '' then
        Builder.Log('Recognized ' .. listFormat .. ' format')
    else
        Builder.Log('Unrecognized list format... Stop')
        Builder.DisplayLog()
        return
    end
    Builder.ParseSquad[listFormat](input)
    Builder.AdvanceState(Builder.states.ListParsed)
end

-- Table containing parse (decode list into table entries) for each supported format
Builder.ParseSquad = {}
Builder.ParseSquad.uk_Browse = function(input)
    -- Strip parentheses with text inside
    input = input:gsub('[%s]%([^%d][%w%s\']+%)', '')
    -- Flag if the next name is a pilot
    local newShip = true
    -- Separate 'words' by opening parentheses OR plus sign
    for word in input:gmatch('[\u{201C}\u{201D}\u{2019}\'\"/%w%s%-%.]+[%s][+%(]') do
        word = Builder.TrimWord(word)
        -- Replace special characters
        word = word:gsub('[\u{201C}\u{201D}]', '"')
        word = word:gsub('\u{2019}', '\'')

        local itemName = word:sub(1, -3)
        local delim = word:sub(-1, -1)
        -- Add new pilot if it is the time
        if newShip == true then
            Builder.AddPilot(Builder.TrimWord(itemName))
        else
            Builder.AddUpgrade(Builder.TrimWord(itemName))
        end
        -- Update the next item type flag
        if delim == '(' then
            newShip = true
        else
            newShip = false
        end
    end
end
Builder.ParseSquad.uk_Plain = function(input)
    -- Cut all the names/headers from input
    local p_b,p_e = input:find('Pilots[%s]+%-%-%-%-%-%-')
    local cutInput = input:sub(p_e+1, -1)
    local prefix = input:sub(1, p_e)
    -- Strip parentheses with text inside
    cutInput = cutInput:gsub('[%s]%([^%d][%w%s\']+%)', '')

    -- Convert:
    --> Pilot (cost) [x times]
    --> ShipName (cost), Upg1 (cost), Upg2 (cost), ... , UpgN (cost)
    -- into
    --> Pilot [upg1, upg2, ... , upgN] (cost)
    -- which is simply co.uk Plain Brief format
    local lines = {}
    for line in string.gmatch(cutInput,'[^\r\n]+') do
        -- If it's just pilot line, add it
        if line:find(',') == nil then
            table.insert(lines, line)
        else
        -- If it's ship and upgrades line
            line = line:gsub('[%s]%([%d]+%)', '')                               -- cut out point costs
            line = Builder.TrimWord(line)
            local firstComma = line:find(',')                                   -- cut out ship name
            line = line:sub(firstComma+2, -1)
            line = ' [' .. line .. ']'                                          -- add brackets
            local e_b,e_e = lines[#lines]:find('[%s]%([%d]+%)')
            local ending = lines[#lines]:sub(e_b, -1)
            lines[#lines] = lines[#lines]:sub(1, e_b-1) .. line .. ending       -- cat with previous line (between pilot and "x times")
        end
    end
    -- Fuse fluff prefix and all the lines
    local finInput = ''
    for k,line in pairs(lines) do
        finInput = finInput .. line .. '\n'
    end
    finInput = prefix .. '\n' .. finInput
    Builder.ParseSquad.uk_PlainBrief(finInput)
end
Builder.ParseSquad.uk_PlainBrief = function(input)
    -- Cut all the names/headers from input
    local p_b,p_e = input:find('Pilots[%s]+%-%-%-%-%-%-')
    local cutInput = input:sub(p_e+1, -1)
    -- Strip parentheses with text inside
    cutInput = cutInput:gsub('[%s]%([^%d][%w%s\']+%)', '')
    -- Convert:
    --> Pilot [upg1, upg2, ... , upgN] (cost)
    -- into:
    --> Pilot + upg1 + upg2 + ... + upgN (cost)
    -- which is simply the co.uk browse format
    cutInput = cutInput:gsub('%s%[', ' + ')
    cutInput = cutInput:gsub(',%s', ' + ')
    cutInput = cutInput:gsub('%]%s%(', ' (')
    local finInput = ''
    -- Replicate any lines that end in 'x [number]' (multiple of these pilots shortened)
    for line in string.gmatch(cutInput,'[^\r\n]+') do
        if (line:sub(-5,-1)):find('x[%s][%d]+') ~= nil then
            local repNum = tonumber((line:sub(-5,-1)):match('x[%s]+([%d]+)'))
            local trimmedLine = line:match('^[%s]*(.-)[%s]+x[%s]+[%d]+[%s]*$')
            for k=1,repNum,1 do
                finInput = finInput .. trimmedLine .. '\r\n'
            end
        else
            finInput = finInput .. line .. '\r\n'
        end
    end
    Builder.ParseSquad['uk_Browse'](finInput)
end
Builder.ParseSquad.geordanr_BB = function(input)
    -- Cut all the footer stuff
    local t_b,t_e = input:find('%[b%]%[i%]Total:')
    local cutInput = input:sub(1, t_b-1)
    -- Replace negative costs since they fuck it up later
    cutInput = cutInput:gsub('%(%-', '(')
    -- Strip parentheses with text inside
    cutInput = cutInput:gsub('[%s]%([^%d][%w%s\']+%)', '')
    -- Split input into lines marked by BB Code bold/italic symbols
    for word in cutInput:gmatch('%[[bi]%][\'\"/%w%s%-%.]+[%s][%(][%d]+[%)]%[/[bi]%]') do
        word = Builder.TrimWord(word)
        -- Determine bold/italic symbol
        local b_i = word:sub(2,2)
        -- Strip BB Code and point cost
        word = word:match('^%[[bi]%]([\'\"/%w%s%-%.]+)[%s][%(][%d]+[%)]%[/[bi]%]$')
        word = Builder.TrimWord(word)
        if b_i == 'b' then
        -- Bold markes marks pilots
            Builder.AddPilot(word)
        elseif b_i == 'i' then
        -- Italic markes marks upgrades
            Builder.AddUpgrade(word)
        end
    end
end

-- Get a position in some object reference frame + height offset
-- Default object - self
-- Default height offset - 0.5
Builder.LocalPos = function(pos, ref, hOff)
    local refOffset = nil
    local refRot = nil
    if ref == nil then ref = self end
    if hOff == nil then hOff = 0.5 end
    if type(ref) == 'table' then
        refOffset = ref
        refRot = ref.rotation
        if refRot == nil then
            refRot = 0
        end
    elseif type(ref) == 'userdata' then
        refOffset = ref.getPosition()
        refRot = math.rad(-1*ref.getRotation()[2])
    else
        Builder.Die('B27', 'Invalid LocalPos reftype')
        return {0, 0, 0}
    end
    local posRot = {pos[3]*math.sin(refRot)-pos[1]*math.cos(refRot), pos[2], -1*pos[1]*math.sin(refRot) - pos[3]*math.cos(refRot)}
    return {posRot[1]+refOffset[1], refOffset[2]+hOff, posRot[3]+refOffset[3]}
end

-- Spawn core elements according to existing pilot/ship tables
-- Spawns ship models, pilot cards and upgrade cards
-- Creates choices when applicable
Builder.SpawnCore = function()
    local shipPos = Builder.ShipInitPos(#Builder.pilots)
    local pilotPos = nil
    local upgPos = nil
    local rot = self.getRotation()
    -- For each pilot
    for k, sInfo in pairs(Builder.pilots) do
        pilotPos = Builder.PilotForShip(shipPos)
        if Spawner.Find('Ship: ' .. sInfo.name) == true then
        -- Spawn his ship model
            sInfo.sRef = Spawner.Spawn('Ship: ' .. sInfo.name, Builder.LocalPos(shipPos), rot)
            if Spawner.Find(sInfo.name) == true then
            -- Spawn his pilot card
                sInfo.pRef = Spawner.Spawn(sInfo.name, Builder.LocalPos(pilotPos), rot)
            else
            -- Error if pilot card not found when there is a ship
                Builder.Log('Pilot \'' .. sInfo.name .. '\' not found... Stop')
                Builder.DisplayLog()
                return false
            end
        elseif Spawner.Find('Ship: ' .. sInfo.name .. ' v1') == true then
        -- Create choice if ship choices exist
            Builder.CreateChoice(sInfo.name, shipPos, k)
        else
        -- Error if neither regular or choices models exist
            Builder.Log('Ship model \'' .. sInfo.name .. '\' not found... Stop')
            Builder.DisplayLog()
            return false
        end
        upgPos = Builder.UpgForPilotInit(pilotPos, #sInfo.upgrades)
        -- For each upgrade for this pilot
        for k2, uInfo in pairs(sInfo.upgrades) do
            if Spawner.Find('Upgrade: ' .. uInfo.name) == true then
            -- Spawn the upgrade if it exists
                uInfo.ref = Spawner.Spawn('Upgrade: ' .. uInfo.name, Builder.LocalPos(upgPos), rot)
            else
            -- Error if upgrade doesn't exist
                Builder.Log('Upgrade \'' .. uInfo.name .. '\' not found... Stop')
                Builder.DisplayLog()
                return false
            end
            upgPos = Builder.UpgStep(upgPos, k2)
        end
        shipPos = Builder.ShipStep(shipPos)
    end
    -- If there were no choices created, advance spawn state
    if Builder.AllResolved() == true then Builder.AdvanceState(Builder.states.CoreSpawned) end
end

-- Add numbers to ship models and pilot cards names if there are multiple of same name
-- Names in tables remain unchanged
Builder.MakeNamesUnique = function()
    for pName,iTable in pairs(Builder.pilotCount) do
        if #iTable > 1 then
            for nr,index in pairs(iTable) do
                local newName = Builder.pilots[index].name .. ' ' .. nr
                Builder.pilots[index].sRef.setName(newName)
                Builder.pilots[index].pRef.setName(newName)
            end
        end
    end
end

-- Table with builder names corrections
-- VERSION PRINTED ON CARD IS ALWAYS THE CORRECT ONE
Builder.Errata = {}
Builder.Errata['IG88-A'] = 'IG-88A'
Builder.Errata['IG88-B'] = 'IG-88B'
Builder.Errata['IG88-C'] = 'IG-88C'
Builder.Errata['IG88-D'] = 'IG-88D'
Builder.Errata['Fire Control System'] = 'Fire-Control System'
Builder.Errata['Burnout Slam'] = 'Burnout SLAM'
Builder.Errata['StarViper Mk. II'] = 'StarViper Mk.II'
Builder.Errata['Countermeasures'] = 'Counter-Measures'

-- Check if a name should be corrected
-- Return correct version (same if no correction entry)
Builder.ErrataPass = function(name)
  local corr = Builder.Errata[name]
  if corr ~= nil and type(corr) == 'string' then
    return corr
  end
  return name
end

-- Fil ship types table
-- This needs to be done once they are spawned (also all choices resolved)
--  since we need physical models with mesh attribute there
-- DEPENDENCY ON THE MAIN TABLE DATABASE!!!
Builder.FillTypes = function()
    for k,pTable in pairs(Builder.pilots) do
        local shipType = Global.call('DB_getShipTypeCallable', {pTable.sRef})
        if shipType == 'Unknown' then
            Builder.Die('B12', 'Unknown \'' .. pTable.name .. '\' model ship type')
        else
            if Builder.ships[shipType] == nil then
                Builder.ships[shipType] = {}
                Builder.shipsCount = Builder.shipsCount + 1
            end
            table.insert(Builder.ships[shipType], k)
        end
        pTable.shipType = shipType
    end
end

-- Verify integrity of all the tables AFTER stuff is spawned
-- Core = ship models, pilot cards, upgrade cards
Builder.ValidateCore = function()
    -- Pilots table integrity
    for k,pTable in pairs(Builder.pilots) do
        if pTable.pRef == nil then Builder.Die('BV02', 'Pilot ' .. k .. ' ref nil') end
        if pTable.sRef == nil then Builder.Die('BV03', 'Ship ' .. k .. ' ref nil') end
        if type(pTable.name) ~= 'string' then Builder.Die('BV04', 'Ship ' .. k .. ' name invalid') end
        if type(pTable.shipType) ~= 'string' then Builder.Die('BV25', 'Ship ' .. k .. ' ship type name invalid') end
        for k2,uInfo in pairs(pTable.upgrades) do
            if uInfo.ref == nil then Builder.Die('BV05', 'Ship ' .. k .. ' upgrade ' .. k2 .. ' ref nil') end
            if type(uInfo.name) ~= 'string' then Builder.Die('BV21', 'Ship ' .. k .. ' upgrade ' .. k2 .. ' name invalid') end
        end
    end
    -- Pilot count table integrity
    for k, ctTable in pairs(Builder.pilotCount) do
        if type(k) ~= 'string' then Builder.Die('BV08', 'Invalid name on a pilot count entry') end
        if #ctTable < 1 then
            Builder.Die('BV17', 'Invalid index table in pilot \'' .. k .. '\' count')
        end
        for k2, index in pairs(ctTable) do
            if k ~= Builder.pilots[index].name then
                Builder.Die('BV05', 'Pilot count name mismatch, ' .. k .. ' & ' .. Builder.pilots[index].name)
            end
        end
    end
    -- Choices table integrity (must be resolved)
    for k, cTable in pairs(Builder.choices) do
        if type(cTable.cName) ~= 'string' then Builder.Die('BV07', 'Invalid name on a conflict') end
        if cTable.resolved ~= true and type(cTable.cName) == 'string' then
            Builder.Die('BV06', 'Unresolved (untagged) choice, name: ' .. cTable.cName)
        end
        local pointingEntry = Builder.pilots[cTable.pilotsIndex]
        if pointingEntry == nil then Builder.Die('BV10', 'Invalid pilots index in a choice') end
        if type(cTable.cName) == 'string' and (cTable.cName ~= Builder.pilots[cTable.pilotsIndex].name) then
            Builder.Die('BV09', 'Name mismatch on a choice an pilot entry: ' .. cTable.cName .. ' & ' .. Builder.Pilots[cTable.pilotsIndex].name)
        end
    end
    -- Ship types table integrity
    for shipType, sTable in pairs(Builder.ships) do
        if type(shipType) ~= 'string' then
            Builder.Die('BV13', 'Invalid ship type')
        end
        if type(sTable) ~= 'table' then
            Builder.Die('BV14', 'Invalid keys table in ' .. shipType .. ' entry')
        end
        for k,index in pairs(sTable) do
            if type(index) ~= 'number' or index > #Builder.pilots then
                Builder.Die('BV23', 'Ship ' .. shipType .. ' index in types index table invalid')
            end
            if Builder.pilots[index].shipType ~= shipType then
                Builder.Die('BV24', 'Ship ' .. shipType .. ' pointing index and pilot ship type name inconsistent')
            end
        end
    end

    -- Advance spawn state - even if validate thrown errors (consecutively thrown error codes may help)
    Builder.AdvanceState(Builder.states.CoreValidated)
end

-- Spawn accesories for each ship type
-- Accesories: dial bags and refcards
Builder.SpawnAccesories = function()
    local dialPos = Builder.DialInitPos(Builder.shipsCount)
    local refcardPos = Builder.RefcardInitPos(Builder.shipsCount)
    local rot = self.getRotation()
    for shipType,pTable in pairs(Builder.ships) do
        local newDial = nil
        local newRefcard = nil
        -- Spawn dial bag
        if Spawner.Find(shipType .. ' Dials') ~= true then
            Builder.Die('B15', 'Cannot find ' .. shipType .. ' dials')
        else
            newDial = Spawner.Spawn(shipType .. ' Dials', Builder.LocalPos(dialPos), rot)
        end
        -- Spawn refcard
        if Spawner.Find(shipType .. ' Refcard') ~= true then
            Builder.Die('B16', 'Cannot find ' .. shipType .. ' refcard')
        else
            newRefcard = Spawner.Spawn(shipType .. ' Refcard', Builder.LocalPos(refcardPos), rot)
        end
        -- Fil tables
        Builder.accesories[shipType] = {dRef=newDial, rcRef=newRefcard}
        dialPos = Builder.DialStep(dialPos)
        refcardPos = Builder.RefcardStep(refcardPos)
    end

    -- Advance spawn state when done
    Builder.AdvanceState(Builder.states.AccesoriesSpawned)
end

-- Validate integrity of the accesories tables
-- Needs to be done after spawning them
Builder.ValidateAccesories = function()
    for shipType,aTable in pairs(Builder.accesories) do
        if type(shipType) ~= 'string' then
            Builder.Die('BV19', 'Invalid name type in accesories table')
        end
        if aTable.dRef == nil or aTable.dRef.getName() ~= shipType .. ' Dials' then
            Builder.Die('BV18', 'Invalid dial object for the ' .. shipType .. ' ship')
        end
        if aTable.rcRef == nil or aTable.rcRef.getName() ~= shipType .. ' Refcard' then
            Builder.Die('BV20', 'Invalid refcard object for the ' .. shipType .. ' ship')
        end
    end
    -- Advance spawn state once done (will pile up errors but that's OK)
    Builder.AdvanceState(Builder.states.AccesoriesValidated)
end

-- Spawn miscellanous things
-- Add new things as needed
Builder.SpawnMisc = function()
    Builder.SpawnShields()
    Builder.SpawnExtraMunitions()
    Builder.SpawnExtraIllicit()
    Builder.SpawnConditionCards()
    Builder.SpawnArcIndicators()
    Builder.SpawnBoShekDials()
    Builder.SpawnSVrollToken()
    Builder.AdvanceState(Builder.states.MiscSpawned)
end

Builder.SpawnSVrollToken = function()
    for k=1,#Builder.pilots,1 do
            local upgrades = Builder.GetUpgrades(k)
            local sRot = self.getRotation()
            local rot = {sRot[1], sRot[2]-90, sRot[3]}
            local offset = {0, 0.1, 0.2}
            for k2,uTable in pairs(upgrades) do
                if uTable.name == 'StarViper Mk.II' then
                    local newRollToken = Spawner.Spawn('StarViper Mk.II roll token', Builder.LocalPos(offset, uTable.ref, 0.1), rot)
                    table.insert(Builder.misc.tokens, {tRef=newRollToken, pRef=uTable.ref})
                end
            end
    end

end

-- Spawn BoShek lookup dial stack so people can resolve his effect easily
Builder.SpawnBoShekDials = function()
    for k,pTable in pairs(Builder.pilots) do
        if Builder.HasUpgrade('BoShek', k) then
            sRot = self.getRotation()
            local boShekDials = Spawner.Spawn('BoShek Lookup Dials (search me)', Builder.LocalPos({-1, 0, 0}, pTable.pRef), {sRot[1], sRot[2], sRot[3]+180})
            table.insert(Builder.misc.other, {ref=boShekDials, com='BoShek lookup dials'})
        end
    end
end


-- Spawn arc indicator for Lancer-Class Pursuit Crafts
Builder.SpawnArcIndicators = function()
    if Builder.ships['Lancer-Class Pursuit Craft'] ~= nil then
        for k, pIndex in pairs(Builder.ships['Lancer-Class Pursuit Craft']) do
            local ship = Builder.pilots[pIndex].sRef
            local newIndicator = Spawner.Spawn('Arc Indicator', Builder.LocalPos({0, 0, 0}, ship), {0, 90, 0})
            table.insert(Builder.misc.other, {ref=newIndicator, com='Arc Indicator'})
        end
    end
end

-- Spawn condition cards next to pilot cards
Builder.SpawnConditionCards = function()
    local cRot = self.getRotation()
    local cOff = {-1, 0, 0}
    for k,pTable in pairs(Builder.pilots) do
        if pTable.name == 'Captain Rex' then
            local newCond = Spawner.Spawn('Suppresive Fire condition', Builder.LocalPos(cOff, pTable.pRef), cRot)
            cOff[2] = cOff[2] + 0.1
            table.insert(Builder.misc.other, {ref=newCond, com='Condition'})
            local condToken = Spawner.Spawn('Suppresive Fire condition token', Builder.LocalPos({0, 0.1, 0}, newCond), cRot)
            table.insert(Builder.misc.tokens, {tRef=condToken, pRef=newCond})
            condToken.setName(condToken.getName():sub(1,-7))
        elseif pTable.name == 'Kylo Ren' then
            local newCond = Spawner.Spawn('I\'ll Show You The Dark Side condition', Builder.LocalPos(cOff, pTable.pRef), cRot)
            cOff[2] = cOff[2] + 0.1
            table.insert(Builder.misc.other, {ref=newCond, com='Condition'})
            local condToken = Spawner.Spawn('I\'ll Show You The Dark Side condition token', Builder.LocalPos({0, 0.1, 0}, newCond), cRot)
            table.insert(Builder.misc.tokens, {tRef=condToken, pRef=newCond})
            condToken.setName(condToken.getName():sub(1,-7))
        end
        if Builder.HasUpgrade('A Score to Settle', k) then
            local newCond = Spawner.Spawn('A Debt To Pay condition', Builder.LocalPos(cOff, pTable.pRef), cRot)
            cOff[2] = cOff[2] + 0.1
            table.insert(Builder.misc.other, {ref=newCond, com='Condition'})
            local condToken = Spawner.Spawn('A Debt To Pay condition token', Builder.LocalPos({0, 0.1, 0}, newCond), cRot)
            table.insert(Builder.misc.tokens, {tRef=condToken, pRef=newCond})
            condToken.setName(condToken.getName():sub(1,-7))
        end
        if Builder.HasUpgrade('Kylo Ren', k) then
            local newCond = Spawner.Spawn('I\'ll Show You The Dark Side condition', Builder.LocalPos(cOff, pTable.pRef), cRot)
            cOff[2] = cOff[2] + 0.1
            table.insert(Builder.misc.other, {ref=newCond, com='Condition'})
            local condToken = Spawner.Spawn('I\'ll Show You The Dark Side condition token', Builder.LocalPos({0, 0.1, 0}, newCond), cRot)
            table.insert(Builder.misc.tokens, {tRef=condToken, pRef=newCond})
            condToken.setName(condToken.getName():sub(1,-7))
        end
        if Builder.HasUpgrade('General Hux', k) then
            local newCond = Spawner.Spawn('Fanatical Devotion condition', Builder.LocalPos(cOff, pTable.pRef), cRot)
            cOff[2] = cOff[2] + 0.1
            table.insert(Builder.misc.other, {ref=newCond, com='Condition'})
            local condToken = Spawner.Spawn('Fanatical Devotion condition token', Builder.LocalPos({0, 0.1, 0}, newCond), cRot)
            table.insert(Builder.misc.tokens, {tRef=condToken, pRef=newCond})
            condToken.setName(condToken.getName():sub(1,-7))
        end
    end
end

-- Spawn EM token on each listed upgrade if parent ship has Extra Munitions upgrade
Builder.SpawnExtraMunitions = function()
    local applicableUpgrades = {}
    applicableUpgrades['Proton Torpedoes'] = true
    applicableUpgrades['Advanced Proton Torpedoes'] = true
    applicableUpgrades['Flechette Torpedoes'] = true
    applicableUpgrades['Ion Torpedoes'] = true
    applicableUpgrades['Extra Munitions'] = true
    applicableUpgrades['Plasma Torpedoes'] = true
    applicableUpgrades['Seismic Torpedo'] = true
    applicableUpgrades['Concussion Missiles'] = true
    applicableUpgrades['Assault Missiles'] = true
    applicableUpgrades['Homing Missiles'] = true
    applicableUpgrades['Ion Pulse Missiles'] = true
    applicableUpgrades['Advanced Homing Missiles'] = true
    applicableUpgrades['Proton Rockets'] = true
    applicableUpgrades['XX-23 S-Thread Tracers'] = true
    applicableUpgrades['Ion Bombs'] = true
    applicableUpgrades['Seismic Charges'] = true
    applicableUpgrades['Proximity Mines'] = true
    applicableUpgrades['Thermal Detonators'] = true
    applicableUpgrades['Cluster Mines'] = true
    applicableUpgrades['Conner Net'] = true
    applicableUpgrades['Proton Bombs'] = true
    for k=1,#Builder.pilots,1 do
        if Builder.HasUpgrade('Extra Munitions', k) then
            local upgrades = Builder.GetUpgrades(k)
            local sRot = self.getRotation()
            local rot = {sRot[1], sRot[2]-90, sRot[3]}
            local offset = {0, 0.1, 0.65}
            for k2,uTable in pairs(upgrades) do
                if applicableUpgrades[uTable.name] == true then
                    local newEMToken = Spawner.Spawn('Extra Munitions', Builder.LocalPos(offset, uTable.ref, 0.1), rot)
                    table.insert(Builder.misc.tokens, {tRef=newEMToken, pRef=uTable.ref})
                end
            end
        end
    end
end

-- Spawn EI token on each listed upgrade if Jabba the Hutt is present anywhere in the squad
Builder.SpawnExtraIllicit = function()
    local applicableUpgrades = {}
    applicableUpgrades['"Hot Shot" Blaster'] = true
    applicableUpgrades['Inertial Dampeners'] = true
    applicableUpgrades['Glitterstim'] = true
    applicableUpgrades['Cloaking Device'] = true
    applicableUpgrades['Rigged Cargo Chute'] = true
    applicableUpgrades['Burnout SLAM'] = true
    applicableUpgrades['EMP Device'] = true
    applicableUpgrades['Scavenger Crane'] = true
    applicableUpgrades['Black Market Slicer Tools'] = true
    applicableUpgrades['Dead Man\'s Switch'] = true
    applicableUpgrades['Feedback Array'] = true

    local jabbaPresent = Builder.HasUpgrade('Jabba the Hutt', 'any')

    if jabbaPresent == true then
        for k=1,#Builder.pilots,1 do
            local upgrades = Builder.GetUpgrades(k)
            local sRot = self.getRotation()
            local rot = {sRot[1], sRot[2], sRot[3]}
            local offset = {0, 0.2, 0.65}
            for k2,uTable in pairs(upgrades) do
                if applicableUpgrades[uTable.name] == true then
                    local newEIToken = Spawner.Spawn('Extra Illicit', Builder.LocalPos(offset, uTable.ref, 0.1), rot)
                    table.insert(Builder.misc.tokens, {tRef=newEIToken, pRef=uTable.ref})
                end
            end
        end
    end
end

-- Spawn shield tokens near each pilot card
-- Number taken from local database table
Builder.SpawnShields = function()
    if Spawner.Find('Shield') ~= true then
        Builder.Die('B28', 'Shield tokens not found in spawner')
    end
    for shipType,iTable in pairs(Builder.ships) do
        for k,index in pairs(iTable) do
            local shieldsNum = shipStatsDatabase[shipType].shieldCount
            if Builder.HasUpgrade('Shield Upgrade', index) then
                shieldsNum = shieldsNum + 1
            end
            if shieldsNum > 0 then
                local rot = self.getRotation()
                local pCard = Builder.pilots[index].pRef
                table.insert(Builder.misc.shields, {pRef=pCard, tSet={}})
                local shieldPos = Builder.ShieldInPilotFrameInit()
                for sNum=1,shieldsNum,1 do
                    local newShield = Spawner.Spawn('Shield', Builder.LocalPos(shieldPos, pCard, 0.1), rot)
                    table.insert(Builder.misc.shields[#Builder.misc.shields].tSet, newShield)
                    shieldPos = Builder.ShieldInPilotFrameStep(shieldPos, sNum)
                end
            end
        end
    end
end

-- Inform user of the great success!
Builder.OnFinish = function()
    if Builder.deathNote == nil then
        Builder.Log('[b]Success![/b]')
        Builder.DisplayLog({0, 1, 0})
        --[[
        for k, aTable in pairs(Builder.accesories) do
            aTable.dRef.setPositionSmooth(Builder.LocalPos({-1*BC.dialOffset_x, 0, 0}, aTable.dRef))
            aTable.rcRef.setPositionSmooth(Builder.LocalPos({-1*BC.refcardOffset_x, 0, 0}, aTable.rcRef))
        end
        ]]--
    end
    self.clearButtons()
    for k,obj in pairs(getAllObjects()) do
        if obj.getName() == 'Squad Builder module' then
            obj.call('builderFinish', {})
        end
    end
end

-- Available spawn states
Builder.SpawnState = 0
Builder.states =    {
    Initial=0,               -- Nothing done yet
    ListParsed=1,            -- List parsed, names in tables filled
    CoreSpawned=2,           -- Models, pilots, upgrades spawned
    CoreValidated=3,         -- Core tables look OK
    AccesoriesSpawned=4,     -- Dial bags, refcards spawned
    AccesoriesValidated=5,   -- Accesories tables look OK
    MiscSpawned=6,           -- Thingamajigs spawned
    Finished=7               -- Fin
}

-- Change state from current to some provided
-- If queried change out of sync (only allow for next), error
Builder.AdvanceState = function(newState)
    if type(newState) ~= 'number' then
        Builder.Die('B11', 'Invalid state change')
    elseif Builder.SpawnState ~= (newState - 1) then
        Builder.Die('B22', 'Invalid state change (from ' .. Builder.SpawnState .. ' to ' .. newState .. ')')
    else
        Builder.SpawnState = newState
    end
    Builder.SpawnList()
end
-- Shorthand for states entries
BS = Builder.states
-- Main state-action flow
Builder.SpawnList = function()
    if Builder.SpawnState == BS.ListParsed then
        Builder.MoveNote()
        Builder.SpawnCore()
    elseif Builder.SpawnState == BS.CoreSpawned then
        Builder.Log('Core spawned')
        Builder.FillTypes()
        Builder.MakeNamesUnique()
        Builder.ValidateCore()
    elseif Builder.SpawnState == BS.CoreValidated then
        Builder.Log('Core validated')
        Builder.SpawnAccesories()
    elseif Builder.SpawnState == BS.AccesoriesSpawned then
        Builder.Log('Accesories spawned')
        Builder.ValidateAccesories()
    elseif Builder.SpawnState == BS.AccesoriesValidated then
        Builder.Log('Accesories validated')
        Builder.SpawnMisc()
    elseif Builder.SpawnState == BS.MiscSpawned then
        Builder.Log('Miscellanous spawned')
        Builder.OnFinish()
    end
end

-- Note with error codes piled up
Builder.deathNote = nil
-- Create an error note, if it exists just cram new error code on top of it
Builder.Die = function(code, desc)
    -- Add new error code if it exists
    if Builder.deathNote ~= nil then
        if Builder.deathNote.getDescription():sub(-1,-1) == ')' then
            Builder.deathNote.setDescription(Builder.deathNote.getDescription() .. '\n')
        end
        Builder.deathNote.setDescription(Builder.deathNote.getDescription() .. '[' .. code .. ']')
        return
    end
    local title = ''
    if code ~= nil and type(code) == 'string' then
        title = title .. '[b]ERROR ' .. code ..'[/b]'
    end
    local vocal = '[b]ALL ISSUES GO THERE:[/b] https://github.com/tjakubo2/issues\n'
    if desc ~= nil and type(desc) == 'string' then
        vocal = vocal .. '(' .. desc .. ')\n'
    end
    if note ~= nil and type(note) == 'userdata' then
        if note.getDescription() ~= nil and type(note.getDescription()) == 'string' then
            vocal = vocal .. note.getDescription()
        end
    end
    objParams = {type='Notecard'}
    Builder.deathNote = spawnObject(objParams)
    local nPos = Builder.noteObj.getPosition()
    local nRot = Builder.noteObj.getRotation()
    Builder.deathNote.setPosition({nPos[1], nPos[2]+0.5, nPos[3]})
    Builder.deathNote.setRotation(nRot)
    Builder.deathNote.setName(title)
    Builder.deathNote.setDescription(vocal)
    Builder.deathNote.highlightOn({1, 0, 0}, 4)
    printToAll('Critical error encountered, pass the spawned info card to the author', {1,0,0})
end

-- Link provided bag as a source (to bo called from outside)
function API_linkBag(bagRef_bagDesc)
    --print('Link src: ' .. bagRef_bagDesc[2])
    Builder.AddSource(bagRef_bagDesc[2], bagRef_bagDesc[1])
end

-- Source bags refs
Builder.sources = {}
Builder.sources['Ship Models Bag'] = 0
Builder.sources['Pilot Cards Bag'] = 0
Builder.sources['Accesories Bag'] = 0

-- Are all sources ready?
Builder.SourcesReady = function()
    for sourceDesc, ref in pairs(Builder.sources) do
        if ref == 0 then return false end
    end
    return true
end

-- Add specific source ref
Builder.AddSource = function(sourceDesc, sourceRef)
    --print('Add src: ' .. sourceDesc)
    if Builder.sources[sourceDesc] == 0 then
        Builder.sources[sourceDesc] = sourceRef
    end
end

-- Fill sources from whatever is found on the table
Builder.FillSources = function()
    --print("Filling")
    for sourceDesc, ref in pairs(Builder.sources) do
        if ref == 0 then
            --print('Fill: ' .. sourceDesc)
            for k,obj in pairs(getAllObjects()) do
                if obj.getName() == sourceDesc and obj.getDescription() == 'Unassigned' then
                    Builder.sources[sourceDesc] = obj
                    obj.setDescription('Assigned')
                    --print('Found fill: ' .. sourceDesc)
                end
            end
        end
    end
end
-- Clear buttons for when it was not working
function ClearButtonsPatch(obj)
    local buttons = obj.getButtons()
    if buttons ~= nil then
        for k,but in pairs(buttons) do
            obj.removeButton(but.index)
        end
    end
end

-- Move note aside
Builder.MoveNote = function()
    Builder.noteObj.setPosition(Builder.LocalPos({9.5, 0, 2}))
    local sRot = self.getRotation()
    local nScale = Builder.noteObj.getScale()
    Builder.noteObj.setRotation({sRot[1], sRot[2]-90, sRot[3]})
    Builder.noteObj.setScale({nScale[1]*0.8, nScale[2]*0.8, nScale[3]*0.8})
end

-- END BUILDER MODULE
--------

--------
-- BROWSER MODULE

-- Allows for compnent search and spawn, usually

Browser = {}

-- Start as browser - spawn the search note
function startAsBrowser()
    self.clearButtons()
    init()
    local rot = {self.getRotation()[1], self.getRotation()[2]+180, self.getRotation()[3]}
    Browser.noteObj = Spawner.Spawn('[b]Item Browser[/b]', Builder.LocalPos({-15, 0, 2}, nil, 0), rot)
    Browser.noteObj.lock()
    Browser.noteObj.setRotation(rot)
    Browser.CreateMainButtons()
end

-- Simple shallow copy to cope with Lua reference handling
function Lua_DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            if type(orig_value) == 'table' then
                copy[orig_key] = Lua_DeepCopy(orig_value)
            else
                copy[orig_key] = orig_value
            end
        end
    else
        copy = orig
    end
    return copy
end

Browser.buttonData = {}

-- Dummy 'SHIPS' button
Browser.buttonData.shipsListingButton = {
                                            function_owner = self,
                                            position = {12.5, 0.5, -9},
                                            height = 1000,
                                            width = 2500,
                                            font_size = 1000,
                                            label = 'SHIPS:',
                                            click_function = 'dummy'
                                        }
-- Dummy 'UPGRADES' button
Browser.buttonData.upgsListingButton =  {
                                            function_owner = self,
                                            position = {26, 0.5, -9},
                                            height = 1000,
                                            width = 4200,
                                            font_size = 1000,
                                            label = 'UPGRADES:',
                                            click_function = 'dummy'
                                        }
-- Search note words button
Browser.buttonData.searchButton =       {
                                            function_owner = self,
                                            position = {-11, 0.5, 3},
                                            height = 800,
                                            width = 2500,
                                            font_size = 1000,
                                            label = 'Search',
                                            click_function = 'searchFromNote',
                                            color = {0.8, 0.8, 0.8}
                                        }

-- Data for storing what ship/upgrade button should spawn
-- Entry: {name=prettyName, key=spawnName}
Browser.buttonData.shipsButtons = {}
Browser.buttonData.upgsButtons = {}

-- Ship spawn position
Browser.mainShipPos = Builder.ShipInitPos(1)
-- Pilot spawn position
Browser.mainPilotPos = Builder.PilotForShip(Browser.mainShipPos)
-- Current misc (refcards, conditions etc) item position
Browser.currentMiscPos = Builder.LocalPos({2.4, 0, -0.4}, Browser.mainPilotPos, 0)
-- Current upgrade position
Browser.currentUpgPos = Builder.UpgForPilotInit(Browser.mainPilotPos, 3)
-- Current upgrade count
Browser.upgCount = 0

function dummy() end

-- Create maim buttons, duh
Browser.CreateMainButtons = function()
    self.createButton(Browser.buttonData.shipsListingButton)
    self.createButton(Browser.buttonData.upgsListingButton)
    --self.createButton(Browser.buttonData.searchButton)
end

-- Click functions for spawn buttons
function P_ch1_click() Browser.Click('ships', 1) end
function P_ch2_click() Browser.Click('ships', 2) end
function P_ch3_click() Browser.Click('ships', 3) end
function P_ch4_click() Browser.Click('ships', 4) end
function P_ch5_click() Browser.Click('ships', 5) end
function P_ch6_click() Browser.Click('ships', 6) end
function P_ch7_click() Browser.Click('ships', 7) end
function U_ch1_click() Browser.Click('upgs', 1) end
function U_ch2_click() Browser.Click('upgs', 2) end
function U_ch3_click() Browser.Click('upgs', 3) end
function U_ch4_click() Browser.Click('upgs', 4) end
function U_ch5_click() Browser.Click('upgs', 5) end
function U_ch6_click() Browser.Click('upgs', 6) end
function U_ch7_click() Browser.Click('upgs', 7) end

-- Search for strings separeted by newlines
function searchFromNote()
    local noteDesc = Browser.noteObj.getDescription()
    local words = {}
    for word in noteDesc:gmatch('[^\n]+') do
        word = word:gsub('-', '%%-')
        if word:len() > 1 then
            word = word:match( "^%s*(.-)%s*$" )
            if word ~= nil and word ~= '' then
                table.insert(words, word)
            end
        end
    end
    Browser.Update(words)
end

Browser.lastDesc = ''

function update()
    if Browser.noteObj ~= nil then
        local noteDesc = Browser.noteObj.getDescription()
        if noteDesc:len() ~= Browser.lastDesc:len() and noteDesc ~= Browser.lastDesc then
            searchFromNote()
            --print('up')
            Browser.lastDesc = noteDesc
        end
    end
end

-- Stuff that was spawned (moved aside with every new ship)
Browser.spawnedStuff = {}
--[[function onObjectLeaveScriptingZone(_, obj)
    for k,spObj in pairs(Browser.spawnedStuff) do
        if obj == spObj then
            print(obj.getName() .. 'lsz')
            table.remove(Browser.spawnedStuff, k)
            break
        end
    end
end]]--
function onObjectDestroyed(obj)
    for k,spObj in pairs(Browser.spawnedStuff) do
        if obj == spObj then
            ---print(obj.getName() .. 'ddd')
            table.remove(Browser.spawnedStuff, k)
            break
        end
    end
end

-- Misc items to spawn for each item listed as key
Browser.bindTable = {   ['Jabba the Hutt'] = 'Extra Illicit',
                        ['General Hux'] = 'Fanatical Devotion condition',
                        ['Fanatical Devotion condition'] = 'Fanatical Devotion condition token',
                        ['Kylo Ren'] = 'I\'ll Show You The Dark Side condition',
                        ['I\'ll Show You The Dark Side condition'] = 'I\'ll Show You The Dark Side condition token',
                        ['A Score to Settle'] = 'A Debt To Pay condition',
                        ['A Debt To Pay condition'] = 'A Debt To Pay condition token',
                        ['Captain Rex'] = 'Suppresive Fire condition',
                        ['Suppresive Fire condition'] = 'Suppresive Fire condition token',
                        ['StarViper Mk.II'] = 'StarViper Mk.II roll token'
                    }

-- Update spawn options with passed words
Browser.Update = function(words)
    self.clearButtons()
    Browser.CreateMainButtons()
    -- Grab mecthes to be listed as buttons
    local results = Spawner.ReturnMatches(words)

    -- Ship spawn buttons
    local shipBpos = Lua_DeepCopy(Browser.buttonData.shipsListingButton.position)
    shipBpos[3] = shipBpos[3]+1
    local function shipBposStep(cPos)
        return {cPos[1], cPos[2], cPos[3]+2}
    end
    Browser.buttonData.shipsButtons = {}
    for k,sTable in pairs(results.ships) do
        if k > 7 then
            break
        end
        shipBpos = shipBposStep(shipBpos)
        Browser.buttonData.shipsButtons[k] = sTable
        local sBut = Lua_DeepCopy(Builder.generalButton)
        sBut.width = StringLen.GetStringLength(sTable.name)/9.5 + 250
        sBut.label = sTable.name
        sBut.height = 650
        sBut.font_size = 500
        sBut.click_function = 'P_ch' .. k .. '_click'
        sBut.position = shipBpos
        self.createButton(sBut)
    end

    -- Upgrade spawn buttons
    local upgBpos = Lua_DeepCopy(Browser.buttonData.upgsListingButton.position)
    upgBpos[3] = upgBpos[3]+1
    local function upgBposStep(cPos)
        return {cPos[1], cPos[2], cPos[3]+2}
    end
    Browser.buttonData.upgsButtons = {}
    for k,uTable in pairs(results.upgrades) do
        if k > 7 then
            break
        end
        upgBpos = upgBposStep(upgBpos)
        Browser.buttonData.upgsButtons[k] = uTable
        local uBut = Lua_DeepCopy(Builder.generalButton)
        uBut.width = StringLen.GetStringLength(uTable.name)/9.5 + 250
        uBut.label = uTable.name
        uBut.height = 650
        uBut.font_size = 500
        uBut.click_function = 'U_ch' .. k .. '_click'
        uBut.position = upgBpos
        self.createButton(uBut)
    end
end

-- Reset upgrade position to 1st
Browser.ResetUpgPos = function()
    Browser.currentUpgPos = Builder.UpgForPilotInit(Browser.mainPilotPos, 3)
    Browser.upgCount = 0
    Browser.currentMiscPos = Builder.LocalPos({2.6, 0, -0.6}, Browser.mainPilotPos, 0)
end
-- Move spawned shit aside to make room for new spawns
Browser.MoveSpawnedAside = function()
    local stillSpawnedStuff = {}
    for k,obj in pairs(Browser.spawnedStuff) do
        --print(obj.getName())
        if obj.getPosition()[1] < -56 then
            --obj.translate({0, 0.5, -5.5})
            local oPos = obj.getPosition()
            obj.setPositionSmooth({oPos[1], oPos[2]+0.2, oPos[3]-5.5}, false, true)
            table.insert(stillSpawnedStuff, obj)
        end
    end
    Browser.spawnedStuff = stillSpawnedStuff
end

-- Spawn a new ship, pilot card, refcard
Browser.ShipSpawn = function(shipKey, prettyName)
    Browser.ResetUpgPos()
    Browser.MoveSpawnedAside()
    table.insert(Browser.spawnedStuff, Spawner.SpawnReturn(shipKey, Builder.LocalPos(Browser.mainShipPos), self.getRotation()))
    local shipType = Global.call('DB_getShipTypeCallable', {Browser.spawnedStuff[#Browser.spawnedStuff]})
    if Spawner.Find(shipType .. ' Refcard') then
        Browser.MiscSpawn(shipType .. ' Refcard')
    end
    --print(prettyName)
    if Browser.bindTable[prettyName] ~= nil then
        Browser.MiscSpawn(Browser.bindTable[prettyName])
    end
    table.insert(Browser.spawnedStuff, Spawner.SpawnReturn(shipKey:gsub('ship: ', ''), Builder.LocalPos(Browser.mainPilotPos), self.getRotation()))
end

-- Spawn a new upgrade
Browser.UpgSpawn = function(upgKey, prettyName)
    table.insert(Browser.spawnedStuff, Spawner.SpawnReturn(upgKey, Builder.LocalPos(Browser.currentUpgPos), self.getRotation()))
    Browser.upgCount = Browser.upgCount + 1
    if Browser.bindTable[prettyName] ~= nil then
        Browser.MiscSpawn(Browser.bindTable[prettyName])
    end
    Browser.currentUpgPos = Builder.UpgStep(Browser.currentUpgPos, Browser.upgCount)
end

-- Spawna  new thingamajig
Browser.MiscSpawn = function(itemKey)
    local function miscPosStep(miscPos)
        return {miscPos[1], miscPos[2]+0.3, miscPos[3]+0.5}
    end
    --local tP = Builder.LocalPos(Browser.currentMiscPos, self, Browser.currentMiscPos[2])
    table.insert(Browser.spawnedStuff, Spawner.SpawnReturn(itemKey, Builder.LocalPos(Browser.currentMiscPos, self, Browser.currentMiscPos[2]), self.getRotation()))
    --Browser.spawnedStuff[#Browser.spawnedStuff].lock()
    Browser.currentMiscPos = miscPosStep(Browser.currentMiscPos)
    if Browser.bindTable[itemKey] ~= nil then
        Browser.MiscSpawn(Browser.bindTable[itemKey])
    end
end

-- Real dispatch click function
Browser.Click = function(type,key)
    local data = Browser.buttonData[type .. 'Buttons'][key]
    if type == 'ships' then
        Browser.ShipSpawn(data.key, data.name)
    else
        Browser.UpgSpawn(data.key, data.name)
    end
end

-- END BROWSER MODULE
--------

--------
-- COMMON FUNCTIONS

function onDestroy()
    if Browser.noteObj ~= nil then
        Browser.noteObj.destruct()
    end
end

-- On load
function onLoad()
    if self.getDescription() ~= 'itemBrowserMode' then
        -- INITIALIZE BUTTON
        Builder.generalButton.click_function = 'startAsBuilder'
        Builder.generalButton.label = 'Initialize'
        Builder.generalButton.width = 3500
        self.createButton(Builder.generalButton)
    else
        Builder.generalButton.click_function = 'startAsBrowser'
        Builder.generalButton.label = 'Initialize'
        Builder.generalButton.width = 3500
        self.createButton(Builder.generalButton)
    end
end

-- INITIALIZE BAG
function init()
    -- Make sure all sources are ready
    if Builder.SourcesReady() ~= true then
        Builder.FillSources()
        if Builder.SourcesReady() ~= true then
            Builder.Log('Source bags not ready... Stop')
            Builder.DisplayLog()
            return
        end
    end

    local sObj = self.getObjects()
    local minorBags = {}
    local hOff = -3

    local sbm = nil
    for k,obj in pairs(getAllObjects()) do
        if obj.getName() == 'Squad Builder module' then
            sbm = obj
        end
    end

    for k, objInfo in pairs(sObj) do
        if objInfo.name:find('Bag') ~= nil then
            local nPos = Builder.LocalPos({0, 0, 0}, self, hOff)
            local newObj = self.takeObject({guid=objInfo.guid, position=nPos})
            newObj.lock()
            newObj.interactable = false
            newObj.tooltip = false
            newObj.setPosition(nPos)
            sbm.call('builderAddChild', {newObj})
            table.insert(minorBags, newObj)
        end
    end

    -- Pass the sources to the spawner
    Spawner.Fill(Builder.sources['Ship Models Bag'], 'Ship: ')
    Spawner.Fill(Builder.sources['Pilot Cards Bag'])
    Spawner.Fill(Builder.sources['Accesories Bag'])
    for k,bag in pairs(minorBags) do
        Spawner.Fill(bag, 'Upgrade: ')
    end
    Builder.Log('Source bags ready')

    -- Get the note
    Spawner.Fill(self)
end



-- Char width table by Indimeco
StringLen = {}
StringLen.charWidthTable = {
        ['`'] = 2381, ['~'] = 2381, ['1'] = 1724, ['!'] = 1493, ['2'] = 2381,
        ['@'] = 4348, ['3'] = 2381, ['#'] = 3030, ['4'] = 2564, ['$'] = 2381,
        ['5'] = 2381, ['%'] = 3846, ['6'] = 2564, ['^'] = 2564, ['7'] = 2174,
        ['&'] = 2777, ['8'] = 2564, ['*'] = 2174, ['9'] = 2564, ['('] = 1724,
        ['0'] = 2564, [')'] = 1724, ['-'] = 1724, ['_'] = 2381, ['='] = 2381,
        ['+'] = 2381, ['q'] = 2564, ['Q'] = 3226, ['w'] = 3704, ['W'] = 4167,
        ['e'] = 2174, ['E'] = 2381, ['r'] = 1724, ['R'] = 2777, ['t'] = 1724,
        ['T'] = 2381, ['y'] = 2564, ['Y'] = 2564, ['u'] = 2564, ['U'] = 3030,
        ['i'] = 1282, ['I'] = 1282, ['o'] = 2381, ['O'] = 3226, ['p'] = 2564,
        ['P'] = 2564, ['['] = 1724, ['{'] = 1724, [']'] = 1724, ['}'] = 1724,
        ['|'] = 1493, ['\\'] = 1923, ['a'] = 2564, ['A'] = 2777, ['s'] = 1923,
        ['S'] = 2381, ['d'] = 2564, ['D'] = 3030, ['f'] = 1724, ['F'] = 2381,
        ['g'] = 2564, ['G'] = 2777, ['h'] = 2564, ['H'] = 3030, ['j'] = 1075,
        ['J'] = 1282, ['k'] = 2381, ['K'] = 2777, ['l'] = 1282, ['L'] = 2174,
        [';'] = 1282, [':'] = 1282, ['\''] = 855, ['"'] = 1724, ['z'] = 1923,
        ['Z'] = 2564, ['x'] = 2381, ['X'] = 2777, ['c'] = 1923, ['C'] = 2564,
        ['v'] = 2564, ['V'] = 2777, ['b'] = 2564, ['B'] = 2564, ['n'] = 2564,
        ['N'] = 3226, ['m'] = 3846, ['M'] = 3846, [','] = 1282, ['<'] = 2174,
        ['.'] = 1282, ['>'] = 2174, ['/'] = 1923, ['?'] = 2174, [' '] = 1282,
        ['avg'] = 2500
    }

-- Get real string lenght per char table
StringLen.GetStringLength = function(str)
    local len = 0
    for i = 1, #str do
        local c = str:sub(i,i)
        if StringLen.charWidthTable[c] ~= nil then
            len = len + StringLen.charWidthTable[c]
        else
            len = len + StringLen.charWidthTable.avg
        end
    end
    return len
end

-- INITIALIZE BAG
function init()
    -- Make sure all sources are ready
    if Builder.SourcesReady() ~= true then
        Builder.FillSources()
        if Builder.SourcesReady() ~= true then
            Builder.Log('Source bags not ready... Stop')
            Builder.DisplayLog()
            return
        end
    end

    local sObj = self.getObjects()
    local minorBags = {}
    local hOff = -3

    local sbm = nil
    for k,obj in pairs(getAllObjects()) do
        if obj.getName() == 'Squad Builder module' then
            sbm = obj
        end
    end

    for k, objInfo in pairs(sObj) do
        if objInfo.name:find('Bag') ~= nil then
            local nPos = Builder.LocalPos({0, 0, 0}, self, hOff)
            local newObj = self.takeObject({guid=objInfo.guid, position=nPos})
            newObj.lock()
            newObj.interactable = false
            newObj.tooltip = false
            newObj.setPosition(nPos)
            sbm.call('builderAddChild', {newObj})
            table.insert(minorBags, newObj)
        end
    end

    -- Pass the sources to the spawner
    Spawner.Fill(Builder.sources['Ship Models Bag'], 'Ship: ')
    Spawner.Fill(Builder.sources['Pilot Cards Bag'])
    Spawner.Fill(Builder.sources['Accesories Bag'])
    for k,bag in pairs(minorBags) do
        Spawner.Fill(bag, 'Upgrade: ')
    end
    Builder.Log('Source bags ready')

    -- Get the note
    Spawner.Fill(self)
end

-- END COMMON FUNCTIONS
--------

--------
-- SHIP STATS DATABASE

-- Ship stats database
-- Key: shipType, {shieldCount=shieldCount}
shipStatsDatabase = {}
shipStatsDatabase['X-Wing'] = { shieldCount=2 }
shipStatsDatabase['Y-Wing Rebel'] = { shieldCount=3 }
shipStatsDatabase['YT-1300'] = { shieldCount=5 }
shipStatsDatabase['YT-2400'] = { shieldCount=5 }
shipStatsDatabase['A-Wing'] = { shieldCount=2 }
shipStatsDatabase['B-Wing'] = { shieldCount=5 }
shipStatsDatabase['HWK-290 Rebel'] = { shieldCount=1 }
shipStatsDatabase['VCX-100'] = { shieldCount=6 }
shipStatsDatabase['Attack Shuttle'] = { shieldCount=2 }
shipStatsDatabase['T-70 X-Wing'] = { shieldCount=3 }
shipStatsDatabase['E-Wing'] = { shieldCount=3 }
shipStatsDatabase['K-Wing'] = { shieldCount=4 }
shipStatsDatabase['Z-95 Headhunter Rebel'] = { shieldCount=2 }
shipStatsDatabase['TIE Fighter Rebel'] = { shieldCount=0 }
shipStatsDatabase['U-Wing'] = { shieldCount=4 }
shipStatsDatabase['ARC-170'] = { shieldCount=3 }

shipStatsDatabase['Firespray-31 Scum'] = { shieldCount=4 }
shipStatsDatabase['Z-95 Headhunter Scum'] = { shieldCount=2 }
shipStatsDatabase['Y-Wing Scum'] = { shieldCount=3 }
shipStatsDatabase['HWK-290 Scum'] = { shieldCount=1 }
shipStatsDatabase['M3-A Interceptor'] = { shieldCount=1 }
shipStatsDatabase['StarViper'] = { shieldCount=1 }
shipStatsDatabase['Aggressor'] = { shieldCount=4 }
shipStatsDatabase['YV-666'] = { shieldCount=6 }
shipStatsDatabase['Kihraxz Fighter'] = { shieldCount=1 }
shipStatsDatabase['JumpMaster 5000'] = { shieldCount=4 }
shipStatsDatabase['G-1A StarFighter'] = { shieldCount=4 }
shipStatsDatabase['Lancer-Class Pursuit Craft'] = { shieldCount=3 }
shipStatsDatabase['Quadjumper'] = { shieldCount=0 }
shipStatsDatabase['Protectorate Starfighter'] = { shieldCount=0 }

shipStatsDatabase['TIE Fighter'] = { shieldCount=0 }
shipStatsDatabase['TIE Interceptor'] = { shieldCount=0 }
shipStatsDatabase['Lambda-Class Shuttle'] = { shieldCount=5 }
shipStatsDatabase['Firespray-31 Imperial'] = { shieldCount=4 }
shipStatsDatabase['TIE Bomber'] = { shieldCount=0 }
shipStatsDatabase['TIE Phantom'] = { shieldCount=2 }
shipStatsDatabase['VT-49 Decimator'] = { shieldCount=4 }
shipStatsDatabase['TIE Advanced'] = { shieldCount=2 }
shipStatsDatabase['TIE Punisher'] = { shieldCount=3 }
shipStatsDatabase['TIE Defender'] = { shieldCount=3 }
shipStatsDatabase['TIE/fo Fighter'] = { shieldCount=1 }
shipStatsDatabase['TIE Adv. Prototype'] = { shieldCount=2 }
shipStatsDatabase['TIE Striker'] = { shieldCount=0 }
shipStatsDatabase['TIE/sf Fighter'] = { shieldCount=3 }
shipStatsDatabase['Upsilon Class Shuttle'] = { shieldCount=6 }

-- END SHIP STATS DATABASE
--------