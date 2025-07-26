# PowerShell script to replace full acronym definitions with \acrfull{} commands
# Based on definitions in myacronyms.sty file
# Uses smart filtering algorithm from rep_short.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$AcronymFile = "myacronyms.sty",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExcludeSections = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowDetails = $false
)

# Function to parse acronyms from the .sty file
function Parse-Acronyms {
    param([string]$FilePath)
    
    $acronyms = @{}
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "Acronym file not found: $FilePath"
        return $acronyms
    }
    
    $content = Get-Content $FilePath
    
    foreach ($line in $content) {
        # Match \newacronym{key}{ACRONYM}{Full Definition}
        if ($line -match '\\newacronym\{([^}]+)\}\{([^}]+)\}\{([^}]+)\}') {
            $key = $matches[1]
            $acronym = $matches[2]
            $fullDef = $matches[3]
            
            # Create patterns to match:
            # 1. "Full Definition (ACRONYM)" 
            # 2. "ACRONYM (Full Definition)"
            $pattern1 = [regex]::Escape("$fullDef ($acronym)")
            $pattern2 = [regex]::Escape("$acronym ($fullDef)")
            
            $acronyms[$pattern1] = @{
                Key = $key
                Acronym = $acronym
                FullDef = $fullDef
                Original = "$fullDef ($acronym)"
                Type = "FullFirst"
            }
            
            $acronyms[$pattern2] = @{
                Key = $key
                Acronym = $acronym
                FullDef = $fullDef
                Original = "$acronym ($fullDef)"
                Type = "AcronymFirst"
            }
            
            Write-Host "Added patterns for '$key':" -ForegroundColor Green
            Write-Host "  - $fullDef ($acronym)" -ForegroundColor Cyan
            Write-Host "  - $acronym ($fullDef)" -ForegroundColor Cyan
        }
    }
    
    return $acronyms
}

# Function to process a single file
function Process-File {
    param(
        [string]$FilePath,
        [hashtable]$Acronyms,
        [bool]$DryRun,
        [bool]$ExcludeSections
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return
    }
    
    $content = Get-Content $FilePath -Raw
    $originalContent = $content
    $replacements = 0
    
    # Sort patterns by length (longest first) to avoid partial replacements
    $sortedPatterns = $Acronyms.Keys | Sort-Object { $_.Length } -Descending
    
    foreach ($pattern in $sortedPatterns) {
        $acronymInfo = $Acronyms[$pattern]
        $key = $acronymInfo.Key
        $replacement = "\acrfull{$key}"
        
        # Create regex pattern with word boundaries and exclusions
        # Note: For full definitions, we don't use word boundaries since they contain spaces and parentheses
        $regexPattern = if ($ExcludeSections) {
            # Exclude lines with LaTeX sectioning commands, captions, already processed acronym commands,
            # URLs, file paths, but allow full definitions that are not already in braces
            "(?m)^(?!.*\\(?:caption|chapter|section|subsection|subsubsection|paragraph|subparagraph|title|author)\b)(.*)($pattern)(?!\})(.*)$"
        } else {
            # Simple pattern that just matches full definitions
            "(?m)(.*)($pattern)(?!\})(.*)$"
        }
        
        # Additional check to avoid replacing definitions that are part of compound constructs or in specific contexts
        $matches = [regex]::Matches($content, $regexPattern)
        
        if ($matches.Count -gt 0 -and $ShowDetails) {
            Write-Host "Found $($matches.Count) raw occurrence(s) of '$($acronymInfo.Original)' in $FilePath" -ForegroundColor Cyan
        }
        
        # Filter out matches that shouldn't be replaced using smart filtering
        $validMatches = @()
        foreach ($match in $matches) {
            # Get the full line for context checking and display
            $lineStart = $content.LastIndexOf("`n", $match.Index) + 1
            $lineEnd = $content.IndexOf("`n", $match.Index)
            if ($lineEnd -eq -1) { $lineEnd = $content.Length }
            $line = $content.Substring($lineStart, $lineEnd - $lineStart)
            
            # Show each match found (only in verbose mode)
            if ($ShowDetails) {
                Write-Host "  Match at position $($match.Groups[2].Index): " -NoNewline -ForegroundColor Gray
                Write-Host "$($line.Trim())" -ForegroundColor Gray
            }
            
            # Smart filtering: Only skip if the full definition is in specific problematic contexts
            $shouldSkip = $false
            $skipReason = ""
            
            # 1. Skip if the definition is already inside an acronym command
            # Check if this specific match position is inside an acronym command
            $acronymCommands = [regex]::Matches($line, '\\acr(short|long|full)\{[^}]*\}|\\gls\{[^}]*\}')
            foreach ($cmdMatch in $acronymCommands) {
                $cmdStart = $cmdMatch.Index
                $cmdEnd = $cmdMatch.Index + $cmdMatch.Length
                
                # Find all occurrences of the pattern in the line to check the right one
                $allMatches = [regex]::Matches($line, [regex]::Escape($pattern), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                foreach ($patternMatch in $allMatches) {
                    $patternStart = $patternMatch.Index
                    $patternEnd = $patternMatch.Index + $patternMatch.Length
                    
                    # Check if this specific pattern occurrence is inside this command
                    if ($patternStart -ge $cmdStart -and $patternEnd -le $cmdEnd) {
                        # Check if this is the same match we're currently processing
                        $lineStartPos = $content.LastIndexOf("`n", $match.Index) + 1
                        $matchPosInLine = $match.Groups[2].Index - $lineStartPos
                        
                        if ($patternStart -eq $matchPosInLine) {
                            $shouldSkip = $true
                            $skipReason = "Already in acronym command: $($cmdMatch.Value)"
                            break
                        }
                    }
                }
                if ($shouldSkip) { break }
            }
            
            # 2. Skip if the definition is inside a LaTeX command parameter (between braces)
            if (-not $shouldSkip) {
                $braceMatches = [regex]::Matches($line, '\{[^}]*\}')
                foreach ($braceMatch in $braceMatches) {
                    $braceStart = $braceMatch.Index
                    $braceEnd = $braceMatch.Index + $braceMatch.Length
                    
                    # Calculate the position of our current match within the line
                    $lineStartPos = $content.LastIndexOf("`n", $match.Index) + 1
                    $matchPosInLine = $match.Groups[2].Index - $lineStartPos
                    $matchEndInLine = $matchPosInLine + $match.Groups[2].Length
                    
                    # Check if this specific match is inside these braces
                    if ($matchPosInLine -ge $braceStart -and $matchEndInLine -le $braceEnd) {
                        # Check if this is a command we should avoid
                        $beforeBrace = $line.Substring(0, $braceStart)
                        if ($beforeBrace -match '\\(label|ref|cite|includegraphics|input|include|newcommand|renewcommand|def|let|href|url)$') {
                            $shouldSkip = $true
                            $skipReason = "Inside command braces: $($braceMatch.Value)"
                            break
                        }
                    }
                }
            }
            
            # 3. Skip if definition is inside mathematical expressions
            if (-not $shouldSkip) {
                $mathMatches = [regex]::Matches($line, '\$[^$]*\$')
                foreach ($mathMatch in $mathMatches) {
                    $mathStart = $mathMatch.Index
                    $mathEnd = $mathMatch.Index + $mathMatch.Length
                    
                    # Calculate the position of our current match within the line
                    $lineStartPos = $content.LastIndexOf("`n", $match.Index) + 1
                    $matchPosInLine = $match.Groups[2].Index - $lineStartPos
                    $matchEndInLine = $matchPosInLine + $match.Groups[2].Length
                    
                    # Check if this specific match is inside this math expression
                    if ($matchPosInLine -ge $mathStart -and $matchEndInLine -le $mathEnd) {
                        $shouldSkip = $true
                        $skipReason = "Inside math expression: $($mathMatch.Value)"
                        break
                    }
                }
            }
            
            # 4. Skip if we're in a math environment
            if (-not $shouldSkip -and ($line -match "\\begin\{(equation|align|gather|multline|flalign)\}" -or $line -match "\\end\{(equation|align|gather|multline|flalign)\}")) {
                $shouldSkip = $true
                $skipReason = "In math environment"
            }
            
            # 5. Skip if inside citations or references
            if (-not $shouldSkip) {
                $citeMatches = [regex]::Matches($line, '\\cite\{[^}]*\}|\\ref\{[^}]*\}|\\label\{[^}]*\}')
                foreach ($citeMatch in $citeMatches) {
                    $citeStart = $citeMatch.Index
                    $citeEnd = $citeMatch.Index + $citeMatch.Length
                    
                    # Calculate the position of our current match within the line
                    $lineStartPos = $content.LastIndexOf("`n", $match.Index) + 1
                    $matchPosInLine = $match.Groups[2].Index - $lineStartPos
                    $matchEndInLine = $matchPosInLine + $match.Groups[2].Length
                    
                    # Check if this specific match is inside this citation
                    if ($matchPosInLine -ge $citeStart -and $matchEndInLine -le $citeEnd) {
                        $shouldSkip = $true
                        $skipReason = "Inside citation/reference: $($citeMatch.Value)"
                        break
                    }
                }
            }
            
            if ($shouldSkip) {
                if ($ShowDetails) {
                    Write-Host "    -> SKIPPED: $skipReason" -ForegroundColor Red
                }
            } else {
                if ($ShowDetails) {
                    # Show focused context for valid replacements
                    $lineStartPos = $content.LastIndexOf("`n", $match.Index) + 1
                    $matchPosInLine = $match.Groups[2].Index - $lineStartPos
                    $matchLength = $match.Groups[2].Length
                    
                    # Extract context around the match (about 10 words before and after)
                    $contextStart = [Math]::Max(0, $matchPosInLine - 50)
                    $contextEnd = [Math]::Min($line.Length, $matchPosInLine + $matchLength + 50)
                    $contextBefore = $line.Substring($contextStart, $matchPosInLine - $contextStart).Trim()
                    $contextAfter = $line.Substring($matchPosInLine + $matchLength, $contextEnd - ($matchPosInLine + $matchLength)).Trim()
                    
                    # Limit context to reasonable length and add ellipsis if needed
                    if ($contextBefore.Length > 40) {
                        $words = $contextBefore -split '\s+'
                        $contextBefore = "..." + ($words[-4..-1] -join ' ')
                    }
                    if ($contextAfter.Length > 40) {
                        $words = $contextAfter -split '\s+'
                        $contextAfter = ($words[0..3] -join ' ') + "..."
                    }
                    
                    $originalDef = $match.Groups[2].Value
                    $replacementCmd = "\acrfull{$key}"
                    
                    Write-Host "    -> VALID for replacement: " -NoNewline -ForegroundColor Green
                    Write-Host "$contextBefore " -NoNewline -ForegroundColor Gray
                    Write-Host "$originalDef" -NoNewline -ForegroundColor Yellow
                    Write-Host " -> " -NoNewline -ForegroundColor Green
                    Write-Host "$replacementCmd" -NoNewline -ForegroundColor Cyan
                    Write-Host " $contextAfter" -ForegroundColor Gray
                }
                $validMatches += $match
            }
        }
        
        if ($validMatches.Count -gt 0) {
            if ($ShowDetails) {
                Write-Host "  Summary: $($validMatches.Count) valid occurrence(s) will be replaced" -ForegroundColor Yellow
            } else {
                Write-Host "Found $($validMatches.Count) valid occurrence(s) of '$($acronymInfo.Original)' in $FilePath" -ForegroundColor Yellow
            }
            
            # Replace the matched patterns (process in reverse order to maintain indices)
            $validMatches = $validMatches | Sort-Object { $_.Index } -Descending
            
            foreach ($match in $validMatches) {
                $beforeText = $match.Groups[1].Value
                $afterText = $match.Groups[3].Value
                $fullMatch = $match.Groups[0].Value
                $newLine = $beforeText + $replacement + $afterText
                
                $content = $content.Remove($match.Index, $match.Length)
                $content = $content.Insert($match.Index, $newLine)
                
                $replacements++
                
                # Show what was replaced
                if ($ShowDetails) {
                    Write-Host "    Replaced: $($match.Groups[2].Value) -> $replacement" -ForegroundColor Green
                } else {
                    Write-Host "  Replaced: $($match.Groups[2].Value) -> $replacement" -ForegroundColor Gray
                }
            }
        } elseif ($matches.Count -gt 0 -and $ShowDetails) {
            Write-Host "  Summary: All $($matches.Count) occurrence(s) were skipped" -ForegroundColor DarkYellow
        }
    }
    
    if ($replacements -gt 0) {
        if ($DryRun) {
            Write-Host "DRY RUN: Would make $replacements replacement(s) in $FilePath" -ForegroundColor Magenta
        } else {
            Set-Content $FilePath -Value $content -NoNewline
            Write-Host "Made $replacements replacement(s) in $FilePath" -ForegroundColor Green
        }
    } else {
        Write-Host "No replacements made in $FilePath" -ForegroundColor DarkGray
    }
    
    Write-Host "--- End processing $(Split-Path $FilePath -Leaf) ---" -ForegroundColor DarkCyan
}

# Main execution
Write-Host "=== Acronym Full Definition Replacement Script ===" -ForegroundColor Cyan
Write-Host "Acronym file: $AcronymFile" -ForegroundColor White
Write-Host "Exclude sections: $ExcludeSections" -ForegroundColor White
Write-Host "Show details: $ShowDetails" -ForegroundColor White
Write-Host "Dry run: $DryRun" -ForegroundColor White
Write-Host ""

# Parse acronyms
Write-Host "Parsing acronyms from $AcronymFile..." -ForegroundColor Yellow
$acronyms = Parse-Acronyms -FilePath $AcronymFile

if ($acronyms.Count -eq 0) {
    Write-Error "No acronyms found in $AcronymFile"
    exit 1
}

Write-Host "Found $($acronyms.Count) acronym definition patterns to replace" -ForegroundColor Green
Write-Host ""

# Find target files - specifically chapter1.tex through chapter9.tex
Write-Host "Finding chapter files..." -ForegroundColor Yellow
$targetFiles = @()
for ($i = 1; $i -le 9; $i++) {
    $chapterFile = "chapter$i.tex"
    if (Test-Path $chapterFile) {
        $targetFiles += Get-Item $chapterFile
        Write-Host "Found: $chapterFile" -ForegroundColor Green
    } else {
        Write-Host "Not found: $chapterFile" -ForegroundColor DarkGray
    }
}

if ($targetFiles.Count -eq 0) {
    Write-Warning "No chapter files found (chapter1.tex to chapter9.tex)"
    exit 0
}

Write-Host "Found $($targetFiles.Count) file(s) to process:" -ForegroundColor Green
foreach ($file in $targetFiles) {
    Write-Host "  - $($file.FullName)" -ForegroundColor Cyan
}
Write-Host ""

# Process each file
foreach ($file in $targetFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Yellow
    Process-File -FilePath $file.FullName -Acronyms $acronyms -DryRun $DryRun -ExcludeSections $ExcludeSections
    Write-Host ""
}

Write-Host "=== Processing Complete ===" -ForegroundColor Green

if ($DryRun) {
    Write-Host "This was a dry run. To make actual changes, run without -DryRun flag." -ForegroundColor Magenta
    Write-Host "Example usage:" -ForegroundColor White
    Write-Host "  .\rep_fulldef.ps1                  # Process all chapter files" -ForegroundColor Gray
    Write-Host "  .\rep_fulldef.ps1 -DryRun         # Preview changes without making them" -ForegroundColor Gray
    Write-Host "  .\rep_fulldef.ps1 -ShowDetails    # Show detailed processing information" -ForegroundColor Gray
    Write-Host "  .\rep_fulldef.ps1 -ExcludeSections:`$false  # Include section headers" -ForegroundColor Gray
}
