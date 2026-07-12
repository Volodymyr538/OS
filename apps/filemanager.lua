-- MoldOS App: filemanager
-- Mouse-controlled file manager

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

local function draw(entries, selectedIdx)
    clear()
    term.write("=== File Manager: " .. currentPath .. " ===")
    term.setCursorPos(1, 2)
    term.write(string.rep("-", W))

    local toolbarY = H
    term.setCursorPos(1, toolbarY)
    term.write("[New Folder]  [Delete]  [Quit]")

    local startY = 3
    local maxVisible = H - 4
    local rows = {}

    for i = 1, math.min(#entries, maxVisible) do
        local name = entries[i]
        local entryPath = fs.combine(currentPath, name)
        local isDir = name == ".." or (fs.exists(entryPath) and fs.isDir(entryPath))
        local y = startY + i - 1
        term.setCursorPos(3, y)

        if i == selectedIdx then
            term.setTextColor(colors.yellow)
            term.write("> ")
        else
            term.setTextColor(colors.white)
            term.write("  ")
        end

        if isDir then
            term.write("[" .. name .. "]")
        else
            term.write(name)
        end
        term.setTextColor(colors.white)

        table.insert(rows, { y = y, name = name, isDir = isDir })
    end

    return rows, toolbarY
end

local function confirmDelete(name)
    clear()
    term.write("Delete '" .. name .. "'?")
    term.setCursorPos(1, 3)
    term.write("[ Yes ]      [ No ]")
    while true do
        local _, _, cx, cy = os.pullEvent("mouse_click")
        if cy == 3 then
            if cx >= 1 and cx <= 8 then return true end
            if cx >= 14 and cx <= 20 then return false end
        end
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
    local selected = nil

    while true do
        local entries = getEntries(currentPath)
        local rows, toolbarY = draw(entries, selected)

        local _, _, cx, cy = os.pullEvent("mouse_click")

        if cy == toolbarY then
            if cx >= 1 and cx <= 12 then
                newFolder()
            elseif cx >= 15 and cx <= 22 then
                if selected and entries[selected] and entries[selected] ~= ".." then
                    local name = entries[selected]
                    if confirmDelete(name) then
                        local entryPath = fs.combine(currentPath, name)
                        local ok, err = pcall(fs.delete, entryPath)
                        if not ok then
                            printError("Failed to delete: " .. tostring(err))
                            sleep(1.5)
                        end
                        selected = nil
                    end
                end
            elseif cx >= 25 and cx <= 31 then
                break
            end
        else
            for i, row in ipairs(rows) do
                if cy == row.y then
                    if selected == i then
                        if row.name == ".." then
                            currentPath = fs.getDir(currentPath)
                            if currentPath == "" then currentPath = "/" end
                            selected = nil
                        elseif row.isDir then
                            currentPath = fs.combine(currentPath, row.name)
                            selected = nil
                        else
                            shell.run("edit", fs.combine(currentPath, row.name))
                        end
                    else
                        selected = i
                    end
                    break
                end
            end
        end
    end

    clear()
end

main()