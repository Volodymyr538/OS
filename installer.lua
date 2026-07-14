-- ============================================
--  MoldOS Installer
--  Run via: wget run <link to installer.lua on GitHub>
-- ============================================

local REPO_BASE = "https://raw.githubusercontent.com/Volodymyr538/OS/main/"

local FILES_TO_DOWNLOAD = {
    { url = REPO_BASE .. "os/startup.lua",       path = "/os/startup.lua" },
    { url = REPO_BASE .. "apps/filemanager.lua", path = "/os/apps/filemanager.lua" },
    { url = REPO_BASE .. "apps/sysinfo.lua",     path = "/os/apps/sysinfo.lua" },
    { url = REPO_BASE .. "apps/calc.lua",        path = "/os/apps/calc.lua" },
    { url = REPO_BASE .. "apps/netshare.lua",    path = "/os/apps/netshare.lua" },
    { url = REPO_BASE .. "apps/notes.lua",       path = "/os/apps/notes.lua" },
    { url = REPO_BASE .. "apps/snake.lua",       path = "/os/apps/snake.lua" },
    { url = REPO_BASE .. "apps/minesweeper.lua", path = "/os/apps/minesweeper.lua" },
    { url = REPO_BASE .. "apps/textedit.lua",    path = "/os/apps/textedit.lua" },
}

local W, H = term.getSize()

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

local function header(title)
    clear()
    term.setCursorPos(1, 1)
    term.write(string.rep("=", W))
    center(2, title)
    term.setCursorPos(1, 3)
    term.write(string.rep("=", W))
    term.setCursorPos(1, 5)
end

local function waitClick(msg)
    local _, h = term.getSize()
    term.setCursorPos(1, h)
    term.write(msg or "Click anywhere to continue...")
    os.pullEvent("mouse_click")
end

local function selectMenu(title, options)
    while true do
        header(title)
        local buttonY = {}
        for i, opt in ipairs(options) do
            local y = 5 + i
            buttonY[i] = y
            term.setCursorPos(4, y)
            term.setTextColor(colors.white)
            term.write("[ " .. opt .. " ]")
        end
        term.setCursorPos(1, H)
        term.write("Click an option to select")

        local _, _, cx, cy = os.pullEvent("mouse_click")
        for i, y in ipairs(buttonY) do
            if cy == y then
                return i, options[i]
            end
        end
    end
end

local function textInput(title, prompt, hideChar, allowEmpty)
    while true do
        header(title)
        term.write(prompt)
        term.setCursorPos(1, 7)
        term.write("> ")
        local value = read(hideChar)
        if value ~= "" or allowEmpty then
            return value
        end
        term.setCursorPos(1, 9)
        term.setTextColor(colors.red)
        term.write("This field cannot be empty!")
        term.setTextColor(colors.white)
        sleep(1)
    end
end

local function progressStep(label, y, duration)
    term.setCursorPos(4, y)
    term.write(label)
    local barWidth = W - 10
    local barX = 4
    local barY = y + 1
    term.setCursorPos(barX, barY)
    term.write("[" .. string.rep(" ", barWidth - 2) .. "]")
    local steps = barWidth - 2
    for i = 1, steps do
        term.setCursorPos(barX + i, barY)
        term.write("=")
        sleep(duration / steps)
    end
end

-- ============================================
--  STEP 1: Welcome
-- ============================================

header("MoldOS Setup")
term.write("Welcome to the MoldOS installation wizard.")
term.setCursorPos(1, 7)
term.write("You will now be asked a few setup questions.")
waitClick("Click anywhere to begin...")

-- ============================================
--  STEP 2: Country
-- ============================================

local _, country = selectMenu("Select Country", {
    "Moldova",
    "Russia",
    "Ukraine",
    "Belarus",
    "Other",
})

-- ============================================
--  STEP 3: Time zone
-- ============================================

local _, timezone = selectMenu("Time Zone", {
    "UTC+2 (Chisinau)",
    "UTC+3 (Moscow)",
    "UTC+2 (Kyiv)",
    "UTC+0",
    "Other",
})

-- ============================================
--  STEP 4: User profile
-- ============================================

local username = textInput("Create Profile", "Enter username:", nil, false)
local password = textInput("Create Profile", "Set a password (leave empty for none):", "*", true)

-- ============================================
--  STEP 5: Confirmation
-- ============================================

header("Review your settings")
term.write("Country: " .. country)
term.setCursorPos(1, 7); term.write("Time zone: " .. timezone)
term.setCursorPos(1, 8); term.write("Username: " .. username)
term.setCursorPos(1, 9); term.write("Password: " .. (password == "" and "(none)" or string.rep("*", #password)))
term.setCursorPos(1, 11)
term.write("[ Install ]        [ Cancel ]")

local proceed = false
while true do
    local _, _, cx, cy = os.pullEvent("mouse_click")
    if cy == 11 then
        if cx >= 1 and cx <= 10 then
            proceed = true
            break
        elseif cx >= 20 and cx <= 29 then
            proceed = false
            break
        end
    end
end

if not proceed then
    clear()
    print("Installation cancelled.")
    return
end

-- ============================================
--  STEP 6: Installation
-- ============================================

header("Installing MoldOS")

progressStep("Preparing system...", 5, 0.6)

if not fs.exists("/os") then fs.makeDir("/os") end
if not fs.exists("/os/apps") then fs.makeDir("/os/apps") end
if not fs.exists("/os/data") then fs.makeDir("/os/data") end

progressStep("Saving settings...", 8, 0.6)

local config = {
    country = country,
    timezone = timezone,
    osName = "MoldOS",
    osVersion = "1.2",
}
local cfgFile = fs.open("/os/data/config.lua", "w")
cfgFile.write(textutils.serialize(config))
cfgFile.close()

progressStep("Creating user account...", 14, 0.8)

local users = {}
users[username] = { password = password }
local usersFile = fs.open("/os/data/users.lua", "w")
usersFile.write(textutils.serialize(users))
usersFile.close()

header("Installing MoldOS")
term.setCursorPos(4, 5)
term.write("Downloading files from GitHub...")

local downloadY = 7
local failedFiles = {}

for i, item in ipairs(FILES_TO_DOWNLOAD) do
    term.setCursorPos(4, downloadY + i - 1)
    term.write(fs.getName(item.path) .. "...")

    local response = http.get(item.url)
    if response then
        local content = response.readAll()
        response.close()

        local dir = fs.getDir(item.path)
        if dir ~= "" and not fs.exists(dir) then
            fs.makeDir(dir)
        end

        local f = fs.open(item.path, "w")
        f.write(content)
        f.close()

        term.setCursorPos(W - 6, downloadY + i - 1)
        term.setTextColor(colors.lime)
        term.write("OK")
        term.setTextColor(colors.white)
    else
        term.setCursorPos(W - 10, downloadY + i - 1)
        term.setTextColor(colors.red)
        term.write("FAIL")
        term.setTextColor(colors.white)
        table.insert(failedFiles, item.path)
    end
end

sleep(0.5)

if not fs.exists("/startup.lua") then
    local su = fs.open("/startup.lua", "w")
    su.write('shell.run("/os/startup.lua")\n')
    su.close()
end

if #failedFiles > 0 then
    header("Installation Error")
    term.write("Failed to download files:")
    for i, f in ipairs(failedFiles) do
        term.setCursorPos(4, 6 + i)
        term.write(f)
    end
    term.setCursorPos(1, 6 + #failedFiles + 2)
    term.write("Check that HTTP is enabled on the server")
    term.setCursorPos(1, 6 + #failedFiles + 3)
    term.write("and that REPO_BASE in installer.lua is correct.")
    waitClick()
    return
end

progressStep("Finishing installation...", 20, 0.6)

-- ============================================
--  STEP 7: Done
-- ============================================

header("Installation Complete")
center(6, "MoldOS was installed successfully!")
center(8, "The computer will now reboot.")
sleep(2)
os.reboot()