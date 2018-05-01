# LuaJIT-RPi
My own scripts toying with the raspberry pi using LuaJIT.

## Included scripts:
- 4Digit Seven-Segments Display.
- 8x5 LED Matrix.
- HD44780 16x2 Characters LCD Display.
- KS0108B GLCDs, With 128x64 and 192x64 in mind.
- Toshiba T6963C 128x128 GLCD.

## Tip to fix flickering with some scripts:
Use this command to lunch luajit: `sudo chrt -rr 99 luajit "%f"`