#!/usr/bin/env bash

set -euo pipefail

echo "========================"
echo " Running Tests"
echo "========================"

BACKEND_EXIT_CODE=0
FRONTEND_EXIT_CODE=0

# ============================================
# Backend Tests
# ============================================

if [ -f "back/gradlew" ]; then
  echo ""
  echo "Running Backend Tests..."

  cd back

  # Check Java
  if ! command -v java >/dev/null 2>&1; then
    echo "ERROR: Java is not installed"
    exit 1
  fi

  echo "Java version: $(java -version 2>&1 | head -1)"

  chmod +x ./gradlew

  # Clean old reports
  rm -rf build/test-results build/reports/tests

  # Run tests
  ./gradlew test || BACKEND_EXIT_CODE=$?

  cd ..

  if [ $BACKEND_EXIT_CODE -eq 0 ]; then
    echo "Backend tests completed successfully"
  else
    echo "Backend tests failed"
  fi
else
  echo "No backend project found"
fi

# ============================================
# Frontend Tests
# ============================================

if [ -f "front/package.json" ]; then
  echo ""
  echo "Running Frontend Tests..."

  cd front

  RESULTS_DIR="test-results"

  # Clean old reports
  rm -rf "$RESULTS_DIR"
  mkdir -p "$RESULTS_DIR"

  # Check Node.js
  if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: Node.js is not installed"
    exit 1
  fi

  # Check npm
  if ! command -v npm >/dev/null 2>&1; then
    echo "ERROR: npm is not installed"
    exit 1
  fi

  echo "Node version: $(node -v)"
  echo "NPM version: $(npm -v)"

  # Install dependencies
  echo "Installing dependencies..."
  npm ci --cache .npm --prefer-offline

  # Run tests
  echo "Running Angular tests..."

  npm test -- \
    --watch=false \
    --browsers=ChromeHeadless || FRONTEND_EXIT_CODE=$?

  cd ..

  if [ $FRONTEND_EXIT_CODE -eq 0 ]; then
    echo "Frontend tests completed successfully"
  else
    echo "Frontend tests failed"
  fi
else
  echo "No frontend project found"
fi

# ============================================
# Final Result
# ============================================

echo ""
echo "========================"
echo " Final Result"
echo "========================"

echo "Backend exit code : $BACKEND_EXIT_CODE"
echo "Frontend exit code: $FRONTEND_EXIT_CODE"

if [ $BACKEND_EXIT_CODE -ne 0 ] || [ $FRONTEND_EXIT_CODE -ne 0 ]; then
  exit 1
fi

echo "All tests passed successfully"
exit 0