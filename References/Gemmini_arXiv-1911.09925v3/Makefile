REPORT=main
BODY=body
REFERENCES=ref

LATEX=pdflatex
LATEX2=latex
BIBTEX=bibtex

SRCS=$(wildcard *.tex section-d/*.tex)
REFS=$(wildcard *.bib)
FIGS=$(wildcard figures/*)

all: $(REPORT).pdf 

body: $(BODY).pdf

refs: $(REFERENCES).pdf

$(REPORT).pdf: $(SRCS) $(REFS) $(FIGS) 
	$(LATEX) $(REPORT)
	$(BIBTEX) $(REPORT)
	$(LATEX) $(REPORT)
	$(LATEX) $(REPORT)
	cp $(REPORT).pdf paper.pdf

$(BODY).pdf: $(SRCS) $(FIGS) 
	$(LATEX) $(REPORT)
	mv $(REPORT).pdf $(BODY).pdf

$(REFERENCES).pdf: $(REFERENCES).tex 
	$(LATEX) $(REFERENCES)

clean:
	rm -f *~ *.dvi *.aux *.log *.blg *.bbl *.toc $(REPORT).out $(REPORT).ps $(REPORT).pdf $(REFERENCES).pdf $(BODY).pdf
