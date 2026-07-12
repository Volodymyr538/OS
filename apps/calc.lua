-- MoldOS App: calc
-- On-screen mouse-clickable calculator

local W, H = term.getSize()

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local expression = ""
local result = nil

local buttons = {
    { "7", "8", "9", "/" },
    { "4", "5", "6", "*" },
    { "1", "2", "3", "-" },
    { "0", ".", "C", "+" },
    { "(", ")", "<-", "=" },
    { "Quit" },
}

local function evaluate()
    if expression == "" then return end
    local fn, err = load("return " .. expression)
    if fn then
        local ok, res = pcall(fn)
        if ok then
            result = tostring(res)
        else
            result = "Error"
        end
    else
        result = "Error"
    end
end

local function draw()
    clear()
    term.write("=== MoldOS Calculator ===")
    term.setCursorPos(1, 2)
    term.write(string.rep("-", W))

    term.setCursorPos(2, 4)
    term.write("Expr: " .. expression)
    term.setCursorPos(2, 5)
    term.write("  =   " .. (result or ""))

    local startY = 7
    local btnWidth = 6
    local positions = {}

    for row, line in ipairs(buttons) do
        local y = startY + row - 1
        local x = 2
        for _, label in ipairs(line) do
            term.setCursorPos(x, y)
            term.write("[" .. label .. "]")
            table.insert(positions, {
                x1 = x, x2 = x + #label + 1, y = y, label = label
            })
            x = x + btnWidth
        end
    end

    return positions
end

local function handleButton(label)
    if label == "C" then
        expression = ""
        result = nil
    elseif label == "<-" then
        expression = expression:sub(1, -2)
    elseif label == "=" then
        evaluate()
    elseif label == "Quit" then
        return true
    else
        expression = expression .. label
        result = nil
    end
    return false
end

local function main()
    while true do
        local positions = draw()
        local _, _, cx, cy = os.pullEvent("mouse_click")

        for _, btn in ipairs(positions) do
            if cy == btn.y and cx >= btn.x1 and cx <= btn.x2 then
                local shouldQuit = handleButton(btn.label)
                if shouldQuit then
                    clear()
                    return
                end
                break
            end
        end
    end
end

main()