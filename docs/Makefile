# Pipeline für Theoriedokumente: LyX -> LaTeX -> Markdown.
#
# Voraussetzungen: lyx (>= 2.4), pandoc (>= 3.0), beide im PATH.
# Output landet in ../assets/theory/, von wo Flutter die .md-Dateien
# als Assets bündelt.
#
# Aufrufe:
#   make            # alle Theoriedokumente konvertieren
#   make steiner    # nur Steiner
#   make clean      # Zwischenstände wegräumen

LYX     ?= lyx
PANDOC  ?= pandoc
ASSETS  := ../assets/theory
SOURCES := $(wildcard *.lyx)
TARGETS := $(patsubst %.lyx,$(ASSETS)/%.md,$(SOURCES))

.PHONY: all clean
all: $(TARGETS)

build $(ASSETS):
	mkdir -p $@

build/%.tex: %.lyx | build
	$(LYX) --export-to latex $@ $<

$(ASSETS)/%.md: build/%.tex | $(ASSETS)
	$(PANDOC) -f latex -t gfm -o $@ $<
	# Pandoc-Kosmetik: Unicode-Anführung statt ASCII-Doppelkomma,
	# Leerzeichen vor öffnendem Inline-Math (Pandoc lässt es manchmal weg).
	sed -i \
	  -e 's/,,/„/g' \
	  -e 's/\([[:alpha:]]\)„/\1 „/g' \
	  -e 's/\([^[:space:]$$]\)\$$\([^$$][^$$]*\)\$$/\1 $$\2$$/g' \
	  $@

steiner: $(ASSETS)/steiner.md

clean:
	rm -rf build
