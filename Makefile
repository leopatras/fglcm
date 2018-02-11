.SUFFIXES: .per .42f .4gl .42m .msg .img 

.per.42f:
	fglform -M $*

.4gl.42m:
	fglcomp -M -W all $<

.msg.iem:
	fglmkmsg $< $@

%.42f: %.per 
	fglform -M $<

%.42m: %.4gl 
	fglcomp -M $*

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

all:: $(FGLCM_WC_DIR)/customMode/4gl.js $(CMDIR)/lib/codemirror.js $(MODS) $(FORMS)

$(FGLCM_WC_DIR)/customMode/4gl.js:
	./updatekeywords.sh > $@

$(CMDIR)/lib/codemirror.js: #some trial and error is behind these lines..I hate depending on npm modules as it seems to be permanently broken 
	#npm install -g rollup
	#cp rollup.config.js $(CMDIR)/
	#cd $(CMDIR) && npm install rollup-plugin-buble && rollup -c
	cd $(CMDIR) && npm install

demo: all
	fglrun cm test/foo.4gl

clean:
	rm -f *.42?  keywords.js $(FGLCM_WC_DIR)/customMode/4gl.js $(CMDIR)/lib/codemirror.js
	cd $(CMDIR) && git clean -fdx && cd -
	make -C webcomponents/fglcm clean
