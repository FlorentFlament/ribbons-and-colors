#!/usr/bin/env python3
import itertools
from sys import argv
from PIL import Image

from asmlib import lst2asm
from imglib import *

# Mapping from the 'atari_vcs_pal' palette to Stella colors
#palette = [
#    0x00, 0x02, 0x04, 0x06, 0x08, 0x0a, 0x0c, 0x0e, # grey
#    0x40, 0x42, 0x44, 0x46, 0x48, 0x4a, 0x4c, 0x4e, # brown
#    0x20, 0x22, 0x24, 0x26, 0x28, 0x2a, 0x2c, 0x2e, # yellow
#    0x30, 0x32, 0x34, 0x36, 0x38, 0x3a, 0x3c, 0x3e, # light green
#    0x50, 0x52, 0x54, 0x56, 0x58, 0x5a, 0x5c, 0x5e, # dark green
#    0x70, 0x72, 0x74, 0x76, 0x78, 0x7a, 0x7c, 0x7e, # cyan
#    0x9e, 0x9c, 0x9a, 0x98, 0x96, 0x94, 0x92, 0xbe, # light blue 1
#    0x90, 0xbc, 0xba, 0xb8, 0xb6, 0xb4, 0xb2, 0xb0, # light blue 2
#    0xd0, 0xd2, 0xd4, 0xd6, 0xd8, 0xda, 0xdc, 0xde, # dark blue
#    0xce, 0xca, 0xcc, 0xc8, 0xc6, 0xc4, 0xc2, 0xc0, # purple
#    0xae, 0xac, 0xaa, 0xa8, 0xa6, 0xa4, 0xa2, 0xa0, # magenta
#    0x8e, 0x8c, 0x8a, 0x88, 0x86, 0x84, 0x82, 0x80, # pink
#    0x6e, 0x6c, 0x6a, 0x68, 0x66, 0x64, 0x62, 0x60, # red
#]

# summer 2025 exocet colors
palette = [
    0x0a, 0xda, 0x8a, 0x9c, 0x0e, 0xca, 0xaa, 0xba, 0x9c
]

class HiResPF:
    # A couple of static methods and fields

    __line_pf = [
        lambda l: lbool2int(itertools.chain(reversed(l[0:4]), [False]*4)),
        lambda l: lbool2int(l[4:12]),
        lambda l: lbool2int(reversed(l[12:20])),
        lambda l: lbool2int(itertools.chain(reversed(l[20:24]), [False]*4)),
        lambda l: lbool2int(l[24:32]),
        lambda l: lbool2int(reversed(l[32:40])),
    ]

    def __init__(self, image):
        # No transparency there
        # self.__transparency = image.info.get('transparency', None)
        self.__width, self.__height = image.size

        # Slicing image data into a "list" of lines to allow iterating over it multiple times
        raw = list(image.getdata())
        lines = [raw[x:x+self.__width] for x in range(0, len(raw), self.__width)]

        # First line color is background color (doesn't really matter)
        self.__bg_colors = [l[0] for l in lines]
        
        # Building lists to allow more freedom on their usage
        self.__data = [[x != bgcol for x in l] for bgcol,l in zip(self.__bg_colors, lines)]
        self.__pf_colors = [next((x for x in l if x != bgcol), None) for bgcol,l in zip(self.__bg_colors, lines)]

    def get_pf(self, n):
        return (HiResPF.__line_pf[n](list(l)) for l in reversed(self.__data))

    def get_all_pfs(self):
        return (self.get_pf(n) for n in range(6))

    def get_half_pfs(self):
        return (self.get_pf(n) for n in range(3))

    # Arbitrarily replace None with color 0
    # This shouldn't be an issue since the color is unused
    def get_pf_cols(self):
        return (palette[x] if x else 0 for x in reversed(self.__pf_colors))

    def get_bg_cols(self):
        return (palette[x] if x else 0 for x in reversed(self.__bg_colors))

def print_block(lst, name):
    print("{}:".format(name))
    print(lst2asm(lst))

def main():
    fname = argv[1] # filename
    sname = argv[2] # symbol name

    hrpf = HiResPF(Image.open(fname))
    for i,pf in enumerate(hrpf.get_all_pfs()):
        print_block(pf, "{}_pf{}".format(sname, i))
    print_block(hrpf.get_pf_cols(), "{}_pfcols".format(sname))
    print_block(hrpf.get_bg_cols(), "{}_bgcols".format(sname))

main()
