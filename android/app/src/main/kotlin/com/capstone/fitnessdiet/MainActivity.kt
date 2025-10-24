package com.capstone.fitnessdiet

import android.os.Bundle
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.capstone.fitnessdiet/health_connect"
    
    private lateinit var healthConnectManager: HealthConnectManager
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var awaitingPermissionResult = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
    
    override fun onResume() {
        super.onResume()
        
        // Check if we're waiting for permission result
        if (awaitingPermissionResult) {
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    // Give Health Connect a moment to update
                    kotlinx.coroutines.delay(300)
                    val hasPermissions = healthConnectManager.hasPermissions()
                    pendingPermissionResult?.success(hasPermissions)
                } catch (e: Exception) {
                    pendingPermissionResult?.error("ERROR", e.message, null)
                } finally {
                    pendingPermissionResult = null
                    awaitingPermissionResult = false
                }
            }
        }
    }
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        healthConnectManager = HealthConnectManager(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val isAvailable = healthConnectManager.isAvailable()
                            result.success(isAvailable)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
                
                "hasPermissions" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val hasPermissions = healthConnectManager.hasPermissions()
                            result.success(hasPermissions)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
                
                "requestPermissions" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            // First check if already has permissions
                            val alreadyHas = healthConnectManager.hasPermissions()
                            if (alreadyHas) {
                                result.success(true)
                                return@launch
                            }
                            
                            pendingPermissionResult = result
                            awaitingPermissionResult = true
                            // Launch the Health Connect permission request
                            healthConnectManager.requestPermissions(this@MainActivity, null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                            pendingPermissionResult = null
                            awaitingPermissionResult = false
                        }
                    }
                }
                
                "getTodayHealthData" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val date = call.argument<String>("date") ?: ""
                            val data = healthConnectManager.getTodayHealthData(date)
                            result.success(data)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
                
                "getHealthDataForDate" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val date = call.argument<String>("date") ?: ""
                            val data = healthConnectManager.getTodayHealthData(date)
                            result.success(data)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
                
                "writeHealthData" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val data = call.arguments as? Map<String, Any> ?: emptyMap()
                            val success = healthConnectManager.writeHealthData(data)
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
                
                "openSettings" -> {
                    try {
                        healthConnectManager.openSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}