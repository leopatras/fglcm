.SUFFIXES: .per .42f .4gl .42m .msg .img 
FGLCM_EXT_DIR=$(CURDIR)/ext
FGLCM_WEBRUN_DIR=$(CURDIR)/fglwebrun

.msg.iem:
	fglmkmsg $< $@

%.42f: %.per 
	fglform -M $<

%.42m: %.4gl 
	FGLLDPATH=$(FGLCM_EXT_DIR):$(FGLCM_WEBRUN_DIR) fglcomp -r -M -Wall $*

#%.iem: %.msg
#	fglmkmsg $< $@

define run-seq
  fglrun $* -run
endef
FGLCM_WC_DIR=./webcomponents/fglcm
CMDIR=$(FGLCM_WC_DIR)/codemirror

#MODS=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))
FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))

UNAME:=$(shell uname)
#$(warning uname is $(UNAME))
#we build the home grown mini crc32 checker until someone finds *the* standard way to do it on linux
ifeq ($(UNAME),Linux)
  CRC32=./crc32
endif

all:: .submodule $(CRC32) fglcm_main.42m fglcm_webpreview.42m spex.42m $(FORMS)


.submodule:
	git submodule init
	git submodule update
	cd fglwebrun && make clean all && cd --
	touch $@

forcesub: .submodule


fglcm_main.42m: fglcm.42m fglped_md_filedlg.42m fglped_fileutils.42m $(FGLCM_EXT_DIR)/fglcm_ext.42m

$(FGLCM_EXT_DIR)/fglcm_ext.42m: $(FGLCM_EXT_DIR)/fglcm_ext.4gl

$(FGLCM_EXT_DIR)/fglcm_ext.42m:
	$(MAKE) -C $(FGLCM_EXT_DIR)

fglped_md_filedlg.42m: fglped_fileutils.42m

./crc32: crc32.c
	cc -O2 -Wall -o $@ crc32.c

$(CMDIR)/lib/codemirror.js: $(CMDIR) #some trial and error is behind these lines..I hate depending on npm modules as it seems to be permanently broken 
	-git submodule init 
	-git submodule update 
	#npm install -g rollup
	#cp rollup.config.js $(CMDIR)/
	#cd $(CMDIR) && npm install rollup-plugin-buble && rollup -c
	cd $(CMDIR) && npm install && ./node_modules/rollup/bin/rollup -c

$(FGLCM_WC_DIR)/codemirror.js: $(CMDIR)/lib/codemirror.js
	cp $(CMDIR)/lib/codemirror.js $(FGLCM_WC_DIR)/codemirror.js

$(FGLDIR)/demo/demo.sch: 
	$(MAKE) -C $(FGLDIR)/demo demo.sch

cmdemo.42m: $(FGLDIR)/demo/demo.sch $(FGLDIR)/demo/demo_load.42m $(FGLDIR)/demo/demo.42m cmdemo.4gl cmdemo.42f
#	-mv $(FGLDIR)/demo/MobileDemo $(FGLDIR)/demo/MobileDemoXX
#	$(MAKE) -C $(FGLDIR)/demo
#	-mv $(FGLDIR)/demo/MobileDemoXX $(FGLDIR)/demo/MobileDemo
	FGLLDPATH=$(CURDIR):$(FGLDIR)/demo FGLDBPATH=$(FGLDIR)/demo fglcomp -M -Wall cmdemo.4gl

cmdemo.42f: $(FGLDIR)/demo/demo.sch cmdemo.per
	FGLDBPATH=$(FGLDIR)/demo fglform -M -Wall cmdemo.per

runcmdemo: cmdemo.42m cmdemo.42f
	FGLLDPATH=$(CURDIR):$(FGLDIR)/demo FGLDBPATH=$(FGLDIR)/demo fglrun cmdemo

fiddle: all cmdemo.42m cmdemo.42f
	rm -rf home&&mkdir home
	cp main.4gl main.per home/
	cd home && ls && FGLIMAGEPATH=$(CURDIR):$(FGLCM_EXT_DIR):$(FGLDIR)/lib/image2font.txt FGLLDPATH=$(CURDIR):$(FGLCM_EXT_DIR):$(FGLDIR)/demo DBPATH=$(FGLDIR)/demo:$(FGLCM_EXT_DIR) FGLDBPATH=$(FGLDIR)/demo:$(FGLCM_EXT_DIR) FGLFIDDLE=1 FGLCMDIR=$(CURDIR) FGLCMHOME=$(CURDIR)/home fglrun $(CURDIR)/fglcm_main.42m main.4gl

webfiddle: all cmdemo.42m cmdemo.42f
	#rm -rf home&&mkdir home
	#cp main.4gl main.per home/
	FGLIMAGEPATH=$(CURDIR):$(FGLDIR)/lib/image2font.txt FGLLDPATH=$(CURDIR):$(CURDIR)/ext:$(FGLDIR)/demo FGLDBPATH=$(FGLDIR)/demo FGLFIDDLE=1 FGLCMDIR=$(CURDIR) FGLCMHOME=$(CURDIR)/home $(CURDIR)/fglwebrun/fglwebrun $(CURDIR)/fglcm_main main.4gl

demo: all
	./cm test/foo.4gl

clean_prog:
	rm -f *.42? .*.42? ext/*.42* 

clean: clean_prog
	rm -f .submodule ./crc32 $(FGLCM_WC_DIR)/customMode/4gl.js $(FGLCM_WC_DIR)/customMode/per.js
	rm -rf ./home
	cd $(CMDIR) && git clean -fdx && cd -
	make -C ext clean
	make -C webcomponents/fglcm clean


dist: $(CMDIR)/lib/codemirror.js
	cp $(CMDIR)/lib/codemirror.js $(FGLCM_WC_DIR)/codemirror.js

distclean: clean
	rm -f $(CMDIR)/lib/codemirror.js
