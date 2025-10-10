@echo off
echo Starting ML Food Recognition Server...
echo.

cd /d "%~dp0"

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8+ and try again
    pause
    exit /b 1
)

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Install dependencies
echo Installing/updating dependencies...
pip install -r requirements.txt

REM Check if models exist
if not exist "food_model_final.keras" (
    echo WARNING: food_model_final.keras not found
    echo The server will run with limited functionality
    echo.
)

if not exist "class_names.json" (
    echo WARNING: class_names.json not found
    echo The server will run with limited functionality
    echo.
)

REM Start the server
echo.
echo Starting Flask API server...
echo Server will be available at: http://localhost:5000
echo.
echo Press Ctrl+C to stop the server
echo.

python flask_api.py

echo.
echo Server stopped.
pause
