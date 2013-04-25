local SCREEN_HEIGHT = 960
local SCREEN_WIDTH = 640
local FAKE_SCREEN_HEIGHT = 60
local FAKE_SCREEN_WIDTH = 40

local BULLET = 1
local PLAYER = 2
local DRAGON = 3
local ITEM = 4
local GEM =  5

local COUNTPERROW = 5
local bulletList = {}
local enemyRowList = {}
local itemList = {}
local gemList = {}

local AIInfo = {}

local objectList = {}

local interval = 1/60
local ret = true
local timeInterval = 0
local startTime = 0
local endTime = 0
local timer = 0
local totalTime = 0

local times = 0
local fastSimuTime = 60 * 60 -- 1 hour
local simulate = true
local refreshScreen = true
local debugStrs = {}

local currentWave = 0

local function pushDebugStr(str)
	table.insert(debugStrs," time: " .. totalTime .. " "..str)
end

local function clearDebugStr()
	--debugStrs = {}
end

local function printDebugStr()
	for k, v in ipairs(debugStrs) do
		print(v)
	end
end

local function initPos(x, y)
	return {x = x, y = y}
end

local function clearObjectList(key)
	objectList.key = nil
end

local function insertObjectList(key, value)
	objectList.key = value
end

local function removeBullet(bullet, index)
	-- clear this row if need
	clearObjectList(bullet)
	table.remove(bulletList, index)
end

local bullet1 = {
	type = BULLET,
	attack = 400,
	speed = 600,
	pos = nil
}

bullet1.update
= function(bullet, index, dt)
	return function(bullet, index, dt)
		bullet.pos.y = bullet.pos.y - dt * bullet.speed
		-- clear this row if need
		if bullet.pos.y < 0 or not bullet.alive then
			removeBullet(bullet, index)
		end
	end
end



local function generateBullet(template, posX, posY)
	local bullet = {}
	bullet.attack = template.attack
	bullet.speed = template.speed
	bullet.pos = initPos(posX, posY)
	bullet.type = template.type
	bullet.update = template.update()
	bullet.alive = true
	
	-- set table address to the key of objectList
	insertObjectList(bullet, bullet.pos)

	table.insert(bulletList, bullet)
end

local DRAGON_HEIGHT = 100
local DRAGON_WIDTH = 100
local DRAGON_SEP =  30
local TOTAL_WIDTH_DRAGONS = DRAGON_WIDTH * COUNTPERROW + DRAGON_SEP * (COUNTPERROW - 1)

local dragon1 = {
	hp = 200,
	speed = 300,
	pos = nil,
	render = "W",
	p = 0,
	currentNum = 0,
	needNum = 0,
	priority = 1,
}

local dragon2 = {
	hp = 500,
	speed = 300,
	pos = nil,
	render = "Y",
	p = 0,
	currentNum = 0,
	needNum = 0,
	priority = 2,
}

local dragon3 = {
	hp = 1250,
	speed = 300,
	pos = nil,
	render = "R",
	p = 0,
	currentNum = 0,
	needNum = 0,
	priority = 3,
}

local dragon4 = {
	hp = 3125,
	speed = 300,
	pos = nil,
	render = "P",
	p = 0,
	currentNum = 0,
	needNum = 0,
	priority = 4,
}

local DragonTemplates = {dragon1}

local function clearTemplatesData()
	for k, v in ipairs(DragonTemplates) do
		v.currentNum = 0
	end
end

local function copyTable(source)
	local t = {}
	for k, v in ipairs(source) do
		table.insert(t, v)
	end
	return t
end

local function addDragonTemplate(templte)
	table.insert(DragonTemplates, templte)
end

local function updateDragonP()
	if currentWave < 7 then
		dragon1.needNum = 5
		dragon1.p = 1
	
		-- yellow dragon
	elseif currentWave >= 7 and currentWave < 34 then
		
		if currentWave == 7 then
			dragon1.needNum = 5
			addDragonTemplate(dragon2)
		end
		
		if currentWave == 7 then
			dragon2.needNum = 1
		elseif currentWave == 14 then
			dragon2.needNum = 2
		elseif currentWave == 20 then
			dragon2.needNum = 3
		elseif currentWave == 28 then
			dragon2.needNum = 4
		end
		-- red dragon
	elseif currentWave >= 35 and currentWave < 63 then
		
		if currentWave == 35 then
			dragon3.needNum = 5
			addDragonTemplate(dragon3)
		end
		
		if currentWave == 35 then
			dragon3.needNum = 1
			dragon2.needNum = 3
			dragon1.needNum = 1
		elseif currentWave == 43 then
			dragon3.needNum = 2
			dragon2.needNum = 2
			dragon1.needNum = 1
		elseif currentWave == 49 then
			dragon3.needNum = 3
			dragon2.needNum = 1
			dragon1.needNum = 1
		elseif currentWave == 58 then
			dragon3.needNum = 4
			dragon2.needNum = 1
			dragon1.needNum = 5
		end
		-- green dragon
	elseif currentWave > 62 then
		
		if currentWave ==  63 then
			dragon4.needNum = 5
			addDragonTemplate(dragon4)
		end
		
	end
end

local player
local PLAYER_HEIGHT = 100
local PLAYER_WIDTH = 100

local Player = 
{
	pos = nil
}

-- attack frequency
Player.emmitFrequency = interval * 3

-- emmit bullet
Player.emmitBullet
= function(player)
	return function(player)
		generateBullet(player.bulletTemplate, player.pos.x, player.pos.y)
	end
end

local function getRowSpeedFactor()
	local x = totalTime/60
	
	return ( 1.3 * x + 0.5) * ( 1.3 * x + 0.5 ) + 1 
end

local currentSlots = {}

local function printCurrentSlots()
	local str = "slots : "
	for k, v in ipairs(currentSlots) do
		str = str .." "..tostring(v.render)
	end
	print(str)
end

local function generateEnemyRow(endPosY)
	currentWave = currentWave + 1
	
	updateDragonP()
	
	-- caculate the bias apply to SCREEN_WIDTH
	local posY = - DRAGON_HEIGHT/2
	local posX = (SCREEN_WIDTH - TOTAL_WIDTH_DRAGONS)/2 + DRAGON_WIDTH/2
	local row = {}
	
	local slots = {}
	
	for i = 1, COUNTPERROW do
		slots[i] = false
	end
	
	local templatesStack = copyTable(DragonTemplates)
	
	print("size: "..tostring(#templatesStack))
	local currentTemplate
	
	local full = false
	 
	while not full do
		
		full = true
		
		local rIndex = math.random(COUNTPERROW)
		
		-- got the head element
		local size = #templatesStack
		
		currentTemplate = templatesStack[size]
		print("size: "..tostring(size))
		
		if slots[rIndex] == false then
			slots[rIndex] = currentTemplate
			currentTemplate.currentNum = currentTemplate.currentNum + 1
			print("priority: "..tostring(currentTemplate.priority))
			print("currNum: "..tostring(currentTemplate.currentNum))
			print("needNum: "..tostring(currentTemplate.needNum))
			if currentTemplate.currentNum >= currentTemplate.needNum then
				print("upate the stack")
				table.remove(templatesStack)
			end	
		end
		
		for i = 1, COUNTPERROW do
			if slots[i] == false then
				full = false
			end
		end
	end	
	
	currentSlots = copyTable(slots)
	
	clearTemplatesData()
	
	for i = 1, COUNTPERROW do
		local dragon = {}
		local x = posX + (DRAGON_SEP + DRAGON_WIDTH) * (i - 1) 
		local y = posY
		
		local template = slots[i]
		
		dragon.hp = template.hp
		dragon.pos = initPos(x, y)
		dragon.alive = true
		dragon.type = DRAGON
		dragon.index = i
		dragon.render = template.render
		
		AIInfo.roads[i].canThrough = false
		
		insertObjectList(dragon, dragon.pos)
		
		table.insert(row, dragon)
	end
	
	-- we only care about the speed of row itself
	row.speed = dragon1.speed * getRowSpeedFactor()
	row.endPosY = endPosY
	-- pos of row just equal to pos of the first dragon in the row
	row.pos = initPos(SCREEN_WIDTH/2, row[1].pos.y )
	
	table.insert(enemyRowList, row)	
end

local function init()
	player = {}
	player.pos =  initPos(SCREEN_WIDTH/2, SCREEN_HEIGHT - PLAYER_HEIGHT/2)
	player.emmitTimer = 0
	player.emmitFrequency = Player.emmitFrequency
	player.emmitBullet = Player.emmitBullet()
	player.bulletTemplate = bullet1
	player.type = PLAYER
	player.alive = true
	
	math.randomseed(os.time())
	
	generateEnemyRow(SCREEN_HEIGHT + DRAGON_HEIGHT/2)
end

local function updateBullets(dt)
	for k, v in ipairs(bulletList) do
		local bullet = v
		bullet.update(bullet, k, dt)
	end
end

local function getItem(index,row)
	return row[index]
end

local function checkCollide()
	for k, bullet in ipairs(bulletList) do
		for i, row in ipairs(enemyRowList) do
			for j, dragon in ipairs(row) do
				
				if ( bullet.pos.x <= dragon.pos.x + DRAGON_WIDTH/2 and
					bullet.pos.x  >= dragon.pos.x - DRAGON_WIDTH/2 ) and
				( bullet.pos.y <= dragon.pos.y + DRAGON_HEIGHT/2 and 
					bullet.pos.y >= dragon.pos.y - DRAGON_HEIGHT/2 ) and bullet.alive then
					-- decrease hps
					dragon.hp = dragon.hp - bullet.attack
					bullet.alive = false
					--pushDebugStr("bullet: "..tostring(bullet).." dragon hurt: "..tostring(dragon.index).." hp: "..tostring(dragon.hp))
					if dragon.hp < 0 then
						dragon.hp = 0
						--debugStr = "dragon die"
						--pushDebugStr("end dragon die")
						dragon.alive = false
					end
				end
				
				-- check player collide with dragon
				if math.abs ( player.pos.x - dragon.pos.x ) < PLAYER_WIDTH/2 - 10 and
					 math.abs( player.pos.y - dragon.pos.y ) < PLAYER_HEIGHT/2 then
					player.alive = false
				end
				
			end
		end
	end
end

local function getDistanceSqr(pos1, pos2)
	return math.abs(pos1.x - pos2.x) + math.abs(pos1.y - pos2.y)
end

local tp = 0
local swipeSpeedMin = 10
local swipeSpeedMax = 100
local action = {
	targetPos = nil,
	initPos = nil,
	object = nil,
	update = nil,
	isDone = false,
	timer = 0
}
local AIActionList = {}

AIInfo.roads = {}

for i = 1, 5 do
	AIInfo.roads[i] = {}
	AIInfo.roads[i].canThrough = false
	local posX = (SCREEN_WIDTH - TOTAL_WIDTH_DRAGONS)/2 + DRAGON_WIDTH/2
	local x = posX + (DRAGON_SEP + DRAGON_WIDTH) * (i - 1) 
	AIInfo.roads[i].pos = initPos(x, SCREEN_HEIGHT - PLAYER_HEIGHT/2)
end

AIInfo.currRoadIndexIndex = 3

local function pushAction(action)
	table.insert(AIActionList, action)
end

local updateMoveTo = function(action, dt)
	if not action.isDone then
		if action.timer < 1 then
			action.timer = action.timer + dt/action.duration
			action.object.pos.x = action.initPos.x *  ( 1 - action.timer) + action.targetPos.x * action.timer
			action.object.pos.y = action.initPos.y * ( 1 - action.timer)  + action.targetPos.y * action.timer						
			debugStr = "update move to posx: "..tostring(action.object.pos.x)
		else
			action.object.pos.x = action.targetPos.x
			action.object.pos.y = action.targetPos.y
			action.timer = 0
			action.isDone = true
			--debugStr = "move to done"
			
		end
	end
end

local function generateMoveToAction(object, initPos, targetPos, duration)
	local action = {}

	action.update = updateMoveTo
	action.isDone = false
	action.duration = duration
	action.timer = 0
	action.initPos = initPos
	action.targetPos = targetPos
	action.object = object
	return action
end

local updateWait = function(action, dt)
	if not action.isDone then
		if action.timer < 1 and action.timer >=0 then
			-- do nothing 
			action.timer = action.timer + dt/action.duration
			debugStr = "update wait timer: "..tostring(action.timer)					
		elseif action.timer >= 1 then
			--debugStr = "wait done"
			if action.doneCallback then
				action.doneCallback()
			end
			action.isDone = true
			action.timer = 0
		end
	end
end

local function generateWaitAction(duration, doneCallback)
	local action = {}

	action.update = updateWait
	action.isDone = false
	action.duration = duration
	action.timer = 0
	action.doneCallback = doneCallback
	
	return action
end

local updateSequence = function(action, dt)	
	if not action.isDone then
		local isDone = true
		for k , v in ipairs(action.sequence) do
			if not v.isDone then
				isDone = false
				v.update(v, dt)
			end
		end
		action.isDone = isDone
	end
end

local function generateSequenceAction(sequence)
	local action = {}
	action.update = updateSequence
	action.isDone = false
	action.sequence = sequence
	return action
end

local updateCallback = function(action, dt)	
	if not action.isDone then
		action.callback()
		action.isDone = true
	end
	
end
local function generateCallbackAction(callback)
	local action = {}
	
	action.update = updateCallback
	action.isDone = false
	action.callback = callback
	return action
end

local function think(dt)
	
	--player.pos.x = SCREEN_WIDTH/2 + math.sin(totalTime) *( (SCREEN_WIDTH - PLAYER_WIDTH) /2)
	-- TODO
	
	-- kill dragon
	local currDragon = nil
	local currRow
	if #enemyRowList > 0 then
		-- first row
		local row = enemyRowList[1]
		
		if row.pos.y <= DRAGON_HEIGHT then
			return
		end
			
		currRow = row
		
		if #currRow <= 0 then
			return
		end
		
		local minDistance = getDistanceSqr(player.pos, row[1].pos)
		local minDisDragon = row[1]
		
		for index, dragon in ipairs(row) do
			if dragon ~= AIInfo.targetDragon then
				local dis = getDistanceSqr(player.pos, dragon.pos)
				if dis < minDistance then
					minDistance = dis
					minDisDragon = dragon
				end
			end
		end
		
		currDragon = minDisDragon
		AIInfo.currRoadIndex = currDragon.index
		
		if currDragon == AIInfo.targetDragon then
			debugStr = "filter currDragon.index: "..tostring(currDragon.index)
			return
		end
		
		AIInfo.targetDragon = currDragon
	else
		return 
	end
	
	local s1 = SCREEN_HEIGHT - (currDragon.pos.y + DRAGON_HEIGHT/2) - (SCREEN_HEIGHT - player.pos.y)
	
	local t1 = s1/(player.bulletTemplate.speed + currRow.speed)
	
	local moveTime = 0.3
	
	local attackSuccessTime = (currDragon.hp / player.bulletTemplate.attack) * player.emmitFrequency  + moveTime + t1
	--pushDebugStr("st: "..tostring(attackSuccessTime))
	
	local failureTime = s1 / currRow.speed
	
	--pushDebugStr("ft: "..tostring(failureTime))
	
	
	if attackSuccessTime < failureTime then
		debugStr = "st < ft"
		-- it's worth shooting
		local targetPos = {x = currDragon.pos.x, y = player.pos.y}
		
		local moveToAction = generateMoveToAction(player, player.pos, targetPos, moveTime)
		-- wait more than correct time 0.1 second
		
		local waitAction = generateWaitAction(attackSuccessTime - moveTime - t1, function()
					AIInfo.targetDragon = nil
					
					AIInfo.roads[AIInfo.currRoadIndex].canThrough = true
					
				end)
		
		local sequence = {moveToAction, waitAction}
		
		local doAll = generateSequenceAction(sequence)
		
		--debugStr = "push action"
		
		pushAction(doAll)
	elseif attackSuccessTime - failureTime > moveTime * 2 then
		--[[
		debugStr = "fail currDragon.index: "..tostring(currDragon.index)
		
		-- shoot and then run
		--debugStr = "fail to shoot"
		
		local targetPos = {x = currDragon.pos.x, y = player.pos.y}
		
		local moveToAction1 = generateMoveToAction(player, player.pos, targetPos, moveTime)
		-- wait more than correct time 0.1 second
		
		local waitAction = generateWaitAction(attackSuccessTime - failureTime - moveTime)
		
		local minRoadDistance = getDistanceSqr(player.pos, targetPos)
		local roadCanTrough = AIInfo.currRoadIndex
		
		
		
		-- an available road
		local minBias = math.abs(currDragon.index - AIInfo.currRoadIndex)
		local shortRoadIndex = AIInfo.currRoadIndex
		
		for i = 1, 5 do
			local road = AIInfo.roads[i]
			if i ~= AIInfo.currRoadIndex and road.canThrough == true then
				bias = math.abs(AIInfo.currRoadIndex - i)
				if bias < minBias then
					minBias = bias
					shortRoadIndex = i
				end
			end
		end
			
				
		local moveToAction2 = generateMoveToAction(player, targetPos, AIInfo.roads[shortRoadIndex].pos, moveTime)
		
		local sequence = {moveToAction1, waitAction, moveToAction2}
		
		local doAll = generateSequenceAction(sequence)
		
		AIInfo.targetDragon = nil
		
		pushAction(doAll)
		]]
	end
	
end

local function action(dt)
	local isDone = true
	for k, v in ipairs(AIActionList) do
		local action = v
		if not v.isDone then
			v.update(v, dt)
			isDone = false
		else
			table.remove(AIActionList, k)
		end
	end
	return isDone
end



local function doAI(dt)
	if player.alive then
		--player.pos.x = SCREEN_WIDTH/2 + math.sin(totalTime) *( (SCREEN_WIDTH - PLAYER_WIDTH) /2)
		
		if 	#AIActionList > 0 then
			action(dt)
		else
			think(dt)
		end	
		
	end
end

local function updatePlayer(dt)
	if player.emmitTimer > player.emmitFrequency then
		-- emmit bullet
		--pushDebugStr("emmit bullet timer: "..tostring(player.emmitTimer))
		player.emmitBullet(player)
		player.emmitTimer = 0
		
	else
		player.emmitTimer = player.emmitTimer + dt
	end
end

local setSubHeightDragon = false
local isGeneratedSubHeight = false
local subHeightDraginWave = 0

local function updateEnemy(dt)
	for k, v in ipairs(enemyRowList) do
		local row = v
		
		local size = #enemyRowList
		
		-- remove the dead one first
		for index, dragon in ipairs(row) do
			if not dragon.alive then
				clearObjectList(dragon)
				table.remove(row, index)
			end
		end
		
		if not setSubHeightDragon and row.pos.y > SCREEN_HEIGHT * 0.5 + DRAGON_HEIGHT then
			
			local r = math.random()
			setSubHeightDragon = true
			if r > 0.95 then
				pushDebugStr("sub height dragon r: "..tostring(r))
				
				generateEnemyRow(SCREEN_HEIGHT + DRAGON_HEIGHT/2)
				
				row.endPosY = SCREEN_HEIGHT * 1.5 + DRAGON_HEIGHT/2
				
				subHeightDraginWave = currentWave
				
				break
			end
		end
			
		if row.pos.y > row.endPosY then
			for index, dragon in ipairs(row) do
				clearObjectList(dragon)
			end
			
			if row.endPosY <= SCREEN_HEIGHT + DRAGON_HEIGHT/2 then
				generateEnemyRow(SCREEN_HEIGHT + DRAGON_HEIGHT/2)
			end
			
			if setSubHeightDragon then
				setSubHeightDragon = false
			end
			
			table.remove(enemyRowList, k)
			break
		end
		
		for index, dragon in ipairs(row) do
			dragon.pos.y = dragon.pos.y + row.speed * dt
		end
		
		row.pos.y = row.pos.y + row.speed * dt
		
	end
end

local posPacket = {}
local resultPixel = {}

local function convertPosPacket()
	for i = 1, FAKE_SCREEN_WIDTH do
		for j = 1, FAKE_SCREEN_HEIGHT do
			if resultPixel[j] == nil then
				resultPixel[j] = ""
			end
			resultPixel[j] = resultPixel[j] .. posPacket[i][j]
		end
	end	
end

local function printResult()
	for j = 1, FAKE_SCREEN_HEIGHT do
		print(resultPixel[j])
	end
end

local function clearWithStr(str)
	for i = 1, FAKE_SCREEN_WIDTH do
		posPacket[i] = {}
		for j = 1, FAKE_SCREEN_HEIGHT do
			if posPacket[i][j] == nil then
				posPacket[i][j] = {}
			end
			if resultPixel[j] == nil then
				resultPixel[j] = {}
			end
			resultPixel[j] = ""
			posPacket[i][j] = str
		end
	end	
end

local function rasterization()
	local hRatio = FAKE_SCREEN_WIDTH/SCREEN_WIDTH
	local vRatio = FAKE_SCREEN_HEIGHT/SCREEN_HEIGHT
	
	for k, v in ipairs(bulletList) do
		local bullet = v
		local posX = bullet.pos.x * hRatio
		local posY = bullet.pos.y * vRatio
		if math.ceil(posX) - posX >= 0.5 then
			posX = math.floor(posX)
		else
			posX = math.ceil(posX)
		end
		
		if math.ceil(posY) - posY >= 0.5 then
			posY = math.floor(posY)
		else
			posY = math.ceil(posY)
		end
		
		if posPacket[posX] == nil then
			posPacket[posX] = {}
		end
		
		if posPacket[posX][posY] == nil then
			posPacket[posX][posY] = {}
		end
		
		posPacket[posX][posY] = "."
	end
	
	for k, v in ipairs(enemyRowList) do
		local row = v
		
		
		for n, dragon in ipairs(row) do
			local posX = dragon.pos.x * hRatio
			local posY = dragon.pos.y * vRatio
			if math.ceil(posX) - posX >= 0.5 then
				posX = math.floor(posX)
			else
				posX = math.ceil(posX)
			end
		
			if math.ceil(posY) - posY >= 0.5 then
				posY = math.floor(posY)
			else
				posY = math.ceil(posY)
			end
		
			if posPacket[posX] == nil then
				posPacket[posX] = {}
			end
			
			if posPacket[posX][posY] == nil then
				posPacket[posX][posY] = {}
			end
			
			posPacket[posX][posY] = dragon.render
		
		end
		
	end
	
	local posX = player.pos.x * hRatio
	local posY = player.pos.y * vRatio
	if math.ceil(posX) - posX >= 0.5 then
		posX = math.floor(posX)
	else
		posX = math.ceil(posX)
	end

	if math.ceil(posY) - posY >= 0.5 then
		posY = math.floor(posY)
	else
		posY = math.ceil(posY)
	end

	if posPacket[posX] == nil then
		posPacket[posX] = {}
	end

	if posPacket[posX][posY] == nil then
		posPacket[posX][posY] = {}
	end

	posPacket[posX][posY] = "p"
end

local function render()
	if refreshScreen then
		os.execute( "clear" )
		print("-------- simulate -------------")
		clearWithStr(" ")
		rasterization()
		convertPosPacket()
		printResult()
		print("wave : "..tostring(currentWave))
		print("num1 : "..tostring(dragon1.needNum))
		print("num2 : "..tostring(dragon2.needNum))
		printCurrentSlots()
		printDebugStr()
		clearDebugStr()
		posPacket = {}
	end
end

local function loop(dt)
	-- update
	if player.alive then
		checkCollide()
		updateBullets(dt)
		doAI(dt)
		updatePlayer(dt)
		updateEnemy(dt)
	else
		return false
	end
	
	render()
	
	return true
end

-- init firstly
init()
while ret do
	if simulate then
		startTime = os.clock()
		timeInterval = startTime - endTime
		timer = timer + timeInterval
		totalTime = totalTime + timeInterval
		if timer > interval then
			ret = loop(interval)
			timer = 0
		end
		
		endTime = os.clock()
	else
		loop(interval)
		times = times + 1
		totalTime = totalTime + interval
		if times  > 1/interval * fastSimuTime then
			render()
			break
		end
	end
end

-- render last frame
render()

