# SpendSense Architecture Documentation

This document provides a detailed overview of the SpendSense application architecture, including data flow, storage mechanisms, and component interactions.

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Patterns](#architecture-patterns)
3. [Data Storage](#data-storage)
4. [Authentication Flow](#authentication-flow)
5. [Component Architecture](#component-architecture)
6. [Security Architecture](#security-architecture)
7. [App Lifecycle Management](#app-lifecycle-management)

## System Overview

SpendSense is a local-first budgeting application with the following characteristics:

- **Local-First Architecture**: All data is stored locally on the device
- **Offline-First**: Full functionality without internet connection
- **Multi-User Support**: Each device can have multiple user accounts
- **Secure by Default**: Automatic logout, biometric authentication, secure storage

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Frontend                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  UI      │  │ Services │  │  Models  │  │  Hive    │ │
│  │ Screens  │→ │  Layer   │→ │  Layer   │→ │ Storage  │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
└─────────────────────────────────────────────────────────┘
                              │
                              │ (Optional API calls)
                              ▼
┌─────────────────────────────────────────────────────────┐
│                  Node.js/Express Backend                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  Routes  │→ │Controllers│→ │  File    │              │
│  │          │  │          │  │ Storage  │              │
│  └──────────┘  └──────────┘  └──────────┘              │
└─────────────────────────────────────────────────────────┘
```

## Architecture Patterns

### Frontend Patterns

1. **Service Layer Pattern**
   - Business logic separated into service classes
   - Services handle data operations, authentication, and external integrations
   - Examples: `AuthService`, `LocalStorageService`, `BiometricService`

2. **Repository Pattern** (Implicit)
   - `LocalStorageService` acts as a repository for data access
   - Abstracts Hive storage implementation
   - Provides clean API for data operations

3. **State Management**
   - Uses Flutter's built-in state management (StatefulWidget, setState)
   - Hive's reactive listeners for automatic UI updates
   - ValueListenableBuilder for reactive UI components

4. **Widget Composition**
   - Reusable widgets in `lib/widgets/`
   - Screen-based organization in `lib/screens/`
   - Separation of concerns between UI and business logic

### Backend Patterns

1. **MVC Pattern**
   - **Models**: Data structures (`User.js`, `Transaction.js`)
   - **Views**: JSON API responses
   - **Controllers**: Business logic (`authController.js`, `transactionController.js`)

2. **Middleware Pattern**
   - Authentication middleware for protected routes
   - CORS middleware for cross-origin requests
   - Request validation middleware

3. **Storage Abstraction**
   - `FileStorage` class abstracts file operations
   - Can be easily swapped for database storage
   - Provides MongoDB-like API for consistency

## Data Storage

### Frontend Storage (Hive)

Hive is a fast, lightweight NoSQL database for Flutter. The app uses multiple Hive boxes:

#### Storage Boxes

1. **`userBox`** - Current user session
   ```dart
   {
     'userId': String,
     'user': User (JSON)
   }
   ```

2. **`usersBox`** - All registered users
   ```dart
   [
     User (JSON),
     User (JSON),
     ...
   ]
   ```

3. **`transactionsBox`** - All transactions
   ```dart
   [
     Transaction (HiveObject),
     Transaction (HiveObject),
     ...
   ]
   ```

4. **`settingsBox`** - App settings
   ```dart
   {
     'currency': String,
     'themeMode': String ('light' | 'dark')
   }
   ```

#### Data Models

- **User Model**: `lib/models/user.dart`
  - Fields: `id`, `name`, `email`, `password`, `currency`, `monthlyBudget`
  - Hive Type ID: 1

- **Transaction Model**: `lib/models/transaction.dart`
  - Fields: `id`, `userId`, `amount`, `type`, `category`, `description`, `date`, `isSynced`
  - Hive Type ID: 0

### Backend Storage (File-Based)

The backend uses JSON file storage in `backend/data/`:

#### Storage Files

1. **`users.json`** - User accounts
   ```json
   [
     {
       "_id": "string",
       "name": "string",
       "email": "string",
       "password": "hashed",
       "currency": "string",
       "monthlyBudget": number,
       "createdAt": "ISO string",
       "updatedAt": "ISO string"
     }
   ]
   ```

2. **`transactions.json`** - All transactions
   ```json
   [
     {
       "_id": "string",
       "userId": "string",
       "amount": number,
       "type": "income" | "expense",
       "category": "string",
       "description": "string",
       "date": "ISO string",
       "createdAt": "ISO string",
       "updatedAt": "ISO string"
     }
   ]
   ```

#### FileStorage API

The `FileStorage` class provides MongoDB-like methods:

- `read()` - Read entire file
- `write(data)` - Write data to file
- `find(query)` - Find items matching query
- `findOne(query)` - Find first matching item
- `findById(id)` - Find item by ID
- `create(item)` - Create new item
- `update(id, updates)` - Update item
- `delete(id)` - Delete item

## Authentication Flow

### Registration Flow

```
User Input → AuthService.register()
    ↓
Validate Input
    ↓
Check Duplicate Username
    ↓
Create User Object
    ↓
Save to usersBox (Hive)
    ↓
Return User (no auto-login)
```

### Login Flow

```
User Input → AuthService.login()
    ↓
Validate Input
    ↓
Search usersBox for username
    ↓
Verify Password
    ↓
Save to userBox (session)
    ↓
Return User
```

### Biometric Login Flow

```
App Startup → Check Biometric Enabled
    ↓
BiometricService.isBiometricEnabled()
    ↓
Show Biometric Prompt
    ↓
BiometricService.authenticate()
    ↓
Get Saved Credentials (Secure Storage)
    ↓
AuthService.login() with credentials
    ↓
Save to userBox (session)
    ↓
Navigate to Home
```

### Logout Flow

```
User Action / App Background → AuthService.logout()
    ↓
LocalStorageService.clearUser()
    ↓
Clear userBox
    ↓
Navigate to Login Screen
```

## Component Architecture

### Frontend Components

#### Services Layer

1. **AuthService** (`lib/services/auth_service.dart`)
   - User registration
   - User login/logout
   - Session management
   - User validation

2. **LocalStorageService** (`lib/services/local_storage_service.dart`)
   - Transaction CRUD operations
   - User session management
   - Data filtering and querying
   - Data clearing utilities

3. **BiometricService** (`lib/services/biometric_service.dart`)
   - Biometric availability checking
   - Biometric authentication
   - Credential storage/retrieval
   - Biometric login flow

4. **ExportService** (`lib/services/export_service.dart`)
   - CSV file generation
   - Date range filtering
   - Report summary generation
   - File system operations

5. **SettingsService** (`lib/services/settings_service.dart`)
   - Theme mode management
   - Currency preference management
   - Settings persistence

#### Screen Components

1. **Auth Screens**
   - `LoginScreen`: User authentication
   - `RegisterScreen`: New user registration

2. **Home Screens**
   - `HomeScreen`: Main navigation hub
   - `DashboardScreen`: Financial overview
   - `AddTransactionScreen`: Transaction creation/editing

3. **Feature Screens**
   - `TransactionsScreen`: Transaction list and management
   - `StatsScreen`: Analytics and charts
   - `ExportScreen`: Data export functionality
   - `SettingsScreen`: App configuration

#### Widget Components

- `BudgetCard`: Financial summary card
- `TransactionCard`: Individual transaction display
- `CategoryChip`: Category selection widget
- `DateRangePicker`: Date range selection

### Backend Components

#### Controllers

1. **authController.js**
   - User registration
   - User login
   - JWT token generation
   - Password hashing

2. **transactionController.js**
   - Transaction CRUD operations
   - User-specific transaction filtering
   - Transaction validation

#### Routes

1. **auth.js** - Authentication endpoints
2. **transactions.js** - Transaction endpoints
3. **export.js** - Export endpoints

#### Middleware

1. **auth.js** - JWT token verification
   - Validates JWT tokens
   - Attaches user info to request
   - Protects routes

## Security Architecture

### Authentication Security

1. **Password Storage**
   - Backend: Passwords hashed with bcryptjs
   - Frontend: Passwords stored in plain text (local only, not recommended for production)

2. **Session Management**
   - Sessions stored in Hive `userBox`
   - No persistent sessions across app restarts
   - Automatic logout on app background

3. **Biometric Security**
   - Credentials stored in Flutter Secure Storage
   - Platform-native secure storage (Keychain/Keystore)
   - Biometric authentication required before credential access

### Data Security

1. **User Data Isolation**
   - All transactions filtered by `userId`
   - Users cannot access other users' data
   - User-specific queries enforced

2. **Secure Storage**
   - Biometric credentials in Flutter Secure Storage
   - Platform-encrypted storage
   - No plain text credentials in app storage

3. **API Security**
   - JWT tokens for backend API
   - Token expiration
   - Protected routes with auth middleware

### App Lifecycle Security

1. **Background Logout**
   - App logs out when going to background
   - Prevents unauthorized access if device is unlocked
   - User must re-authenticate on resume

2. **Session Validation**
   - Login status checked on app resume
   - Automatic navigation to login if not authenticated
   - Prevents session hijacking

## App Lifecycle Management

### Lifecycle States

The app uses `WidgetsBindingObserver` to monitor app lifecycle:

1. **Resumed**: App is visible and active
   - Check login status
   - Navigate to login if not authenticated

2. **Paused**: App is in background
   - Logout user automatically
   - Clear session

3. **Inactive**: App is transitioning
   - No action (avoids conflicts with lock screen)

### Lifecycle Flow

```
App Start → SplashScreen
    ↓
Check Login Status
    ↓
Navigate to LoginScreen
    ↓
User Authenticates
    ↓
Navigate to HomeScreen
    ↓
[App Goes to Background]
    ↓
Logout User
    ↓
[App Resumes]
    ↓
Check Login Status
    ↓
Navigate to LoginScreen (if not logged in)
```

### Implementation Details

The lifecycle management is implemented in `lib/app.dart`:

- `didChangeAppLifecycleState()`: Handles lifecycle changes
- `_logoutOnBackground()`: Logs out on pause
- `_checkAndNavigateToLogin()`: Validates session on resume
- Delay on resume to avoid conflicts with device lock screen

## Data Flow Examples

### Adding a Transaction

```
User Input (AddTransactionScreen)
    ↓
Form Validation
    ↓
Create Transaction Object
    ↓
LocalStorageService.addTransaction()
    ↓
Save to transactionsBox (Hive)
    ↓
Hive Listener Notifies UI
    ↓
UI Updates Automatically
```

### Exporting Data

```
User Selects Date Range (ExportScreen)
    ↓
ExportService.getReportSummary()
    ↓
LocalStorageService.getTransactionsByDateRange()
    ↓
Filter and Calculate Totals
    ↓
ExportService.exportToExcel()
    ↓
Generate CSV File
    ↓
Save to Downloads Directory
    ↓
Open File with OpenFile
```

## Performance Considerations

1. **Hive Performance**
   - Fast key-value storage
   - Efficient for small to medium datasets
   - Lazy loading of boxes

2. **File Storage Performance**
   - Entire file read/write (suitable for small datasets)
   - Consider database for larger datasets
   - File locking for concurrent access

3. **UI Performance**
   - ValueListenableBuilder for reactive updates
   - Efficient list rendering
   - Image caching

## Future Improvements

1. **Database Migration**: Consider SQLite for better performance
2. **Cloud Sync**: Optional cloud backup/sync
3. **Offline Queue**: Queue API calls for when online
4. **Data Encryption**: Encrypt sensitive data at rest
5. **Backup/Restore**: Export/import app data
6. **Multi-Device Sync**: Sync across multiple devices

---

**Last Updated**: 2024

