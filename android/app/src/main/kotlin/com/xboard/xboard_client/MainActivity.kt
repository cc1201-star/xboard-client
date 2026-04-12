package com.xboard.xboard_client

import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.xboard.mihomo"
        private const val EVENT_CHANNEL = "com.xboard.mihomo/status"
        private const val VPN_REQUEST_CODE = 1001
    }

    private var methodResult: MethodChannel.Result? = null
    private var statusSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val config = call.argument<String>("config").orEmpty()
                        startVpn(config, result)
                    }
                    "stop" -> stopVpn(result)
                    "isRunning" -> result.success(MihomoVpnService.isRunning)
                    "requestVpnPermission" -> requestVpnPermission(result)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    statusSink = events
                    MihomoVpnService.statusCallback = { status ->
                        runOnUiThread { statusSink?.success(status) }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    statusSink = null
                    MihomoVpnService.statusCallback = null
                }
            })
    }

    private fun requestVpnPermission(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            methodResult = result
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            result.success(true)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            methodResult?.success(resultCode == RESULT_OK)
            methodResult = null
        }
    }

    private fun startVpn(config: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(this, MihomoVpnService::class.java).apply {
                action = MihomoVpnService.ACTION_START
                putExtra(MihomoVpnService.EXTRA_CONFIG, config)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result.success(true)
        } catch (t: Throwable) {
            Log.e(TAG, "startVpn error", t)
            result.success(false)
        }
    }

    private fun stopVpn(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, MihomoVpnService::class.java).apply {
                action = MihomoVpnService.ACTION_STOP
            }
            startService(intent)
            result.success(true)
        } catch (_: Throwable) {
            result.success(false)
        }
    }
}
