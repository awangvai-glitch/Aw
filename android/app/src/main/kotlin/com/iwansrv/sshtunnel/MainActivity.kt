package com.iwansrv.sshtunnel

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import androidx.annotation.NonNull
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.Serializable

class MainActivity: FlutterActivity() {
    private val CHANNEL_NAME = "com.iwansrv.sshtunnel/vpn"
    private lateinit var channel: MethodChannel

    private var pendingVpnConfig: Map<*, *>? = null

    private val statusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.getStringExtra("type")) {
                "status" -> {
                    val status = intent.getStringExtra("status") ?: ""
                    val message = intent.getStringExtra("message") ?: ""
                    channel.invokeMethod("updateStatus", mapOf("status" to status, "message" to message))
                }
                "hostKey" -> {
                    val hostname = intent.getStringExtra("hostname") ?: ""
                    val fingerprint = intent.getStringExtra("fingerprint") ?: ""
                    val keyString = intent.getStringExtra("keyString") ?: ""
                    channel.invokeMethod("verifyHostKey", mapOf(
                        "hostname" to hostname,
                        "fingerprint" to fingerprint,
                        "keyString" to keyString
                    ))
                }
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startVpn" -> {
                    val config = call.arguments as? Map<*, *>
                    if (config != null) {
                        prepareAndStartVpn(config)
                        result.success("VPN start request received.")
                    } else {
                        result.error("INVALID_ARGUMENT", "Config is null", null)
                    }
                }
                "stopVpn" -> {
                    stopVpnService()
                    result.success("VPN stop request received.")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        LocalBroadcastManager.getInstance(this).registerReceiver(
            statusReceiver, IntentFilter(MyVpnService.ACTION_STATUS_CHANGED)
        )
    }

    override fun onStop() {
        super.onStop()
        LocalBroadcastManager.getInstance(this).unregisterReceiver(statusReceiver)
    }

    private fun prepareAndStartVpn(config: Map<*, *>) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingVpnConfig = config
            startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
        } else {
            startVpnService(config)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PERMISSION_REQUEST_CODE && resultCode == Activity.RESULT_OK) {
            pendingVpnConfig?.let {
                startVpnService(it)
                pendingVpnConfig = null
            }
        } else {
             channel.invokeMethod("updateStatus", mapOf("status" to "error", "message" to "Izin VPN ditolak oleh pengguna."))
        }
    }

    private fun startVpnService(config: Map<*, *>) {
        val intent = Intent(this, MyVpnService::class.java).apply {
             putExtra("config", config as Serializable)
        }
        startService(intent)
    }

    private fun stopVpnService() {
        val intent = Intent(this, MyVpnService::class.java)
        stopService(intent)
    }

    companion object {
        private const val VPN_PERMISSION_REQUEST_CODE = 1
    }
}
