-- MoldOS App: snake
-- Classic snake game. Controlled with arrow keys (exception to mouse-only rule).

local W, H = term.getSize()
H = H - 1

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local snake, dir, food, score, gameOver

local function resetGame()
    snake = {
        { x = math.floor(W / 2), y = math.floor(H / 2) },
        { x = math.floor(W / 2) - 1, y = math.floor(H / 2) },
        { x = math.floor(W / 2) - 2, y = math.floor(H / 2) },
    }
    dir = { x = 1, y = 0 }
    score = 0
    gameOver = false
end

local function randomFood()
    while true do
        local fx = math.random(1, W)
        local fy = math.random(1, H)
        local collides = false
        for _, seg in ipairs(snake) do
            if seg.x == fx and seg.y == fy then
                collides = true
                break
            end
        end
        if not collides then
            return { x = fx, y = fy }
        end
    end
end

local function draw()
    clear()
    for _, seg in ipairs(snake) do
        term.setCursorPos(seg.x, seg.y)
        term.setBackgroundColor(colors.green)
        term.write(" ")
    end
    term.setBackgroundColor(colors.black)

    term.setCursorPos(food.x, food.y)
    term.setBackgroundColor(colors.red)
    term.write(" ")
    term.setBackgroundColor(colors.black)

    term.setCursorPos(1, H + 1)
    term.write("Score: " .. score .. "   Arrow keys to move, Q to quit")
end

local function step()
    local head = snake[1]
    local newHead = { x = head.x + dir.x, y = head.y + dir.y }

    if newHead.x < 1 then newHead.x = W end
    if newHead.x > W then newHead.x = 1 end
    if newHead.y < 1 then newHead.y = H end
    if newHead.y > H then newHead.y = 1 end

    for _, seg in ipairs(snake) do
        if seg.x == newHead.x and seg.y == newHead.y then
            gameOver = true
            return
        end
    end

    table.insert(snake, 1, newHead)

    if newHead.x == food.x and newHead.y == food.y then
        score = score + 1
        food = randomFood()
    else
        table.remove(snake)
    end
end

local function inputLoop()
    while not gameOver do
        local _, key = os.pullEvent("key")
        if key == keys.up and dir.y == 0 then
            dir = { x = 0, y = -1 }
        elseif key == keys.down and dir.y == 0 then
            dir = { x = 0, y = 1 }
        elseif key == keys.left and dir.x == 0 then
            dir = { x = -1, y = 0 }
        elseif key == keys.right and dir.x == 0 then
            dir = { x = 1, y = 0 }
        elseif key == keys.q then
            gameOver = true
        end
    end
end

local function gameLoop()
    while not gameOver do
        step()
        draw()
        sleep(0.2)
    end
end

local function main()
    math.randomseed(os.epoch("utc"))
    resetGame()
    food = randomFood()

    parallel.waitForAny(gameLoop, inputLoop)

    clear()
    local msg = "Game Over! Final score: " .. score
    term.setCursorPos(math.floor((W - #msg) / 2) + 1, math.floor(H / 2))
    term.write(msg)
    term.setCursorPos(1, H + 1)
    term.write("Click anywhere to exit...")
    os.pullEvent("mouse_click")
    clear()
end

main()