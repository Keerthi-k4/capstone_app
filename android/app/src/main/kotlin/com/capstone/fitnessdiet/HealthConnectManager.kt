package com.capstone.fitnessdiet

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class HealthConnectManager(private val context: Context) {
    
    private var healthConnectClient: HealthConnectClient? = null
    
    // Required permissions - using string permissions for compatibility
    val PERMISSIONS = setOf(
        // Heart Rate
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class),
        // Steps
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        // Calories (Total includes active + BMR)
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
        HealthPermission.getWritePermission(TotalCaloriesBurnedRecord::class),
        // Active Calories (for detailed tracking)
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getWritePermission(ActiveCaloriesBurnedRecord::class),
        // Exercise Sessions
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
        // Oxygen Saturation (SpO2)
        HealthPermission.getReadPermission(OxygenSaturationRecord::class),
        HealthPermission.getWritePermission(OxygenSaturationRecord::class),
        // Sleep Sessions
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getWritePermission(SleepSessionRecord::class),
        // Resting Heart Rate
        HealthPermission.getReadPermission(RestingHeartRateRecord::class),
        HealthPermission.getWritePermission(RestingHeartRateRecord::class),
        // Respiratory Rate (for stress assessment)
        HealthPermission.getReadPermission(RespiratoryRateRecord::class),
        HealthPermission.getWritePermission(RespiratoryRateRecord::class)
    )

    
    /**
     * Check if Health Connect is available on this device
     */
    suspend fun isAvailable(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val sdkStatus = HealthConnectClient.getSdkStatus(context)
                when (sdkStatus) {
                    HealthConnectClient.SDK_AVAILABLE -> {
                        healthConnectClient = HealthConnectClient.getOrCreate(context)
                        true
                    }
                    HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> {
                        // Health Connect needs update
                        false
                    }
                    else -> false
                }
            } catch (e: Exception) {
                e.printStackTrace()
                false
            }
        }
    }
    
    /**
     * Check if all required permissions are granted
     */
    suspend fun hasPermissions(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val client = healthConnectClient ?: return@withContext false
                val granted = client.permissionController.getGrantedPermissions()
                granted.containsAll(PERMISSIONS)
            } catch (e: Exception) {
                e.printStackTrace()
                false
            }
        }
    }
    
    /**
     * Request permissions - opens Health Connect permission screen
     */
    fun requestPermissions(activity: MainActivity, launcher: ActivityResultLauncher<Set<String>>?) {
        try {
            // Open Health Connect app to manage permissions
            // This is the most reliable way on most Android devices
            val intent = Intent("androidx.health.ACTION_MANAGE_HEALTH_PERMISSIONS").apply {
                putExtra("androidx.health.EXTRA_PERMISSIONS", PERMISSIONS.toTypedArray())
                // Try to open directly in this app's permission page
                putExtra("android.intent.extra.PACKAGE_NAME", activity.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            try {
                activity.startActivity(intent)
            } catch (e: Exception) {
                // Fallback: open Health Connect settings home
                openSettings()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    /**
     * Get today's health data aggregated
     */
    suspend fun getTodayHealthData(date: String): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            try {
                val client = healthConnectClient ?: return@withContext emptyMap<String, Any>()
                
                // Parse date (format: YYYY-MM-DD)
                val localDate = LocalDateTime.parse("${date}T00:00:00")
                val zoneId = ZoneId.systemDefault()
                val startTime = localDate.atZone(zoneId).toInstant()
                val endTime = localDate.plusDays(1).atZone(zoneId).toInstant()
                
                // Aggregate steps
                val stepsResponse = client.aggregate(
                    AggregateRequest(
                        metrics = setOf(StepsRecord.COUNT_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )
                val steps = stepsResponse[StepsRecord.COUNT_TOTAL] ?: 0L
                
                // Aggregate TOTAL calories burned (includes active + BMR)
                val totalCaloriesResponse = client.aggregate(
                    AggregateRequest(
                        metrics = setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )
                val totalCalories = totalCaloriesResponse[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories?.toInt() ?: 0
                
                // Fallback to active calories if total is not available
                val calories = if (totalCalories > 0) {
                    totalCalories
                } else {
                    val activeCaloriesResponse = client.aggregate(
                        AggregateRequest(
                            metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                        )
                    )
                    activeCaloriesResponse[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories?.toInt() ?: 0
                }
                
                // Get latest heart rate
                val heartRateRecords = client.readRecords(
                    ReadRecordsRequest(
                        recordType = HeartRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )
                val heartRate = if (heartRateRecords.records.isNotEmpty()) {
                    val latestRecord = heartRateRecords.records.maxByOrNull { it.endTime }
                    latestRecord?.samples?.lastOrNull()?.beatsPerMinute ?: 0L
                } else {
                    0L
                }
                
                // Get resting heart rate
                val restingHeartRateRecords = client.readRecords(
                    ReadRecordsRequest(
                        recordType = RestingHeartRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )
                val restingHeartRate = if (restingHeartRateRecords.records.isNotEmpty()) {
                    val latestRecord = restingHeartRateRecords.records.maxByOrNull { it.time }
                    latestRecord?.beatsPerMinute ?: 0L
                } else {
                    0L
                }
                
                // Aggregate exercise minutes from ExerciseSessionRecord
                val exerciseRecords = client.readRecords(
                    ReadRecordsRequest(
                        recordType = ExerciseSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )
                val exerciseMinutes = exerciseRecords.records.sumOf { record ->
                    val duration = java.time.Duration.between(record.startTime, record.endTime)
                    duration.toMinutes()
                }.toInt()
                
                // Get latest Oxygen Saturation (SpO2)
                val oxygenSaturationRecords = client.readRecords(
                    ReadRecordsRequest(
                        recordType = OxygenSaturationRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )
                val oxygenSaturation = if (oxygenSaturationRecords.records.isNotEmpty()) {
                    val latestRecord = oxygenSaturationRecords.records.maxByOrNull { it.time }
                    latestRecord?.percentage?.value ?: 0.0
                } else {
                    0.0
                }
                
                // Aggregate sleep hours for today
                val sleepRecords = client.readRecords(
                    ReadRecordsRequest(
                        recordType = SleepSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )
                val sleepHours = sleepRecords.records.sumOf { record ->
                    val duration = java.time.Duration.between(record.startTime, record.endTime)
                    duration.toMinutes()
                }.toDouble() / 60.0 // Convert minutes to hours
                
                // Get respiratory rate (for stress assessment)
                val respiratoryRateRecords = client.readRecords(
                    ReadRecordsRequest(
                        recordType = RespiratoryRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )
                val respiratoryRate = if (respiratoryRateRecords.records.isNotEmpty()) {
                    val latestRecord = respiratoryRateRecords.records.maxByOrNull { it.time }
                    latestRecord?.rate ?: 0.0
                } else {
                    0.0
                }
                
                mapOf(
                    "steps" to steps.toInt(),
                    "heartRate" to heartRate.toInt(),
                    "restingHeartRate" to restingHeartRate.toInt(),
                    "caloriesBurned" to calories,
                    "exerciseMinutes" to exerciseMinutes,
                    "oxygenSaturation" to oxygenSaturation,
                    "sleepHours" to sleepHours,
                    "respiratoryRate" to respiratoryRate,
                    "timestamp" to Instant.now().toString(),
                    "isDemoMode" to false
                )
            } catch (e: Exception) {
                e.printStackTrace()
                emptyMap<String, Any>()
            }
        }
    }
    
    /**
     * Write health data to Health Connect
     */
    suspend fun writeHealthData(data: Map<String, Any>): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val client = healthConnectClient ?: return@withContext false
                
                val steps = (data["steps"] as? Number)?.toInt() ?: 0
                val heartRate = (data["heartRate"] as? Number)?.toLong() ?: 0L
                val caloriesBurned = (data["caloriesBurned"] as? Number)?.toDouble() ?: 0.0
                val exerciseMinutes = (data["exerciseMinutes"] as? Number)?.toInt() ?: 0
                
                val endTime = Instant.now()
                val startTime = endTime.minusSeconds(3600) // 1 hour ago
                val zoneOffset = ZoneId.systemDefault().rules.getOffset(startTime)
                
                val records = mutableListOf<Record>()
                
                // Add steps record
                if (steps > 0) {
                    records.add(
                        StepsRecord(
                            count = steps.toLong(),
                            startTime = startTime,
                            startZoneOffset = zoneOffset,
                            endTime = endTime,
                            endZoneOffset = zoneOffset
                        )
                    )
                }
                
                // Add heart rate record
                if (heartRate > 0) {
                    records.add(
                        HeartRateRecord(
                            startTime = startTime,
                            startZoneOffset = zoneOffset,
                            endTime = endTime,
                            endZoneOffset = zoneOffset,
                            samples = listOf(
                                HeartRateRecord.Sample(
                                    time = endTime,
                                    beatsPerMinute = heartRate
                                )
                            )
                        )
                    )
                }
                
                // Add calories record
                if (caloriesBurned > 0) {
                    records.add(
                        ActiveCaloriesBurnedRecord(
                            energy = androidx.health.connect.client.units.Energy.kilocalories(caloriesBurned),
                            startTime = startTime,
                            startZoneOffset = zoneOffset,
                            endTime = endTime,
                            endZoneOffset = zoneOffset
                        )
                    )
                }
                
                // Add exercise session if minutes > 0
                if (exerciseMinutes > 0) {
                    val exerciseEndTime = Instant.now()
                    val exerciseStartTime = exerciseEndTime.minusSeconds(exerciseMinutes.toLong() * 60)
                    records.add(
                        ExerciseSessionRecord(
                            exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_WALKING,
                            title = "Exercise Session",
                            startTime = exerciseStartTime,
                            startZoneOffset = zoneOffset,
                            endTime = exerciseEndTime,
                            endZoneOffset = zoneOffset
                        )
                    )
                }
                
                if (records.isNotEmpty()) {
                    client.insertRecords(records)
                    true
                } else {
                    false
                }
            } catch (e: Exception) {
                e.printStackTrace()
                false
            }
        }
    }
    
    /**
     * Open Health Connect app settings
     */
    fun openSettings() {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("healthconnect://home")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            // Fallback to Play Store if Health Connect app not found
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("market://details?id=com.google.android.apps.healthdata")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            } catch (ex: Exception) {
                ex.printStackTrace()
            }
        }
    }
}
