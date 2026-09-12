#!/bin/bash
# Android Release Build Script
# Run this on a machine with Android SDK installed

set -e

echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building Android App Bundle (AAB) for Google Play Store..."
flutter build appbundle --release --android-skip-build-dependency-validation

echo "🔨 Building Android APK for direct distribution..."
flutter build apk --release --android-skip-build-dependency-validation

echo ""
echo "✅ Build Complete!"
echo ""
echo "📦 App Bundle (for Google Play Store):"
echo "   build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "📦 APK (for direct installation):"
echo "   build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📝 Next Steps:"
echo "   - For Google Play Store: Upload the AAB file"
echo "   - For direct installation: Use the APK file"
echo ""
