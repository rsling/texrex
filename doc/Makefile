LX = pdflatex
PP = ps2pdf
PX = pdflatex
BX = bibtex
DP = dvips
AR = evince

TEXFLAGS =
SOURCEDIR = ./
FILEN = texrex-neuedimensionen_manual

all:
	-$(LX) $(TEXFLAGS) $(FILEN)
	-$(BX) $(FILEN)
	-$(LX) $(TEXFLAGS) $(FILEN)
	-$(LX) $(TEXFLAGS) $(FILEN)

view:
	-$(AR) $(FILEN).pdf &

clean:
	-@$(RM) *.pdf
	-@$(RM) *~
	-@$(RM) *.aux
	-@$(RM) *.log
	-@$(RM) *.out
	-@$(RM) *.bbl
	-@$(RM) *.blg
	-@$(RM) *.toc
	-@$(RM) latexSuiteTemp*
	-@$(RM) *.dvi
	-@$(RM) *.ps
	-@$(RM) *.swp
	-@$(RM) *.lof
	-@$(RM) *.lot
	-@$(RM) *.idx
	-@$(RM) *.ilg
	-@$(RM) *.ind
	-@$(RM) *.nav
	-@$(RM) *.snm
	-@$(RM) *.thm

quick:
	-$(LX) $(TEXFLAGS) $(FILEN)

cleanall:
	-@$(RM) *~
	-@$(RM) *.aux
	-@$(RM) *.log
	-@$(RM) *.out
	-@$(RM) *.bbl
	-@$(RM) *.blg
	-@$(RM) *.toc
	-@$(RM) latexSuiteTemp*
	-@$(RM) *.dvi
	-@$(RM) *.ps
	-@$(RM) *.pdf
	-@$(RM) *.swp
	-@$(RM) *.lof
	-@$(RM) *.lot
	-@$(RM) *.idx
	-@$(RM) *.ilg
	-@$(RM) *.ind
	-@$(RM) *.nav
	-@$(RM) *.snm
