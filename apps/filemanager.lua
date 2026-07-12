-- MoldOS App: filemanager
-- Simple file manager with arrow-key navigation

local W, H = term.getSize()
local currentPath = "/"

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function getEntries(path)
    local list = fs.list(path)
    table.sort(list)
    local entries = {}
    if path ~= "/" then
        table.insert(entries, "..")
    end
    for _, name in ipairs(list) do
        table.insert(entries, name)
    end
    return entries
end

local function draw(entries, selected)
    clear()
    term.write("=== File Manager: " .. currentPath .. " ===")
    term.setCursorPos(1, 2)
    term.write(string.rep("-", W))

    local startY = 3
    local maxVisible = H - 5

    local scrollOffset = 0
    if selected > maxVisible then
        scrollOffset = selected - maxVisible
    end

    for i = 1, math.min(#entries, maxVisible) do
        local idx = i + scrollOffset
        if entries[idx] then
            local entryPath = fs.combine(currentPath, entries[idx])
            local isDir = entries[idx] == ".." or (fs.exists(entryPath) and fs.isDir(entryPath))
            term.setCursorPos(3, startY + i - 1)

            if idx == selected then
                term.setTextColor(colors.white)
                term.write("> ")
            else
                term.setTextColor(colors.lightGray)
                term.write("  ")
            end

            if isDir then
                term.write("[" .. entries[idx] .. "]")
            else
                term.write(entries[idx])
            end
        end
    end

    term.setTextColor(colors.white)
    term.setCursorPos(1, H)
    term.write("Enter-open  D-delete  N-new folder  Q-quit")
end

local function confirmDelete(name)
    clear()
    term.write("Delete '" .. name .. "'? (y/n)")
    while true do
        local _, key = os.pullEvent("key")
        if key == keys.y then return true end
        if key == keys.n then return false end
    end
end

local function newFolder()
    clear()
    term.write("New folder name:")
    term.setCursorPos(1, 3)
    write("> ")
    local name = read()
    if name and name ~= "" then
        local ok, err = pcall(fs.makeDir, fs.combine(currentPath, name))
        if not ok then
            printError("Failed to create folder: " .. tostring(err))
            sleep(1.5)
        end
    end
end

local function main()
    local selected = 1

    while true do
        local entries = getEntries(currentPath)
        if selected > #entries then selected = #entries end
        if selected < 1 then selected = 1 end

        draw(entries, selected)

        local _, key = os.pullEvent("key")

        if key == keys.up then
            selected = selected - 1
            if selected < 1 then selected = #entries end
        elseif key == keys.down then
            selected = selected + 1
            if selected > #entries then selected = 1 end
        elseif key == keys.enter then
            local name = entries[selected]
            if name == ".." then
                currentPath = fs.getDir(currentPath)
                if currentPath == "" then currentPath = "/" end
                selected = 1
            else
                local entryPath = fs.combine(currentPath, name)
                if fs.isDir(entryPath) then
                    currentPath = entryPath
                    selected = 1
                else
                    shell.run("edit", entryPath)
                end
            end
        elseif key == keys.d then
            local name = entries[selected]
            if name and name ~= ".." then
                if confirmDelete(name) then
                    local entryPath = fs.combine(currentPath, name)
                    local ok, err = pcall(fs.delete, entryPath)
                    if not ok then
                        printError("Failed to delete: " .. tostring(err))
                        sleep(1.5)
                    end
                    selected = 1
                end
            end
        elseif key == keys.n then
            newFolder()
        elseif key == keys.q then
            break
        end
    end

    clear()
end

main()