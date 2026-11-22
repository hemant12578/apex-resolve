package com.apexresolve.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val origin = "https://apex-resolve-one.vercel.app"
    private val channelId = "apex_alerts_channel"

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        // Ensure CookieManager is enabled for Xiaomi MIUI / HyperOS
        try {
            val cm = CookieManager.getInstance()
            cm.setAcceptCookie(true)
        } catch (_: Exception) {}

        createNotificationChannel()

        MethodChannel(engine.dartExecutor.binaryMessenger, "apex/session").setMethodCallHandler { call, result ->
            when (call.method) {
                "getStorageDir" -> {
                    result.success(applicationContext.filesDir.absolutePath)
                    return@setMethodCallHandler
                }
                "logout" -> {
                    val cookieManager = CookieManager.getInstance()
                    cookieManager.removeAllCookies {
                        cookieManager.flush()
                        val prefs = getSharedPreferences("apex_cookies", Context.MODE_PRIVATE)
                        prefs.edit().clear().apply()
                        runOnUiThread { result.success(true) }
                    }
                    return@setMethodCallHandler
                }
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "Apex Resolve"
                    val body = call.argument<String>("body") ?: ""
                    val notifId = call.argument<Int>("id") ?: System.currentTimeMillis().toInt()
                    showSystemNotification(title, body, notifId)
                    result.success(true)
                    return@setMethodCallHandler
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                        }
                    }
                    result.success(true)
                    return@setMethodCallHandler
                }
            }

            val (path, httpMethod) = when (call.method) {
                "chat" -> Pair("/api/chat/session", "POST")
                "directory" -> {
                    val section = call.argument<String>("section")
                    if (section !in setOf("chats", "groups", "issues", "knowledge")) {
                        result.error("SECTION", "Unknown directory.", null)
                        return@setMethodCallHandler
                    }
                    Pair("/api/mobile/directory?section=$section", "GET")
                }
                "login" -> Pair("/api/auth/firebase", "POST")
                "api" -> {
                    val p = call.argument<String>("path") ?: ""
                    val m = (call.argument<String>("method") ?: "GET").uppercase()
                    Pair(p, m)
                }
                else -> { result.notImplemented(); return@setMethodCallHandler }
            }

            val arguments = call.arguments as? Map<*, *> ?: emptyMap<String, String>()
            val cookieManager = CookieManager.getInstance()
            try {
                cookieManager.setAcceptCookie(true)
            } catch (_: Exception) {}

            var cookies = cookieManager.getCookie(origin)

            // Xiaomi MIUI/HyperOS fallback: check SharedPreferences if CookieManager returned blank
            val prefs = getSharedPreferences("apex_cookies", Context.MODE_PRIVATE)
            if (cookies.isNullOrBlank()) {
                val cachedCookies = prefs.getString("session_cookies", null)
                if (!cachedCookies.isNullOrBlank()) {
                    cookies = cachedCookies
                    try {
                        for (part in cachedCookies.split(";")) {
                            val c = part.trim()
                            if (c.isNotEmpty()) cookieManager.setCookie(origin, c)
                        }
                        cookieManager.flush()
                    } catch (_: Exception) {}
                }
            }

            if (call.method != "login" && cookies.isNullOrBlank()) {
                result.error("SIGN_IN", "Sign in to your workspace.", null)
                return@setMethodCallHandler
            }

            Thread {
                try {
                    val connection = URL(origin + path).openConnection() as HttpsURLConnection
                    try {
                        connection.instanceFollowRedirects = false
                        connection.requestMethod = httpMethod
                        connection.connectTimeout = 15000
                        connection.readTimeout = 30000
                        connection.doOutput = httpMethod != "GET"
                        connection.setRequestProperty("Origin", origin)
                        connection.setRequestProperty("Content-Type", "application/json")
                        if (cookies != null) connection.setRequestProperty("Cookie", cookies)
                        if (connection.doOutput) {
                            val payload = call.argument<Map<*, *>>("data") ?: arguments
                            connection.outputStream.use { it.write(JSONObject(payload).toString().toByteArray(Charsets.UTF_8)) }
                        }
                        val status = connection.responseCode
                        if (status == 401) {
                            runOnUiThread { result.error("SIGN_IN", "Sign in to your workspace.", null) }
                            return@Thread
                        }
                        if (status !in 200..299) {
                            runOnUiThread { result.error("HTTP", "Workspace returned HTTP $status.", null) }
                            return@Thread
                        }
                        val response = connection.inputStream.bufferedReader().use { it.readText() }
                        val updates = connection.headerFields.entries
                            .filter { it.key.equals("set-cookie", ignoreCase = true) }.flatMap { it.value }

                        // Persist cookies to SharedPreferences AND CookieManager
                        if (updates.isNotEmpty()) {
                            val existing = prefs.getString("session_cookies", "") ?: ""
                            val cookieMap = mutableMapOf<String, String>()
                            for (part in existing.split(";")) {
                                val p = part.trim()
                                val eq = p.indexOf('=')
                                if (eq > 0) cookieMap[p.substring(0, eq).trim()] = p.substring(eq + 1).trim()
                            }
                            for (header in updates) {
                                val cookiePart = header.split(";").firstOrNull()?.trim() ?: ""
                                val eq = cookiePart.indexOf('=')
                                if (eq > 0) cookieMap[cookiePart.substring(0, eq).trim()] = cookiePart.substring(eq + 1).trim()
                                try {
                                    cookieManager.setCookie(origin, header)
                                } catch (_: Exception) {}
                            }
                            try { cookieManager.flush() } catch (_: Exception) {}
                            val combined = cookieMap.entries.joinToString("; ") { "${it.key}=${it.value}" }
                            prefs.edit().putString("session_cookies", combined).apply()
                        }

                        // Always return success on HTTP 200 without blocking on Xiaomi cookie callbacks
                        runOnUiThread { result.success(response) }
                    } finally { connection.disconnect() }
                } catch (error: Exception) {
                    android.util.Log.w("ApexSession", "Workspace request failed: ${error.javaClass.simpleName}")
                    runOnUiThread { result.error("UNAVAILABLE", "Unable to open this session. Check your connection and sign in again.", null) }
                }
            }.start()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Apex Resolve Alerts"
            val descriptionText = "Message requests, resolution rooms, and team updates"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                enableLights(true)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showSystemNotification(title: String, body: String, notifId: Int) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(this, 0, intent, flags)

            val iconRes = if (applicationInfo.icon != 0) applicationInfo.icon else android.R.drawable.ic_dialog_info

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(this, channelId)
            } else {
                @Suppress("DEPRECATION")
                android.app.Notification.Builder(this)
            }

            builder.setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(iconRes)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                builder.setStyle(android.app.Notification.BigTextStyle().bigText(body))
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(notifId, builder.build())
        } catch (e: Exception) {
            android.util.Log.w("ApexNotif", "Could not show notification: ${e.message}")
        }
    }
}
