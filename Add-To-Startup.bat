@echo off
title EquiLauncher Setup
chcp 65001 > nul

echo.
echo  [ EquiLauncher: Настройка автозагрузки ]
echo.
echo  Этот скрипт добавит лаунчер в автозагрузку Windows.
echo  Discord будет автоматически патчиться и запускаться при включении ПК.
echo.

call "%~dp0EquiLauncher.bat" --startup

echo.
echo  [ Готово! ]
echo  Теперь вы можете закрыть это окно.
echo.
pause
