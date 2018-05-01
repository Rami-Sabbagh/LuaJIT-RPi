--HD44780 LCD Driver

local bits = require("bit")
local band,bor,lshift,rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local socket = require("socket")
local periphery = require('periphery')

local GPIO = periphery.GPIO

print("Using GPIO:",GPIO.version)

local function sleep(seconds)
  socket.sleep(seconds)
end

--WR RD CE C/D RST DB0 1 2 3 4 5 6 7 FS
local pins = {2,3, 1,17,14, 27,22,15,18, 26,16,13,6, 23}

--Initalize the pins
print("Initializing the pins...")
for i=1,#pins do
  pins[i] = GPIO(pins[i], i < 6 and "high" or "low")
end

local WR, RD, CE, CD, RST = unpack(pins)
local FS = pins[14]

local DB = {} --Data Bus
for i=1,8 do DB[i] = pins[5+i] end --Copy from pins

local DB_WRITE = true

local function setWrite()
  if DB_WRITE then return end
  
  for i=1,8 do
    DB[i].direction = "out"
  end
  
  DB_WRITE = true
end

local function setRead()
  if not DB_WRITE then return end
  
  for i=1,8 do
    DB[i].direction = "in"
  end
  
  DB_WRITE = false
end

local function readDataBus(cd)
  
  --Ensure that the DB pins are in read mode
  setRead()
  
  --Tell that we are reading
  RD:write(false)
  
  --Tell that we are NOT writing
  WR:write(true)
  
  --Data read (cd = false), Status read (cd = true)
  CD:write(cd or false)
  
  --Chip enable
  CE:write(false)
  
  sleep(0.00015) --Sleep for 150 ns
  
  --Read the data bus
  local states, bits, bitStr = {}, 0, ""
  for i=8,1,-1 do
    local b = DB[i]:read()
        
    states[i] = b
    bits = bor(lshift(bits,1), b and 1 or 0)
    bitStr = bitStr..(b and "1" or "0")
  end
  
  --Chip disable
  CE:write(true)
  
  --Return the data
  return bits, states, bitStr
  
end

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
  print("Check the blink condition", sta[8] and "Blink ON" or "Blink OFF")
  print("------- "..str.." ------")
end

local function checkStatus(ignoreSTA1)
  
  --Ensure that the DB pins are in read mode
  setRead()
  
  --Tell that we are reading
  RD:write(false)
  
  --Tell that we are NOT writing
  WR:write(true)
  
  --Data read (cd = false), Status read (cd = true)
  CD:write(true)
  
  --Loop until the status flags are on
  while true do
    sleep(0.00015)
    
    --Chip enable
    CE:write(false)
    
    sleep(0.00015)
    
    local STA0 = DB[1]:read()
    local STA1 = DB[2]:read()
    
    --Chip disable
    CE:write(true)
    
    if STA0 and (STA1 or ignoreSTA1) then
      print("* Status ready")
      break
    end
    
    print("Status fail",STA0,STA1)
    
    sleep(0.5)
  end
end

local function writeDataBus(bits,cd,igSTA1)
  
  checkStatus(igSTA1)
  
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
  
  --Chip enable
  CE:write(false)
  
  sleep(0.001)
  
  --Chip disable
  CE:write(true)
  
  sleep(0.002)
  
  --Clear Data bus
  for i=1,8 do DB[i]:write(false) end
end

local function resetDisplay()
  RST:write(false)
  
  sleep(0.1)
  
  RST:write(true)
  
  sleep(0.1)
  
  print("Waiting for the screen to initialize")
  
  checkStatus(true)
end

local function sendCommand(binary, arg1, arg2, igSTA1)
  igSTA1 = true
  if arg1 then writeDataBus(arg1, true, igSTA1) end
  if arg2 then writeDataBus(arg2, true, igSTA1) end
  writeDataBus(tonumber(binary, 2), true, igSTA1)
end

print("--RESET DISPLAY")
resetDisplay()

print("--Reset auto")
sendCommand(10110010)

print("--Set graphic home address")
sendCommand(01000010,0,0)

print("--Set text home address")
sendCommand(01000000,0x0A,0)

print("--Set graphic area")
sendCommand(01000011,32)

print("--Set text area")
sendCommand(01000001,32)

print("--Set offset")
sendCommand(00100010,tonumber(11111,2),0) --At the memory end

print("--Set merge mode")
sendCommand(10000000) --OR Mode

print("--Set display mode")
sendCommand(10011111)

print("--Send test bytes")
sendCommand(11000000,255)
sendCommand(11000000,255)
sendCommand(11000000,255)
sendCommand(11000000,255)

print("--Status check")
checkStatus(true)

print("\n---Press enter to status check")
io.read()
logStatus()

print("\n---Press enter to stop")
io.read()

--Close the GPIO Pins
print("Closing the pins")
for i=1,#pins do
  pins[i].direction = "in" --Set all pins to read
  pins[i]:close()
end

