# Daily Wallpaper

A feature-rich daily wallpaper application built with Flutter that provides high-quality images from multiple sources every day.

## Project Analysis & Architecture

This project is a modern Flutter application designed to fetch, process, and set daily wallpapers. Key architectural points include:

- **State Management (BLoC Pattern):** The app uses the BLoC (Business Logic Component) pattern for clear separation of UI and business logic. It includes specific BLoCs for Home, History, Settings, and Pexels Categories (`lib/bloc/`, `lib/bloc_provider/`, `lib/bloc_state/`).
- **Multi-Source Image APIs:** While initially utilizing the Bing Image of the Day API, the app includes structural support for additional sources like **NASA** and **Pexels** (`lib/api/`, `lib/models/`).
- **Smart Crop Engine:** A highly sophisticated custom feature (`lib/services/smart_crop/`) that intelligently crops images to fit mobile screens perfectly. It includes various analyzers like face detection, rule of thirds, entropy, color, and subject detection to ensure the most important parts of the image remain visible.
- **Performance & Caching:** Implements intelligent caching, image preloading, and performance optimizations tailored for mobile battery and hardware constraints (`lib/services/smart_crop/utils/`).
- **Local Storage:** SQLite (`sqflite`) and Shared Preferences are used for managing wallpaper history and user settings.
- **UI/UX:** Supports edge-to-edge full-screen experiences, transparent overlays, and fluid animations for browsing wallpapers.

## Instructions & Getting Started

### Prerequisites

1. **Flutter SDK:** Ensure you have Flutter installed (version >=3.4.3 <4.0.0). [Install Flutter](https://docs.flutter.dev/get-started/install).
2. **Dart SDK:** Included with Flutter.
3. **IDE:** VS Code or Android Studio with Flutter extensions installed.

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd dailywallpaper
   ```

2. **Install Dependencies:**
   Run the following command to fetch all required packages:
   ```bash
   flutter pub get
   ```

3. **Environment Variables (.env):**
   The application requires a `.env` file at the root of the project to manage API keys securely. Create a file named `.env` and add your keys (e.g., for Pexels, NASA, etc.).
   *Note: Never commit your `.env` file to version control. It is already added to `.gitignore`.*

4. **Code Generation:**
   Since the project uses `built_value` and `json_serializable`, you might need to generate serialization code if you make changes to models:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### Running the App

To run the app on a connected device or emulator:
```bash
flutter run
```

### Testing

The project includes test configurations. To run tests:
```bash
flutter test
```

## Preview

![](example.gif)
