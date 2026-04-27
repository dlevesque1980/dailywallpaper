# DailyWallpaper Documentation

Welcome to the official documentation for **DailyWallpaper**, a modern Flutter application for fetching, processing, and applying daily wallpapers from multiple sources.

This document explains the software architecture, design choices, and supported features of the app.

---

## 1. Architecture

The app is built on a clear, modular architecture that separates business logic, state management, and user interface.

### 1.1 State Management (BLoC Pattern)
DailyWallpaper uses the **BLoC (Business Logic Component)** pattern for global state management. The architecture is organized by feature:
- **Home (`lib/features/wallpaper/`)**: Manages the main screen, display, and selection of the wallpaper of the day.
- **History (`lib/features/history/`)**: Handles the history of previously retrieved images.
- **Settings (`lib/features/settings/`)**: Manages user preferences (image sources, regions, crop settings).

Each module contains its own `Bloc`, `State`, `Provider` (for dependency injection), and `Screens`.

### 1.2 Data Layer Structure
- **Models (`lib/data/models/`)**: Uses `built_value` and `json_serializable` for strong typing and safe serialization of data from external APIs (Bing, NASA, Pexels).
- **Repositories (`lib/data/repositories/`)**: Abstracts data access. The `ImageRepository` orchestrates access to different services (Bing, NASA, Pexels).
- **Local Database**: Uses `sqflite` (e.g. `wallpaper.db` and `crop_cache.db`) to store history and expensive image calculations. User preferences are stored with `shared_preferences`.

### 1.3 Smart Crop Engine
The project’s technical core lives in `lib/services/smart_crop/`. This engine uses multiple analyzers to identify the best crop area so images fit vertical mobile screens without losing the main subject.

---

## 2. Design and UI/UX

The interface is designed for an **immersive** and smooth experience, keeping the image front and center.

- **Immersive / Edge-to-Edge**: The UI hides or makes system bars transparent so the image is displayed fullscreen (`SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`).
- **Transparency and Layers**: Menus and informational text use transparency and overlays so they do not block the wallpaper view.
- **Reusable Components**: Widgets are centralized and modular (`lib/widgets/`: carousel, buttons, image info, descriptive text, etc.).
- **Performance Optimization**: Image rendering uses optimized components (`OptimizedImageWidget`) combined with a preloader service (`ImagePreloaderService`) that anticipates loading to avoid stuttering during swipes or history scrolling.

---

## 3. Supported Features

### 3.1 Multiple Image Sources
The app supports multiple sources and integrates via secure APIs stored in `.env`:
- **Bing**: Bing’s image of the day with support for changing region.
- **NASA**: Astronomy Picture of the Day (APOD).
- **Pexels**: High-quality photo search by configurable categories.

### 3.2 Smart Crop
A device-side image analysis engine centers the wallpaper around the most interesting part of the image:
- Face detection (`FaceDetectionCropAnalyzer`).
- Object and subject detection via machine learning (`MLSubjectCropAnalyzer`, `SubjectDetectionCropAnalyzer`).
- Entropy and color-based analysis (`EntropyBasedCropAnalyzer`, `ColorCropAnalyzer`).
- Composition-aware cropping with the rule of thirds (`RuleOfThirdsCropAnalyzer`, `EnhancedCompositionCropAnalyzer`).

### 3.3 History and Cache Management
- Users can browse an unlimited history of wallpapers and revisit previous days (`HistoryScreen`).
- **Intelligent Cache Manager (`IntelligentCacheManager`)**: Automatically purges old images and stores crop profiles to avoid recalculating images that were already processed.

### 3.4 Wallpaper Setting
Using a custom or third-party plugin (`setwallpaper`), the app can apply the selected image as the home screen wallpaper, lock screen wallpaper, or both.

### 3.5 Quality and Battery Management
The Smart Crop system includes performance profilers (`BatteryOptimizer`, `PerformanceProfiler`) to dynamically adjust analysis complexity based on battery state and device hardware.
