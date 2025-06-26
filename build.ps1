# Build script for LaTeX document
Write-Host "Building LaTeX document..."
rm main.pdf

# Run pdflatex multiple times
Write-Host "Running pdflatex (first pass)..."
pdflatex -interaction=nonstopmode -synctex=1 main.tex

# Run makeglossaries
Write-Host "Running makeglossaries..."
makeglossaries main

# Run biber
Write-Host "Running biber..."
biber main

rm main.pdf

Write-Host "Running pdflatex (second pass)..."
pdflatex -interaction=nonstopmode -synctex=1 main.tex

# Write-Host "Running pdflatex (final pass)..."
# pdflatex -interaction=nonstopmode -synctex=1 main.tex

Write-Host "Build complete!" 