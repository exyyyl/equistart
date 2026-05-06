@echo off
chcp 65001 > nul
echo Добавление EquiLauncher в автозагрузку...
call "%~dp0EquiLauncher.bat" --startup
echo.
echo Готово! Теперь скрипт будет запускаться вместе с Windows.
pause
