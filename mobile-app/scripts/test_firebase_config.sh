#!/bin/bash

# Firebase Configuration Test Script
# Tests connectivity to production Firebase project

echo "🔥 Firebase Configuration Test"
echo "================================"

PROJECT_ID="slumber-insights-tqv7z"
echo "Expected Project: $PROJECT_ID"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if firebase_options.dart exists
if [ ! -f "lib/config/firebase_options.dart" ]; then
    echo -e "${RED}❌ firebase_options.dart not found${NC}"
    exit 1
fi

# Extract project ID from config
CURRENT_PROJECT=$(grep "projectId:" lib/config/firebase_options.dart | head -1 | sed "s/.*projectId: '\(.*\)'.*/\1/")

echo "Current Project:  $CURRENT_PROJECT"
echo ""

if [ "$CURRENT_PROJECT" == "$PROJECT_ID" ]; then
    echo -e "${GREEN}✅ Configuration is correct${NC}"
else
    echo -e "${RED}❌ Configuration mismatch!${NC}"
    echo -e "${YELLOW}⚠️  Please update firebase_options.dart with correct credentials${NC}"
    echo ""
    echo "Run this command to reconfigure:"
    echo "  flutterfire configure --project=$PROJECT_ID"
    exit 1
fi

echo ""
echo "📋 Configuration Details:"
grep -E "(apiKey|appId|projectId|authDomain|storageBucket)" lib/config/firebase_options.dart | head -6

echo ""
echo "🧪 Running integration tests..."
echo ""

# Run integration tests
$HOME/flutter/bin/flutter test test/integration/firebase_integration_test.dart

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo ""
    echo -e "${RED}❌ Tests failed${NC}"
    exit 1
fi
