# LLM Folder Cleanup Script
# This will delete all unused files and keep only the core 8 files

Write-Host "Starting aggressive cleanup..." -ForegroundColor Cyan

# Delete unused Python files
$filesToDelete = @(
    "apillm_backup.py",
    "advanced_llm_handlers.py",
    "room_specific_handlers.py",
    "anomalies_llm.py",
    "anomaly_detector.py",
    "app.py",
    "mongo.py",
    "logging_manager.py",
    "prompt_manager.py",
    "custom_prompts.json",
    "room_log_analyzer.py",
    "health_check.py",
    "example_prompt_usage.py",
    "test_advanced_features.py",
    "test_anomaly_detection.py",
    "test_connections.py",
    "test_database_connection.py",
    "test_database_only.py",
    "test_room_queries.py"
)

# Delete log files
$logFiles = @(
    "apillm_enhanced.log",
    "app.log",
    "room_analysis.log"
)

# Delete folders
$foldersToDelete = @(
    "backup_logs",
    "db"
)

$deletedCount = 0
$totalSize = 0

# Delete files
foreach ($file in $filesToDelete) {
    if (Test-Path $file) {
        $size = (Get-Item $file).Length
        $totalSize += $size
        Remove-Item $file -Force
        Write-Host "Deleted: $file ($([math]::Round($size/1KB, 2)) KB)" -ForegroundColor Green
        $deletedCount++
    }
}

# Delete log files
foreach ($log in $logFiles) {
    if (Test-Path $log) {
        $size = (Get-Item $log).Length
        $totalSize += $size
        Remove-Item $log -Force
        Write-Host "Deleted log: $log ($([math]::Round($size/1MB, 2)) MB)" -ForegroundColor Yellow
        $deletedCount++
    }
}

# Delete folders
foreach ($folder in $foldersToDelete) {
    if (Test-Path $folder) {
        $size = (Get-ChildItem $folder -Recurse | Measure-Object -Property Length -Sum).Sum
        $totalSize += $size
        Remove-Item $folder -Recurse -Force
        Write-Host "Deleted folder: $folder ($([math]::Round($size/1KB, 2)) KB)" -ForegroundColor Magenta
        $deletedCount++
    }
}

Write-Host "`nCleanup complete!" -ForegroundColor Cyan
Write-Host "Deleted $deletedCount items" -ForegroundColor Green
Write-Host "Freed $([math]::Round($totalSize/1MB, 2)) MB of space" -ForegroundColor Green

Write-Host "`n Remaining core files:" -ForegroundColor Cyan
Write-Host "  1. apillm.py" -ForegroundColor White
Write-Host "  2. database_adapter.py" -ForegroundColor White
Write-Host "  3. main.py" -ForegroundColor White
Write-Host "  4. prompts_config.py" -ForegroundColor White
Write-Host "  5. advanced_prompts.json" -ForegroundColor White
Write-Host "  6. requirements-llm.txt" -ForegroundColor White
Write-Host "  7. .env_sample" -ForegroundColor White
Write-Host "  8. .gitignore" -ForegroundColor White

Write-Host "`nReady to run: python apillm.py" -ForegroundColor Green
