package com.darsakai.darsak_teacher_v2

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val FILE_PICK_CHANNEL = "com.darsakai/file_picker"
    private val PICK_PDF = 1001
    private val PICK_IMAGE = 1002
    private val PICK_ANY = 1003
    private var pendingResult: MethodChannel.Result? = null
    private var sharedPdfPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_PICK_CHANNEL)
            .setMethodCallHandler { call, callResult ->
                when (call.method) {
                    "pickPdf" -> {
                        pendingResult = callResult
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "application/pdf"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(Intent.createChooser(intent, "اختر ملف PDF"), PICK_PDF)
                    }
                    "pickImage" -> {
                        pendingResult = callResult
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(Intent.createChooser(intent, "اختر صورة"), PICK_IMAGE)
                    }
                    "pickAny" -> {
                        pendingResult = callResult
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "*/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                                "application/pdf",
                                "image/jpeg",
                                "image/png",
                                "image/webp"
                            ))
                        }
                        startActivityForResult(Intent.createChooser(intent, "اختر ملف"), PICK_ANY)
                    }
                    "getSharedPdf" -> {
                        callResult.success(sharedPdfPath)
                        sharedPdfPath = null
                    }
                    else -> callResult.notImplemented()
                }
            }

        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "application/pdf") {
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            if (uri != null) {
                val path = copyUriToCache(uri)
                if (path != null) {
                    sharedPdfPath = path
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val displayName = getDisplayName(uri)
            val cacheDir = cacheDir
            val file = File(cacheDir, displayName)
            contentResolver.openInputStream(uri)?.use { input ->
                file.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            file.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun getDisplayName(uri: Uri): String {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                cursor.moveToFirst()
                if (idx >= 0) cursor.getString(idx) else "file"
            } ?: "file"
        } catch (e: Exception) {
            "file"
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode == Activity.RESULT_OK && data?.data != null) {
            val uri: Uri = data.data!!
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: SecurityException) {}
            val filePath = copyUriToCache(uri)
            pendingResult?.success(filePath)
        } else {
            pendingResult?.success(null)
        }
        pendingResult = null
    }
}
