--4-Digits, Seven-Segments display driver.
--[[
Required Lua Libraries (Use luarocks to install them):
- luasocket (For sleep function)
- periphery (For GPIO access)
]]

local socket = require("socket") --Require luasocket, for it's sleep function.
local periphery = require('periphery') --Require periphery, which gives access to GPIO related things.

local GPIO = periphery.GPIO --The GPIO api, given a shorter name.

print("Using GPIO:",GPIO.version) --Display the used versions of the GPIO library.

--A function to wrap socket sleep function, giving it a shorter name, and making it easier to patch for other sleep functions.
local function sleep(seconds)
  socket.sleep(seconds)
end

--[[GPIO Pins configuration table, uses CPU pins numbering.
The first 7 values (A,B,C,D,E,F) are the 7 segments.
The 8th one is the dot pin.
The remaining 4 pins are the digit pins.]]

--A, B C, D, E F, G, DT, 1 2 3 4
local pins = {2, 3,4, 17, 27,22, 10, 9, 11,5,6,13}

--[[SevSeg digits font table:
{A,B,C,D,E,F,G}

#-----##-----#-----#-----#-----#-----#-----#-----#-----#-----#-----##-----#-----#-----#-----#-----#-----#
| AAA || @@@ |     | @@@ | @@@ |     | @@@ | @@@ | @@@ | @@@ | @@@ || @@@ |     |     |     | @@@ | @@@ |
|F   B||@   @|    @|    @|    @|@   @|@    |@    |    @|@   @|@   @||@   @|@    |     |    @|@    |@    |
|F   B||@   @|    @|    @|    @|@   @|@    |@    |    @|@   @|@   @||@   @|@    |     |    @|@    |@    |
| GGG ||     |     | @@@ | @@@ | @@@ | @@@ | @@@ |     | @@@ | @@@ || @@@ | @@@ | @@@ | @@@ | @@@ | @@@ |
|E   C||@   @|    @|@    |    @|    @|    @|@   @|    @|@   @|    @||@   @|@   @|@    |@   @|@    |@    |
|E   C||@   @|    @|@    |    @|    @|    @|@   @|    @|@   @|    @||@   @|@   @|@    |@   @|@    |@    |
| DDD || @@@ |     | @@@ | @@@ |     | @@@ | @@@ |     | @@@ | @@@ ||     | @@@ | @@@ | @@@ | @@@ |     |
#-----##-----#-----#-----#-----#-----#-----#-----#-----#-----#-----##-----#-----#-----#-----#-----#-----#

]]

local sv_font = {
  -- A     B     C     D     E     F     G
  {true ,true ,true ,true ,true ,true ,false}, --0
  {false,true ,true ,false,false,false,false}, --1
  {true ,true ,false,true ,true ,false,true }, --2
  {true ,true ,true ,true ,false,false,true }, --3
  {false,true ,true ,false,false,true ,true }, --4
  {true ,false,true ,true ,false,true ,true }, --5
  {true ,false,true ,true ,true ,true ,true }, --6
  {true ,true ,true ,false,false,false,false}, --7
  {true ,true ,true ,true ,true ,true ,true }, --8
  {true ,true ,true ,true ,false,true ,true }, --9
  {true ,true ,true ,false,true ,true ,true }, --A (10)
  {false,false,true ,true ,true ,true ,true }, --b (11)
  {false,false,false,true ,true ,false,true }, --C (12)
  {false,true ,true ,true ,true ,false,true }, --d (13)
  {true ,false,false,true ,true ,true ,true }, --E (14)
  {true ,false,false,false,true ,true ,true }, --F (15)
  -- A     B     C     D     E     F     G
}

--Draw a digit
--[[
Arguments:
- num (number/nil): A number between 0 and 15 [hex digit] to display.
- digitID (number/nil): A number between 1 and 4 (Depending on the pins table), which digit to turn on.
- dot (boolean/nil): True to turn on the digit dot, False to turn off the digit dot.
]]
local function display(num,digitID,dot)
  local num = math.floor(num or 0) --The number to display, defaults to 0, and the floating point is ignored/removed.
  local digitID = math.floor(digitID or 1) --Which digit to display defaults to 1, and the floating point is ignored/removed.
  
  num = num + 1 --Offset the number by 1, because lua tables are 1-based, so the number 0 would be at index 1
  
  --Iterate of the sev-segmets
  for i=1,7 do
    pins[i]:write(not sv_font[num][i]) --Set each segment accourding to the sv_font.
  end
  
  pins[8]:write(not dot) --Set the dot led.
  
  --Disable all the digits and enable the provided in the arguments.
  for i=9,#pins do
    pins[i]:write((i-8) == digitID)
  end
end

local DigitTime = 1/120 --The time to show each digit for, our eyes sees 60 frames per second, so we go for double (in case if we miss some), 120.

--Display a hex number
--[[
Arguments:
- num (number/string/nil): The number to display, accepts hex numbers as string, and normal numbers are treated as dec numbers, defaults to 0.
- timelength (number/nil): How long to show the number for in seconds (blocks the program flow), defaults to 1 second, floating points allowed.
- digits (number/nil): How many digits to display at the screen, defaults to the num length.
]]
local function displayDigits(num,timelength,digits)
  local num = type(num) == "number" and math.floor(num) or num --Remove the floating points if it was a number.
  num = tostring(num or 0):reverse() --Convert it to a string, and reverse it (reverse the order of characters).
  local timer = timelength or 1 --A timer to track how long the number has been displayed.
  local digits = math.floor(digits or #num) --The number of digits to display.
  
  --As long as the timer is still positive display the number.
  while timer > 0 do
    --Iterate over the digits
    for dig=1,digits do
      local char = num:sub(dig,dig) --Get the digit character of each one
      if char == "" then char == "0" end --If the digits were more than the number itself, then default to 0.
      display(tonumber(char,16) or 0, digits-dig+1, false) --Convert it into a number (hex digit to dec number) and display it.
      sleep(DigitTime) --Sleep for the digit time
    end
    timer = timer - DigitTime*digits --Remove the total sleeps from the timer
  end
end

--Initalize the pins
print("Initializing the pins...")
for i=1,#pins do
  --Create the GPIO objects, and set them as output,
  --The first 8 pins are initialized as high, and the rest as low
  pins[i] = GPIO(pins[i],i < 9 and "high" or "low")
end

for n=0,99 do
  print("DISPLAY", n)
  displayDigits(n,1,4)
end

--Close the GPIO Pins
print("Closing the pins")
for i=1,#pins do
  pins[i].direction = "in" --Set all the pins as input (that's the default).
  pins[i]:close() --Close them (They actually act as files).
end
