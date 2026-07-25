@echo off
setlocal enabledelayedexpansion

set "ENV_FILE=%~dp0.env"

if not exist "%ENV_FILE%" (
    echo Error: .env file not found at %ENV_FILE%
    exit /b 1
)

set "URL="
set "KEY="

for /f "usebackq tokens=1,2 delims==" %%A in ("%ENV_FILE%") do (
    set "KEY_NAME=%%A"
    set "VALUE=%%B"
    if "!KEY_NAME!"=="SUPABASE_URL" set "URL=!VALUE!"
    if "!KEY_NAME!"=="SUPABASE_ANON_KEY" set "KEY=!VALUE!"
)

set "URL=!URL:"=!"
set "KEY=!KEY:"=!"

if "!URL!"=="" (
    echo Error: SUPABASE_URL is not set in .env
    exit /b 1
)

if "!KEY!"=="" (
    echo Error: SUPABASE_ANON_KEY is not set in .env
    exit /b 1
)

echo Running with SUPABASE_URL=!URL!
flutter run -d edge --dart-define=SUPABASE_URL=!URL! --dart-define=SUPABASE_ANON_KEY=!KEY!
exit /b %errorlevel%
