@echo off
echo Clearing Python cache...
del /s /q *.pyc 2>nul
for /d /r %%d in (__pycache__) do @if exist "%%d" rd /s /q "%%d"

echo Starting LLM server...
python apillm.py
