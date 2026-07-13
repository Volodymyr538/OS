-- ============================================
--  MoldOS - /os/startup.lua
--  Runs automatically when the computer starts
-- ============================================

local W, H = term.getSize()
local DATA_DIR = "/os/data"
local APPS_DIR = "/os/apps"
local osName, osVersion = "MoldOS", "1.4"

-- GitHub repo used for update / install
local REPO_BASE = "https://raw.githubusercontent.com/Volodymyr538/OS/main/"
local SYSTEM_FILES = {
    { url = REPO_BASE .. "os/startup.lua", path = "/os/startup.lua" },
}
local APP_REGISTRY = {
    filemanager  = REPO_BASE .. "apps/filemanager.lua",
    sysinfo      = REPO_BASE .. "apps/sysinfo.lua",
    calc         = REPO_BASE .. "apps/calc.lua",
    netshare     = REPO_BASE .. "apps/netshare.lua",
    notes        = REPO_BASE .. "apps/notes.lua",
    snake        = REPO_BASE .. "apps/snake.lua",
    minesweeper  = REPO_BASE .. "apps/minesweeper.lua",
}

-- ---------- monitor mirroring ----------

local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(0.5)
end

local originalTerm = term.current()

local function mirror(fnName)
    return function(...)
        local args = { ... }
        local result = { originalTerm[fnName](table.unpack(args)) }
        if monitor then
            pcall(function() monitor[fnName](table.unpack(args)) end)
        end
        return table.unpack(result)
    end
end

if monitor then
    local mirrored = {}
    for _, name in ipairs({
        "write", "clear", "clearLine", "setCursorPos", "setCursorBlink",
        "setTextColour", "setTextColor", "setBackgroundColour", "setBackgroundColor",
        "scroll", "getCursorPos", "getSize", "isColour", "isColor",
        "getTextColour", "getTextColor", "getBackgroundColour", "getBackgroundColor",
        "blit",
    }) do
        mirrored[name] = mirror(name)
    end
    term.redirect(mirrored)
end

-- ---------- UI helpers ----------

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function center(y, text)
    local x = math.floor((W - #text) / 2) + 1
    term.setCursorPos(x, y)
    term.write(text)
end

-- ---------- load config and users ----------

local function loadTable(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok then return data end
    return nil
end

local function saveTable(path, tbl)
    local f = fs.open(path, "w")
    f.write(textutils.serialize(tbl))
    f.close()
end

local config = loadTable(DATA_DIR .. "/config.lua") or {}
local users = loadTable(DATA_DIR .. "/users.lua") or {}

-- ============================================
--  BOOT SCREEN
-- ============================================

local function bootScreen()
    clear()
    center(math.floor(H / 2) - 1, osName .. " v" .. osVersion)
    center(math.floor(H / 2) + 1, "Starting system...")

    local barWidth = math.min(W - 4, 30)
    local barX = math.floor((W - barWidth) / 2) + 1
    local barY = math.floor(H / 2) + 3
    term.setCursorPos(barX, barY)
    term.write("[" .. string.rep(" ", barWidth - 2) .. "]")
    for i = 1, barWidth - 2 do
        term.setCursorPos(barX + i, barY)
        term.write("=")
        sleep(0.03)
    end
    sleep(0.3)
end

-- ============================================
--  LOGIN SCREEN (click your account, then type password)
-- ============================================

local function loginScreen()
    local userList = {}
    for name in pairs(users) do
        table.insert(userList, name)
    end
    table.sort(userList)

    if #userList == 0 then
        return "guest"
    end

    while true do
        clear()
        center(3, osName)
        center(5, "Select your account")
        term.setCursorPos(1, 4)
        term.write(string.rep("-", W))

        local rows = {}
        local y = 7
        for _, name in ipairs(userList) do
            term.setCursorPos(4, y)
            term.write("[ " .. name .. " ]")
            table.insert(rows, { y = y, name = name })
            y = y + 1
        end

        local _, _, cx, cy = os.pullEvent("mouse_click")
        local chosen = nil
        for _, row in ipairs(rows) do
            if cy == row.y then
                chosen = row.name
                break
            end
        end

        if chosen then
            local userData = users[chosen]
            while true do
                clear()
                center(3, osName)
                center(5, "Welcome back, " .. chosen)
                term.setCursorPos(1, 4)
                term.write(string.rep("-", W))

                term.setCursorPos(4, 8)
                term.write("Password: ")
                local inputPass = read("*")

                if userData.password == "" or userData.password == inputPass then
                    return chosen
                else
                    term.setCursorPos(4, 10)
                    term.setTextColor(colors.red)
                    term.write("Incorrect password.")
                    term.setTextColor(colors.white)
                    sleep(1.2)
                    break
                end
            end
        end
    end
end

-- ============================================
--  GREETING & CLOCK
-- ============================================

local function getGreeting()
    local hour = os.time("ingame")
    if hour >= 5 and hour < 12 then
        return "Good morning"
    elseif hour >= 12 and hour < 17 then
        return "Good afternoon"
    elseif hour >= 17 and hour < 21 then
        return "Good evening"
    else
        return "Good night"
    end
end

local function getClockString()
    local hour = os.time("ingame")
    local h = math.floor(hour)
    local m = math.floor((hour - h) * 60)
    return string.format("%02d:%02d", h, m)
end

local function showGreeting(user)
    clear()
    center(math.floor(H / 2), getGreeting() .. ", " .. user .. "!")
    sleep(1.2)
end

-- ============================================
--  UPDATE / INSTALL
-- ============================================

local function downloadFile(url, path)
    local response = http.get(url)
    if not response then
        return false, "failed to fetch " .. url
    end
    local content = response.readAll()
    response.close()

    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local f = fs.open(path, "w")
    f.write(content)
    f.close()
    return true
end

local function runUpdate()
    clear()
    print("Checking for updates...")
    print("")

    local anyFailed = false
    for _, item in ipairs(SYSTEM_FILES) do
        write(fs.getName(item.path) .. "... ")
        local ok, err = downloadFile(item.url, item.path)
        if ok then
            print("OK")
        else
            print("FAILED")
            anyFailed = true
        end
    end

    print("")
    if anyFailed then
        print("Some files failed to update. Check your connection.")
    else
        print("Update complete! Rebooting...")
        sleep(1.5)
        os.reboot()
    end
    print("")
    print("Click anywhere to go back...")
    os.pullEvent("mouse_click")
end

local function runInstall()
    clear()
    print("=== Install App ===")
    print("")
    print("Available apps:")
    for name in pairs(APP_REGISTRY) do
        print("  " .. name)
    end
    print("")
    write("Enter app name to install: ")
    local appName = read()

    local url = APP_REGISTRY[appName]
    if not url then
        print("")
        print("Unknown app: " .. tostring(appName))
        print("")
        print("Click anywhere to go back...")
        os.pullEvent("mouse_click")
        return
    end

    print("")
    print("Installing '" .. appName .. "'...")
    local path = fs.combine(APPS_DIR, appName .. ".lua")
    local ok, err = downloadFile(url, path)
    if ok then
        print("Installed successfully!")
    else
        print("Failed: " .. tostring(err))
    end
    print("")
    print("Click anywhere to go back...")
    os.pullEvent("mouse_click")
end

-- ============================================
--  SETTINGS
-- ============================================

local currentUser = nil

local function changePassword()
    clear()
    print("=== Change Password ===")
    print("")
    write("Current password: ")
    local current = read("*")

    local userData = users[currentUser]
    if userData.password ~= "" and userData.password ~= current then
        print("")
        print("Incorrect current password.")
        sleep(1.5)
        return
    end

    write("New password (leave empty for none): ")
    local newPass = read("*")
    userData.password = newPass
    saveTable(DATA_DIR .. "/users.lua", users)

    print("")
    print("Password changed successfully!")
    sleep(1.2)
end

local function renameUser()
    clear()
    print("=== Change Username ===")
    print("")
    write("New username: ")
    local newName = read()

    if not newName or newName == "" then
        return
    end
    if users[newName] then
        print("")
        print("That username is already taken.")
        sleep(1.5)
        return
    end

    users[newName] = users[currentUser]
    users[currentUser] = nil
    currentUser = newName
    saveTable(DATA_DIR .. "/users.lua", users)

    print("")
    print("Username changed to '" .. newName .. "'!")
    sleep(1.2)
end

local function createUser()
    clear()
    print("=== New User ===")
    print("")
    write("Username: ")
    local newName = read()

    if not newName or newName == "" then
        return
    end
    if users[newName] then
        print("")
        print("That username already exists.")
        sleep(1.5)
        return
    end

    write("Password (leave empty for none): ")
    local newPass = read("*")

    users[newName] = { password = newPass }
    saveTable(DATA_DIR .. "/users.lua", users)

    print("")
    print("User '" .. newName .. "' created!")
    sleep(1.2)
end

local function deleteUser()
    clear()
    print("=== Delete a User ===")
    print("")
    for name in pairs(users) do
        print("  " .. name)
    end
    print("")
    write("Username to delete: ")
    local targetName = read()

    if targetName == currentUser then
        print("")
        print("You cannot delete the account you are logged into.")
        sleep(1.5)
        return
    end
    if not users[targetName] then
        print("")
        print("User not found.")
        sleep(1.5)
        return
    end

    users[targetName] = nil
    saveTable(DATA_DIR .. "/users.lua", users)
    print("")
    print("User '" .. targetName .. "' deleted.")
    sleep(1.2)
end

local function runSettings()
    local options = {
        { label = "Change Password", action = changePassword },
        { label = "Change Username", action = renameUser },
        { label = "Create New User", action = createUser },
        { label = "Delete a User",   action = deleteUser },
        { label = "Back",            action = function() return "back" end },
    }

    while true do
        clear()
        term.write("=== Settings ===")
        local y = 3
        local rows = {}
        for _, opt in ipairs(options) do
            term.setCursorPos(4, y)
            term.write("[ " .. opt.label .. " ]")
            table.insert(rows, { y = y, action = opt.action })
            y = y + 1
        end

        local _, _, cx, cy = os.pullEvent("mouse_click")
        for _, row in ipairs(rows) do
            if cy == row.y then
                local result = row.action()
                if result == "back" then
                    return
                end
                break
            end
        end
    end
end

local function logOut()
    currentUser = loginScreen()
    showGreeting(currentUser)
end

-- ============================================
--  RENDET (network chat)
-- ============================================

local function rednetChat()
    clear()
    local modem = peripheral.find("modem")
    if not modem then
        print("No modem attached to this computer.")
        print("")
        print("Click anywhere to go back...")
        os.pullEvent("mouse_click")
        return
    end

    if not rednet.isOpen(peripheral.getName(modem)) then
        rednet.open(peripheral.getName(modem))
    end

    print("=== MoldOS Chat ===")
    print("Your computer ID: " .. os.getComputerID())
    print("")
    print("Enter target computer ID (or 'all' to broadcast):")
    write("> ")
    local target = read()

    print("Type your message. Type 'exit' to quit chat.")
    print("")

    local function listenLoop()
        while true do
            local senderId, message = rednet.receive("moldos_chat")
            print("[" .. senderId .. "] " .. tostring(message))
        end
    end

    local function sendLoop()
        while true do
            write("me> ")
            local msg = read()
            if msg == "exit" then
                return
            end
            if target == "all" then
                rednet.broadcast(msg, "moldos_chat")
            else
                local targetId = tonumber(target)
                if targetId then
                    rednet.send(targetId, msg, "moldos_chat")
                else
                    print("Invalid target ID.")
                end
            end
        end
    end

    parallel.waitForAny(listenLoop, sendLoop)
    rednet.close(peripheral.getName(modem))
end

-- ============================================
--  APP LIST (click to launch)
-- ============================================

local systemActions = {
    { label = "About System",  action = function()
        clear()
        print(osName .. " v" .. osVersion)
        print("Country: " .. tostring(config.country))
        print("Time zone: " .. tostring(config.timezone))
        print(_HOST)
        print("")
        print("Click anywhere to go back...")
        os.pullEvent("mouse_click")
    end },
    { label = "Network Chat", action = rednetChat },
    { label = "Settings", action = runSettings },
    { label = "Check for Updates", action = runUpdate },
    { label = "Install App", action = runInstall },
    { label = "Log Out", action = logOut },
    { label = "Reboot",   action = function() os.reboot() end },
    { label = "Shutdown", action = function() os.shutdown() end },
}

local function getAppList()
    local apps = {}
    if fs.exists(APPS_DIR) then
        local files = fs.list(APPS_DIR)
        table.sort(files)
        for _, f in ipairs(files) do
            table.insert(apps, {
                label = f:gsub("%.lua$", ""),
                path = fs.combine(APPS_DIR, f),
            })
        end
    end
    return apps
end

local function drawMenu(apps)
    clear()
    term.setCursorPos(1, 1)
    term.write(string.rep("=", W))
    center(2, osName .. " - " .. getGreeting() .. ", " .. currentUser)

    local clockStr = getClockString()
    term.setCursorPos(W - #clockStr, 1)
    term.setTextColor(colors.yellow)
    term.write(clockStr)
    term.setTextColor(colors.white)

    term.setCursorPos(1, 3)
    term.write(string.rep("=", W))

    local y = 5
    local rows = {}

    term.setCursorPos(4, y)
    term.setTextColor(colors.yellow)
    term.write("-- Apps --")
    term.setTextColor(colors.white)
    y = y + 1

    if #apps == 0 then
        term.setCursorPos(4, y)
        term.setTextColor(colors.lightGray)
        term.write("(no apps installed)")
        term.setTextColor(colors.white)
        y = y + 1
    else
        for _, app in ipairs(apps) do
            term.setCursorPos(4, y)
            term.write("[ " .. app.label .. " ]")
            table.insert(rows, { y = y, action = function() shell.run(app.path) end })
            y = y + 1
        end
    end

    y = y + 1
    term.setCursorPos(4, y)
    term.setTextColor(colors.yellow)
    term.write("-- System --")
    term.setTextColor(colors.white)
    y = y + 1

    for _, item in ipairs(systemActions) do
        term.setCursorPos(4, y)
        term.write("[ " .. item.label .. " ]")
        table.insert(rows, { y = y, action = item.action })
        y = y + 1
    end

    return rows
end

local function menuLoop()
    while true do
        local apps = getAppList()
        local rows = drawMenu(apps)

        local timerId = os.startTimer(1)
        local clicked = false
        local cx, cy

        while not clicked do
            local event, p1, p2, p3 = os.pullEvent()
            if event == "mouse_click" then
                cx, cy = p2, p3
                clicked = true
            elseif event == "timer" and p1 == timerId then
                local clockStr = getClockString()
                term.setCursorPos(W - #clockStr, 1)
                term.setTextColor(colors.yellow)
                term.write(clockStr)
                term.setTextColor(colors.white)
                timerId = os.startTimer(1)
            end
        end

        for _, row in ipairs(rows) do
            if cy == row.y then
                local ok, err = pcall(row.action)
                if not ok then
                    clear()
                    print("Error running program:")
                    print(err)
                    print("")
                    print("Click anywhere to go back...")
                    os.pullEvent("mouse_click")
                end
                break
            end
        end
    end
end

-- ============================================
--  START
-- ============================================

if not fs.exists(APPS_DIR) then fs.makeDir(APPS_DIR) end
if not fs.exists(DATA_DIR) then fs.makeDir(DATA_DIR) end

bootScreen()
currentUser = loginScreen()
showGreeting(currentUser)
menuLoop()