@echo off

echo ================================

echo Flutter packages pub run build_runner build --delete-conflicting-outputs
call flutter packages pub run build_runner build --delete-conflicting-outputs

echo Finish!
