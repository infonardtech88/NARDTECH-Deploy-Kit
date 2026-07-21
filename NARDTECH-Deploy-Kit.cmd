@echo off
REM ================================================
REM  NARDTECH - Avvio installazione automatica
REM  nardtech.altervista.org | @nardtech88
REM ================================================
title NARDTECH - Installazione software automatica
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-software.ps1"
