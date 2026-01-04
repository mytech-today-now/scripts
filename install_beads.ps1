<#
.SYNOPSIS
    Sets up Beads[](https://github.com/steveyegge/beads) in a local Git repository to enable AI-assisted development
    using structured task tracking. This is particularly useful for PowerShell script development.

.DESCRIPTION
    Beads is a git-backed task tracker designed for AI coding agents, providing persistent memory and dependency-aware tasks.
    This script:
    - Clones the target repository if not already in a Git repo (optional).
    - Installs the Beads CLI (`bd`) on Windows using available methods (Go preferred, fallback to build from source).
    - Initializes Beads in the repository.
    - Creates essential agent instruction files (AGENTS.md, AGENT_INSTRUCTIONS.md if needed).
    - Optionally initializes OpenSpec for spec-driven development (requires Node.js/npm).

    OpenSpec[](https://github.com/Fission-AI/OpenSpec) complements Beads by enforcing spec-driven workflows.

.NOTES
    Requires administrative privileges for some installation steps.
    Tested on Windows with PowerShell 7+.
#>

param(
    [switch]$CloneRepo,
    [string]$RepoUrl = "https://github.com/mytech-today-now/PowerShellScripts.git",
    [switch]$InitOpenSpec
)

# Ensure running in a repository directory
if ($CloneRepo) {
    $repoName = Split-Path $RepoUrl -Leaf
    $repoName = $repoName -replace '\.git$',''
    if (Test-Path $repoName) {
        Write-Warning "Directory $repoName already exists. Skipping clone."
    } else {
        git clone $RepoUrl
    }
    Set-Location $repoName
}

# Check if already in a Git repo
if (-not (Test-Path .git)) {
    Write-Error "Not in a Git repository. Run with -CloneRepo or navigate to your repo first."
    exit 1
}

# Install Beads CLI (bd)
Write-Host "Installing Beads CLI..." -ForegroundColor Green

# Preferred: Use Go if available
if (Get-Command go -ErrorAction SilentlyContinue) {
    Write-Host "Using Go to install bd..."
    go install github.com/steveyegge/beads/cmd/bd@latest
} else {
    # Fallback: Clone and build (requires Go anyway, but attempt direct build)
    Write-Host "Go not found. Attempting to clone and build Beads..."
    $tempDir = Join-Path $env:TEMP "beads-temp"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    git clone https://github.com/steveyegge/beads.git $tempDir
    Set-Location $tempDir
    go build -o bd.exe ./cmd/bd
    # Move to a path location (e.g., user bin)
    $userBin = "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps"
    if (-not (Test-Path $userBin)) { New-Item $userBin -ItemType Directory | Out-Null }
    Move-Item bd.exe $userBin
    Set-Location ..
    Remove-Item $tempDir -Recurse -Force
    Write-Host "bd.exe placed in $userBin (add to PATH if needed)."
}

# Verify installation
if (-not (Get-Command bd -ErrorAction SilentlyContinue)) {
    Write-Error "Beads CLI (bd) installation failed. Ensure Go is installed or manually install from https://github.com/steveyegge/beads."
    exit 1
}

# Initialize Beads
Write-Host "Initializing Beads in the repository..." -ForegroundColor Green
bd init

# Optional: Stealth mode (local only, no commits to .beads)
# bd init --stealth

# Create AGENTS.md to guide AI agents
$agentsContent = @"
# AI Agent Instructions for this Repository

Use the `bd` command for all task tracking and planning.

## Key Guidelines
- Always use `bd ready` to find the next task with no blockers.
- Create tasks with `bd create "Title" --desc "Detailed description"`.
- Add dependencies with `bd dep add <child-id> <parent-id>`.
- Update status with `bd done <id>` or `bd block <id> "reason"`.
- View tasks with `bd list` or `bd graph`.

Beads provides persistent, dependency-aware memory across sessions.
"@

if (-not (Test-Path AGENTS.md)) {
    Set-Content -Path AGENTS.md -Value $agentsContent
    git add AGENTS.md
    git commit -m "Add AGENTS.md for Beads-guided AI development"
}

Write-Host "Beads setup complete! Commit and push changes if needed." -ForegroundColor Green

# Optional OpenSpec setup
if ($InitOpenSpec) {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Error "npm not found. Install Node.js to use OpenSpec."
        exit 1
    }
    Write-Host "Installing OpenSpec CLI globally..." -ForegroundColor Green
    npm install -g @fission-ai/openspec@latest

    Write-Host "Initializing OpenSpec..." -ForegroundColor Green
    openspec init

    Write-Host "OpenSpec initialized. Use /spec commands in supported AI tools for spec-driven development."
}

Write-Host @"
Setup complete!

To develop PowerShell scripts with AI assistance:
1. Commit and push the .beads directory (unless using --stealth).
2. Instruct your AI agent (e.g., Claude, Cursor, etc.) to follow AGENTS.md.
3. Use Beads for task management and (if installed) OpenSpec for specifications.

Enjoy structured, AI-assisted PowerShell development!
"@