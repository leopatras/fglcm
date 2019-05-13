.SUFFIXES: .per .42f .4gl .42m
export FGLLDPATH=..:../ext

%.42f: %.per 
	fglform -M $<

%.42m: %.4gl 
	FGLLDPATH=..:../ext fglcomp -M -r $*


MODS=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))
FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))

all:: ../fglcm.42m ../fglcm_main.42m $(MODS) $(FORMS)

../fglcm.42m:
	make -C ..

../fglcm_main.42m:
	make -C ..

test: simple.42m
	cd .. && pwd && FGLLDPATH=ext fglrun test/simple


clean:
	rm -f *.42?
