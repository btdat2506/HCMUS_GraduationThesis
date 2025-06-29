@ECHO OFF
REM Build script for LaTeX document

ECHO Building LaTeX document...
IF EXIST main.pdf DEL main.pdf

REM Run pdflatex multiple times
ECHO Running pdflatex (first pass)...
pdflatex -interaction=nonstopmode -synctex=1 main.tex

REM Run makeglossaries
ECHO Running makeglossaries...
makeglossaries main

REM Run biber
ECHO Running biber...
biber main

IF EXIST main.pdf DEL main.pdf

ECHO Running pdflatex (second pass)...
pdflatex -interaction=nonstopmode -synctex=1 main.tex

REM ECHO Running pdflatex (final pass)...
REM pdflatex -interaction=nonstopmode -synctex=1 main.tex

ECHO.
ECHO Build complete!