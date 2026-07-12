-- MoldOS App: minesweeper
-- Mouse-controlled minesweeper. Left click = reveal, right click = flag.

local W, H = term.getSize()
H = H - 1

local GRID_W = math.min(W, 25)
local GRID_H = math.min(H - 1, 12)
local MINE_COUNT = math.floor(GRID_W * GRID_H * 0.15)

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local grid, revealed, flagged, gameOver, won

local function inBounds(x, y)
    return x >= 1 and x <= GRID_W and y >= 1 and y <= GRID_H
end

local function countNeighborMines(x, y)
    local count = 0
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local nx, ny = x + dx, y + dy
                if inBounds(nx, ny) and grid[nx][ny] then
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function setupGrid(safeX, safeY)
    grid = {}
    for x = 1, GRID_W do
        grid[x] = {}
        for y = 1, GRID_H do
            grid[x][y] = false
        end
    end

    local placed = 0
    while placed < MINE_COUNT do
        local x = math.random(1, GRID_W)
        local y = math.random(1, GRID_H)
        if not grid[x][y] and not (math.abs(x - safeX) <= 1 and math.abs(y - safeY) <= 1) then
            grid[x][y] = true
            placed = placed + 1
        end
    end
end

local function resetState()
    revealed = {}
    flagged = {}
    for x = 1, GRID_W do
        revealed[x] = {}
        flagged[x] = {}
        for y = 1, GRID_H do
            revealed[x][y] = false
            flagged[x][y] = false
        end
    end
    gameOver = false
    won = false
end

local function floodReveal(x, y)
    if not inBounds(x, y) or revealed[x][y] or flagged[x][y] then return end
    revealed[x][y] = true
    if grid[x][y] then return end

    if countNeighborMines(x, y) == 0 then
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    floodReveal(x + dx, y + dy)
                end
            end
        end
    end
end

local function checkWin()
    for x = 1, GRID_W do
        for y = 1, GRID_H do
            if not grid[x][y] and not revealed[x][y] then
                return false
            end
        end
    end
    return true
end

local numberColors = {
    [1] = colors.blue, [2] = colors.green, [3] = colors.red,
    [4] = colors.purple, [5] = colors.orange, [6] = colors.cyan,
    [7] = colors.gray, [8] = colors.lightGray,
}

local function draw()
    clear()
    for x = 1, GRID_W do
        for y = 1, GRID_H do
            term.setCursorPos(x, y)
            if revealed[x][y] then
                if grid[x][y] then
                    term.setTextColor(colors.red)
                    term.write("*")
                else
                    local n = countNeighborMines(x, y)
                    if n == 0 then
                        term.setBackgroundColor(colors.gray)
                        term.write(" ")
                        term.setBackgroundColor(colors.black)
                    else
                        term.setTextColor(numberColors[n] or colors.white)
                        term.write(tostring(n))
                    end
                end
            elseif flagged[x][y] then
                term.setTextColor(colors.yellow)
                term.write("F")
            else
                term.setTextColor(colors.lightGray)
                term.write(".")
            end
            term.setTextColor(colors.white)
        end
    end

    term.setCursorPos(1, GRID_H + 1)
    term.write("Left-click: reveal   Right-click: flag")
end

local function main()
    math.randomseed(os.epoch("utc"))
    resetState()
    local firstClick = true

    while not gameOver do
        draw()
        local event, button, cx, cy = os.pullEvent("mouse_click")

        if inBounds(cx, cy) then
            if firstClick then
                setupGrid(cx, cy)
                firstClick = false
            end

            if button == 1 then
                if not flagged[cx][cy] then
                    if grid[cx][cy] then
                        revealed[cx][cy] = true
                        gameOver = true
                        won = false
                    else
                        floodReveal(cx, cy)
                        if checkWin() then
                            gameOver = true
                            won = true
                        end
                    end
                end
            elseif button == 2 then
                if not revealed[cx][cy] then
                    flagged[cx][cy] = not flagged[cx][cy]
                end
            end
        end
    end

    draw()
    term.setCursorPos(1, GRID_H + 1)
    if won then
        term.setTextColor(colors.lime)
        term.write("You win! Click anywhere to exit...")
    else
        term.setTextColor(colors.red)
        term.write("Boom! Click anywhere to exit...")
    end
    term.setTextColor(colors.white)
    os.pullEvent("mouse_click")
    clear()
end

main()