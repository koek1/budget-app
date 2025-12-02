# SpendSense - Budget Management App

A modern, full-stack budgeting application built with Flutter (frontend) and Node.js/Express (backend) to help users plan and track their monthly spending. The app features local-first storage, biometric authentication, dark mode support, and comprehensive financial reporting.

##  Features

### Core Functionality
- **User Authentication**: Secure registration and login system
- **Biometric Authentication**: Fingerprint/Face ID support for quick and secure login
- **Transaction Management**: Add, edit, and delete income and expense transactions
- **Financial Dashboard**: Real-time overview of income, expenses, and net balance
- **Statistics & Analytics**: Visual charts and insights into spending patterns
- **Data Export**: Export transactions to CSV with date range filtering and summary reports
- **Offline Support**: Full functionality without internet connection using local storage

### User Experience
- **Dark Mode**: Beautiful dark theme with automatic theme switching
- **Multi-Currency Support**: Support for multiple currencies (ZAR, USD, GBP, EUR)
- **Category Management**: Organize transactions by categories
- **Date Range Filtering**: Filter transactions and reports by custom date ranges
- **Responsive Design**: Modern Material Design 3 UI with smooth animations
- **App Lifecycle Security**: Automatic logout when app goes to background

##  Tech Stack

### Frontend
- **Flutter** (v3.0+) - Cross-platform mobile framework
- **Hive** - Fast, lightweight local NoSQL database
- **Flutter Secure Storage** - Secure credential storage
- **Local Auth** - Biometric authentication (fingerprint/Face ID)
- **FL Chart** - Beautiful charts and graphs
- **Google Fonts** - Custom typography (Poppins)
- **Open File** - File system access for exports
- **Path Provider** - File system paths
- **HTTP** - API communication (for backend integration)

### Backend
- **Node.js** - JavaScript runtime
- **Express.js** - Web framework
- **File Storage** - JSON-based local file storage (no database required)
- **ExcelJS** - Excel file generation
- **JWT** - Token-based authentication
- **bcryptjs** - Password hashing
- **CORS** - Cross-origin resource sharing

##  Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v14 or higher) - [Download](https://nodejs.org/)
- **Flutter SDK** (v3.0 or higher) - [Download](https://flutter.dev/docs/get-started/install)
- **Git** - Version control

**For Android Development:**
- **Android Studio** - [Download](https://developer.android.com/studio)
- **Android SDK** (API level 21+)
- **Java Development Kit (JDK)**

**For iOS Development:**
- **macOS** (required for iOS development)
- **Xcode** (latest version) - [Download from App Store](https://apps.apple.com/us/app/xcode/id497799835)
- **CocoaPods** - Install via: `sudo gem install cocoapods`
- **Apple Developer Account** (for device testing and App Store distribution)

##  Setup Instructions

### Backend Setup

1. **Navigate to the backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Create a `.env` file** in the `backend` directory:
   ```env
   PORT=5000
   JWT_SECRET=your-secret-key-here-change-in-production
   ```
   > **Note**: The app uses local file storage, so no MongoDB connection string is needed.

4. **Start the backend server:**
   ```bash
   # Development mode (with auto-reload)
   npm run dev

   # Production mode
   npm start
   ```

   The backend will run on `http://localhost:5000` and automatically create a `data/` directory for storing JSON files.

### Frontend Setup

1. **Navigate to the frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Generate Hive type adapters:**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Update API URL (if needed):**
   - The app primarily uses local storage (Hive), but the backend API is available for optional features
   - For Android Emulator: `http://10.0.2.2:5000/api`
   - For iOS Simulator: `http://localhost:5000/api`
   - For Physical Device: Use your computer's IP address (e.g., `http://192.168.1.100:5000/api`)
   - Update in `lib/services/api_service.dart` if needed

5. **iOS-Specific Setup (for iOS development):**
   ```bash
   # Install CocoaPods dependencies (required for iOS)
   cd ios
   pod install
   cd ..
   ```

   **Note**: iOS development requires:
   - macOS with Xcode installed
   - Apple Developer account (for device testing and App Store)
   - iOS Simulator or physical iOS device

6. **Generate app icons (optional):**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

7. **Run the app:**
   ```bash
   # List available devices
   flutter devices

   # Run on a specific device
   flutter run -d <device-id>

   # Or simply run (will use default device)
   flutter run

   # For iOS specifically
   flutter run -d ios

   # For Android specifically
   flutter run -d android
   ```

##  Platform-Specific Notes

### Android
- Minimum SDK: 21 (Android 5.0)
- Biometric authentication: Fingerprint and Face Unlock
- File export: Downloads directory
- Tested on Android 5.0+

### iOS
- Minimum iOS version: 12.0
- Biometric authentication: Face ID and Touch ID
- File export: Files app integration
- Requires Xcode for building
- Tested on iOS 12.0+

##  Project Structure

```
budget-app/
├── backend/
│   ├── controllers/          # Business logic controllers
│   │   ├── authController.js
│   │   └── transactionController.js
│   ├── middleware/            # Express middleware
│   │   └── auth.js            # JWT authentication middleware
│   ├── models/                # Data models
│   │   ├── User.js
│   │   └── Transaction.js
│   ├── routes/                # API route handlers
│   │   ├── auth.js            # Authentication routes
│   │   ├── transactions.js   # Transaction CRUD routes
│   │   └── export.js          # Excel export routes
│   ├── storage/               # Storage abstraction layer
│   │   └── fileStorage.js     # JSON file-based storage
│   ├── data/                  # Data storage (auto-created)
│   │   ├── users.json         # User accounts
│   │   └── transactions.json  # All transactions
│   ├── server.js              # Express server entry point
│   └── package.json
│
└── frontend/
    ├── lib/
    │   ├── main.dart          # App entry point
    │   ├── app.dart           # Main app widget with theme & lifecycle
    │   ├── models/             # Data models
    │   │   ├── transaction.dart
    │   │   ├── transaction.g.dart
    │   │   ├── user.dart
    │   │   └── user.g.dart
    │   ├── screens/            # UI screens
    │   │   ├── auth/
    │   │   │   ├── login_screen.dart
    │   │   │   └── register_screen.dart
    │   │   ├── home/
    │   │   │   ├── home_screen.dart
    │   │   │   ├── dashboard_screen.dart
    │   │   │   └── add_transaction_screen.dart
    │   │   ├── transactions/
    │   │   │   └── transactions_screen.dart
    │   │   ├── stats/
    │   │   │   └── stats_screen.dart
    │   │   ├── export/
    │   │   │   └── export_screen.dart
    │   │   └── settings/
    │   │       └── settings_screen.dart
    │   ├── services/           # Business logic services
    │   │   ├── auth_service.dart
    │   │   ├── biometric_service.dart
    │   │   ├── local_storage_service.dart
    │   │   ├── export_service.dart
    │   │   └── settings_service.dart
    │   ├── widgets/            # Reusable UI components
    │   │   ├── budget_card.dart
    │   │   ├── transaction_card.dart
    │   │   ├── category_chip.dart
    │   │   └── date_range_picker.dart
    │   └── utils/              # Helper utilities
    │       ├── constants.dart
    │       └── helpers.dart
    ├── images/                 # App assets
    │   └── logo.png
    ├── android/                # Android-specific files
    ├── pubspec.yaml            # Flutter dependencies
    └── analysis_options.yaml   # Dart analyzer config
```

##  Security Features

### Authentication & Authorization
- **Password-based Authentication**: Secure user registration and login
- **Biometric Authentication**: Optional fingerprint/Face ID login for convenience
- **Secure Credential Storage**: Biometric credentials stored using Flutter Secure Storage
- **JWT Tokens**: Backend uses JWT for API authentication
- **Session Management**: User sessions managed securely

### App Lifecycle Security
- **Automatic Logout**: App automatically logs out users when the app goes to background
- **Login Required on Resume**: Users must re-authenticate when app resumes from background
- **No Persistent Sessions**: Sessions do not persist across app restarts for enhanced security

### Data Security
- **Local-First Storage**: All sensitive data stored locally on device
- **User Data Isolation**: Each user's transactions are isolated by userId
- **Secure Storage**: Credentials stored using platform-native secure storage

## 📡 API Endpoints

The backend provides RESTful API endpoints (though the app primarily uses local storage):

### Authentication
- `POST /api/auth/register` - Register a new user
  ```json
  {
    "username": "string",
    "password": "string"
  }
  ```

- `POST /api/auth/login` - Login user
  ```json
  {
    "username": "string",
    "password": "string"
  }
  ```

### Transactions
- `GET /api/transactions` - Get all transactions (requires auth)
- `POST /api/transactions` - Create a new transaction (requires auth)
- `PUT /api/transactions/:id` - Update a transaction (requires auth)
- `DELETE /api/transactions/:id` - Delete a transaction (requires auth)

### Export
- `POST /api/export/excel` - Generate Excel report (requires auth)
- `GET /api/export/summary` - Get report summary (requires auth)

##  Features in Detail

### Biometric Authentication
- Supports fingerprint sensors, Face ID, and other biometric methods
- Credentials stored securely using Flutter Secure Storage
- Automatic biometric login on app startup (if enabled)
- Can be enabled/disabled from settings
- Falls back to password authentication if biometric fails

### Dark Mode
- Beautiful dark theme with custom color scheme
- Automatic theme switching based on user preference
- Theme preference persisted across app restarts
- Smooth transitions between light and dark modes

### Data Export
- Export transactions to CSV format
- Filter by date range
- Filter by transaction type (income/expense/all)
- Includes summary statistics (total income, expenses, net)
- Automatically opens exported file

### Statistics & Analytics
- Visual charts showing spending patterns
- Category-wise breakdown
- Income vs expense comparison
- Monthly/weekly/daily views

##  Testing

### Backend Testing
```bash
cd backend
npm test  # If tests are configured
```

### Frontend Testing
```bash
cd frontend
flutter test
```

##  Troubleshooting

### Common Issues

1. **MongoDB Connection Error**
   -  **Solution**: The app no longer uses MongoDB. It uses local file storage. Ensure the `backend/data/` directory is writable.

2. **Flutter Build Errors**
   ```bash
   flutter clean
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Hive Adapter Generation Errors**
   ```bash
   cd frontend
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **API Connection Issues**
   - The app primarily uses local storage (Hive), so API connection is optional
   - If using backend features, ensure backend is running on port 5000
   - Check API URL in `lib/services/api_service.dart` if needed

5. **Biometric Authentication Not Working**
   - Ensure device has biometric hardware (fingerprint sensor/Face ID)
   - Check that biometric permissions are granted in device settings
   - For Android: Verify `AndroidManifest.xml` includes biometric permissions
   - For iOS: Ensure `Info.plist` includes `NSFaceIDUsageDescription` key
   - Try disabling and re-enabling biometric login from settings

6. **Excel Export Not Working**
   - The app exports CSV files, not Excel files
   - Ensure device has file access permissions
   - Check that `open_file` package is properly installed
   - Verify downloads directory is accessible

7. **Data Not Persisting**
   - Ensure Hive boxes are properly initialized in `main.dart`
   - Check that app has storage permissions
   - Try clearing app data and re-registering

8. **App Logs Out Automatically**
   - This is by design for security
   - App logs out when going to background
   - Users must re-authenticate when app resumes

##  Development Notes

### Local Storage Architecture
- **Frontend**: Uses Hive for all data storage (users, transactions, settings)
- **Backend**: Uses JSON file-based storage in `backend/data/` directory
- **No Database Required**: The app works entirely offline with local storage
- **Data Persistence**: All data persists between app restarts

### Migration from MongoDB
The app was migrated from MongoDB to local file storage. See `MIGRATION_NOTES.md` for details.

##  License

ISC

##  Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

##  Support

For issues, questions, or feature requests, please open an issue on the repository.

---
