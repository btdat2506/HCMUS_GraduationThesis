# PowerShell script to replace plural acronym long forms with \acrlongpl{} commands
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
        # Match \newacronym with optional parameters including plural forms
        # Pattern: \newacronym[options]{key}{ACRONYM}{Full Definition}
        if ($line -match '\\newacronym(?:\[([^\]]+)\])?\{([^}]+)\}\{([^}]+)\}\{([^}]+)\}') {
            $options = $matches[1]
            $key = $matches[2]
            $acronym = $matches[3]
            $fullDef = $matches[4]
            
            # Initialize plural forms with defaults
            $pluralAcronym = $acronym + "s"  # Default plural
            $pluralFullDef = $fullDef + "s"  # Default plural
            
            # Parse options if they exist
            if ($options) {
                # Extract plural= option
                if ($options -match 'plural=([^,\]]+)') {
                    $pluralAcronym = $matches[1]
                }
                
                # Extract firstplural= option
                if ($options -match 'firstplural=([^,\]]+)') {
                    $firstPluralFull = $matches[1]
                    # Parse "Full Definition (ACRONYM)" format
                    if ($firstPluralFull -match '^(.+)\s+\(([^)]+)\)$') {
                        $pluralFullDef = $matches[1]
                        $extractedPluralAcronym = $matches[2]
                        # Use extracted acronym if it matches our expectation
                        if ($extractedPluralAcronym -eq $pluralAcronym) {
                            # Good, they match
                        } else {
                            # Update our plural acronym to match
                            $pluralAcronym = $extractedPluralAcronym
                        }
                    } else {
                        # If no parentheses, assume it's just the full definition
                        $pluralFullDef = $firstPluralFull
                    }
                }
            }
            
            # Only create patterns if we have actual plural forms
            if ($pluralFullDef -ne $fullDef) {
                # Create pattern to match just the plural full definition (long form)
                $pattern = [regex]::Escape($pluralFullDef)
                
                $acronyms[$pattern] = @{
                    Key = $key
                    Acronym = $acronym
                    PluralAcronym = $pluralAcronym
                    FullDef = $fullDef
                    PluralFullDef = $pluralFullDef
                    Original = $pluralFullDef
                    Type = "PluralLongForm"
                }
                
                Write-Host "Added plural long form pattern for '$key': $pluralFullDef" -ForegroundColor Green
            } else {
                Write-Host "Skipped '$key' - no explicit plural long form defined" -ForegroundColor DarkGray
            }
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
        $replacement = "\acrlongpl{$key}"
        
        # Create regex pattern with word boundaries and exclusions
        # For long forms, we need to be more careful with boundaries since they contain spaces
        $regexPattern = if ($ExcludeSections) {
            # Exclude lines with LaTeX sectioning commands, captions, already processed acronym commands,
            # URLs, file paths, but allow plural long forms that are not already in braces or parentheses
            "(?m)^(?!.*\\(?:caption|chapter|section|subsection|subsubsection|paragraph|subparagraph|title|author)\b)(.*)(\b$pattern\b)(?!\w)(?!\})(?!\))(.*)$"
        } else {
            # Simple pattern that just matches standalone plural long forms with word boundaries
            "(?m)(.*)(\b$pattern\b)(?!\w)(?!\})(?!\))(.*)$"
        }
        
        # Additional check to avoid replacing long forms that are part of compound constructs or in specific contexts
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
            
            # Smart filtering: Only skip if the plural long form is in specific problematic contexts
            $shouldSkip = $false
            $skipReason = ""
            
            # 1. Skip if the long form is already inside an acronym command
            # Check if this specific match position is inside an acronym command
            $acronymCommands = [regex]::Matches($line, '\\acr(short|long|full|shortpl|longpl|fullpl)\{[^}]*\}|\\gls\{[^}]*\}|\\glspl\{[^}]*\}')
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
            
            # 2. Skip if the long form is inside a LaTeX command parameter (between braces)
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
            
            # 3. Skip if long form is inside mathematical expressions
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
            
            # 6. Skip if the long form is part of a parenthetical acronym definition
            if (-not $shouldSkip) {
                # Look for patterns like "Plural Full Definition (PLURAL_ACRONYM)" where this might be the plural full definition part
                $lineStartPos = $content.LastIndexOf("`n", $match.Index) + 1
                $matchPosInLine = $match.Groups[2].Index - $lineStartPos
                $matchEndInLine = $matchPosInLine + $match.Groups[2].Length
                
                # Check if there's an opening parenthesis right after the match
                if ($matchEndInLine -lt ($line.Length - 1) -and $line[$matchEndInLine] -eq ' ' -and ($matchEndInLine + 1) -lt ($line.Length - 1) -and $line[$matchEndInLine + 1] -eq '(') {
                    # Check if what follows looks like a plural acronym in parentheses
                    $afterMatch = $line.Substring($matchEndInLine)
                    if ($afterMatch -match '^\s+\([A-Z0-9\-]+s?\)') {
                        $shouldSkip = $true
                        $skipReason = "Part of plural full definition with acronym in parentheses"
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
                    
                    $originalLongForm = $match.Groups[2].Value
                    $replacementCmd = "\acrlongpl{$key}"
                    
                    Write-Host "    -> VALID for replacement: " -NoNewline -ForegroundColor Green
                    Write-Host "$contextBefore " -NoNewline -ForegroundColor Gray
                    Write-Host "$originalLongForm" -NoNewline -ForegroundColor Yellow
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
Write-Host "=== Acronym Plural Long Form Replacement Script ===" -ForegroundColor Cyan
Write-Host "Acronym file: $AcronymFile" -ForegroundColor White
Write-Host "Exclude sections: $ExcludeSections" -ForegroundColor White
Write-Host "Show details: $ShowDetails" -ForegroundColor White
Write-Host "Dry run: $DryRun" -ForegroundColor White
Write-Host ""

# Parse acronyms
Write-Host "Parsing acronyms from $AcronymFile..." -ForegroundColor Yellow
$acronyms = Parse-Acronyms -FilePath $AcronymFile

if ($acronyms.Count -eq 0) {
    Write-Warning "No plural acronym long form patterns found in $AcronymFile"
    Write-Host "Note: This script only processes acronyms with explicit plural long form definitions (firstplural= options)" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($acronyms.Count) plural acronym long form patterns to replace" -ForegroundColor Green
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
    Write-Host "  .\rep_longplural.ps1               # Process all chapter files" -ForegroundColor Gray
    Write-Host "  .\rep_longplural.ps1 -DryRun      # Preview changes without making them" -ForegroundColor Gray
    Write-Host "  .\rep_longplural.ps1 -ShowDetails # Show detailed processing information" -ForegroundColor Gray
    Write-Host "  .\rep_longplural.ps1 -ExcludeSections:`$false  # Include section headers" -ForegroundColor Gray
}
