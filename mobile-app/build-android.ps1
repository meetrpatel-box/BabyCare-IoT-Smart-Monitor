# Android Release Build Script for Windows
# Run this in PowerShell on a machine with Android SDK installed

Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

Write-Host "📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "🔨 Building Android App Bundle (AAB) for Google Play Store..." -ForegroundColor Yellow
flutter build appbundle --release

Write-Host "🔨 Building Android APK for direct distribution..." -ForegroundColor Yellow
flutter build apk --release

Write-Host ""
Write-Host "✅ Build Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📦 App Bundle (for Google Play Store):" -ForegroundColor Cyan
Write-Host "   build\app\outputs\bundle\release\app-release.aab"
Write-Host ""
Write-Host "📦 APK (for direct installation):" -ForegroundColor Cyan
Write-Host "   build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   - For Google Play Store: Upload the AAB file"
Write-Host "   - For direct installation: Use the APK file"
Write-Host ""
