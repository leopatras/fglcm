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

CM=./webcomponents/fglcm/codemirror

MODS=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))
FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))
PROGS=$(patsubst %.42m,%.42r,$(MODS))

all:: $(CM)/mode/4gl/4gl.js $(CM)/lib/codemirror.js $(MODS) $(FORMS) $(PROGS)

$(CM)/mode/4gl/4gl.js:
	mkdir -p $(CM)/mode/4gl
	./updatekeywords.sh

$(CM)/lib/codemirror.js:
	cp rollup.config.js $(CM)/
	cd $(CM) && rollup -c

clean:
	rm -f *.42?  $(CM)/mode/4gl/4gl.js $(CM)/lib/codemirror.js
	make -C webcomponents/fglcm clean
