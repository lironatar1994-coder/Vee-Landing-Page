# ==============================================================================
# Vee Landing Page Deployment Script (Local Windows)
# ==============================================================================

param (
    [string]$CommitMessage = "Deploy Vee landing page",
    [switch]$SkipCheck
)

$ErrorActionPreference = "Stop"

$SSH_HOST = "root@vee-app.co.il"
$SSH_DOMAIN = "vee-app.co.il"
$REMOTE_REPO = "https://github.com/lironatar1994-coder/Vee-Landing-Page.git"
$REMOTE_DIR = "/root/Vee-Landing-Page"

Write-Host "--- Starting Vee Landing Page Deployment ---" -ForegroundColor Cyan

if (-not $SkipCheck) {
    Write-Host "Checking server connectivity..." -ForegroundColor Gray
    if (-not (Test-Connection -ComputerName $SSH_DOMAIN -Count 1 -Quiet)) {
        Write-Host "Error: Could not ping server $SSH_DOMAIN." -ForegroundColor Red
        exit 1
    }
}

$remoteUrl = git remote get-url origin
if ($remoteUrl -ne $REMOTE_REPO) {
    Write-Host "Setting origin to $REMOTE_REPO" -ForegroundColor Yellow
    git remote set-url origin $REMOTE_REPO
}

$status = git status --porcelain
if ($status) {
    if (-not $CommitMessage) {
        $CommitMessage = Read-Host "Changes detected. Enter commit message"
    }
    if (-not $CommitMessage) {
        Write-Host "Error: Commit message required." -ForegroundColor Red
        exit 1
    }

    Write-Host "Staging and committing landing page files..." -ForegroundColor Gray
    git add .
    git commit -m "$CommitMessage"
} else {
    Write-Host "No local changes to commit. Proceeding with deploy." -ForegroundColor Yellow
}

$branch = git branch --show-current
if (-not $branch) {
    $branch = "main"
    git branch -M main
} elseif ($branch -ne "main") {
    Write-Host "Switching branch name to main for deployment..." -ForegroundColor Yellow
    git branch -M main
}

Write-Host "Pushing to GitHub..." -ForegroundColor Gray
git push -u origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Git push failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Connecting to server and triggering remote deploy..." -ForegroundColor Blue
$REMOTE_CMD = "if [ ! -d $REMOTE_DIR/.git ]; then git clone $REMOTE_REPO $REMOTE_DIR; fi && cd $REMOTE_DIR && git remote set-url origin $REMOTE_REPO && git fetch origin main && git reset --hard origin/main && chmod +x deploy_linux.sh && ./deploy_linux.sh"

ssh $SSH_HOST $REMOTE_CMD
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[!] DEPLOYMENT FAILED" -ForegroundColor Red
    Write-Host "The remote script exited with error code $LASTEXITCODE." -ForegroundColor Yellow
    exit $LASTEXITCODE
}

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "      VEE LANDING PAGE DEPLOYED SUCCESSFULLY" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "Visit: https://vee-app.co.il" -ForegroundColor Cyan
