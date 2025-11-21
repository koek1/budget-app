# Quick Setup Guide

## Backend Setup (5 minutes)

1. **Install dependencies:**
   ```bash
   cd backend
   npm install
   ```

2. **Create `.env` file:**
   Create a file named `.env` in the `backend` folder with:
   ```env
   MONGODB_URI=mongodb://localhost:27017/budget_app
   PORT=5000
   JWT_SECRET=your-secret-key-change-this-in-production
   ```

3. **Start MongoDB:**
   - If using local MongoDB: Make sure MongoDB service is running
   - If using MongoDB Atlas: Update `MONGODB_URI` in `.env` with your connection string

4. **Start the server:**
   ```bash
   npm run dev
   ```
   You should see: "Server running on port 5000" and "MongoDB connected"

## Frontend Setup (5 minutes)

1. **Install Flutter dependencies:**
   ```bash
   cd frontend
   flutter pub get
   ```

2. **Configure API URL (if needed):**
   - Open `lib/services/api_service.dart`
   - For Android Emulator: Already set to `http://10.0.2.2:5000/api` ✓
   - For iOS Simulator: Change to `http://localhost:5000/api`
   - For Physical Device: Use your computer's IP (e.g., `http://192.168.1.100:5000/api`)

3. **Run the app:**
   ```bash
   flutter run
   ```

## Testing the App

1. **Start Backend:**
   ```bash
   cd backend
   npm run dev
   ```

2. **Start Frontend (in a new terminal):**
   ```bash
   cd frontend
   flutter run
   ```

3. **Test Export Feature:**
   - Login/Register in the app
   - Click the chart/assessment icon in the top-right
   - Select date range
   - Choose report type
   - Click "Export to Excel"
   - File should download and open automatically

## Common Issues

### Backend won't start
- Check if MongoDB is running: `mongod --version`
- Verify `.env` file exists and has correct values
- Check if port 5000 is already in use

### Frontend can't connect to backend
- Verify backend is running on port 5000
- Check API URL in `api_service.dart` matches your setup
- For physical device: Ensure phone and computer are on same network

### Excel export not working
- Check backend logs for errors
- Verify `exceljs` package is installed: `npm list exceljs`
- Check device file permissions

### Flutter build errors
```bash
cd frontend
flutter clean
flutter pub get
flutter run
```

## Project Structure

```
budget-app/
├── backend/          # Node.js/Express API
│   ├── routes/       # API endpoints (auth, transactions, export)
│   ├── models/       # MongoDB models
│   └── server.js     # Main server file
│
└── frontend/         # Flutter app
    └── lib/
        ├── screens/   # UI screens
        ├── services/  # API services
        └── widgets/   # Reusable components
```

## Next Steps

- Add more transaction categories
- Implement budget limits
- Add charts and graphs
- Export to PDF
- Multi-currency support

