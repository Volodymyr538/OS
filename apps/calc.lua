-- MoldOS App: calc
-- Simple calculator. Supports + - * / ( )
-- Type 'exit' to quit

print("=== MoldOS Calculator ===")
print("Enter an expression (e.g. 2 + 2 * 3)")
print("Type 'exit' to quit")
print("")

while true do
    write("calc> ")
    local input = read()

    if input == "exit" then
        break
    end

    if input:match("^[%d%s%+%-%*%/%(%)%.]+$") then
        local fn, err = load("return " .. input)
        if fn then
            local ok, result = pcall(fn)
            if ok then
                print("= " .. tostring(result))
            else
                printError("Calculation error")
            end
        else
            printError("Invalid expression")
        end
    else
        printError("Only numbers and + - * / ( ) are allowed")
    end
end