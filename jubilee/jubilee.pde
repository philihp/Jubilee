#include "LPD8806.h"
#include "SPI.h"
#include <avr/sleep.h>

int dataPin = 5;
int clockPin = 6;
int powerPin = 4;
int upModePin = 3;
int downModePin = 2;

int upButtonState = HIGH;
int upButtonCycles = 0;
int downButtonState = HIGH;
int downButtonCycles = 0;

int CYCLES_DEBOUNCE = 2; //check the button for X ticks to see if it is bouncing
int MAX_COLORS = 7;
int MAX_MODES = 4;

unsigned long tick = 0;

int mode = 1;
int color = 1;

uint16_t i, j;
uint32_t c;

// Set the first variable to the NUMBER of pixels. 32 = 32 pixels in a row
// The LED strips are 32 LEDs per meter but you can extend/cut the strip
LPD8806 strip = LPD8806(32*3, dataPin, clockPin);

void ISR_Wake() {
  detachInterrupt(0);
  detachInterrupt(1);
}

void triggerSleep() {
  for(int i=0; i < strip.numPixels(); i++) {
      strip.setPixelColor(i, strip.Color(0,0,0));
  }
  strip.show();

  attachInterrupt(0,ISR_Wake,LOW); //pin 2
  attachInterrupt(1,ISR_Wake,LOW); //pin 3
  
  set_sleep_mode(SLEEP_MODE_PWR_DOWN);
  sleep_enable();
  sleep_mode();
  //sleeping, until rudely interrupted
  sleep_disable();
}

void triggerModeUp() {
  if(++mode >= MAX_MODES) mode = 0;
}

void triggerModeDown() {
  if(++color >= MAX_COLORS) color = 0;
}


void handleButtons() {
  if(digitalRead(powerPin) == LOW) {
    triggerSleep();
  }
  // software debounce
  if(digitalRead(upModePin) != upButtonState) {
    upButtonCycles++;
    if(upButtonCycles > CYCLES_DEBOUNCE) {
      upButtonCycles = 0;
      upButtonState = digitalRead(upModePin);
      if(upButtonState == LOW) {
        triggerModeUp();
      }
    }
  }
  // software debounce
  if(digitalRead(downModePin) != downButtonState) {
    downButtonCycles++;
    if(downButtonCycles > CYCLES_DEBOUNCE) {
      downButtonCycles = 0;
      downButtonState = digitalRead(downModePin);
      if(downButtonState == LOW) {
        triggerModeDown();
      }
    }
  }
}

void handleStrip() {
  switch(mode) {
    case 0: //solid
      c = GetColor(color);
      for(i=0; i<strip.numPixels(); i++) {
        strip.setPixelColor(i, c);
      }
      break;
    case 1:
      c = GetColor((tick%3+color)% MAX_COLORS);
      for(i=0; i<strip.numPixels(); i++) {
        strip.setPixelColor(i, c);
      }
      break;
    case 2:
      if(tick % 15 == 0) {
        c = GetColor(color);
        for(i=0; i<strip.numPixels(); i++) {
          strip.setPixelColor(i, c);
        }      
        strip.show();
        c = strip.Color(0,0,0);
        for(i=0; i<strip.numPixels(); i++) {
          strip.setPixelColor(i, c);
        }
      }
      break;
    case 3:
      //fuckin' rainbows
      j = tick % 384;
      for (i=0; i < strip.numPixels(); i++) {
        strip.setPixelColor(i, Wheel(((i * 384 / strip.numPixels() * mode) + j) % 384));
      }
      break;
  }  
  strip.show();
}


void setup() {
  // Start up the LED strip
  strip.begin();

  pinMode(powerPin, INPUT);    // declare pushbutton as input
  pinMode(upModePin, INPUT);    // declare pushbutton as input
  pinMode(downModePin, INPUT);    // declare pushbutton as input
  
  triggerSleep();
}


void loop() {
  tick++;
  handleStrip();
  handleButtons();
}

// fill the dots one after the other with said color
// good for testing purposes
void colorWipe(uint32_t c, uint8_t wait) {
  int i;

  for (i=0; i < strip.numPixels(); i++) {
      strip.setPixelColor(i, c);
      strip.show();
      delay(wait);
  }
}

// Chase a dot down the strip
// good for testing purposes
void colorChase(uint32_t c, uint8_t wait) {
  int i;

  for (i=0; i < strip.numPixels(); i++) {
    strip.setPixelColor(i, 0);  // turn all pixels off
  }

  for (i=0; i < strip.numPixels(); i++) {
      strip.setPixelColor(i, c); // set one pixel
      strip.show();              // refresh strip display
      delay(wait);               // hold image for a moment
      strip.setPixelColor(i, 0); // erase pixel (but don't refresh yet)
  }
  strip.show(); // for last erased pixel
}

// An "ordered dither" fills every pixel in a sequence that looks
// sparkly and almost random, but actually follows a specific order.
void dither(uint32_t c, uint8_t wait) {

  // Determine highest bit needed to represent pixel index
  int hiBit = 0;
  int n = strip.numPixels() - 1;
  for(int bit=1; bit < 0x8000; bit <<= 1) {
    if(n & bit) hiBit = bit;
  }

  int bit, reverse;
  for(int i=0; i<(hiBit << 1); i++) {
    // Reverse the bits in i to create ordered dither:
    reverse = 0;
    for(bit=1; bit <= hiBit; bit <<= 1) {
      reverse <<= 1;
      if(i & bit) reverse |= 1;
    }
    strip.setPixelColor(reverse, c);
    strip.show();
    delay(wait);
  }
  delay(250); // Hold image for 1/4 sec
}

// "Larson scanner" = Cylon/KITT bouncing light effect
void scanner(uint8_t r, uint8_t g, uint8_t b, uint8_t wait) {
  int i, j, pos, dir;

  pos = 0;
  dir = 1;

  for(i=0; i<((strip.numPixels()-1) * 8); i++) {
    // Draw 5 pixels centered on pos.  setPixelColor() will clip
    // any pixels off the ends of the strip, no worries there.
    // we'll make the colors dimmer at the edges for a nice pulse
    // look
    strip.setPixelColor(pos - 2, strip.Color(r/4, g/4, b/4));
    strip.setPixelColor(pos - 1, strip.Color(r/2, g/2, b/2));
    strip.setPixelColor(pos, strip.Color(r, g, b));
    strip.setPixelColor(pos + 1, strip.Color(r/2, g/2, b/2));
    strip.setPixelColor(pos + 2, strip.Color(r/4, g/4, b/4));

    strip.show();
    delay(wait);
    // If we wanted to be sneaky we could erase just the tail end
    // pixel, but it's much easier just to erase the whole thing
    // and draw a new one next time.
    for(j=-2; j<= 2; j++) 
        strip.setPixelColor(pos+j, strip.Color(0,0,0));
    // Bounce off ends of strip
    pos += dir;
    if(pos < 0) {
      pos = 1;
      dir = -dir;
    } else if(pos >= strip.numPixels()) {
      pos = strip.numPixels() - 2;
      dir = -dir;
    }
  }
}

// Sine wave effect
#define PI 3.14159265
void wave(uint32_t c, int cycles, uint8_t wait) {
  float y;
  byte  r, g, b, r2, g2, b2;

  // Need to decompose color into its r, g, b elements
  g = (c >> 16) & 0x7f;
  r = (c >>  8) & 0x7f;
  b =  c        & 0x7f; 

  for(int x=0; x<(strip.numPixels()*5); x++)
  {
    for(int i=0; i<strip.numPixels(); i++) {
      y = sin(PI * (float)cycles * (float)(x + i) / (float)strip.numPixels());
      if(y >= 0.0) {
        // Peaks of sine wave are white
        y  = 1.0 - y; // Translate Y to 0.0 (top) to 1.0 (center)
        r2 = 127 - (byte)((float)(127 - r) * y);
        g2 = 127 - (byte)((float)(127 - g) * y);
        b2 = 127 - (byte)((float)(127 - b) * y);
      } else {
        // Troughs of sine wave are black
        y += 1.0; // Translate Y to 0.0 (bottom) to 1.0 (center)
        r2 = (byte)((float)r * y);
        g2 = (byte)((float)g * y);
        b2 = (byte)((float)b * y);
      }
      strip.setPixelColor(i, r2, g2, b2);
    }
    strip.show();
    delay(wait);
  }
}

/* Helper functions */

//Input a value 0 to 384 to get a color value.
//The colours are a transition r - g - b - back to r

uint32_t Wheel(uint16_t WheelPos)
{
  byte r, g, b;
  switch(WheelPos / 128)
  {
    case 0:
      r = 127 - WheelPos % 128; // red down
      g = WheelPos % 128;       // green up
      b = 0;                    // blue off
      break;
    case 1:
      g = 127 - WheelPos % 128; // green down
      b = WheelPos % 128;       // blue up
      r = 0;                    // red off
      break;
    case 2:
      b = 127 - WheelPos % 128; // blue down
      r = WheelPos % 128;       // red up
      g = 0;                    // green off
      break;
  }
  return(strip.Color(r,g,b));
}


uint32_t GetColor(int c)
{
  switch(c) {
    case 0:
      return strip.Color(127,0,0);
    case 1:
      return strip.Color(0,127,0);
    case 2:
      return strip.Color(0,0,127);
    case 3:
      return strip.Color(127,127,0);
    case 4:
      return strip.Color(0,127,127);
    case 5:
      return strip.Color(127,0,127);
    case 6:
      return strip.Color(127,127,127);
    default:
      return strip.Color(0,0,0);
  }
}
