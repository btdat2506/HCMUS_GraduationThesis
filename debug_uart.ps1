# Test script to debug UART detection in chapter8.tex
$content = Get-Content 'chapter8.tex' -Raw
$pattern = "UART"

# Test the actual regex pattern from the script
$regexPattern = "(?m)^(?!.*\\(?:caption|chapter|section|subsection|subsubsection|paragraph|subparagraph|title|author)\b)(.*)(\b$pattern\b)(?!\w)(?!\})(.*)$"

$matches = [regex]::Matches($content, $regexPattern)
Write-Host "Found $($matches.Count) matches for UART with section exclusion"

foreach ($match in $matches) {
    $lineStart = $content.LastIndexOf("`n", $match.Index) + 1
    $lineEnd = $content.IndexOf("`n", $match.Index)
    if ($lineEnd -eq -1) { $lineEnd = $content.Length }
    $line = $content.Substring($lineStart, $lineEnd - $lineStart)
    Write-Host "Match: $($line.Trim())"
    
    # Check for additional filtering conditions
    $shouldSkip = $false
    
    # Skip if line contains certain patterns that suggest we shouldn't replace
    # Only skip if the acronym itself is part of these commands, not just if they exist in the line
    if ($line -match "\\(label|newcommand|renewcommand|def|let)\{[^}]*$pattern[^}]*\}") {
        $shouldSkip = $true
        Write-Host "  -> SKIPPED: Acronym is inside special command"
    }
    
    # Skip if the acronym is specifically inside a \ref{} or \cite{} command
    if ($line -match "\\(ref|cite)\{[^}]*$pattern[^}]*\}") {
        $shouldSkip = $true
        Write-Host "  -> SKIPPED: Acronym is inside ref/cite command"
    }
    
    # Check if acronym is inside mathematical expressions
    if ($line -match "\$.*$pattern.*\$" -or $line -match "\\begin\{equation\}|\\end\{equation\}|\\begin\{align\}|\\end\{align\}") {
        $shouldSkip = $true
        Write-Host "  -> SKIPPED: Inside math expression"
    }
    
    # Check if already inside an acronym command
    if ($line -match "\\acr(short|long|full)\{[^}]*$pattern[^}]*\}" -or $line -match "\\gls\{[^}]*$pattern[^}]*\}") {
        $shouldSkip = $true
        Write-Host "  -> SKIPPED: Already in acronym command"
    }
    
    if (-not $shouldSkip) {
        Write-Host "  -> VALID for replacement"
    }
}
