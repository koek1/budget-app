# Migration to Local Storage

This app has been successfully migrated from MongoDB cloud storage to local file-based storage.

## Backend Changes

1. **Removed MongoDB**: The backend now uses JSON file-based storage instead of MongoDB
2. **New Storage System**: Created `backend/storage/fileStorage.js` for file-based data persistence
3. **Updated Models**: `User.js` and `Transaction.js` now use the file storage system
4. **Data Location**: Data is stored in `backend/data/` directory as JSON files

## Frontend Changes

1. **Removed API Dependencies**: The frontend now uses only Hive for local storage
2. **New Local Storage Service**: Created `frontend/lib/services/local_storage_service.dart`
3. **Updated Authentication**: Auth now works entirely locally using Hive
4. **Removed Sync Service**: No longer needed since everything is local
5. **Export Service**: Updated to work with local data (exports as CSV)

## Setup Instructions

### Backend
1. Install dependencies:
   ```bash
   cd backend
   npm install
   ```

2. The backend will automatically create a `data/` directory for storing JSON files

3. Start the server:
   ```bash
   npm start
   ```

### Frontend
1. Install dependencies:
   ```bash
   cd frontend
   flutter pub get
   ```

2. Generate Hive adapters:
   ```bash
   flutter pub run build_runner build
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Data Storage

- **Backend**: JSON files in `backend/data/` directory
  - `users.json` - User accounts
  - `transactions.json` - All transactions

- **Frontend**: Hive boxes (local device storage)
  - `userBox` - Current user session
  - `usersBox` - All registered users
  - `transactionsBox` - All transactions

## Notes

- All data is now stored locally
- No internet connection required
- Data persists between app restarts
- Each device has its own independent data
- Export functionality now generates CSV files instead of Excel

