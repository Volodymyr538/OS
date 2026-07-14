-- MoldOS App: textedit
-- Simple text editor with printing support via a connected Printer peripheral

local W, H = term.getSize()
local DOCS_DIR = "/os/data/documents"
local PAGE_WIDTH = 25
local PAGE_HEIGHT = 21

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

if not fs.exists(DOCS_DIR) then
    fs.makeDir(DOCS_DIR)
end

local function getDocList()
    local files = fs.list(DOCS_DIR)
    table.sort(files)
    return files
end

local function readDoc(name)
    local f = fs.open(fs.combine(DOCS_DIR, name), "r")
    local content = f.readAll()
    f.close()
    return content
end

local function writeDoc(name, content)
    local f = fs.open(fs.combine(DOCS_DIR, name), "w")
    f.write(content)
    f.close()
end

local function wrapForPrinting(text)
    local outLines = {}
    for rawLine in (text .. "\n"):gmatch("(.-)\n") do
        if rawLine == "" then
            table.insert(outLines, "")
        else
            local line = ""
            for word in rawLine:gmatch("%S+") do
                if line == "" then
                    line = word
                elseif #line + 1 + #word <= PAGE_WIDTH then
                    line = line .. " " .. word
                else
                    table.insert(outLines, line)
                    line = word
                end
                while #line > PAGE_WIDTH do
                    table.insert(outLines, line:sub(1, PAGE_WIDTH))
                    line = line:sub(PAGE_WIDTH + 1)
                end
            end
            table.insert(outLines, line)
        end
    end
    return outLines
end

local function printDocument(title, content)
    local printer = peripheral.find("printer")
    if not printer then
        clear()
        print("No printer attached to this computer.")
        print("")
        print("Click anywhere to go back...")
        os.pullEvent("mouse_click")
        return
    end

    if printer.getInkLevel and printer.getInkLevel() <= 0 then
        clear()
        print("The printer is out of ink.")
        print("")
        print("Click anywhere to go back...")
        os.pullEvent("mouse_click")
        return
    end
    if printer.getPaperLevel and printer.getPaperLevel() <= 0 then
        clear()
        print("The printer is out of paper.")
        print("")
        print("Click anywhere to go back...")
        os.pullEvent("mouse_click")
        return
    end

    local lines = wrapForPrinting(content)

    local pages = {}
    local currentPage = {}
    for _, line in ipairs(lines) do
        table.insert(currentPage, line)
        if #currentPage >= PAGE_HEIGHT then
            table.insert(pages, currentPage)
            currentPage = {}
        end
    end
    if #currentPage > 0 then
        table.insert(pages, currentPage)
    end
    if #pages == 0 then
        table.insert(pages, { "" })
    end

    clear()
    print("Printing '" .. title .. "'...")
    print(#pages .. " page(s) to print.")
    print("")

    for pageNum, pageLines in ipairs(pages) do
        write("Page " .. pageNum .. "/" .. #pages .. "... ")

        if not printer.newPage() then
            print("FAILED")
            print("Could not start a new page. Check ink and paper.")
            sleep(1.5)
            break
        end

        printer.setPageTitle(title)
        for i, line in ipairs(pageLines) do
            printer.setCursorPos(1, i)
            printer.write(line)
        end

        if not printer.endPage() then
            print("FAILED")
            print("Could not finish the page.")
            sleep(1.5)
            break
        end

        print("OK")
    end

    print("")
    print("Done. Click anywhere to continue...")
    os.pullEvent("mouse_click")
end

local function editDocument(name)
    local content = name and readDoc(name) or ""
    local title = name or ""

    if not name then
        clear()
        print("Document title:")
        write("> ")
        title = read()
        if not title or title == "" then return end
    end

    clear()
    print("Editing: " .. title)
    print("Type your text. Finish with a line containing only '.'")
    print("(Existing content shown below if any)")
    print("")
    if content ~= "" then
        print(content)
        print("--- end of existing content, continue typing or '.' to keep as-is ---")
    end

    local lines = {}
    while true do
        local line = read()
        if line == "." then break end
        table.insert(lines, line)
    end

    local newContent = table.concat(lines, "\n")
    if newContent ~= "" then
        if content ~= "" and #lines > 0 then
            content = content .. "\n" .. newContent
        elseif newContent ~= "" then
            content = newContent
        end
    end

    writeDoc(title, content)

    clear()
    print("Saved '" .. title .. "'.")
    term.setCursorPos(1, H)
    term.write("[ Print ]          [ Back ]")

    while true do
        local _, _, cx, cy = os.pullEvent("mouse_click")
        if cy == H then
            if cx >= 1 and cx <= 9 then
                printDocument(title, content)
                return
            elseif cx >= 20 and cx <= 27 then
                return
            end
        end
    end
end

local function viewDocument(name)
    local content = readDoc(name)
    clear()
    term.write("=== " .. name .. " ===")
    term.setCursorPos(1, 2)
    term.write(string.rep("-", W))

    local y = 3
    for line in (content .. "\n"):gmatch("(.-)\n") do
        term.setCursorPos(1, y)
        term.write(line)
        y = y + 1
        if y > H - 2 then break end
    end

    term.setCursorPos(1, H)
    term.write("[ Edit ][ Print ][ Delete ][ Back ]")

    while true do
        local _, _, cx, cy = os.pullEvent("mouse_click")
        if cy == H then
            if cx >= 1 and cx <= 6 then
                editDocument(name)
                return
            elseif cx >= 7 and cx <= 14 then
                printDocument(name, content)
            elseif cx >= 15 and cx <= 24 then
                clear()
                term.write("Delete '" .. name .. "'? [ Yes ]  [ No ]")
                while true do
                    local _, _, cx2, cy2 = os.pullEvent("mouse_click")
                    if cy2 == 1 then
                        local line1 = "Delete '" .. name .. "'? "
                        local yesX = #line1 + 1
                        if cx2 >= yesX and cx2 <= yesX + 7 then
                            fs.delete(fs.combine(DOCS_DIR, name))
                            return
                        elseif cx2 >= yesX + 9 and cx2 <= yesX + 15 then
                            break
                        end
                    end
                end
            elseif cx >= 25 and cx <= 32 then
                return
            end
        end
    end
end

local function mainMenu()
    while true do
        clear()
        term.write("=== MoldOS Text Editor ===")
        term.setCursorPos(1, 2)
        term.write(string.rep("-", W))

        local docs = getDocList()
        local rows = {}
        local y = 4

        if #docs == 0 then
            term.setCursorPos(4, y)
            term.setTextColor(colors.lightGray)
            term.write("(no documents yet)")
            term.setTextColor(colors.white)
            y = y + 1
        else
            for _, name in ipairs(docs) do
                term.setCursorPos(4, y)
                term.write("[ " .. name .. " ]")
                table.insert(rows, { y = y, name = name })
                y = y + 1
            end
        end

        term.setCursorPos(1, H)
        term.write("[ New Document ]          [ Quit ]")

        local _, _, cx, cy = os.pullEvent("mouse_click")
        if cy == H then
            if cx >= 1 and cx <= 16 then
                editDocument(nil)
            elseif cx >= 27 and cx <= 33 then
                break
            end
        else
            for _, row in ipairs(rows) do
                if cy == row.y then
                    viewDocument(row.name)
                    break
                end
            end
        end
    end
    clear()
end

mainMenu()