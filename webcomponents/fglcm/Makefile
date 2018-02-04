.SUFFIXES: .per .42f .4gl .42m .msg .img 


%.42f: %.per 
	fglform -M $<

%.42m: %.4gl 
	fglcomp -M $*

%.42r: %.42m
	fgllink -o $@ $*.42m $(QAUTILS) $$FGLDIR/lib/libfgl4js.42x

MODS=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))
FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))
PROGS=$(patsubst %.42m,%.42r,$(MODS))

all:: $(MODS) $(FORMS) $(PROGS)

run: all
	BROWSER="/Users/leo/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" fglrun miniws fglcm.html

clean:
	rm -f *.42?
