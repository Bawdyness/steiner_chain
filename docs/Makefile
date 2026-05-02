# Pipeline für Theoriedokumente: LyX -> LaTeX -> Typst.
#
# Voraussetzungen: lyx (>= 2.4), pandoc (>= 3.0), beide im PATH.
# Die App lädt die erzeugten .typ-Dateien zur Laufzeit aus docs/build/
# und rendert sie mit ihrer eingebauten Typst-Engine.
#
# Aufrufe:
#   make            # alle Theoriedokumente konvertieren
#   make steiner    # nur Steiner
#   make clean      # build/ wegräumen

LYX     ?= lyx
PANDOC  ?= pandoc
SOURCES := $(wildcard *.lyx)
TARGETS := $(patsubst %.lyx,build/%.typ,$(SOURCES))

.PHONY: all clean
all: $(TARGETS)

build:
	mkdir -p build

build/%.tex: %.lyx | build
	$(LYX) --export-to latex $@ $<

build/%.typ: build/%.tex
	$(PANDOC) -f latex -t typst -o $@ $<
	# Pandoc-Kosmetik: Unicode-Anführung statt ASCII-Doppelkomma,
	# Leerzeichen vor öffnendem Inline-Math (Pandoc lässt es manchmal weg).
	sed -i \
	  -e 's/,,/„/g' \
	  -e 's/\([[:alpha:]]\)„/\1 „/g' \
	  -e 's/\([^[:space:]]\)\$$\([^$$][^$$]*\)\$$/\1 $$\2$$/g' \
	  $@

steiner: build/steiner.typ

clean:
	rm -rf build
