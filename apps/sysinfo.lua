-- MoldOS App: sysinfo
-- Показывает информацию о компьютере

term.setTextColor(colors.white)
print("=== Информация о системе ===")
print("")
print("Версия CraftOS: " .. _HOST)
print("ID компьютера: " .. os.getComputerID())
local label = os.getComputerLabel()
print("Имя компьютера: " .. (label or "(не задано)"))
print("")

local total = fs.getCapacity("/")
local free = fs.getFreeSpace("/")
if total and free then
    print("Диск: " .. math.floor(free / 1024) .. " KB свободно из " .. math.floor(total / 1024) .. " KB")
end

print("")
print("Нажми любую клавишу для выхода...")
os.pullEvent("key")
