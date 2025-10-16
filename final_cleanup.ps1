# Final Cleanup Script - October 17, 2025
# Removes all temporary files created during development session

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "FINAL CLEANUP - Removing All Temporary Files" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$deletedCount = 0
$totalSize = 0

# Root directory cleanup
Write-Host "`n[ROOT] Cleaning root directory..." -ForegroundColor Yellow

$rootFiles = @(
    "ENHANCED_IMPROVEMENTS_COMPLETE.md",
    "DOCUMENTATION_CLEANUP.md"
)

foreach ($file in $rootFiles) {
    if (Test-Path $file) {
        $size = (Get-Item $file).Length
        Remove-Item $file -Force
        Write-Host "  [OK] Deleted: $file ($([math]::Round($size/1KB, 2)) KB)" -ForegroundColor Green
        $deletedCount++
        $totalSize += $size
    }
}

# LLM directory cleanup
Write-Host "`n[LLM] Cleaning llm/static_remote_LLM/..." -ForegroundColor Yellow

Set-Location "llm/static_remote_LLM"

$llmFiles = @(
    "cleanup_fix_scripts.ps1",
    "cleanup_docs.ps1"
)

foreach ($file in $llmFiles) {
    if (Test-Path $file) {
        $size = (Get-Item $file).Length
        Remove-Item $file -Force
        Write-Host "  [OK] Deleted: $file ($([math]::Round($size/1KB, 2)) KB)" -ForegroundColor Green
        $deletedCount++
        $totalSize += $size
    }
}

Set-Location "../.."

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "CLEANUP COMPLETE!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`nSummary:" -ForegroundColor White
Write-Host "  Files deleted: $deletedCount" -ForegroundColor White
Write-Host "  Space freed: $([math]::Round($totalSize/1KB, 2)) KB" -ForegroundColor White

Write-Host "`n[INFO] Files kept (production):" -ForegroundColor Cyan
Write-Host "  Backend:" -ForegroundColor White
Write-Host "    - llm/static_remote_LLM/apillm.py" -ForegroundColor Gray
Write-Host "    - llm/static_remote_LLM/main.py" -ForegroundColor Gray
Write-Host "    - llm/static_remote_LLM/database_adapter.py" -ForegroundColor Gray
Write-Host "    - llm/static_remote_LLM/README.md" -ForegroundColor Gray
Write-Host "  Frontend:" -ForegroundColor White
Write-Host "    - web/src/features/pages/LLMChatPage.tsx" -ForegroundColor Gray
Write-Host "    - web/src/service/LLMService.tsx" -ForegroundColor Gray

Write-Host "`n[SUCCESS] Repository is now clean and production-ready!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
