#!/usr/bin/env bash 2>/dev/null || goto :windows

#linux & macos

odin test ./tests -vet -sanitize:address -define:ODIN_TEST_SHORT_LOGS=false -define:ODIN_TEST_ALWAYS_REPORT_MEMORY=true

exit 0

::---------------------------------------------------------------------------------
:windows

@echo off

odin test ./tests -vet -sanitize:address -define:ODIN_TEST_SHORT_LOGS=false -define:ODIN_TEST_ALWAYS_REPORT_MEMORY=true

exit /b