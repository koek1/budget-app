# Migration to Local Storage

This document describes the migration of SpendSense from MongoDB cloud storage to local file-based storage. This migration enables offline-first functionality and removes the dependency on external database services.

## Overview

The app has been successfully migrated from MongoDB cloud storage to a local-first architecture using:
- **Backend**: JSON file-based storage (`backend/storage/fileStorage.js`)
- **Frontend**: Hive local database (`lib/services/local_storage_service.dart`)

## Migration Benefits

- ✅ **Offline-First**: Full functionality without internet connection
- ✅ **No Database Required**: No need for MongoDB installation or cloud services
- ✅ **Faster Performance**: Local storage is faster than network requests
- ✅ **Data Privacy**: All data stored locally on device
- ✅ **Simplified Setup**: Easier deployment and setup process

## Backend Changes

### Removed Components
- MongoDB connection and Mongoose models
- MongoDB URI configuration
- Database connection middleware

### New Components
1. **File Storage System** (`backend/storage/fileStorage.js`)
   - JSON file-based storage abstraction
   - MongoDB-like API for consistency
   - Automatic file creation and management

2. **Updated Models**
   - `User.js`: Now uses FileStorage instead of Mongoose
   - `Transaction.js`: Now uses FileStorage instead of Mongoose

3. **Data Storage Location**
   - Data stored in `backend/data/` directory (auto-created)
   - `users.json`: User accounts
   - `transactions.json`: All transactions

### Migration Steps for Backend

1. **Install dependencies** (no MongoDB packages needed):
   ```bash
   cd backend
   npm install
   ```

2. **Update `.env` file** (remove MongoDB URI):
   ```env
   PORT=5000
   JWT_SECRET=your-secret-key-here
   # MONGODB_URI removed - no longer needed
   ```

3. **Start the server**:
   ```bash
   npm start
   # or for development
   npm run dev
   ```

4. **Data Migration** (if migrating existing data):
   - Export data from MongoDB
   - Convert to JSON format
   - Place in `backend/data/` directory

## Frontend Changes

### Removed Components
- API service dependencies (mostly)
- Cloud sync functionality
- Network-based authentication

### New Components
1. **Local Storage Service** (`lib/services/local_storage_service.dart`)
   - Hive-based data operations
   - User session management
   - Transaction CRUD operations
   - Data filtering and querying

2. **Updated Services**
   - `AuthService`: Now uses Hive for user management
   - `ExportService`: Works with local Hive data (exports as CSV)
   - Removed sync service (no longer needed)

3. **Hive Storage Boxes**
   - `userBox`: Current user session
   - `usersBox`: All registered users
   - `transactionsBox`: All transactions
   - `settingsBox`: App settings (currency, theme)

### Migration Steps for Frontend

1. **Install dependencies**:
   ```bash
   cd frontend
   flutter pub get
   ```

2. **Generate Hive adapters**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

## Data Storage Architecture

### Backend Storage
- **Location**: `backend/data/` directory
- **Format**: JSON files
- **Files**:
  - `users.json`: Array of user objects
  - `transactions.json`: Array of transaction objects
- **Operations**: Read/write entire files (suitable for small to medium datasets)

### Frontend Storage
- **Location**: Device local storage (Hive)
- **Format**: Binary Hive database
- **Boxes**:
  - `userBox`: Current session data
  - `usersBox`: All user accounts
  - `transactionsBox`: All transactions (typed with Transaction model)
  - `settingsBox`: App preferences
- **Operations**: Fast key-value operations with reactive listeners

## Data Migration Guide

If you have existing data in MongoDB that needs to be migrated:

### Export from MongoDB
```bash
mongoexport --db budget_app --collection users --out users.json
mongoexport --db budget_app --collection transactions --out transactions.json
```

### Convert to File Storage Format
1. Ensure JSON files are valid arrays
2. Place in `backend/data/` directory
3. Restart backend server

### Frontend Data Migration
- Frontend data is device-specific
- Users will need to re-register or manually import data
- Consider implementing an import feature for CSV/JSON data

## Breaking Changes

1. **No Cloud Sync**: Data is now device-specific
2. **Export Format**: Changed from Excel to CSV
3. **API Usage**: Backend API is optional (app works entirely offline)
4. **User Accounts**: Each device has independent user accounts

## Compatibility Notes

- **Backward Compatibility**: Not maintained - fresh install recommended
- **Data Format**: New data format incompatible with old MongoDB format
- **User Migration**: Users need to re-register on each device

## Performance Considerations

### Advantages
- Faster data access (local storage)
- No network latency
- Works offline

### Limitations
- File-based storage suitable for small to medium datasets
- Entire file read/write operations
- Consider database migration for larger datasets

## Future Improvements

1. **Optional Cloud Sync**: Add cloud backup/sync feature
2. **Database Migration**: Consider SQLite for better performance
3. **Data Import/Export**: Add backup and restore functionality
4. **Multi-Device Sync**: Sync across multiple devices

## Troubleshooting

### Backend Issues
- **File Permissions**: Ensure `backend/data/` directory is writable
- **File Corruption**: Delete JSON files and restart (data will be recreated)
- **Concurrent Access**: File storage handles one operation at a time

### Frontend Issues
- **Hive Errors**: Run `flutter clean` and regenerate adapters
- **Data Loss**: Data is stored locally - clearing app data removes all data
- **Migration Errors**: Clear app data and start fresh if needed

## Notes

- ✅ All data is now stored locally
- ✅ No internet connection required
- ✅ Data persists between app restarts
- ✅ Each device has its own independent data
- ✅ Export functionality generates CSV files
- ✅ Backend API still available for optional features
- ⚠️ Data is device-specific (no cloud sync)
- ⚠️ Users must re-register on each device

---

**Migration Date**: 2024  
**Status**: ✅ Complete

