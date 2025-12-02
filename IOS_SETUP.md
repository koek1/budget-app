# iOS Setup and Deployment Guide

This guide provides detailed instructions for setting up, building, and deploying SpendSense for iOS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configuration](#configuration)
4. [Building for iOS](#building-for-ios)
5. [Testing](#testing)
6. [App Store Deployment](#app-store-deployment)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

1. **macOS** (macOS 10.15 or later)
   - iOS development can only be done on macOS

2. **Xcode** (latest version)
   - Download from Mac App Store
   - Includes iOS Simulator and development tools
   - Minimum version: Xcode 12.0+

3. **CocoaPods**
   ```bash
   sudo gem install cocoapods
   ```

4. **Flutter SDK**
   - Ensure Flutter is installed and configured
   - Verify with: `flutter doctor`

5. **Apple Developer Account**
   - Free account for device testing
   - Paid account ($99/year) for App Store distribution

### Verify Installation

```bash
# Check Flutter installation
flutter doctor

# Check CocoaPods installation
pod --version

# Check Xcode installation
xcodebuild -version
```

## Initial Setup

### 1. Install iOS Dependencies

```bash
cd frontend/ios
pod install
cd ../..
```

### 2. Open Project in Xcode

```bash
cd frontend/ios
open Runner.xcworkspace
```

**Important**: Always open `Runner.xcworkspace`, not `Runner.xcodeproj`

### 3. Configure Signing & Capabilities

In Xcode:

1. Select **Runner** in the project navigator
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Select your **Team** (Apple Developer account)
5. Xcode will automatically create a provisioning profile

**Required Capabilities:**
- ✅ **Keychain Sharing** (for flutter_secure_storage)
- ✅ **Face ID** (automatically added if device supports it)

## Configuration

### Info.plist Settings

The `Info.plist` file has been pre-configured with:

- **NSFaceIDUsageDescription**: Required for Face ID/Touch ID authentication
- **UIFileSharingEnabled**: Enables file sharing for CSV exports
- **NSAppTransportSecurity**: Allows local network connections for development

### Bundle Identifier

Default bundle identifier: `com.example.budgetApp`

To change it:
1. Open Xcode
2. Select Runner target
3. Go to General tab
4. Update Bundle Identifier

### App Display Name

The app display name is set to "SpendSense" in `Info.plist`.

### Minimum iOS Version

- **Minimum iOS**: 12.0 (configured in Podfile)
- **Recommended**: iOS 13.0+ for best experience

## Building for iOS

### Development Build

```bash
cd frontend
flutter build ios --debug
```

### Profile Build (for performance testing)

```bash
flutter build ios --profile
```

### Release Build (for App Store)

```bash
flutter build ios --release
```

The build output will be in: `frontend/build/ios/iphoneos/`

## Testing

### iOS Simulator

1. **List available simulators:**
   ```bash
   flutter devices
   ```

2. **Run on simulator:**
   ```bash
   flutter run -d ios
   ```

3. **Or specify a specific simulator:**
   ```bash
   flutter run -d "iPhone 14 Pro"
   ```

### Physical Device

1. **Connect iPhone/iPad via USB**

2. **Trust the computer** on your device

3. **Enable Developer Mode** (iOS 16+):
   - Settings → Privacy & Security → Developer Mode → Enable

4. **In Xcode:**
   - Select your device from the device dropdown
   - Xcode will automatically handle code signing

5. **Run the app:**
   ```bash
   flutter run -d <device-id>
   ```

### Test Checklist

- [ ] App launches successfully
- [ ] User registration works
- [ ] User login works
- [ ] Face ID/Touch ID authentication works
- [ ] Transactions can be added/edited/deleted
- [ ] Dashboard displays correctly
- [ ] Statistics and charts work
- [ ] CSV export works
- [ ] Dark mode toggle works
- [ ] Currency selection works
- [ ] App lifecycle (background/foreground) works
- [ ] Automatic logout on background works

## App Store Deployment

### 1. Prepare App Store Assets

**Required Assets:**
- App icon (1024x1024 PNG)
- Screenshots for different device sizes:
  - iPhone 6.7" (iPhone 14 Pro Max)
  - iPhone 6.5" (iPhone 11 Pro Max)
  - iPhone 5.5" (iPhone 8 Plus)
  - iPad Pro 12.9"

**Optional Assets:**
- App preview videos
- Marketing website URL
- Privacy policy URL

### 2. Update Version Numbers

In `pubspec.yaml`:
```yaml
version: 1.0.0+1
```
- First number: Version (1.0.0)
- Second number: Build number (+1)

### 3. Build Archive in Xcode

1. **Open Xcode:**
   ```bash
   cd frontend/ios
   open Runner.xcworkspace
   ```

2. **Select "Any iOS Device" or "Generic iOS Device"** as target

3. **Product → Archive**

4. **Wait for archive to complete**

5. **Organizer window opens automatically**

### 4. Upload to App Store Connect

1. **In Xcode Organizer:**
   - Select your archive
   - Click **Distribute App**
   - Choose **App Store Connect**
   - Click **Next**

2. **Select distribution options:**
   - Choose **Upload**
   - Click **Next**

3. **Select distribution certificate:**
   - Choose automatic signing
   - Click **Next**

4. **Review and upload:**
   - Review the summary
   - Click **Upload**

5. **Wait for processing:**
   - App Store Connect will process your build (15-30 minutes)
   - You'll receive an email when processing is complete

### 5. Submit for Review

1. **Go to App Store Connect:**
   - https://appstoreconnect.apple.com

2. **Select your app**

3. **Go to App Store tab**

4. **Fill in required information:**
   - App description
   - Keywords
   - Category
   - Privacy policy URL
   - Support URL

5. **Select build:**
   - Choose the uploaded build
   - Add screenshots

6. **Submit for review:**
   - Click **Submit for Review**
   - Answer export compliance questions
   - Submit

### 6. App Review Process

- **Typical review time**: 24-48 hours
- **Status updates**: Check App Store Connect
- **If rejected**: Address issues and resubmit

## Alternative Distribution Methods

### TestFlight (Beta Testing)

1. **Upload build to App Store Connect** (same as above)

2. **In App Store Connect:**
   - Go to TestFlight tab
   - Add internal/external testers
   - Send invitations

3. **Testers:**
   - Install TestFlight app
   - Accept invitation
   - Install beta version

### Ad-Hoc Distribution

For testing on specific devices:

1. **Register device UDIDs** in Apple Developer portal

2. **Create Ad-Hoc provisioning profile**

3. **In Xcode:**
   - Product → Archive
   - Distribute App → Ad-Hoc
   - Export IPA file

4. **Distribute IPA** to registered devices

**Limitations:**
- Maximum 100 devices per year
- Devices must be registered in advance

## Troubleshooting

### Common Issues

#### 1. CocoaPods Installation Errors

```bash
# Update CocoaPods
sudo gem install cocoapods

# Clean and reinstall pods
cd frontend/ios
rm -rf Pods Podfile.lock
pod install
```

#### 2. Code Signing Errors

- Ensure you have a valid Apple Developer account
- Check that your team is selected in Xcode
- Verify bundle identifier is unique

#### 3. Build Errors

```bash
# Clean Flutter build
cd frontend
flutter clean
flutter pub get

# Clean Xcode build
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter build ios --release
```

#### 4. Simulator Not Starting

```bash
# List available simulators
xcrun simctl list devices

# Boot a simulator
xcrun simctl boot "iPhone 14 Pro"
```

#### 5. Face ID Not Working

- Ensure `NSFaceIDUsageDescription` is in Info.plist
- Test on a physical device (simulator has limited Face ID support)
- Check that Face ID is set up on the device

#### 6. File Export Not Working

- Ensure `UIFileSharingEnabled` is set to `true` in Info.plist
- Check file permissions
- Test on a physical device

#### 7. Network Connection Issues

- For iOS Simulator: Use `http://localhost:5000`
- For physical device: Use your computer's IP address
- Ensure `NSAppTransportSecurity` allows local networking

### Debugging Tips

1. **Check Xcode console** for detailed error messages

2. **Use Flutter logs:**
   ```bash
   flutter run --verbose
   ```

3. **Check device logs:**
   ```bash
   # In Xcode: Window → Devices and Simulators
   # Select device → View Device Logs
   ```

4. **Test on multiple devices** to catch device-specific issues

## Best Practices

1. **Always test on physical devices** before App Store submission
2. **Test on multiple iOS versions** (minimum and latest)
3. **Test on different device sizes** (iPhone SE, iPhone Pro Max, iPad)
4. **Keep dependencies updated** regularly
5. **Follow App Store Review Guidelines**
6. **Test all features** before submission
7. **Prepare privacy policy** (required for App Store)

## Resources

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)

---

**Last Updated**: 2024

