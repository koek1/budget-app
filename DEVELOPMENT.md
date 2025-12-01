# SpendSense Development Guide

This guide provides information for developers working on the SpendSense project, including setup, coding standards, testing, and contribution guidelines.

## Table of Contents

1. [Development Setup](#development-setup)
2. [Project Structure](#project-structure)
3. [Coding Standards](#coding-standards)
4. [Development Workflow](#development-workflow)
5. [Testing](#testing)
6. [Debugging](#debugging)
7. [Common Tasks](#common-tasks)
8. [Troubleshooting](#troubleshooting)

## Development Setup

### Prerequisites

- **Node.js** v14+ and npm
- **Flutter SDK** v3.0+
- **Git** for version control
- **VS Code** or **Android Studio** (recommended IDEs)
- **Android Studio** or **Xcode** for mobile development

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd budget-app
   ```

2. **Backend Setup:**
   ```bash
   cd backend
   npm install
   cp .env.example .env  # Create .env file if needed
   npm run dev  # Start development server
   ```

3. **Frontend Setup:**
   ```bash
   cd frontend
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure

### Frontend Structure

```
frontend/lib/
├── main.dart              # App entry point, Hive initialization
├── app.dart               # Main app widget, theme, lifecycle
├── models/                # Data models with Hive annotations
├── screens/               # UI screens organized by feature
│   ├── auth/
│   ├── home/
│   ├── transactions/
│   ├── stats/
│   ├── export/
│   └── settings/
├── services/              # Business logic services
├── widgets/               # Reusable UI components
└── utils/                 # Helper functions and constants
```

### Backend Structure

```
backend/
├── server.js              # Express server setup
├── controllers/           # Business logic
├── models/                # Data models
├── routes/                # API route handlers
├── middleware/            # Express middleware
├── storage/               # Storage abstraction
└── data/                  # JSON file storage (auto-created)
```

## Coding Standards

### Dart/Flutter Standards

1. **Naming Conventions:**
   - Files: `snake_case.dart`
   - Classes: `PascalCase`
   - Variables/Functions: `camelCase`
   - Constants: `lowerCamelCase` or `UPPER_SNAKE_CASE`

2. **Code Formatting:**
   ```bash
   flutter format .
   ```

3. **Linting:**
   ```bash
   flutter analyze
   ```

4. **File Organization:**
   - One class per file
   - Group imports: dart, package, relative
   - Use meaningful file names

5. **Widget Guidelines:**
   - Extract reusable widgets
   - Keep widgets small and focused
   - Use const constructors where possible
   - Prefer StatelessWidget when possible

### JavaScript/Node.js Standards

1. **Naming Conventions:**
   - Files: `camelCase.js`
   - Classes: `PascalCase`
   - Functions/Variables: `camelCase`
   - Constants: `UPPER_SNAKE_CASE`

2. **Code Formatting:**
   - Use 2 spaces for indentation
   - Use semicolons
   - Use single quotes for strings

3. **Error Handling:**
   - Always handle errors
   - Use try-catch blocks
   - Return appropriate HTTP status codes

## Development Workflow

### Feature Development

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes:**
   - Write code following coding standards
   - Add comments for complex logic
   - Update documentation if needed

3. **Test your changes:**
   ```bash
   # Frontend
   flutter test
   flutter analyze
   
   # Backend
   npm test  # If tests exist
   ```

4. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

5. **Push and create PR:**
   ```bash
   git push origin feature/your-feature-name
   ```

### Commit Message Convention

Use conventional commits:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting)
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

Example:
```
feat: add dark mode toggle in settings
fix: resolve transaction filtering issue
docs: update API documentation
```

## Testing

### Frontend Testing

1. **Unit Tests:**
   ```bash
   cd frontend
   flutter test
   ```

2. **Widget Tests:**
   - Test individual widgets
   - Mock dependencies
   - Test user interactions

3. **Integration Tests:**
   ```bash
   flutter test integration_test/
   ```

### Backend Testing

1. **Unit Tests:**
   ```bash
   cd backend
   npm test
   ```

2. **API Testing:**
   - Use Postman or curl
   - Test all endpoints
   - Test error cases

### Manual Testing Checklist

- [ ] User registration and login
- [ ] Biometric authentication
- [ ] Add/edit/delete transactions
- [ ] Dashboard displays correctly
- [ ] Statistics calculations
- [ ] Export functionality
- [ ] Dark mode toggle
- [ ] Currency selection
- [ ] App lifecycle (background/foreground)
- [ ] Data persistence

## Debugging

### Flutter Debugging

1. **Use Flutter DevTools:**
   ```bash
   flutter pub global activate devtools
   flutter pub global run devtools
   ```

2. **Print Debugging:**
   ```dart
   print('Debug message: $variable');
   debugPrint('Debug message');  // Better for production
   ```

3. **Breakpoints:**
   - Set breakpoints in VS Code or Android Studio
   - Use `debugger()` statement

4. **Hot Reload:**
   - Press `r` in terminal for hot reload
   - Press `R` for hot restart

### Backend Debugging

1. **Console Logging:**
   ```javascript
   console.log('Debug:', variable);
   console.error('Error:', error);
   ```

2. **Node Debugger:**
   ```bash
   node --inspect server.js
   ```

3. **Check Logs:**
   - Monitor server console output
   - Check error messages

## Common Tasks

### Adding a New Screen

1. Create screen file in `lib/screens/`:
   ```dart
   class NewScreen extends StatefulWidget {
     const NewScreen({super.key});
     
     @override
     State<NewScreen> createState() => _NewScreenState();
   }
   ```

2. Add route in navigation:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(builder: (context) => const NewScreen()),
   );
   ```

### Adding a New Service

1. Create service file in `lib/services/`:
   ```dart
   class NewService {
     static Future<void> doSomething() async {
       // Implementation
     }
   }
   ```

2. Use static methods for stateless services
3. Add error handling

### Adding a New Model

1. Create model file in `lib/models/`:
   ```dart
   import 'package:hive/hive.dart';
   
   part 'model.g.dart';
   
   @HiveType(typeId: 2)
   class NewModel extends HiveObject {
     @HiveField(0)
     final String id;
     
     // Add fields
   }
   ```

2. Generate Hive adapter:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. Register adapter in `main.dart`:
   ```dart
   Hive.registerAdapter(NewModelAdapter());
   ```

### Adding a New API Endpoint

1. Create route in `backend/routes/`:
   ```javascript
   router.post('/new-endpoint', auth, async (req, res) => {
     // Implementation
   });
   ```

2. Add route to `server.js`:
   ```javascript
   app.use('/api/new', require('./routes/new'));
   ```

3. Add controller logic if needed

### Updating Dependencies

**Frontend:**
```bash
cd frontend
flutter pub upgrade
flutter pub get
```

**Backend:**
```bash
cd backend
npm update
npm install
```

## Troubleshooting

### Common Issues

1. **Hive Adapter Errors:**
   ```bash
   flutter clean
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

2. **Build Errors:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Import Errors:**
   - Check file paths
   - Run `flutter pub get`
   - Restart IDE

4. **Hot Reload Not Working:**
   - Try hot restart (R)
   - Stop and restart app
   - Check for syntax errors

5. **Backend Not Starting:**
   - Check if port 5000 is available
   - Verify `.env` file exists
   - Check Node.js version

### Debugging Tips

1. **Check Console Output:**
   - Flutter: Terminal output
   - Backend: Server console

2. **Use Debug Mode:**
   - Flutter: `flutter run --debug`
   - Backend: `npm run dev` (nodemon)

3. **Clear Cache:**
   ```bash
   # Flutter
   flutter clean
   
   # Backend
   rm -rf node_modules
   npm install
   ```

4. **Check Dependencies:**
   - Verify all packages installed
   - Check version compatibility

## Best Practices

### Code Quality

1. **Keep functions small and focused**
2. **Use meaningful variable names**
3. **Add comments for complex logic**
4. **Follow DRY (Don't Repeat Yourself)**
5. **Handle errors gracefully**

### Performance

1. **Use const constructors where possible**
2. **Avoid unnecessary rebuilds**
3. **Lazy load data when possible**
4. **Optimize images and assets**
5. **Profile with Flutter DevTools**

### Security

1. **Never commit secrets or API keys**
2. **Use secure storage for sensitive data**
3. **Validate all user input**
4. **Sanitize data before storage**
5. **Keep dependencies updated**

### Documentation

1. **Update README for major changes**
2. **Document complex functions**
3. **Add inline comments for non-obvious code**
4. **Keep API documentation updated**

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Express.js Guide](https://expressjs.com/en/guide/routing.html)
- [Hive Documentation](https://docs.hivedb.dev/)

## Getting Help

1. Check existing documentation
2. Search for similar issues
3. Ask in team chat/forum
4. Create an issue with details

---

**Happy Coding! 🚀**

