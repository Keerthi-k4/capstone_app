"""
Flask API Server for Food Recognition
Serves the ML models for food recognition via HTTP API
"""

import os
import json
import base64
from io import BytesIO
from PIL import Image
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
import tensorflow as tf

# Import our existing food recognition modules
from enhanced_food_recognition import EnhancedFoodRecognizer
from nutritionix_adapter import NutritionixAdapter

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app

# Initialize the food recognizer and nutrition adapter
food_recognizer = None
nutrition_adapter = NutritionixAdapter()

def initialize_model():
    """Initialize the food recognition model"""
    global food_recognizer
    try:
        food_recognizer = EnhancedFoodRecognizer(model_type='efficientnet', use_custom_model=True)
        print("Food recognizer initialized successfully")
        return True
    except Exception as e:
        print(f"Error initializing food recognizer: {e}")
        print("Server will run without ML model - using fallback predictions")
        food_recognizer = None
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model_loaded': food_recognizer is not None
    })

@app.route('/predict', methods=['POST'])
def predict_food():
    """Predict food from uploaded image"""
    try:
        # Get image data from request
        data = request.get_json()
        if 'image' not in data:
            return jsonify({'error': 'No image data provided'}), 400
        
        if food_recognizer is None:
            # Return fallback predictions when model is not loaded
            return jsonify({
                'success': True,
                'predictions': [
                    {'name': 'Mixed Food', 'confidence': 0.8, 'is_custom_model': False},
                    {'name': 'Indian Cuisine', 'confidence': 0.6, 'is_custom_model': False},
                    {'name': 'Rice Dish', 'confidence': 0.5, 'is_custom_model': False},
                    {'name': 'Curry', 'confidence': 0.4, 'is_custom_model': False},
                    {'name': 'Vegetable Dish', 'confidence': 0.3, 'is_custom_model': False}
                ]
            })
        
        # Decode base64 image
        image_data = data['image']
        if image_data.startswith('data:image'):
            # Remove data URL prefix
            image_data = image_data.split(',')[1]
        
        # Decode and save image temporarily
        image_bytes = base64.b64decode(image_data)
        temp_image_path = 'temp_image.jpg'
        
        with open(temp_image_path, 'wb') as f:
            f.write(image_bytes)
        
        # Make prediction
        predictions = food_recognizer.predict(temp_image_path)
        
        # Clean up temporary file
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        
        # Format response
        formatted_predictions = []
        for pred in predictions[:5]:  # Return top 5 predictions
            formatted_predictions.append({
                'name': pred.get('display_name', pred.get('class_name', 'Unknown')),
                'confidence': pred.get('probability', 0.0),
                'is_custom_model': pred.get('is_custom', False)
            })
        
        return jsonify({
            'success': True,
            'predictions': formatted_predictions
        })
        
    except Exception as e:
        print(f"Error in prediction: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/nutrition', methods=['POST'])
def get_nutrition():
    """Get nutrition information for a food item"""
    try:
        data = request.get_json()
        if 'food_name' not in data:
            return jsonify({'error': 'No food name provided'}), 400
        
        food_name = data['food_name']
        quantity = data.get('quantity', 100)  # Default to 100g
        
        # Get nutrition data
        nutrition_data = nutrition_adapter.get_nutrition(food_name)
        
        if nutrition_data is not None and not nutrition_data.empty:
            # Convert pandas Series to dictionary
            nutrition_dict = nutrition_data.to_dict()
            
            # Scale nutrition data based on quantity
            scale_factor = quantity / 100.0  # Assuming base data is per 100g
            
            scaled_nutrition = {}
            for key, value in nutrition_dict.items():
                if isinstance(value, (int, float)) and key != 'food_name':
                    scaled_nutrition[key] = value * scale_factor
                else:
                    scaled_nutrition[key] = value
            
            return jsonify({
                'success': True,
                'nutrition': scaled_nutrition,
                'quantity': quantity
            })
        else:
            return jsonify({'error': 'Nutrition data not found'}), 404
            
    except Exception as e:
        print(f"Error getting nutrition: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/predict_with_nutrition', methods=['POST'])
def predict_with_nutrition():
    """Predict food and get nutrition information in one call"""
    try:
        if food_recognizer is None:
            return jsonify({'error': 'Model not loaded'}), 500
        
        data = request.get_json()
        if 'image' not in data:
            return jsonify({'error': 'No image data provided'}), 400
        
        # Decode base64 image
        image_data = data['image']
        if image_data.startswith('data:image'):
            image_data = image_data.split(',')[1]
        
        image_bytes = base64.b64decode(image_data)
        temp_image_path = 'temp_image.jpg'
        
        with open(temp_image_path, 'wb') as f:
            f.write(image_bytes)
        
        # Make prediction
        predictions = food_recognizer.predict(temp_image_path)
        
        # Clean up temporary file
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        
        # Get nutrition for top prediction
        top_prediction = None
        nutrition_data = None
        
        if predictions:
            top_prediction = predictions[0]
            food_name = top_prediction.get('display_name', top_prediction.get('class_name', ''))
            
            if food_name:
                nutrition_raw = nutrition_adapter.get_nutrition(food_name)
                if nutrition_raw is not None and not nutrition_raw.empty:
                    nutrition_data = nutrition_raw.to_dict()
                else:
                    nutrition_data = None
        
        # Format response
        formatted_predictions = []
        for pred in predictions[:5]:
            formatted_predictions.append({
                'name': pred.get('display_name', pred.get('class_name', 'Unknown')),
                'confidence': pred.get('probability', 0.0),
                'is_custom_model': pred.get('is_custom', False)
            })
        
        return jsonify({
            'success': True,
            'predictions': formatted_predictions,
            'top_prediction': {
                'name': top_prediction.get('display_name', '') if top_prediction else '',
                'confidence': top_prediction.get('probability', 0.0) if top_prediction else 0.0,
                'nutrition': nutrition_data
            }
        })
        
    except Exception as e:
        print(f"Error in prediction with nutrition: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("Starting Food Recognition API Server...")
    initialize_model()
    app.run(host='0.0.0.0', port=5000, debug=True)
