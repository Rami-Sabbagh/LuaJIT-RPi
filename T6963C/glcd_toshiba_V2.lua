--HD44780 LCD Driver

local bits = require("bit") --Require bitwise operations library
local band,bor,lshift,rshift = bit.band, bit.bor, bit.lshift, bit.rshift --Make some of them available as local as a shortcut and for speed reasons.

local socket = require("socket") --Require the LuaSocket library because it has a sleep function.
local periphery = require('periphery') --Require the periphery library which provides the GPIO library.

local GPIO = periphery.GPIO --Make a shortcut to the GPIO module

print("Using GPIO:",GPIO.version) --Print the GPIO version

--Sleep function shortcut, and to make porting easier.
local function sleep(seconds)
  socket.sleep(seconds)
end

--WR RD C/D RST DB0 1 2 3 4 5 6 7
local pins = {4,17, 27,22, 10,9,11,5, 6,13,19,26}

--Initalize the pins
print("Initializing the pins...")
for i=1,#pins do
  pins[i] = GPIO(pins[i], i < 5 and "high" or "low") --Set the first pins to high, and the rest (data bus) to low.
end

local WR, RD, CD, RST = unpack(pins) --Give the first 4 pins names

local DB = {} --Data Bus
for i=1,8 do DB[i] = pins[4+i] end --Copy from pins

local DB_WRITE = true --Is it in write mode ? (It's initialized as write)

--Set the databus pins to write mode
local function setWrite()
  if DB_WRITE then return end --It's already in write mode.
  
  for i=1,8 do
    DB[i].direction = "out"
  end
  
  DB_WRITE = true
end

--Set the databus pins to read mode
local function setRead()
  if not DB_WRITE then return end --It's already in read mode.
  
  for i=1,8 do
    DB[i].direction = "in"
  end
  
  DB_WRITE = false
end

--Read byte from the databus
local function readDataBus(cd)
  
  --Ensure that the DB pins are in read mode
  setRead()
  
  --Tell that we are reading
  RD:write(false)
  
  --Tell that we are NOT writing
  WR:write(true)
  
  --Data read (cd = false), Status read (cd = true)
  CD:write(cd or false)
  
  sleep(0.00015) --Sleep for 150 ns
  
  --Read the data bus
  local states, bits, bitStr = {}, 0, ""
  for i=8,1,-1 do
    local b = DB[i]:read()
        
    states[i] = b
    bits = bor(lshift(bits,1), b and 1 or 0)
    bitStr = bitStr..(b and "1" or "0")
  end
  
  --Return the data
  return bits, states, bitStr
  
end

--Print to the console the current status of the display
local function logStatus()
  --Read the STA bits
  local _, sta, str = readDataBus(true)
  
  print("----- STATUS READ -----")
  print("Check command execution capability", sta[1])
  print("Check data read/write capability", sta[2])
  print("Check Auto mode data read capability", sta[3])
  print("Check Auto mode data write capability", sta[4])
  print("Check controller operation capability", sta[6])
  print("Error flag. Used for Screen Peek and Screen copy commands", sta[7] and "Error" or "No error")
  print("Check the blink condition", sta[8] and "Normal Display" or "Display Off")
  print("------- "..str.." ------")
end

local function checkStatus()
  
  --Ensure that the DB pins are in read mode
  setRead()
  
  --Tell that we are NOT writing
  WR:write(true)
  
  --Loop until the status flags are on
  while true do
    sleep(0.00015)
    
    --Chip enable
    RD:write(false)
    CD:write(true)
    
    sleep(0.00015)
    
    local STA0 = DB[1]:read()
    local STA1 = DB[2]:read()
    
    --Chip disable
    RD:write(true)
    CD:write(false)
    
    if STA0 and STA1 then
      print("* Status ready")
      break
    end
    
    print("Status fail",STA0,STA1)
    
    sleep(0.5)
  end
end

local function writeDataBus(bits,cd)
  
  --Ensure that the DB pins are in write mode
  setWrite()
  
  --Tell that we are NOT reading
  RD:write(true)
  
  --Tell that we are writing
  WR:write(false)
  
  --Data write (cd = false), Command write (cd = true)
  CD:write(cd or false)
  
  --Send the actual data
  for i=1,8 do
    DB[i]:write(band(bits,1) > 0) --Write the bit
    bits = rshift(bits,1) --Shift right
  end
  
  checkStatus()
  
  setWrite() --Set write after status check
  
  --Clear Data bus
  for i=1,8 do DB[i]:write(false) end
end

--Reset the display
local function resetDisplay()
  RST:write(false)
  
  sleep(0.1)
  
  RST:write(true)
  
  sleep(0.1)
  
  print("Waiting for the screen to initialize")
  
  checkStatus()
end

local function sendCommand(binary, arg1, arg2)
  if arg1 then writeDataBus(arg1, true) end
  if arg2 then writeDataBus(arg2, true) end
  writeDataBus(tonumber(binary, 2), true)
end

print("--RESET DISPLAY")
resetDisplay()
logStatus()
io.read()

print("\n---Press enter to stop")
io.read()

--Close the GPIO Pins
print("Closing the pins")
for i=1,#pins do
  pins[i].direction = "in" --Set all pins to read
  pins[i]:close()
end

