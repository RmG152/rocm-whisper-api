#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a new release for the ROCm Whisper API project.
    
.DESCRIPTION
    Automates the release process by:
    1. Updating version in app/__init__.py
    2. Creating a git commit with version bump
    3. Creating a git tag
    4. Pushing changes to GitHub
    
.PARAMETER Version
    The version to release (e.g., v0.2.0)
    
.EXAMPLE
    .\create-release.ps1 -Version v0.2.0
#>

param(
    [string]$Version = ""
)

# Colors for output
$Green = [System.ConsoleColor]::Green
$Red = [System.ConsoleColor]::Red
$Yellow = [System.ConsoleColor]::Yellow
$Cyan = [System.ConsoleColor]::Cyan

function Write-Success {
    param([string]$Message)
    Write-Host "SUCCESS: $Message" -ForegroundColor $Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor $Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "INFO: $Message" -ForegroundColor $Cyan
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "WARNING: $Message" -ForegroundColor $Yellow
}

# Validate version parameter
if (-not $Version) {
    Write-Error-Custom "Version not specified"
    Write-Info "Usage: .\create-release.ps1 -Version v0.2.0"
    exit 1
}

# Validate version format
if ($Version -notmatch '^v\d+\.\d+\.\d+') {
    Write-Error-Custom "Invalid version format: $Version"
    Write-Info "Expected format: v0.2.0, v1.0.0, etc."
    exit 1
}

# Extract version number without 'v' prefix
$VersionNumber = $Version -replace '^v', ''

Write-Host ""
Write-Host "🚀 Creating release: $Version" -ForegroundColor $Cyan
Write-Host ""

# Step 1: Update version in __init__.py
Write-Info "Step 1: Updating version in app/__init__.py"
$InitFile = "../app/__init__.py"

if (-not (Test-Path $InitFile)) {
    Write-Error-Custom "File not found: $InitFile"
    exit 1
}

try {
    $content = Get-Content $InitFile -Raw
    $newContent = $content -replace '__version__ = "[^"]*"', "__version__ = `"$VersionNumber`""
    Set-Content $InitFile -Value $newContent
    Write-Success "Version updated to $VersionNumber"
}
catch {
    Write-Error-Custom "Failed to update version: $_"
    exit 1
}

# Step 2: Add and commit changes
Write-Info "Step 2: Creating git commit"
try {
    git add $InitFile
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add file to git"
    }
    
    git commit -m "chore: bump version to $VersionNumber"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create commit"
    }
    Write-Success "Commit created"
}
catch {
    Write-Error-Custom "Git operation failed: $_"
    exit 1
}

# Step 3: Create git tag
Write-Info "Step 3: Creating git tag"
try {
    git tag -a $Version -m "Release version $VersionNumber"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create tag"
    }
    Write-Success "Tag $Version created"
}
catch {
    Write-Error-Custom "Tag creation failed: $_"
    # Rollback commit
    Write-Warning-Custom "Rolling back commit..."
    git reset HEAD~1
    exit 1
}

# Step 4: Push to GitHub
Write-Info "Step 4: Pushing changes to GitHub"
try {
    Write-Info "Pushing main branch..."
    git push origin main
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push main branch"
    }
    
    Write-Info "Pushing tag..."
    git push origin $Version
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push tag"
    }
    Write-Success "Push completed"
}
catch {
    Write-Error-Custom "Push failed: $_"
    Write-Warning-Custom "You may need to manually push:"
    Write-Info "  git push origin main"
    Write-Info "  git push origin $Version"
    exit 1
}

Write-Host ""
Write-Host "✨ Release $Version ready!" -ForegroundColor $Green
Write-Info "GitHub Actions will automatically create the release in a few moments."

# Get repository URL for the release link
try {
    $remoteUrl = git config --get remote.origin.url
    if ($remoteUrl -match 'github\.com[/:]([^/]+/[^/.]+)') {
        $repoPath = $matches[1]
        Write-Info "View it here: https://github.com/$repoPath/releases/tag/$Version"
    } else {
        Write-Info "View your releases at: https://github.com/YOUR_USERNAME/YOUR_REPO/releases"
    }
} catch {
    Write-Info "View your releases at: https://github.com/YOUR_USERNAME/YOUR_REPO/releases"
}

Write-Host ""
