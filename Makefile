INCDIRS=inc src generated
DFLAGS=$(patsubst %,-I%,$(INCDIRS)) -f3 -d

# asm files
SRC=$(wildcard src/*.asm)

all: main.bin

generated:
	mkdir generated

generated/text_data.asm: generated text/text0.txt text/text1.txt
	echo "text_data0:" > $@
	cat text/text0.txt | sed 's/\. /;   /g' | sed "s/[,']/;/g" | sed 's/^/\tdc.b "/' | sed 's/\.$$$\/;   "/' >> $@
	echo "\tdc.b 0" >> $@
	echo "text_data1:" >> $@
	cat text/text1.txt | sed 's/\. /;   /g' | sed "s/[,']/;/g" | sed 's/^/\tdc.b "/' | sed 's/\.$$$\/;   "/' >> $@
	echo "\tdc.b 0" >> $@

generated/gfx_data.asm:
	tools/png2hrpf.py gfx/shadow2025_vcspal_40x26.png header > $@

main.bin: src/main.asm generated/text_data.asm $(SRC)
	dasm $< -o$@ -l$(patsubst %.bin,%,$@).lst -s$(patsubst %.bin,%,$@).sym $(DFLAGS)

run: main.bin
	stella $<

clean:
	rm -f \
	main.bin main.lst main.sym generated/*
	rmdir generated
