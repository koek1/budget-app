# Deployment Guide - SpendSense

This guide covers deployment options for both Android and iOS platforms.

## Table of Contents

1. [Android Deployment](#android-deployment)
2. [iOS Deployment](#ios-deployment)
3. [Build Configurations](#build-configurations)
4. [Version Management](#version-management)
5. [Release Checklist](#release-checklist)

## Android Deployment

### Development Build

```bash
cd frontend
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release Build (APK)

```bash
cd frontend
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (for Google Play Store)

```bash
cd frontend
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Google Play Store Deployment

1. **Create Google Play Developer Account**
   - One-time fee: $25
   - https://play.google.com/console

2. **Prepare Store Listing**
   - App name: SpendSense
   - Short description (80 characters)
   - Full description (4000 characters)
   - Screenshots (phone, tablet, TV)
   - Feature graphic (1024x500)
   - App icon (512x512)

3. **Upload App Bundle**
   - Go to Google Play Console
   - Create new app or select existing
   - Go to Production → Create new release
   - Upload `app-release.aab`
   - Fill in release notes
   - Review and roll out

4. **Content Rating**
   - Complete content rating questionnaire
   - Get rating certificate

5. **Privacy Policy**
   - Required for apps handling user data
   - Add privacy policy URL

### Internal Testing

1. **Create Internal Testing Track**
   - Upload APK/AAB
   - Add testers (up to 100)
   - Testers get access via link

### Beta Testing

1. **Create Closed Beta Track**
   - Upload APK/AAB
   - Add testers via email
   - Testers join via opt-in link

### Open Beta Testing

1. **Create Open Beta Track**
   - Upload APK/AAB
   - Anyone can join via opt-in link
   - Good for public beta testing

## iOS Deployment

### Development Build

```bash
cd frontend
flutter build ios --debug
```

### Release Build

```bash
cd frontend
flutter build ios --release
```

### App Store Deployment

See [IOS_SETUP.md](./IOS_SETUP.md) for detailed iOS deployment instructions.

**Quick Steps:**

1. **Open in Xcode:**
   ```bash
   cd frontend/ios
   open Runner.xcworkspace
   ```

2. **Archive:**
   - Product → Archive
   - Wait for archive to complete

3. **Distribute:**
   - Distribute App → App Store Connect
   - Upload build

4. **App Store Connect:**
   - Complete app information
   - Add screenshots
   - Submit for review

### TestFlight (Beta Testing)

1. **Upload build to App Store Connect**
2. **Go to TestFlight tab**
3. **Add internal/external testers**
4. **Send invitations**

## Build Configurations

### Environment Variables

Create environment-specific configurations:

**Android:**
- `android/app/build.gradle.kts` - Build configurations
- `android/app/src/main/AndroidManifest.xml` - Permissions

**iOS:**
- `ios/Runner/Info.plist` - App configuration
- `ios/Podfile` - Dependencies

### Build Variants

**Debug:**
- Hot reload enabled
- Debug symbols included
- Larger app size

**Profile:**
- Performance optimizations
- Debug symbols included
- Good for performance testing

**Release:**
- Full optimizations
- No debug symbols
- Smallest app size
- Production-ready

## Version Management

### Version Number Format

In `pubspec.yaml`:
```yaml
version: 1.0.0+1
```

- **1.0.0**: Version name (user-facing)
- **+1**: Build number (incremental)

### Versioning Strategy

**Major Version (1.0.0):**
- Breaking changes
- Major feature additions
- Significant UI changes

**Minor Version (0.1.0):**
- New features
- Enhancements
- Non-breaking changes

**Patch Version (0.0.1):**
- Bug fixes
- Small improvements
- Security patches

**Build Number (+1):**
- Increment for every build
- Used for internal tracking
- Required for App Store/Play Store

### Updating Version

**Before Release:**
1. Update version in `pubspec.yaml`
2. Update version in `android/app/build.gradle.kts` (if needed)
3. Update version in `ios/Runner/Info.plist` (if needed)
4. Commit version changes

## Release Checklist

### Pre-Release

- [ ] All features tested
- [ ] All bugs fixed
- [ ] Performance tested
- [ ] Security reviewed
- [ ] Privacy policy updated
- [ ] Version numbers updated
- [ ] Release notes prepared
- [ ] Screenshots captured
- [ ] Store listings prepared

### Android Release

- [ ] Build release APK/AAB
- [ ] Test release build on device
- [ ] Sign APK/AAB (automatic for Play Store)
- [ ] Upload to Play Store
- [ ] Complete store listing
- [ ] Set pricing and distribution
- [ ] Submit for review

### iOS Release

- [ ] Build release in Xcode
- [ ] Archive build
- [ ] Upload to App Store Connect
- [ ] Complete app information
- [ ] Add screenshots
- [ ] Set pricing and availability
- [ ] Submit for review

### Post-Release

- [ ] Monitor crash reports
- [ ] Monitor user reviews
- [ ] Respond to user feedback
- [ ] Plan next release
- [ ] Update documentation

## Build Commands Reference

### Android

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release

# Split APKs by ABI
flutter build apk --split-per-abi --release
```

### iOS

```bash
# Debug build
flutter build ios --debug

# Release build
flutter build ios --release

# Build for simulator
flutter build ios --simulator
```

### Both Platforms

```bash
# Build for all platforms
flutter build apk --release
flutter build ios --release

# Clean build
flutter clean
flutter pub get
flutter build apk --release
```

## Distribution Channels

### Google Play Store
- **Primary**: Public app distribution
- **Cost**: $25 one-time fee
- **Review Time**: 1-3 days typically
- **Requirements**: Privacy policy, content rating

### Apple App Store
- **Primary**: Public app distribution
- **Cost**: $99/year
- **Review Time**: 24-48 hours typically
- **Requirements**: Privacy policy, detailed app information

### TestFlight (iOS)
- **Beta Testing**: Up to 10,000 external testers
- **Cost**: Included with Apple Developer account
- **Review Time**: Usually instant for internal, 24-48h for external

### Google Play Internal/Closed Beta
- **Beta Testing**: Limited testers
- **Cost**: Included with Play Console
- **Review Time**: Usually instant

### Direct Distribution
- **Android APK**: Can be distributed directly
- **iOS**: Requires enterprise account or TestFlight
- **Use Case**: Internal company apps, limited distribution

## Troubleshooting

### Build Errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build apk --release
```

### Signing Issues

**Android:**
- Check `android/app/build.gradle.kts` for signing config
- Verify keystore file exists
- Check keystore password

**iOS:**
- Verify Apple Developer account
- Check code signing in Xcode
- Ensure provisioning profile is valid

### Upload Errors

**Google Play:**
- Check AAB file size (max 150MB)
- Verify version code is incremented
- Check for required permissions

**App Store:**
- Verify bundle identifier is unique
- Check for required Info.plist keys
- Ensure all required assets are included

## Resources

- [Flutter Deployment](https://docs.flutter.dev/deployment)
- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [iOS Code Signing](https://developer.apple.com/documentation/xcode/managing-your-team-s-signing-assets)

---

**Last Updated**: 2024

