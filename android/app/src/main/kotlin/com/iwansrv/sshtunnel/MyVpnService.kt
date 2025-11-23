
package com.iwansrv.sshtunnel

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Base64
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.hierynomus.sshj.SSHClient
import com.hierynomus.sshj.connection.channel.direct.LocalPortForwarder
import com.hierynomus.sshj.transport.Transport
import com.hierynomus.sshj.transport.verification.HostKeyVerifier
import com.hierynomus.sshj.transport.verification.PromiscuousVerifier
import com.hierynomus.sshj.transport.tcp.TCPTransport
import java.io.IOException
import java.net.InetSocketAddress
import java.security.PublicKey
import java.net.Socket
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory
import java.io.InputStream
import java.io.OutputStream


class MyVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    private var sshClient: SSHClient? = null

    // --- VPN Service Lifecycle ---

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val config = intent?.getSerializableExtra("config") as? Map<*, *>
        if (config == null) {
            sendUpdate("disconnected", "Config is missing, stopping service.")
            stopSelf()
            return START_NOT_STICKY
        }

        vpnThread = Thread {
            try {
                establishSshConnection(config)
                sendUpdate("connecting", "SSH connected. Establishing VPN...")
                establishVpn()
                sendUpdate("connected", "VPN connection established successfully.")
            } catch (e: HostKeyNotTrustedException) {
                 sendHostKeyUpdate(e.hostname, e.fingerprint, e.keyString)
            } catch (e: Exception) {
                e.printStackTrace()
                sendUpdate("error", "Connection failed: ${e.message}")
                stopVpn()
            }
        }
        vpnThread?.start()

        return START_STICKY
    }
    
    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    private fun stopVpn() {
        sendUpdate("disconnected", "VPN has been disconnected.")
        vpnThread?.interrupt()
        try { sshClient?.disconnect() } catch (e: IOException) { /* Ignore */ }
        try { vpnInterface?.close() } catch (e: IOException) { /* Ignore */ }
        sshClient = null
        vpnInterface = null
        stopSelf()
    }
    
    // --- Connection Logic ---

    @Throws(IOException::class)
    private fun establishSshConnection(config: Map<*, *>) {
        val sshHost = config["sshHost"] as? String ?: throw IOException("SSH Host is missing")
        val sshPort = (config["sshPort"] as? String)?.toIntOrNull() ?: 22
        val sshUser = config["sshUser"] as? String ?: throw IOException("Username is missing")
        val sshPass = config["sshPass"] as? String ?: throw IOException("Password is missing")

        val proxyHost = config["proxyHost"] as? String
        val proxyPort = (config["proxyPort"] as? String)?.toIntOrNull()
        val payload = config["payload"] as? String
        val sni = config["sni"] as? String
        val trustedKey = config["trustedKey"] as? String // Key sent from UI after user confirmation

        sshClient = SSHClient()
        // *** REMOVED PromiscuousVerifier ***
        sshClient?.addHostKeyVerifier(KnownHostsVerifier(this, trustedKey))
        sshClient?.useCompression()
        
        sendUpdate("connecting", "Connecting to SSH server...")

        if (proxyHost != null && proxyPort != null && !payload.isNullOrEmpty()) {
            sendUpdate("connecting", "Connecting via proxy: $proxyHost:$proxyPort")
            val proxyConnector = CustomHttpProxyConnector(proxyHost, proxyPort, sshHost, sshPort, payload, sni, ::sendUpdate)
            sshClient?.connect(sshHost, sshPort, proxyConnector)
        } else {
            sendUpdate("connecting", "Connecting directly to $sshHost:$sshPort")
            sshClient?.connect(sshHost, sshPort)
        }
        
        sendUpdate("connecting", "Authenticating with username and password...")
        sshClient?.authPassword(sshUser, sshPass)
        
        sendUpdate("connecting", "Authentication successful. Creating tunnel...")
        val localPort = 1080 
        val params = LocalPortForwarder.Parameters("127.0.0.1", localPort, "localhost", 0)
        sshClient?.newLocalPortForwarder(params)?.listen()
    }

    private fun establishVpn() {
        val builder = Builder()
        builder.setSession("SSHTunnel VPN")
        builder.addAddress("10.8.0.1", 24)
        builder.addRoute("0.0.0.0", 0)
        builder.addDnsServer("8.8.8.8")
        builder.setHttpProxy(InetSocketAddress("127.0.0.1", 1080))

        vpnInterface = builder.establish()
        if (vpnInterface == null) {
            throw IOException("VPN permission was not granted by the user.")
        }
    }

    // --- Communication ---

    private fun sendUpdate(status: String, message: String) {
        val intent = Intent(ACTION_STATUS_CHANGED).apply {
            putExtra("type", "status")
            putExtra("status", status)
            putExtra("message", message)
        }
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }

    private fun sendHostKeyUpdate(hostname: String, fingerprint: String, keyString: String) {
        val intent = Intent(ACTION_STATUS_CHANGED).apply {
            putExtra("type", "hostKey")
            putExtra("hostname", hostname)
            putExtra("fingerprint", fingerprint)
            putExtra("keyString", keyString)
        }
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }
    
    companion object {
        const val ACTION_STATUS_CHANGED = "com.iwansrv.sshtunnel.STATUS_CHANGED"
        const val PREFS_NAME = "SSHTunnel_KnownHosts"
        const val PREFS_KEY = "hosts"
    }
}

// --- Custom HostKey Verifier ---

class KnownHostsVerifier(private val context: Context, private val newTrustedKey: String?) : HostKeyVerifier {

    override fun verify(hostname: String, port: Int, key: PublicKey): Boolean {
        val keyString = Base64.encodeToString(key.encoded, Base64.NO_WRAP)
        val fingerprint = com.hierynomus.sshj.transport.verification.SecurityUtils.getFingerprint(key)
        val host = "$hostname:$port"
        
        val prefs = context.getSharedPreferences(MyVpnService.PREFS_NAME, Context.MODE_PRIVATE)
        val knownHosts = prefs.getStringSet(MyVpnService.PREFS_KEY, emptySet()) ?: emptySet()

        // 1. If user just trusted this key from the UI, save it and approve.
        if (keyString == newTrustedKey) {
            val editor = prefs.edit()
            val updatedHosts = knownHosts.toMutableSet()
            updatedHosts.add("$host $keyString")
            editor.putStringSet(MyVnService.PREFS_KEY, updatedHosts)
            editor.apply()
            return true
        }

        // 2. Check if the host is already known
        for (entry in knownHosts) {
            val parts = entry.split(" ")
            if (parts.size == 2 && parts[0] == host) {
                 // Host is known, check if key matches
                if (parts[1] == keyString) {
                    return true // Key matches, it's our server.
                } else {
                    // KEY MISMATCH! Possible MitM attack!
                    throw HostKeyNotTrustedException(
                        "WARNING! HOST KEY HAS CHANGED FOR $host! POSSIBLE MitM ATTACK!", 
                        hostname,
                        fingerprint,
                        keyString
                    )
                }
            }
        }

        // 3. Host is not known, ask user for verification.
        throw HostKeyNotTrustedException("Unknown host key for $host", hostname, fingerprint, keyString)
    }
}

class HostKeyNotTrustedException(
    message: String, 
    val hostname: String, 
    val fingerprint: String, 
    val keyString: String
) : IOException(message)

// (The CustomHttpProxyConnector class remains the same as before)

class CustomHttpProxyConnector(
    private val proxyHost: String,
    private val proxyPort: Int,
    private val sshHost: String,
    private val sshPort: Int,
    private val payload: String,
    private val sni: String?,
    private val logCallback: (String, String) -> Unit
) : (SSHClient) -> Transport {

    override fun invoke(client: SSHClient): Transport {
        return object : TCPTransport(client) {
            override fun open(host: String, port: Int): Socket {
                logCallback("connecting", "Opening socket to proxy $proxyHost:$proxyPort...")
                var socket = Socket()
                socket.connect(InetSocketAddress(proxyHost, proxyPort), client.connectTimeout)
                logCallback("connecting", "Socket connected. Applying SNI if needed.")

                // Apply SNI if present
                if (!sni.isNullOrEmpty()) {
                    logCallback("connecting", "Wrapping socket with SSL/TLS and setting SNI to: $sni")
                    val sslSocketFactory = SSLSocketFactory.getDefault() as SSLSocketFactory
                    val sslSocket = sslSocketFactory.createSocket(socket, proxyHost, proxyPort, true) as SSLSocket

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                         val params = sslSocket.sslParameters
                         params.serverNames = listOf(javax.net.ssl.SNIServerName(0, sni.toByteArray()))
                         sslSocket.sslParameters = params
                    } else {
                         try {
                            val setHostnameMethod = sslSocket.javaClass.getMethod("setHostname", String::class.java)
                            setHostnameMethod.invoke(sslSocket, sni)
                        } catch (e: Exception) {
                            throw IOException("Failed to set SNI on older Android version: ${e.message}", e)
                        }
                    }

                    logCallback("connecting", "Starting SSL/TLS handshake with proxy...")
                    sslSocket.startHandshake()
                    socket = sslSocket
                    logCallback("connecting", "Handshake successful.")
                }
                
                logCallback("connecting", "Creating tunnel by sending payload...")
                createTunnel(socket)
                
                return socket
            }
        }
    }
    
    @Throws(IOException::class)
    private fun createTunnel(sock: Socket) {
        val out = sock.outputStream
        val 'in' = sock.inputStream

        val processedPayload = payload
            .replace("[host_port]", "$sshHost:$sshPort")
            .replace("[ssh_host]", sshHost)
            .replace("[ssh_port]", sshPort.toString())
            .replace("[protocol]", "HTTP/1.1")
            .replace("\r\n", "
")

        logCallback("connecting", "Sending payload:
$processedPayload")
        out.write(processedPayload.toByteArray())
        out.flush()

        val response = readResponse( 'in')
        logCallback("connecting", "Proxy response:
$response")

        if (!response.startsWith("HTTP/1.") || !response.contains("200")) {
            throw IOException("Proxy responded with an error: ${response.substring(0, response.indexOf('
'))}")
        }
    }

    @Throws(IOException::class)
    private fun readResponse(inputStream: InputStream): String {
         val builder = StringBuilder()
         val buffer = ByteArray(1024)
         var len: Int

         len = inputStream.read(buffer)
         if(len == -1) throw IOException("Proxy closed connection unexpectedly.")
         builder.append(String(buffer, 0, len))
        
        while (!builder.toString().endsWith("

")) {
             len = inputStream.read(buffer)
             if(len == -1) break;
             builder.append(String(buffer, 0, len))
        }

        return builder.toString()
    }
}

