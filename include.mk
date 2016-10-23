CASK_BIN ?= cask
EMACS_BIN ?= emacs
LEAN_BIN ?= lean
ORGS  := $(wildcard [0-9A][0-9]_*.org)
HTMLS := $(ORGS:.org=.html)
TEXS  := $(ORGS:.org=.tex)
PDFS  := $(ORGS:.org=.pdf)
NAV_DATA := js/nav_data.js

CASK_EMACS := cd $(MKLEANBOOK_PATH) && $(CASK_BIN) exec $(EMACS_BIN)

BIBFILES ?= lean.bib

all: htmls book.pdf

htmls: $(HTMLS) copy-html-assets $(NAV_DATA)

book.org: $(ORGS)
	$(MKLEANBOOK_PATH)/merge_chapters.sh >$@ $+

%.tmphtml.org: %.org $(MKLEANBOOK_PATH)/header/html.org $(MKLEANBOOK_PATH)/footer/bib.html.org
	cat $(MKLEANBOOK_PATH)/header/html.org $< > $@
	(grep "\\\\cite{" $< && cat footer/bib.html.org >> $@) || true

.PRECIOUS: %.html
%.html: %.tmphtml.org $(MKLEANBOOK_PATH)/.cask $(MKLEANBOOK_PATH)/elisp/org-html-export.el $(BIBFILES)
	(cd $(MKLEANBOOK_PATH) && $(CASK_BIN) exec $(EMACS_BIN) \
	  --no-site-file --no-site-lisp -q --batch \
	  -l elisp/org-html-export.el \
	  --visit $(PWD)/$< \
	  -f org-html-export-to-html) && \
	mv $*.tmphtml.html $@

%.tmptex.org: %.org $(MKLEANBOOK_PATH)/header/latex.org $(MKLEANBOOK_PATH)/footer/latex.org
	cat $(MKLEANBOOK_PATH)/header/latex.org $< $(MKLEANBOOK_PATH)/footer/latex.org >$@

.PRECIOUS: %.tex
%.tex: %.tmptex.org $(MKLEANBOOK_PATH)/.cask $(MKLEANBOOK_PATH)/elisp/org-pdf-export.el
	(cd $(MKLEANBOOK_PATH) && $(CASK_BIN) exec $(EMACS_BIN) \
	  --no-site-file --no-site-lisp -q --batch \
	  -l elisp/org-pdf-export.el \
	  --visit $(PWD)/$< \
	  -f org-latex-export-to-latex) && \
	mv $*.tmptex.tex $@

%.pdf: %.tex pygments-main gitHeadInfo.gin
	TEXINPUTS="$(MKLEANBOOK_PATH)/:$(TEXINPUTS)" latexmk --xelatex --shell-escape $<

$(MKLEANBOOK_PATH)/.cask:
	$(MAKE) -C $(MKLEANBOOK_PATH) .cask

clean:
	rm -rf $(HTMLS) \
	       ${PDFS} \
	       ${TEXS} \
	       *.acn *.aux *.glo *.idx *.ist *.log *.out *.toc *.fdb_latexmk *.fls *.ilg *.ind \
	       *.out.pyg *.pyg tutorial.* \
	       [0-9][0-9]*.lean \
	       _minted-*

dist-clean:
	make clean
	rm -rf .cask watchman pygments-main

install-cask:
	curl -fsSkL https://raw.github.com/cask/cask/master/go | python

pygments-main: install-pygments

install-pygments:
	if [ ! -d pygments-main ] ; then hg clone https://bitbucket.org/leanprover/pygments-main && cd pygments-main && python setup.py build; fi

gitHeadInfo.gin:
	git log -1 --date=short \
	--pretty=format:"\usepackage[shash={%h},lhash={%H},authname={%an},authemail={%ae},authsdate={%ad},authidate={%ai},authudate={%at},commname={%an},commemail={%ae},commsdate={%ad},commidate={%ai},commudate={%at},refnames={%d}]{gitsetinfo}" HEAD >$@

test:
	for ORG in $(ORGS); do $(MKLEANBOOK_PATH)/test.sh $(LEAN_BIN) $$ORG || exit 1; done
test_js:
	for ORG in $(ORGS); do $(MKLEANBOOK_PATH)/test_js.sh $$ORG || exit 1; done

$(NAV_DATA): copy-html-assets
	echo "var lean_nav_data = [" > $(NAV_DATA)
	for i in $(HTMLS); do echo $$i; done | sed 's/\(.*\)/"\1",/' >> $(NAV_DATA)
	echo "];" >> $(NAV_DATA)

copy-html-assets:
	cp -ra $(MKLEANBOOK_PATH)/{css,fonts,images,js,index.html,juicy-ace-editor.html} ./

.PHONY: all copy-html-assets clean install-cask pygments-main

.DELETE_ON_ERROR: