package com.xboard.xboard_client

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.xboard.singbox"
        private const val EVENT_CHANNEL = "com.xboard.singbox/status"
        private const val VPN_REQUEST_CODE = 1001
    }

    private var methodResult: MethodChannel.Result? = null
    private var statusSink: EventChannel.EventSink? = null
    private var isVpnRunning = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val config = call.argument<String>("config") ?: ""
                    startSingbox(config, result)
                }
                "stop" -> {
                    stopSingbox(result)
                }
                "isRunning" -> {
                    result.success(isVpnRunning)
                }
                "requestVpnPermission" -> {
                    requestVpnPermission(result)
                }
                "writeConfig" -> {
                    val config = call.argument<String>("config") ?: ""
                    writeConfig(config, result)
                }
                else -> result.notImplemented()
            }
        }

        // Event Channel for status updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    statusSink = events
                }
                override fun onCancel(arguments: Any?) {
                    statusSink = null
                }
            }
        )
    }

    private fun requestVpnPermission(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            methodResult = result
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            result.success(true) // Already granted
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            methodResult?.success(resultCode == RESULT_OK)
            methodResult = null
        }
    }

    private fun startSingbox(config: String, result: MethodChannel.Result) {
        try {
            // Write config to app files
            val configFile = File(filesDir, "sing-box-config.json")
            configFile.writeText(config)

            // TODO: Start sing-box via VpnService
            // This requires integrating the sing-box Android library (libbox.aar)
            // For now, mark as started so the Clash API flow works
            // In production: start SingboxVpnService with the config path
            isVpnRunning = true
            statusSink?.success("started")
            result.success(true)
        } catch (e: Exception) {
            statusSink?.success("error")
            result.success(false)
        }
    }

    private fun stopSingbox(result: MethodChannel.Result) {
        try {
            // TODO: Stop sing-box VpnService
            isVpnRunning = false
            statusSink?.success("stopped")
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun writeConfig(config: String, result: MethodChannel.Result) {
        try {
            val configFile = File(filesDir, "sing-box-config.json")
            configFile.writeText(config)
            result.success(configFile.absolutePath)
        } catch (e: Exception) {
            result.error("WRITE_ERROR", e.message, null)
        }
    }
}
