# PowerShell script to replace full acronym definitions with \acrfull{} commands
# Based on definitions in myacronyms.sty file

param(
    [Parameter(Mandatory=$false)]
    [string]$AcronymFile = "myacronyms.sty",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetPattern = "*.tex",
    
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
            
            # Create patterns to match:
            # 1. "Full Definition (ACRONYM)"
            # 2. "ACRONYM (Full Definition)" 
            $pattern1 = [regex]::Escape("$fullDef ($acronym)")
            $pattern2 = [regex]::Escape("$acronym ($fullDef)")
            
            $acronyms[$pattern1] = @{
                Key = $key
                Type = "FullFirst"
                Original = "$fullDef ($acronym)"
            }
            
            $acronyms[$pattern2] = @{
                Key = $key
                Type = "AcronymFirst" 
                Original = "$acronym ($fullDef)"
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
        
        # Create regex pattern with word boundaries and optional exclusions
        $regexPattern = if ($ExcludeSections) {
            # Exclude lines with LaTeX sectioning commands and captions
            "(?m)^(?!.*\\(?:caption|chapter|section|subsection|subsubsection|paragraph|subparagraph|title|author)\b)(.*)$pattern(.*)$"
        } else {
            "(?m)(.*)$pattern(.*)$"
        }
        
        $matches = [regex]::Matches($content, $regexPattern)
        
        if ($matches.Count -gt 0) {
            Write-Host "Found $($matches.Count) occurrence(s) of '$($acronymInfo.Original)' in $FilePath" -ForegroundColor Yellow
            
            if ($ExcludeSections) {
                $content = [regex]::Replace($content, $regexPattern, "`$1$replacement`$2")
            } else {
                $content = [regex]::Replace($content, $regexPattern, "`$1$replacement`$2")
            }
            
            $replacements += $matches.Count
            
            # Show what was replaced
            foreach ($match in $matches) {
                $lineStart = $content.LastIndexOf("`n", $match.Index) + 1
                $lineEnd = $content.IndexOf("`n", $match.Index)
                if ($lineEnd -eq -1) { $lineEnd = $content.Length }
                $line = $content.Substring($lineStart, $lineEnd - $lineStart)
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
Write-Host "=== Acronym Replacement Script ===" -ForegroundColor Cyan
Write-Host "Acronym file: $AcronymFile" -ForegroundColor White
Write-Host "Target pattern: $TargetPattern" -ForegroundColor White
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
