local mq = require('mq')
local LIP = require('lib/LIP')
local ImGui = require('ImGui')

local BFOUtils = {};

local bfoSettings = {}

---@diagnostic disable-next-line: undefined-field
local bfo_config_dir = mq.TLO.MacroQuest.Path():gsub('\\', '/')
local bfo_settings_file = '/lua/config/bfoutils.ini'
local bfo_settings_path = bfo_config_dir .. bfo_settings_file

---@return string
function GetScriptName()
    local _script_name = debug.getinfo(1, 'S').short_src
    if string.match(_script_name, ".*init.lua$") then
        _script_name = _script_name:gsub(".*\\([^\\]+)\\init.lua", "%1")
    else
        _script_name = _script_name:gsub(".*\\([^\\]+).lua", "%1")
    end

    return _script_name
end

---@return string
function FormatInt(number)
    if not number then return "" end

    ---@diagnostic disable-next-line: undefined-field
    local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')

    -- reverse the int-string and append a comma to all blocks of 3 digits
    int = int:reverse():gsub("(%d%d%d)", "%1,")

    -- reverse the int-string back remove an optional comma and put the
    -- optional minus and fractional part back
    return minus .. int:reverse():gsub("^,", "") .. fraction
end

function TableContains(t, v)
    if not t then return false end
    for _, tv in pairs(t) do
        if tv == v then return true end
    end
    return false
end

function FormatTime(time)
    local days = math.floor(time / 86400)
    local hours = math.floor((time % 86400) / 3600)
    local minutes = math.floor((time % 3600) / 60)
    local seconds = math.floor((time % 60))
    return string.format("%d:%02d:%02d:%02d", days, hours, minutes, seconds)
end

function NoComma(numString)
    if not numString then return "" end

    return numString:gsub(",", "")
end

function Tooltip(desc)
    ImGui.SameLine()
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 25.0)
        ImGui.Text(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

function BFOUtils.UpdateWMCast(wmCast)
    bfoSettings["Default"] = {}
    bfoSettings["Default"]["WMCast"] = 0

    if wmCast then
        bfoSettings["Default"]["WMCast"] = 1
    end

    LIP.save(bfo_settings_path, bfoSettings)
end

local reloadSettings = function()
    bfoSettings = {}

    if file_exists(bfo_settings_path) then
        bfoSettings = LIP.load(bfo_settings_path)
    end

    if not bfoSettings or not bfoSettings["Default"] or not bfoSettings["Default"]["WMCast"] then
        print("No INI Making it.")
        BFOUtils.UpdateWMCast(false)
    end
end

function BFOUtils.WaitCastFinish()
    ---@diagnostic disable-next-line: undefined-field
    while mq.TLO.Me.Casting() and (not mq.TLO.Cast.Ready()) do
        mq.delay(1000)
    end
end

function BFOUtils.IsCasting()
    return mq.TLO.Me.Casting()
end

function BFOUtils.IsInCombat()
    return mq.TLO.Me.CombatState() == "COMBAT"
end

function BFOUtils.GetHighestSpell(spellList, format)
    local ret = "None"
    for i, v in ipairs(spellList) do
        local value = v
        if format then
            value = string.format(v, format)
        end

        if mq.TLO.Me.Book(value)() then
            ret = value
        end
    end
    return ret
end

function BFOUtils.Tokenize(inputStr, sep)
    if sep == nil then
        sep = "|"
    end

    local t = {}
    if string.find(tostring(inputStr), "^#") == nil then
        for str in string.gmatch(tostring(inputStr), "([^" .. sep .. "]+)") do
            if string.find(str, "^#") == nil then
                table.insert(t, str)
            end
        end
    end

    return t
end

function BFOUtils.RenderCurrentState(curState)
    if string.find(curState, "Idle") then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 1.0, 0.0, 1.0)
    else
        ImGui.PushStyleColor(ImGuiCol.Text, 0.63, 0.13, 0.63, 1.0)
    end

    ImGui.Text("Currently: " .. curState)
    ImGui.PopStyleColor(1)
end

local useWM = function()
    reloadSettings()
    return bfoSettings["Default"]["WMCast"]
end

function BFOUtils.HasBuffByName(target, buffname)
    if target == nil then return end

    local spawn = nil

    if target.ID() == mq.TLO.Me.ID() then
        spawn = mq.TLO.Me
    else
        spawn = mq.TLO.Spawn(target.ID())
    end

    --print(spawn.DisplayName().." id "..spawn.ID()..spawn.FindBuff("name "..buffname)())

    return spawn.FindBuff("name " .. buffname).ID() ~= nil
end

function BFOUtils.GetBuffByName(target, buffname)
    if target == nil then return nil end

    local spawn = nil

    if target.ID() == mq.TLO.Me.ID() then
        spawn = mq.TLO.Me
    else
        spawn = mq.TLO.Spawn(target.ID())
    end

    return spawn.FindBuff("name " .. buffname)()
end

function BFOUtils.GetBuffDuration(buff)
    if buff == nil then return 0 end

    if buff["Duration"] then return buff.Duration() end

    return 0
end

function BFOUtils.CanCast(spellName)
    if not spellName or spellName:len() == 0 then return false end
    if mq.TLO.Spell(spellName)() == nil then return false end

    if useWM() == 1 then
        return true
    end

    if mq.TLO.Me.CurrentMana() < mq.TLO.Spell(spellName).Mana() then return false end

    return true
end

function BFOUtils.Cast(spellName, slot, targetId, wait)
    local slot = slot or 5

    if not spellName or spellName:len() == 0 or spellName == "None" then return end

    if useWM() == 1 then
        local spellId = mq.TLO.Spell(spellName).ID()

        if not spellId then return end

        mq.cmd("/stand")
        mq.cmd("/wm cast " .. spellId .. " " .. (targetId or ""))
        mq.delay(mq.TLO.Spell(spellId).RecastTime())
        return
    end

    if mq.TLO.Spell(spellName)() == nil then return end

    if targetId and mq.TLO.Spawn(targetId)() then
        local spellRange = mq.TLO.Spell(spellName).Range() or 0
        local targetDistance = mq.TLO.Spawn(targetId).Distance()

        if spellRange > 0 and targetDistance > spellRange then
            --print("Failed to cast "..spellName.." oor: "..spellRange.." vs "..targetDistance)
            return
        end
    end

    if spellName then
        local cmd = "/casting \"" .. spellName .. "\" -invis "
        if slot then
            cmd = cmd .. "gem" .. slot .. " "
        end

        if targetId ~= nil and tonumber(targetId) > 0 then
            cmd = cmd .. "-targetid|" .. targetId .. " "
        end

        --print(cmd)

        mq.cmd(cmd)

        if wait then
            BFOUtils.WaitCastFinish()
        end
    end
end

function BFOUtils.GetItem(packSlot)
    return mq.TLO.Me.Inventory("pack" .. packSlot)
end

function BFOUtils.GetItemInContainer(packSlot, itemIdx)
    return mq.TLO.Me.Inventory("pack" .. packSlot).Item(itemIdx)
end

return BFOUtils
