package ultracoachmatrix.`in`

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val downloadChannelName = "ultracoachmatrix.in/downloads"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            downloadChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path").orEmpty()
                    scanFile(path)
                    result.success(null)
                }
                "openFile" -> {
                    val path = call.argument<String>("path").orEmpty()
                    val mimeType = call.argument<String>("mimeType").orEmpty().ifBlank { "*/*" }
                    openFile(path, mimeType, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channelId = getString(R.string.default_notification_channel_id)
        val channel = NotificationChannel(
            channelId,
            "UltraCoachMatrix Notifications",
            NotificationManager.IMPORTANCE_HIGH,
        )
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager?.createNotificationChannel(channel)
    }

    private fun scanFile(path: String) {
        if (path.isBlank()) {
            return
        }
        MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
    }

    private fun openFile(
        path: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        if (path.isBlank()) {
            result.error("missing_path", "File path is empty.", null)
            return
        }

        val file = File(path)
        if (!file.exists()) {
            result.error("missing_file", "Downloaded file was not found.", null)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(Intent.createChooser(intent, "Open downloaded file"))
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("no_viewer", "No app is available to open this file.", null)
        }
    }
}
