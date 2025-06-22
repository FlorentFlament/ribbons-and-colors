import math
from PIL import Image

N = 11 # Number of characters
M = 10 # Number of steps between characters
CHAR_HEIGHT = 8
CIRCLE_RADIUS = 52

IM_WIDTH = 120
IM_HEIGHT = 120
IM_DEPTH = 1 # 1 per pixel
BUF_SIZE = IM_WIDTH * IM_HEIGHT * IM_DEPTH

PALETTE = [
    0, 0, 0,
    255, 0, 0,
    0, 255, 0,
    0, 0, 255,
    255, 255, 0,
    0, 255, 255,
    255, 0, 255,
    255, 128, 0,
    0, 255, 128,
    255, 0, 128,
    128, 255, 0,
    0, 128, 255,
    128, 0, 255,
    255, 64, 0,
    0, 255, 64,
    255, 0, 64,
    64, 255, 0,
    0, 64, 255,
    64, 0, 255,
    196, 128, 0,
    0, 196, 128,
    196, 0, 128,
    128, 196, 0,
    0, 128, 196,
    128, 0, 196,
]

def position(alpha):
    """
    Given an angle alpha, compute the position of the N characters.
    returns a tuple of (x,y) coordinates after doing some checks.
    """
    x = tuple(CIRCLE_RADIUS*math.cos((k/N + alpha/(N*M)) *2*math.pi) for k in range(0, N))
    y = tuple(CIRCLE_RADIUS*math.sin((k/N + alpha/(N*M)) *2*math.pi) for k in range(0, N))

    dx = tuple(abs(a-b) for a,b in zip(x, x[1:]+(x[0],)))
    dy = tuple(abs(a-b) for a,b in zip(y, y[1:]+(y[0],)))
    mxy = tuple(max(x,y) for x,y in zip(dx,dy))
    # Ensure characters never overlap
    assert min(mxy) >= (CHAR_HEIGHT-1)

    # Check chunks of 5 characters in y
    # And ensure they are spaced enough - so that we never have 3 sprites aligned
    c = (y[i:i+3] for i in range(0, N-3))
    dc = tuple(max(a) - min(a) for a in c)
    print(alpha, min(dc))
    assert min(dc) >= CHAR_HEIGHT+1

    return zip(x,y)

def main():
    for p in range(0, M):
        # Ensure our asserts are checked against
        position(p)

    buf = [0]*BUF_SIZE
    cal = int((IM_WIDTH-CIRCLE_RADIUS*2-CHAR_HEIGHT) / 2 + CIRCLE_RADIUS)
    for c,(x,y) in enumerate((int(x),int(y)) for x,y in position(7)):
        for i in range(x+cal, x+cal+CHAR_HEIGHT):
            for j in range(y+cal, y+cal+CHAR_HEIGHT):
                buf[IM_WIDTH*IM_DEPTH*j + i*IM_DEPTH] = c+1

    im = Image.frombytes('P', (IM_WIDTH, IM_HEIGHT), bytes(buf))
    im.putpalette(PALETTE)
    im.show()

main()
