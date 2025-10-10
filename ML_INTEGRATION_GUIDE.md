# ML Food Recognition Integration - Setup Instructions

This document explains how to set up and use the integrated ML food recognition feature in your Flutter fitness/diet app.

## Overview

The app now supports two methods for food tracking:

1. **Manual Search**: Search for food items and manually add them
2. **Photo Recognition**: Take photos of food items and automatically recognize them using ML

## Setup Instructions

### 1. Flutter Dependencies

The following dependencies have been added to `pubspec.yaml`:

```yaml
dependencies:
  # Camera and image functionality
  image_picker: ^1.0.7
  camera: ^0.10.5+9
  path_provider: ^2.1.2
  
  # ML and API communication
  dio: ^5.4.1
```

Run `flutter pub get` to install these dependencies.

### 2. Python ML Server Setup

#### Prerequisites
- Python 3.8 or higher
- TensorFlow 2.3+
- All packages listed in `ML_image_recognition/requirements.txt`

#### Installation Steps

1. Navigate to the ML directory:
```bash
cd ML_image_recognition
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
```

3. Start the Flask API server:
```bash
python flask_api.py
```

The server will start on `http://localhost:5000` by default.

#### Server Endpoints

- `GET /health` - Check if server and models are loaded
- `POST /predict` - Predict food from image
- `POST /predict_with_nutrition` - Predict food and get nutrition data
- `POST /nutrition` - Get nutrition data for specific food

### 3. Android Permissions

Add these permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### 4. iOS Permissions

Add these keys to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to recognize food items</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select food images</string>
```

## Usage Guide

### Manual Food Search

1. Open the Food Tracking screen
2. Tap "Search Food"
3. Type the name of the food item
4. Select from suggestions or search results
5. Adjust quantity and nutritional information
6. Save to food log

### Photo Recognition

1. Open the Food Tracking screen
2. Ensure ML server is running (green cloud icon in app bar)
3. Tap "Take Photo"
4. Choose camera or gallery
5. Take/select a photo of food
6. Review ML predictions
7. Select the correct food item
8. Adjust quantity and details as needed
9. Save to food log

## Features

### ML Recognition
- Uses EfficientNet and custom-trained models
- Recognizes 20+ Indian food items including:
  - burger, pizza, dosa, idli, biryani
  - samosa, momos, dal, chapati, etc.
- Confidence scoring for predictions
- Fallback to manual entry if recognition fails

### Nutrition Data
- Automatic nutrition lookup via Nutritionix API
- Fallback nutrition database for common foods
- Editable nutrition information
- Per-serving calculations

### Food Logging
- Categorized by meal type (breakfast, lunch, dinner, snack)
- Local SQLite storage
- Edit and delete functionality
- Daily food log view

## Architecture

### Flutter Components

1. **Services**:
   - `MLFoodRecognitionService`: Communicates with Python API
   - `ImageCaptureService`: Handles camera/gallery operations
   - `FoodDBHelper`: Local database operations

2. **Screens**:
   - `FoodTrackingScreen`: Main food tracking interface
   - `ManualFoodSearchScreen`: Manual food search
   - `FoodConfirmationScreen`: Confirm/edit ML predictions

3. **Models**:
   - `FoodPrediction`: ML prediction results
   - `NutritionData`: Nutrition information
   - `FoodItem`: Food item data structure

### Python Components

1. **ML Models**:
   - `EnhancedFoodRecognizer`: Main recognition class
   - Custom trained model for Indian foods
   - ImageNet-based recognition for general foods

2. **API Server**:
   - Flask-based REST API
   - Image processing and prediction
   - Nutrition data integration

## Troubleshooting

### Common Issues

1. **ML Server Not Available**:
   - Check if Python server is running
   - Verify network connectivity
   - Use manual search as fallback

2. **Camera Permission Denied**:
   - Check app permissions in device settings
   - Restart the app after granting permissions

3. **Poor Recognition Accuracy**:
   - Ensure good lighting
   - Take clear, close-up photos
   - Use manual search for unrecognized items

4. **Nutrition Data Missing**:
   - Check Nutritionix API credentials
   - Fallback data used for common foods
   - Manual entry available

### Configuration

#### Server URL Configuration
Update the server URL in `MLFoodRecognitionService` if running on different host:

```dart
static const String _baseUrl = 'http://YOUR_SERVER_IP:5000';
```

#### API Keys
Configure Nutritionix API credentials in `nutritionix_adapter.py`:

```python
self.app_id = "YOUR_APP_ID"
self.api_key = "YOUR_API_KEY"
```

## Future Enhancements

1. **Quantity Estimation**: Automatic portion size detection
2. **Multiple Food Items**: Recognize multiple foods in one image
3. **Offline Mode**: Local model inference without server
4. **Barcode Scanning**: UPC/barcode based food lookup
5. **Meal Planning**: AI-powered meal suggestions

## Support

For technical issues:
1. Check server logs in Python console
2. Check Flutter debug console for errors
3. Verify all dependencies are installed
4. Test with manual search first
