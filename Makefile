.SUFFIXES: .per .42f .4gl .42m .msg .img 

.msg.iem:
	fglmkmsg $< $@

%.42f: %.per 
	fglform -M $<

%.42m: %.4gl 
	fglcomp -r -M $*

%.42r: %.42m
	fgllink -o $@ $*.42m $(QAUTILS) $$FGLDIR/lib/libfgl4js.42x

%.iem: %.msg
	fglmkmsg $< $@

define run-seq
  fglrun $* -run
endef

FGLCM_WC_DIR=./webcomponents/fglcm
CMDIR=$(FGLCM_WC_DIR)/codemirror

MODS=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))
FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))

UNAME:=$(shell uname)
$(warning uname is $(UNAME))
#we build the home grown mini crc32 checker until someone finds *the* standard way to do it on linux
ifeq ($(UNAME),Linux)
  CRC32=./crc32
endif

all:: $(CRC32) $(FGLCM_WC_DIR)/customMode/4gl.js $(CMDIR)/lib/codemirror.js $(MODS) $(FORMS)

$(FGLCM_WC_DIR)/customMode/4gl.js:
	./updatekeywords.sh > $@

./crc32: crc32.c
	cc -O2 -Wall -o $@ crc32.c

$(CMDIR)/lib/codemirror.js: $(CMDIR) #some trial and error is behind these lines..I hate depending on npm modules as it seems to be permanently broken 
	-git submodule init 
	-git submodule update 
	#npm install -g rollup
	#cp rollup.config.js $(CMDIR)/
	#cd $(CMDIR) && npm install rollup-plugin-buble && rollup -c
	cd $(CMDIR) && npm install && ./node_modules/rollup/bin/rollup -c

demo: all
	fglrun cm.42m test/foo.4gl

clean_prog:
	rm -f *.42? .*.42?

clean: clean_prog
	rm -f ./crc32 keywords.js $(FGLCM_WC_DIR)/customMode/4gl.js $(CMDIR)/lib/codemirror.js
	cd $(CMDIR) && git clean -fdx && cd -
	make -C webcomponents/fglcm clean
