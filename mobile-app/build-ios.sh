#!/bin/bash
# iOS Release Build Script
# Run this on macOS with Xcode installed

set -e

echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building iOS IPA for App Store/TestFlight..."
flutter build ipa --release

echo ""
echo "✅ Build Complete!"
echo ""
echo "📦 IPA file location:"
echo "   build/ios/ipa/*.ipa"
echo ""
echo "📝 Next Steps:"
echo "   1. Open 'build/ios/archive/Runner.xcarchive' in Xcode"
echo "   2. Use Xcode's Organizer to:"
echo "      - Distribute to App Store Connect"
echo "      - Or export for Ad Hoc distribution"
echo ""
echo "   Alternatively, upload directly:"
echo "   xcrun altool --upload-app --file build/ios/ipa/*.ipa \\"
echo "     --type ios --apiKey YOUR_KEY --apiIssuer YOUR_ISSUER"
echo ""
