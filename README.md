# Budget App (SpendSense)

A full-stack budgeting application built with Flutter (frontend) and Node.js/Express (backend) to help plan and track monthly money spending.

## Features

- User authentication (Register/Login)
- Biometric authentication (Fingerprint/Face ID) for secure and quick login
- Transaction management (Income/Expenses)
- Dashboard with financial overview
- Excel export functionality with date range filtering
- Report generation with summary preview
- Offline support with local storage

## Tech Stack

### Frontend
- Flutter
- Hive (local storage)
- HTTP (API calls)
- Open File (for opening exported Excel files)
- Local Auth (biometric authentication)
- Flutter Secure Storage (secure credential storage)

### Backend
- Node.js
- Express.js
- MongoDB with Mongoose
- ExcelJS (for Excel file generation)
- JWT authentication

## Setup Instructions

### Prerequisites
- Node.js (v14 or higher)
- MongoDB (local installation or MongoDB Atlas)
- Flutter SDK (v3.0 or higher)
- Android Studio / Xcode (for mobile development)

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file in the backend directory:
```env
MONGODB_URI=mongodb://localhost:27017/budget_app
PORT=5000
JWT_SECRET=your-secret-key-here-change-in-production
```

4. Start the backend server:
```bash
# Development mode (with auto-reload)
npm run dev

# Production mode
npm start
```

The backend will run on `http://localhost:5000`

### Frontend Setup

1. Navigate to the frontend directory:
```bash
cd frontend
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Update API URL (if needed):
   - For Android Emulator: `http://10.0.2.2:5000/api` (already configured)
   - For iOS Simulator: `http://localhost:5000/api`
   - For Physical Device: Use your computer's IP address (e.g., `http://192.168.1.100:5000/api`)
   - Update in `lib/services/api_service.dart`

4. Run the app:
```bash
# For Android
flutter run

# For iOS
flutter run

# For specific device
flutter devices  # List available devices
flutter run -d <device-id>
```

## Project Structure

```
budget-app/
├── backend/
│   ├── controllers/      # Business logic
│   ├── middleware/       # Auth middleware
│   ├── models/           # MongoDB models
│   ├── routes/           # API routes
│   │   ├── auth.js
│   │   ├── transactions.js
│   │   └── export.js     # Excel export routes
│   ├── server.js         # Express server
│   └── package.json
│
└── frontend/
    ├── lib/
    │   ├── screens/      # UI screens
    │   │   ├── auth/
    │   │   ├── home/
    │   │   ├── transactions/
    │   │   └── export/   # Export screen
    │   ├── services/     # API services
    │   ├── widgets/      # Reusable widgets
    │   ├── models/       # Data models
    │   └── utils/        # Helpers
    └── pubspec.yaml
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user

### Biometric Authentication
The app supports biometric authentication (fingerprint/Face ID) for quick and secure login:
- Users can enable biometric login after successful password authentication
- Biometric credentials are stored securely using Flutter Secure Storage
- Automatic biometric login on app startup (if enabled)
- Works with fingerprint sensors, Face ID, and other supported biometric methods

### Transactions
- `GET /api/transactions` - Get all transactions
- `POST /api/transactions` - Create transaction
- `PUT /api/transactions/:id` - Update transaction
- `DELETE /api/transactions/:id` - Delete transaction

### Export
- `POST /api/export/excel` - Generate Excel report
- `GET /api/export/summary` - Get report summary

## Testing

### Backend
```bash
cd backend
npm test  # If tests are configured
```

### Frontend
```bash
cd frontend
flutter test
```

## Troubleshooting

1. **MongoDB Connection Error**: Ensure MongoDB is running locally or update `MONGODB_URI` in `.env`
2. **Flutter Build Errors**: Run `flutter clean` then `flutter pub get`
3. **API Connection Issues**: Check that backend is running and verify the API URL in `api_service.dart`
4. **Excel Export Not Working**: Ensure `open_file` package is properly installed and device has file access permissions
5. **Biometric Authentication Not Working**: 
   - Ensure device has biometric hardware (fingerprint sensor/Face ID)
   - Check that biometric permissions are granted in device settings
   - For Android: Verify `AndroidManifest.xml` includes biometric permissions
   - For iOS: Ensure `Info.plist` includes `NSFaceIDUsageDescription` key

## License

ISC
