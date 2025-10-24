package com.capstone.fitnessdiet

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity

/**
 * Activity to show Health Connect permissions rationale
 * Required by Health Connect for privacy policy display
 */
class HealthConnectPermissionsActivity : FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // This is a simple activity that explains why we need Health Connect permissions
        // In a production app, you would create a proper UI with layout XML
        
        // For now, we'll just finish and let the main app handle permissions
        finish()
    }
}
