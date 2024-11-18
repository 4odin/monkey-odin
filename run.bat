#!/usr/bin/env bash 2>/dev/null || goto :windows

#linux & macos

odin run . -vet

exit 0

::---------------------------------------------------------------------------------
:windows

@echo off

odin run . -vet

exit /b