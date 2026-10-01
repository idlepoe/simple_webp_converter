package com.jylee.simple_webp_converter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingSave: Pair<String, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "simple_webp_converter/media")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveWebp") { result.notImplemented(); return@setMethodCallHandler }
                val path = call.argument<String>("path")
                if (path == null) { result.error("INVALID_PATH", "Missing file", null); return@setMethodCallHandler }
                if (Build.VERSION.SDK_INT < 29 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    if (pendingSave != null) { result.error("BUSY", "Save already pending", null); return@setMethodCallHandler }
                    pendingSave = Pair(path, result)
                    requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 701)
                } else saveWebp(path, result)
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 701) {
            val pending = pendingSave ?: return
            pendingSave = null
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) saveWebp(pending.first, pending.second)
            else pending.second.error("PERMISSION_DENIED", "Storage access denied", null)
        }
    }

    // Copy bytes instead of bitmap re-encoding, preserving animation and quality.
    private fun saveWebp(path: String, result: MethodChannel.Result) {
        Thread {
            try {
                val source = File(path)
                require(source.isFile && source.length() > 12)
                val name = "WebP_${System.currentTimeMillis()}.webp"
                if (Build.VERSION.SDK_INT >= 29) {
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, name)
                        put(MediaStore.Images.Media.MIME_TYPE, "image/webp")
                        put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/WebP Converter")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                        ?: error("Could not create gallery entry")
                    try {
                        val output = contentResolver.openOutputStream(uri) ?: error("Could not open gallery entry")
                        output.use { target -> source.inputStream().use { it.copyTo(target) } }
                        values.clear()
                        values.put(MediaStore.Images.Media.IS_PENDING, 0)
                        contentResolver.update(uri, values, null, null)
                    } catch (error: Exception) {
                        contentResolver.delete(uri, null, null)
                        throw error
                    }
                } else {
                    @Suppress("DEPRECATION")
                    val directory = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "WebP Converter")
                    check(directory.exists() || directory.mkdirs())
                    val target = File(directory, name)
                    try { source.copyTo(target) }
                    catch (error: Exception) { target.delete(); throw error }
                    MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), arrayOf("image/webp"), null)
                }
                runOnUiThread { result.success(null) }
            } catch (error: Exception) {
                runOnUiThread { result.error("SAVE_FAILED", error.message, null) }
            }
        }.start()
    }
}
