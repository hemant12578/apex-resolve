package com.apexresolve.app

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val origin = "https://apex-resolve-one.vercel.app"
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "apex/session").setMethodCallHandler { call, result ->
            if (call.method == "logout") {
                val cookieManager = CookieManager.getInstance()
                cookieManager.removeAllCookies {
                    cookieManager.flush()
                    runOnUiThread { result.success(true) }
                }
                return@setMethodCallHandler
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
            val cookies = cookieManager.getCookie(origin)
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
                        runOnUiThread {
                            if (updates.isEmpty()) { result.success(response); return@runOnUiThread }
                            var pending = updates.size
                            var ok = true
                            for (value in updates) cookieManager.setCookie(origin, value) { stored ->
                                ok = ok && stored
                                if (--pending == 0) {
                                    cookieManager.flush()
                                    if (ok) result.success(response) else result.error("COOKIES", "Could not save the session.", null)
                                }
                            }
                        }
                    } finally { connection.disconnect() }
                } catch (error: Exception) {
                    android.util.Log.w("ApexSession", "Workspace request failed: ${error.javaClass.simpleName}")
                    runOnUiThread { result.error("UNAVAILABLE", "Unable to open this session. Check your connection and sign in again.", null) }
                }
            }.start()
        }
    }
}
