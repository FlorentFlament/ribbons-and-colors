#!/usr/bin/env python
from math import sin, pi
from asmlib import *
AMPLITUDE = 96 # Should be between 1/3 and 2/3 of 144 (/ (* 2 144) 3)
OFFSET = 0

# -0.5 to have rounded value between 0 and AMPLITUDE-1 (ignoring OFFSET)
f = [round( \
            ( (1 + sin(2*pi*x / 256.0)) \
              * AMPLITUDE/2 - 0.5
            ) * 0.999 \
           ) + OFFSET \
     for x in range(256)]

print(lst2asm(f))

