#!/bin/bash

echo "Starting Roda in development mode..."
echo "=================================="
echo "Once the app starts:"
echo "  r - Hot reload (fast)"
echo "  R - Hot restart (medium)"
echo "  q - Quit"
echo ""

# Run on simulator with hot reload enabled
flutter run -d 408C2F71-C43A-446C-A66B-21BFEEF91AEB

# Alternative: Run on real device if available
# flutter run -d "Ali's iPhone"