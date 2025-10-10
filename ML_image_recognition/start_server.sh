#!/bin/bash

echo "Starting ML Food Recognition Server..."
echo

# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$DIR"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed or not in PATH"
    echo "Please install Python 3.8+ and try again"
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing/updating dependencies..."
pip install -r requirements.txt

# Check if models exist
if [ ! -f "food_model_final.keras" ]; then
    echo "WARNING: food_model_final.keras not found"
    echo "The server will run with limited functionality"
    echo
fi

if [ ! -f "class_names.json" ]; then
    echo "WARNING: class_names.json not found"
    echo "The server will run with limited functionality"
    echo
fi

# Start the server
echo
echo "Starting Flask API server..."
echo "Server will be available at: http://localhost:5000"
echo
echo "Press Ctrl+C to stop the server"
echo

python flask_api.py

echo
echo "Server stopped."
