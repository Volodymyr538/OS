-- MoldOS App: sysinfo
-- Shows information about the computer

term.setTextColor(colors.white)
print("=== System Information ===")
print("")
print("CraftOS version: " .. _HOST)
print("Computer ID: " .. os.getComputerID())
local label = os.getComputerLabel()
print("Computer label: " .. (label or "(not set)"))
print("")

local total = fs.getCapacity("/")
local free = fs.getFreeSpace("/")
if total and free then
    print("Disk: " .. math.floor(free / 1024) .. " KB free of " .. math.floor(total / 1024) .. " KB")
end

print("")
print("Click anywhere to exit...")
os.pullEvent("mouse_click")