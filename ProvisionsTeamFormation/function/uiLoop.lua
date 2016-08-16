local function TeamFormation_MakeIcon(index)
	if ProvTF.UI.Player[index] then return end

	local posLifeBar = (true and 14 or -14)

	ProvTF.UI.Player[index] = CreateControl(nil, ProvTF.UI, CT_TOPLEVELCONTROL)
	ProvTF.UI.Player[index]:SetDrawLevel(10)
	ProvTF.UI.Player[index]:SetHidden(true)
	ProvTF.UI.Player[index].data = {}

	ProvTF.UI.Player[index].Icon = WINDOW_MANAGER:CreateControl(nil, ProvTF.UI.Player[index], CT_TEXTURE)
	ProvTF.UI.Player[index].Icon:SetDimensions(24, 24)
	ProvTF.UI.Player[index].Icon:SetAnchor(CENTER, ProvTF.UI.Player[index], CENTER, 0, 0)
	ProvTF.UI.Player[index].Icon:SetTexture("/esoui/art/icons/mapkey/mapkey_groupmember.dds")
	ProvTF.UI.Player[index].Icon:SetDrawLevel(3)

	if index >= 100 then return end
	ProvTF.UI.Player[index].LifeBar = WINDOW_MANAGER:CreateControl(nil, ProvTF.UI.Player[index], CT_TEXTURE)
	ProvTF.UI.Player[index].LifeBar:SetDimensions(24, 2)
	ProvTF.UI.Player[index].LifeBar:SetColor(1, 0, 0)
	ProvTF.UI.Player[index].LifeBar:SetAnchor(CENTER, ProvTF.UI.Player[index], CENTER, 0, posLifeBar)
	ProvTF.UI.Player[index].LifeBar:SetDrawLevel(2)
end

--[[local function recursive(control, str)
	d(str .. " " .. control:GetName())
	if control:GetNumChildren() == 0 or string.len(str) > 2 then return end
	for i = 1, control:GetNumChildren() do recursive(control:GetChild(i), str .. "-") end
end


SLASH_COMMANDS["/12i"] = function()
	recursive(WINDOW_MANAGER:GetControlByName("LAMAddonSettingsWindow"), "-")
end
--]]


--[[SLASH_COMMANDS["/12"] = function()

end
--]]

local function outOfScreenRect(x1, y1, minX, minY, maxX, maxY)
	if x1 > minX and x1 < maxX and y1 > minY and y1 < maxY then
		return nil, nil
	end

	local ix = nil
	local iy = nil
	local x = nil
	local y = nil
	local m = y1 / (x1 ~= 0 and x1 or 1)

	if x1 < minX then
		y = m * minX
		if (y > minY and y < maxY) then ix = minX iy = y end
	else
		y = m * maxX
		if (y > minY and y < maxY) then ix = maxX iy = y end
	end

	if y1 < minY then
		x = minY / m
		if (x > minX and x < maxX) then ix = x iy = minY end
	else
		x = maxY / m
		if (x > minX and x < maxX) then ix = x iy = maxY end
	end

	return ix, iy
end

local function outOfScreenCircle(x1, y1, rx, ry)
	if (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry) < 1 then
		return nil, nil
	end

	local a = math.atan2(y1, x1)
	local ix = rx * math.cos(a)
	local iy = ry * math.sin(a)

	return ix, iy
end

local function TeamFormation_getDivisor() -- RangeReticle function (Author: Adein - http://www.esoui.com/downloads/info177-RangeReticle.html)
	local mapWidth, mapHeight = GetMapNumTiles()
	local mapType = GetMapType()
	local mapContentType = GetMapContentType()

	local divisor = mapType * mapWidth

	if mapContentType == MAP_CONTENT_NONE then
		if mapType == MAPTYPE_SUBZONE then
			divisor = 1.00
		elseif mapType == MAPTYPE_ZONE then
			divisor = 0.20
		end
	elseif mapContentType == MAP_CONTENT_AVA then
		if mapType == MAPTYPE_SUBZONE then
			divisor = 1.75
		elseif mapType == MAPTYPE_ZONE then
			divisor = 0.08
		end
	elseif mapContentType == MAP_CONTENT_DUNGEON then
		if mapType == MAPTYPE_SUBZONE then
			divisor = 1.45
		elseif mapType == MAPTYPE_ZONE then
			divisor = 1.79
		end
	end

	return divisor
end

local function TeamFormation_MoveIcon(index, x, y)
	local unitTag = (index ~= 0) and ("group" .. index) or "player"

	local mx = (ProvTF.vars.width / 2)
	local my = (ProvTF.vars.height / 2)

	local bx, by
	if ProvTF.vars.circle then
		bx, by = outOfScreenCircle(x, y, mx, my)
	else
		bx, by = outOfScreenRect(x, y, -mx, -my, mx, my)
	end

	if bx ~= nil then x = bx y = by end

	ProvTF.UI.Player[index].data.isOut = (bx == nil)
	ProvTF.UI.Player[index]:SetAnchor(CENTER, ProvTF.UI, CENTER, x, y)
end

local function updateIsNecessary(index, key, value)
	if not ProvTF.UI.Player[index] then return end

	local oldValue = ProvTF.UI.Player[index].data[key]
	ProvTF.UI.Player[index].data[key] = value
	return (oldValue ~= value)
end

local function TeamFormation_UpdateIcon(index, sameZone, isDead, isInCombat)
	local unitTag = (index ~= 0) and ("group" .. index) or "player"
	local name = GetUnitName(unitTag)
	local health, maxHealth, _ = GetUnitPower(unitTag, POWERTYPE_HEALTH)
	local sizeHealthBar = zo_round(24 * health / maxHealth)
	local isUnitBeingResurrected = isDead and IsUnitBeingResurrected(unitTag)
	local doesUnitHaveResurrectPending = isDead and DoesUnitHaveResurrectPending(unitTag)
	local updateIsNecessaryOnDead = (updateIsNecessary(index, "isDead", isDead) or
		updateIsNecessary(index, "isUnitBeingResurrected", isUnitBeingResurrected) or
		updateIsNecessary(index, "doesUnitHaveResurrectPending", doesUnitHaveResurrectPending)
	)
	local updateIsNecessaryOnSameZone = updateIsNecessary(index, "sameZone", sameZone)
	local isGroupLeader = IsUnitGroupLeader(unitTag)
	local updateIsNecessaryOnGrLeader = updateIsNecessary(index, "isGroupLeader", isGroupLeader)
	local isMe = (name == GetUnitName("player"))
	local r, g, b = unpack(ProvTF.vars.jRules[name] or {1, 1, 1})

	-- Set Icon
	if updateIsNecessary(index, "name", name) or updateIsNecessaryOnGrLeader or updateIsNecessaryOnDead then
		local class = tostring(CLASS_ID2NAME[GetUnitClassId(unitTag)])
		ProvTF.UI.Player[index].Icon:SetColor(r, g, b, 1)
		ProvTF.UI.Player[index].Icon:SetTextureRotation(0)
		ProvTF.UI.Player[index].Icon:SetDimensions(24, 24)
		ProvTF.UI.Player[index]:SetHidden(false)

		if isMe then
			ProvTF.UI.Player[index].Icon:SetTexture("/esoui/art/icons/mapkey/mapkey_player.dds")
		elseif isDead then
			local iconPath = "in"

			if doesUnitHaveResurrectPending then
				iconPath = ""
			elseif not isUnitBeingResurrected then
				ProvTF.UI.Player[index].Icon:SetColor(1, 0, 0)
			end

			ProvTF.UI.Player[index].Icon:SetTexture("/esoui/art/icons/poi/poi_groupboss_" .. iconPath .. "complete.dds")
			if isGroupLeader then
				ProvTF.UI.Player[index].Icon:SetDimensions(48, 48)
			else
				ProvTF.UI.Player[index].Icon:SetDimensions(32, 32)
			end
		elseif ProvTF.vars.roleIcon then
			local isDps, isHealer, isTank = GetGroupMemberRoles(unitTag)
			local role = "dps"
			if isTank then
				role = "tank"
			elseif isHealer then
				role = "healer"
			end
			ProvTF.UI.Player[index].Icon:SetTexture("/esoui/art/lfg/lfg_" .. role .. "_up.dds")
			ProvTF.UI.Player[index].Icon:SetDimensions(32, 32)
		elseif isGroupLeader then
			ProvTF.UI.Player[index].Icon:SetTexture("EsoUI/Art/Compass/groupLeader.dds")
			ProvTF.UI.Player[index].Icon:SetDimensions(32, 32)
		elseif class ~= "nil" then
			ProvTF.UI.Player[index].Icon:SetTexture("/esoui/art/icons/class/class_" .. class .. ".dds")
		else
			ProvTF.UI.Player[index].Icon:SetTexture("/esoui/art/icons/mapkey/mapkey_groupmember.dds")
			ProvTF.UI.Player[index].Icon:SetDimensions(16, 16)
			ProvTF.UI.Player[index].data.name = nil
			--d("[TF] bug n69: " .. name .. " " .. unitTag)
		end
	end

	-- Set Icon Color
	if updateIsNecessary(index, "colorIcon", tostring(r) .. tostring(g) .. tostring(b)) then
		ProvTF.UI.Player[index].Icon:SetColor(r, g * health / maxHealth, b * health / maxHealth)
	end

	-- Set Life
	if updateIsNecessary(index, "sizeHealthBar", sizeHealthBar) then
		ProvTF.UI.Player[index].LifeBar:SetDimensions(sizeHealthBar, 1 / GetSetting(SETTING_TYPE_UI, UI_SETTING_CUSTOM_SCALE))

		ProvTF.UI.Player[index].Icon:SetColor(r, g * health / maxHealth, b * health / maxHealth)
	end

	if updateIsNecessaryOnDead then
		ProvTF.UI.Player[index].LifeBar:SetHidden(isDead)
	end

	-- Set Zone
	if updateIsNecessaryOnSameZone or updateIsNecessaryOnGrLeader or updateIsNecessaryOnDead then
		if isGroupLeader then
			ProvTF.UI.Player[index]:SetDrawLevel((sameZone and not isDead) and 11 or 6)
		else
			ProvTF.UI.Player[index]:SetDrawLevel((sameZone and not isDead) and 10 or 5)
		end
		ProvTF.UI.Player[index].LifeBar:SetHidden(not sameZone)
	end

	-- Set LifeBar Color
	if updateIsNecessary(index, "isInCombat", isInCombat) then
		if isInCombat and name ~= GetUnitName("player") then
			ProvTF.UI.Player[index].LifeBar:SetColor(1, 0, 0)
		else
			ProvTF.UI.Player[index].LifeBar:SetColor(.72, .24, .24)
		end
	end

	-- Set Alpha
	if isMe then
		local myAlpha = ProvTF.vars.myAlpha
		if updateIsNecessary(index, "myAlpha", myAlpha) then
			if myAlpha == 0 then
				ProvTF.UI.Player[index]:SetHidden(true)
			else
				ProvTF.UI.Player[index]:SetHidden(false)
			end
			ProvTF.UI.Player[index]:SetAlpha(myAlpha)
		end
	else
		local defAlpha = sameZone and (ProvTF.UI.Player[index].data.isOut and 1 or 0.4) or 0.2
		if updateIsNecessary(index, "defAlpha", defAlpha) then
			ProvTF.UI.Player[index]:SetAlpha(defAlpha)
		end
	end
end

local function TeamFormation_CalculateXY(x, y)
	if x == nil or y == nil then
		return nil, nil
	end
	local fX, fY, fHeading = GetMapPlayerPosition("player")
	local gameScale = 100 * ProvTF.vars.scale / TeamFormation_getDivisor()

	x = (x - fX)
	y = (y - fY)

	--[[ debug
	if ProvTF.debug.enabled and ProvTF.debug.pos.num == i and ProvTF.debug.pos.x ~= nil and myName ~= GetUnitName(unitTag) then
		local dist = math.sqrt(x * x + y * y) * 800 / TeamFormation_getDivisor() -- meter
		local dist = zo_round(dist * 100) / 100
		ProvTF.UI.LblMyPosition:SetText("Distance avec " .. i .. " : " .. dist .. " mètres ")
	end
	--]]

	local head = (ProvTF.vars.camRotation and GetPlayerCameraHeading() or fHeading)
	local vx = (math.cos(head) * x) - (math.sin(head) * y)
	local vy = (math.sin(head) * x) + (math.cos(head) * y)

	if ProvTF.vars.logdist ~= 0 then
		local denominator = math.log(1000)
		if vx ~= 0 then vx = vx + (vx * math.log(math.abs(vx)) / denominator * ProvTF.vars.logdist) end
		if vy ~= 0 then vy = vy + (vy * math.log(math.abs(vy)) / denominator * ProvTF.vars.logdist) end
	end

	x = zo_round(vx * gameScale)
	y = zo_round(vy * gameScale)

	return x, y
end

local function TeamFormation_GetOrder()
	local order = {}
	local numChildren = WINDOW_MANAGER:GetControlByName("ZO_GroupListListContents"):GetNumChildren()
	local str, text
	for i = 1, numChildren do
		if WINDOW_MANAGER:GetControlByName("ZO_GroupListList1Row" .. i .. "CharacterName") then
			text = WINDOW_MANAGER:GetControlByName("ZO_GroupListList1Row" .. i .. "CharacterName"):GetText()
			str = string.match(text, "^[0-9]+\. [^ ]+ (.+)$")
			if str and str ~= "" then
				order[str] = tostring(i)
			end
		end
	end
	return order
end

ProvTF.lastSize = nil
ProvTF.numUpdate = 0
local function TeamFormation_uiLoop()
	if not ProvTF.vars.enabled then
		TeamFormation_SetHidden(true)
		return
	end

	local groupSize = GetGroupSize()

	ProvTF.numUpdate = ProvTF.numUpdate + 1

	local LAM2Panel = WINDOW_MANAGER:GetControlByName("ProvisionsTeamFormationLAM2Panel")

	if updateIsNecessary(1, "LAM2PanelisHidden", not LAM2Panel:IsHidden()) then
		if not LAM2Panel:IsHidden() then
			TeamFormation_SetHidden(false)
			ProvTF.UI:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, LAM2Panel:GetWidth() + LAM2Panel:GetLeft() + 40, LAM2Panel:GetTop())
		else
			ProvTF.UI:SetAnchor(CENTER, GuiRoot, CENTER, ProvTF.vars.posx, ProvTF.vars.posy)
		end
	end

	if ProvTF.lastSize and groupSize < ProvTF.lastSize then
		for i = math.max(1, groupSize), ProvTF.lastSize do
			ProvTF.UI.Player[i]:SetHidden(true)
		end
	end

	if groupSize == 0 then
		ProvTF.lastSize = 0
		TeamFormation_SetHidden(true)
		return
	elseif ProvTF.lastSize == 0 then
		TeamFormation_SetHidden(false)
	end

	local ABCOrder = TeamFormation_GetOrder()

	local myName = GetUnitName("player")
	local fX, fY, fHeading = GetMapPlayerPosition("player")
	local myIndex = 1

	local unitTag, name, x, y, heading, xi, yi, isOnline
	local zone, sameZone, dist, text, ctrl_class

	for i = 1, groupSize do
		unitTag = (i ~= 0) and ("group" .. i) or "player"
		name = GetUnitName(unitTag)
		x, y, heading = GetMapPlayerPosition(unitTag)
		zone = GetUnitZone(unitTag)
		isOnline = IsUnitOnline(unitTag) and not (name == "" or (x == 0 and y == 0)) -- last condition prevent issue

		if ProvTF.debug.enabled and ProvTF.debug.pos.num == i and ProvTF.debug.pos.x ~= nil and myName ~= name then
			x = ProvTF.debug.pos.x
			y = ProvTF.debug.pos.y
			zone = ProvTF.debug.pos.zone
			heading = ProvTF.debug.pos.heading
			isOnline = true

			--[[ debug
			if ProvTF.debug.enabled and ProvTF.debug.pos.num == i and ProvTF.debug.pos.x ~= nil and myName ~= GetUnitName(unitTag) then
				local fX, fY, fHeading = GetMapPlayerPosition("player")
				x = (x - fX)
				y = (y - fY)
				local dist = math.sqrt(x * x + y * y) * 800 / TeamFormation_getDivisor() -- meter
				local dist = zo_round(dist * 100) / 100
				ProvTF.UI.LblMyPosition:SetText("Distance avec " .. i .. " : " .. dist .. " mètres ")
			end
			--]]
		end

		TeamFormation_MakeIcon(i)

		if isOnline then
			xi, yi = TeamFormation_CalculateXY(x, y)
			sameZone = GetUnitZone("player") == zone

			if ProvTF.UI.Player[i].data.name ~= name then
				ProvTF.UI.Player[i].data = {}
			end

			TeamFormation_MoveIcon(i, xi, yi)
			TeamFormation_UpdateIcon(i, sameZone, IsUnitDead(unitTag), IsUnitInCombat(unitTag))

			if sameZone and myName ~= name then
				x = (x - fX)
				y = (y - fY)
				dist = math.sqrt(x * x + y * y) * 800 / TeamFormation_getDivisor() -- meter

				if dist < 1000 then
					dist = zo_round(dist)
					text = "~ " .. dist .. " m"
				else
					dist = zo_round(dist / 10) / 100
					text = "~ " .. dist .. " Km"
				end
			else
				text = zo_strformat(SI_SOCIAL_LIST_LOCATION_FORMAT, zone)
				if myName == name then
					text = "|c00C000" .. text .. "|r"
				end
			end

			if WINDOW_MANAGER:GetControlByName("ZO_GroupListList1Row" .. tostring(ABCOrder[name]) .. "Zone") then
				WINDOW_MANAGER:GetControlByName("ZO_GroupListList1Row" .. tostring(ABCOrder[name]) .. "Zone"):SetText(text)

				ctrl_class = WINDOW_MANAGER:GetControlByName("ZO_GroupListList1Row" .. tostring(ABCOrder[name]) .. "ClassIcon")
				ctrl_class:SetColor(unpack(ProvTF.vars.jRules[name] or {1, 1, 1}))
			end
		end

		if updateIsNecessary(i, "isOnline", isOnline) then
			ProvTF.UI.Player[i]:SetHidden(not isOnline)
		end

		if myName == name then
			myIndex = i
		end
	end

	local _, _, myHeading = GetMapPlayerPosition("player")
	local myCamHeading = math.abs(myHeading - math.pi *2) + GetPlayerCameraHeading()
	myCamHeading = (ProvTF.vars.camRotation and myCamHeading or 0)
	if ProvTF.UI.Player[myIndex] and updateIsNecessary(myIndex, "MyCamHeading", myCamHeading) then
		ProvTF.UI.Player[myIndex].Icon:SetTextureRotation(-myCamHeading)
	end

	TeamFormation_MakeIcon(100)
	x, y = GetMapPlayerWaypoint()
	if x ~= 0 and y ~= 0 then
		x, y = TeamFormation_CalculateXY(x, y)
		TeamFormation_MoveIcon(100, x, y)
		ProvTF.UI.Player[100].Icon:SetTexture("/esoui/art/compass/compass_waypoint.dds")
		ProvTF.UI.Player[100]:SetHidden(false)
	else
		ProvTF.UI.Player[100]:SetHidden(true)
	end

	local cx, cy, ca

	local mx = (ProvTF.vars.width / 2)
	local my = (ProvTF.vars.height / 2)

	for i = 1, 4 do
		ca = (i - 2) * math.pi / 2 + (ProvTF.vars.camRotation and GetPlayerCameraHeading() or myHeading)
		cx = zo_round((ProvTF.vars.width / 2) * math.cos(ca))
		cy = zo_round((ProvTF.vars.height / 2) * math.sin(ca))

		if not ProvTF.vars.circle then
			cx, cy = outOfScreenRect(cx * 2, cy * 2, -mx, -my, mx, my)
		end

		ProvTF.UI.Cardinal[i]:SetAnchor(CENTER, ProvTF.UI, CENTER, cx, cy)
		ProvTF.UI.Cardinal[i]:SetAlpha(ProvTF.vars.cardinal)
	end

	--[[TeamFormation_MakeIcon(101)
	x = nil
	x, y = TeamFormation_CalculateXY(GetMapRallyPoint())
	ProvTF.UI.Player[101]:SetHidden(x == nil)
	if x ~= nil and ProvTF.numUpdate == 1 then
		TeamFormation_MoveIcon(101, x, y)
		ProvTF.UI.Player[101].Icon:SetTexture("/esoui/art/mappins/maprallypoint.dds")
		ProvTF.UI.Player[101].Icon:SetDimensions(128, 128)

		local anim, timeline = CreateSimpleAnimation(ANIMATION_TEXTURE, ProvTF.UI.Player[101].Icon)
		anim:SetImageData(32, 1)
		anim:SetFramerate(32)
		anim:SetHandler("OnStop", function() ProvTF.UI.Player[101].Icon:SetTextureCoords(0, 1, 0, 1) end)

		timeline:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, 10)
		timeline:PlayFromStart()
	end]]

	ProvTF.lastSize = groupSize
end

function TeamFormation_OnUpdate()
	TeamFormation_ErrorSniffer(TeamFormation_uiLoop)
end