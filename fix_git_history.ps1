# Fix Git History - Remove myenv from all commits
# This will rewrite history to remove the large files

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "FIXING GIT HISTORY - Removing myenv/" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`n[STEP 1] Installing BFG Repo Cleaner..." -ForegroundColor Yellow

# Check if BFG is available
$bfgUrl = "https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar"
$bfgPath = "bfg.jar"

if (-not (Test-Path $bfgPath)) {
    Write-Host "  Downloading BFG..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $bfgUrl -OutFile $bfgPath
    Write-Host "  [OK] BFG downloaded" -ForegroundColor Green
} else {
    Write-Host "  [OK] BFG already exists" -ForegroundColor Green
}

Write-Host "`n[STEP 2] Removing myenv/ from Git history..." -ForegroundColor Yellow
java -jar bfg.jar --delete-folders myenv --no-blob-protection

Write-Host "`n[STEP 3] Cleaning up Git repository..." -ForegroundColor Yellow
git reflog expire --expire=now --all
git gc --prune=now --aggressive

Write-Host "`n[STEP 4] Force pushing to remote..." -ForegroundColor Yellow
git push origin LLM_FINAL --force

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "DONE! Repository cleaned and pushed!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
