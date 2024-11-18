#!/bin/bash 2>nul || goto :windows

#linux & macos

odin test .\tests\ -vet -sanitize:address -sanitize:memory -sanitize:thread -define:ODIN_TEST_SHORT_LOGS=false -define:ODIN_TEST_ALWAYS_REPORT_MEMORY=true

exit

::---------------------------------------------------------------------------------
:windows

@echo off

odin test .\tests\ -vet -sanitize:address -define:ODIN_TEST_SHORT_LOGS=false -define:ODIN_TEST_ALWAYS_REPORT_MEMORY=true

exit /b