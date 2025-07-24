# PowerShell script to replace full acronym definitions with \acrlong{} commands
# Based on definitions in myacronyms.sty file

param(
    [Parameter(Mandatory=$false)]
    [string]$AcronymFile = "myacronyms.sty",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExcludeSections = $true
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
            
            # Create pattern to match just the full definition (without parentheses)
            # We need to be careful about word boundaries to avoid partial matches
            $pattern = [regex]::Escape($fullDef)
            
            $acronyms[$pattern] = @{
                Key = $key
                Acronym = $acronym
                FullDef = $fullDef
                Original = $fullDef
            }
            
            Write-Host "Added pattern for '$key': $fullDef" -ForegroundColor Green
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
        $replacement = "\acrlong{$key}"
        
        # Create regex pattern with word boundaries and optional exclusions
        # Use \b for word boundaries to ensure we match complete terms
        $regexPattern = if ($ExcludeSections) {
            # Exclude lines with LaTeX sectioning commands, captions, and already processed acronym commands
            "(?m)^(?!.*\\(?:caption|chapter|section|subsection|subsubsection|paragraph|subparagraph|title|author|acrfull|acrlong|acrshort|gls)\b)(.*)(\b$pattern\b)(.*)$"
        } else {
            # Still exclude already processed acronym commands to avoid double processing
            "(?m)^(?!.*\\(?:acrfull|acrlong|acrshort|gls)\b)(.*)(\b$pattern\b)(.*)$"
        }
        
        $matches = [regex]::Matches($content, $regexPattern)
        
        if ($matches.Count -gt 0) {
            Write-Host "Found $($matches.Count) occurrence(s) of '$($acronymInfo.Original)' in $FilePath" -ForegroundColor Yellow
            
            # Replace the matched pattern
            $content = [regex]::Replace($content, $regexPattern, "`$1$replacement`$3")
            
            $replacements += $matches.Count
            
            # Show what was replaced
            foreach ($match in $matches) {
                $lineStart = $originalContent.LastIndexOf("`n", $match.Index) + 1
                $lineEnd = $originalContent.IndexOf("`n", $match.Index)
                if ($lineEnd -eq -1) { $lineEnd = $originalContent.Length }
                $line = $originalContent.Substring($lineStart, $lineEnd - $lineStart)
                Write-Host "  Line preview: $($line.Trim())" -ForegroundColor Gray
            }
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
        Write-Host "No replacements needed in $FilePath" -ForegroundColor DarkGray
    }
}

# Main execution
Write-Host "=== Acronym Long Form Replacement Script ===" -ForegroundColor Cyan
Write-Host "Acronym file: $AcronymFile" -ForegroundColor White
Write-Host "Exclude sections: $ExcludeSections" -ForegroundColor White
Write-Host "Dry run: $DryRun" -ForegroundColor White
Write-Host ""

# Parse acronyms
Write-Host "Parsing acronyms from $AcronymFile..." -ForegroundColor Yellow
$acronyms = Parse-Acronyms -FilePath $AcronymFile

if ($acronyms.Count -eq 0) {
    Write-Error "No acronyms found in $AcronymFile"
    exit 1
}

Write-Host "Found $($acronyms.Count) acronym patterns to replace" -ForegroundColor Green
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
}
