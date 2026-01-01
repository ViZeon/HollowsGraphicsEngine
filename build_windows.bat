@echo off
if not exist out\Windows_Speed mkdir out\Windows_Speed
odin build src -o:speed -resource:resources/icon.rc -out:out/Windows_Speed/HollowsEngline.exe
if %ERRORLEVEL% EQU 0 (
    xcopy /E /I /Y assets out\Windows_Speed\assets
    out\Windows_Speed\HollowsEngline.exe
)