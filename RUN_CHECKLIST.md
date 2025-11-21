# Pre-Run Checklist ✅

Use this checklist before running your app to ensure everything is set up correctly.

## Backend Checklist

- [x] **Dependencies installed**: `npm install` completed
- [x] **ExcelJS package**: Installed (v4.4.0) ✓
- [ ] **`.env` file created**: Create in `backend/` folder with:
  ```env
  MONGODB_URI=mongodb://localhost:27017/budget_app
  PORT=5000
  JWT_SECRET=your-secret-key-here
  ```
- [ ] **MongoDB running**: 
  - Local: Check MongoDB service is running
  - Atlas: Connection string in `.env` is correct
- [ ] **Export route registered**: ✓ Already in `server.js` (line 15)
- [ ] **Server starts**: Run `npm run dev` in `backend/` folder

## Frontend Checklist

- [x] **Dependencies installed**: `flutter pub get` completed ✓
- [x] **All packages available**: 
  - `open_file` ✓
  - `path_provider` ✓
  - `intl` ✓
  - `http` ✓
- [ ] **API URL configured**: Check `lib/services/api_service.dart`
  - Android Emulator: `http://10.0.2.2:5000/api` (default) ✓
  - iOS Simulator: Change to `http://localhost:5000/api`
  - Physical Device: Use computer's IP address
- [ ] **Imports verified**: All imports are correct ✓
- [ ] **App runs**: Run `flutter run` in `frontend/` folder

## Code Verification

- [x] **Export route**: `backend/routes/export.js` exists and is complete
- [x] **Export service**: `frontend/lib/services/export_service.dart` has correct Content-Type header
- [x] **Export screen**: `frontend/lib/screens/export/export_screen.dart` has all imports
- [x] **Date picker widget**: `frontend/lib/widgets/date_range_picker.dart` exists
- [x] **Home screen**: Export button added to AppBar
- [x] **Server routes**: Export route registered in `server.js`

## Testing Steps

1. **Start Backend:**
   ```bash
   cd backend
   npm run dev
   ```
   Expected: "Server running on port 5000" and "MongoDB connected"

2. **Start Frontend (new terminal):**
   ```bash
   cd frontend
   flutter run
   ```

3. **Test Flow:**
   - [ ] Register/Login works
   - [ ] Can view dashboard
   - [ ] Can add transactions
   - [ ] Click export icon (chart/assessment icon) in top-right
   - [ ] Export screen opens
   - [ ] Date range picker works
   - [ ] Report type dropdown works
   - [ ] Summary preview loads
   - [ ] Export to Excel button works
   - [ ] Excel file downloads and opens

## Quick Commands Reference

### Backend
```bash
cd backend
npm install          # Install dependencies
npm run dev          # Start development server
npm start            # Start production server
```

### Frontend
```bash
cd frontend
flutter pub get      # Install dependencies
flutter clean        # Clean build
flutter run          # Run app
flutter devices      # List available devices
```

## Troubleshooting Quick Fixes

**Backend won't start:**
- Check MongoDB is running
- Verify `.env` file exists
- Check port 5000 is not in use

**Frontend can't connect:**
- Verify backend is running
- Check API URL in `api_service.dart`
- For physical device: Use computer's IP, not localhost

**Excel export fails:**
- Check backend logs
- Verify `exceljs` is installed: `npm list exceljs`
- Check device file permissions

**Flutter build errors:**
```bash
flutter clean
flutter pub get
flutter run
```

## Project Status: ✅ READY TO RUN

All code is organized and ready. Just complete the checklist items above and you're good to go!

