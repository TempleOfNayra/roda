#!/bin/bash

echo "Fast Run Script for Roda App"
echo "============================"

# Check if we should clean
if [ "$1" == "clean" ]; then
    echo "Cleaning build artifacts..."
    flutter clean
    flutter pub get
fi

# Run in release mode for faster performance
echo "Running in release mode on simulator..."
flutter run --release -d 408C2F71-C43A-446C-A66B-21BFEEF91AEB

# Alternative: Run on real device if connected
# flutter run --release -d "Ali's iPhone"