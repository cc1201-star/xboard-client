package com.xboard.xboard_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.File

/**
 * VpnService that runs the bundled mihomo (Clash.Meta) kernel as a native
 * subprocess. The flow is:
 *
 *   1. MainActivity receives `start` over the MethodChannel and kicks off
 *      this service with the raw Clash.Meta YAML from the subscription.
 *   2. [Builder.establish] creates the TUN interface and returns a
 *      ParcelFileDescriptor.
 *   3. The fd number is injected into the YAML `tun.file-descriptor` key so
 *      mihomo picks it up when it starts.
 *   4. The mihomo binary (packaged as `libmihomo.so` inside the APK and
 *      extracted to `applicationInfo.nativeLibraryDir`) is spawned as a child
 *      process. The Clash API listens on 127.0.0.1:9090 so the Dart side can
 *      query traffic / proxies.
 *
 * Why ship the kernel as `libmihomo.so`: Android only makes files under
 * `nativeLibraryDir` executable, and AGP requires `.so`-suffixed files in
 * `jniLibs/`. Combined with `useLegacyPackaging = true` + `extractNativeLibs`
 * this gives us an executable on disk without writing our own extractor.
 */
class MihomoVpnService : VpnService() {
    companion object {
        const val ACTION_START = "com.xboard.mihomo.START"
        const val ACTION_STOP = "com.xboard.mihomo.STOP"
        const val EXTRA_CONFIG = "config"

        private const val TAG = "MihomoVpnService"
        private const val NOTIFICATION_ID = 8964
        private const val CHANNEL_ID = "mihomo-vpn"

        @Volatile
        var isRunning: Boolean = false
            private set

        /** Set by [MainActivity] to pipe status events back into Flutter. */
        var statusCallback: ((String) -> Unit)? = null
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var mihomoProcess: Process? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopVpn()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG).orEmpty()
                if (config.isEmpty()) {
                    Log.e(TAG, "start without config")
                    emit("error")
                    stopSelf()
                    return START_NOT_STICKY
                }
                try {
                    startForeground(NOTIFICATION_ID, buildNotification())
                    startVpn(config)
                } catch (t: Throwable) {
                    Log.e(TAG, "startVpn failed", t)
                    emit("error")
                    stopVpn()
                    stopSelf()
                }
            }
        }
        return START_STICKY
    }

    private fun startVpn(rawYaml: String) {
        val builder = Builder()
            .setSession("Xboard")
            .setMtu(9000)
            .addAddress("172.19.0.1", 30)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .addDnsServer("8.8.8.8")
            .addDnsServer("1.1.1.1")
            .setBlocking(false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        val tun = builder.establish()
        if (tun == null) {
            Log.e(TAG, "Builder.establish() returned null – VPN permission?")
            emit("error")
            return
        }
        tunInterface = tun

        val workDir = File(filesDir, "mihomo").apply { mkdirs() }
        val configFile = File(workDir, "config.yaml")
        configFile.writeText(injectRuntimeSettings(rawYaml, tun.fd))

        val binary = File(applicationInfo.nativeLibraryDir, "libmihomo.so")
        if (!binary.exists()) {
            Log.e(TAG, "mihomo binary missing at ${binary.absolutePath} – did you run scripts/download-kernels.sh?")
            emit("error")
            return
        }

        val pb = ProcessBuilder(binary.absolutePath, "-d", workDir.absolutePath)
            .redirectErrorStream(true)
        pb.environment()["HOME"] = workDir.absolutePath
        val proc = pb.start()
        mihomoProcess = proc
        isRunning = true
        emit("started")

        Thread({
            try {
                proc.inputStream.bufferedReader().useLines { seq ->
                    seq.forEach { Log.i(TAG, "mihomo: $it") }
                }
            } catch (_: Throwable) {
            }
            Log.i(TAG, "mihomo process exited")
            isRunning = false
            emit("stopped")
        }, "mihomo-stdout").start()
    }

    private fun stopVpn() {
        try {
            mihomoProcess?.destroy()
        } catch (_: Throwable) {
        }
        mihomoProcess = null
        try {
            tunInterface?.close()
        } catch (_: Throwable) {
        }
        tunInterface = null
        if (isRunning) {
            isRunning = false
            emit("stopped")
        }
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        stopSelf()
        super.onRevoke()
    }

    private fun emit(status: String) {
        try {
            statusCallback?.invoke(status)
        } catch (t: Throwable) {
            Log.w(TAG, "status callback threw", t)
        }
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Xboard VPN",
                        NotificationManager.IMPORTANCE_LOW
                    )
                )
            }
        }
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Xboard VPN")
            .setContentText("已连接")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    /**
     * Rewrite the subscription YAML so mihomo:
     *   - uses our tun fd instead of opening one itself
     *   - exposes the Clash external controller on 127.0.0.1:9090
     *   - enables the mixed inbound (so tests from within the app work)
     */
    private fun injectRuntimeSettings(yaml: String, fd: Int): String {
        var out = stripTopBlock(yaml, "tun")
        out = upsertTopKey(out, "mixed-port", "7890")
        out = upsertTopKey(out, "allow-lan", "false")
        out = upsertTopKey(out, "external-controller", "127.0.0.1:9090")
        val tunBlock = """
tun:
  enable: true
  stack: system
  device: utun
  mtu: 9000
  auto-route: false
  auto-detect-interface: false
  file-descriptor: $fd
  dns-hijack:
    - any:53

""".trimStart()
        return tunBlock + out
    }

    private fun upsertTopKey(yaml: String, key: String, value: String): String {
        val re = Regex("^$key\\s*:.*$", RegexOption.MULTILINE)
        return if (re.containsMatchIn(yaml)) {
            yaml.replace(re, "$key: $value")
        } else {
            "$key: $value\n$yaml"
        }
    }

    private fun stripTopBlock(yaml: String, key: String): String {
        val lines = yaml.split('\n').toMutableList()
        val out = StringBuilder()
        var skipping = false
        val keyRe = Regex("^$key\\s*:")
        val topRe = Regex("^\\S")
        for (line in lines) {
            if (skipping) {
                if (line.isEmpty()) continue
                if (topRe.containsMatchIn(line)) {
                    skipping = false
                    out.append(line).append('\n')
                }
                continue
            }
            if (keyRe.containsMatchIn(line)) {
                skipping = true
                continue
            }
            out.append(line).append('\n')
        }
        return out.toString()
    }
}
