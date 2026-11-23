package com.shadow.blackhole

import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Message
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.Toast
import android.net.Uri

/**
 * Jotify Online: the live, same-origin website is the Android app's online UI.
 *
 * Keep the existing Flutter AudioServiceActivity and its offline library in
 * the APK. Users can open it from the exit dialog ("Classic / Offline").
 *
 * IMPORTANT: WebView does not authorize screen-locked/background-only YouTube
 * playback. Keep the official player visible and respect YouTube restrictions.
 */
class JotifyOnlineActivity : Activity() {
    private val homeUrl = "https://jotify-web-online.onrender.com/"
    private val trustedHost = "jotify-web-online.onrender.com"
    private lateinit var root: FrameLayout
    private lateinit var browser: WebView
    private var fullscreenView: View? = null
    private var fullscreenCallback: WebChromeClient.CustomViewCallback? = null
    private var previousOrientation: Int = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.rgb(14, 19, 18)
        window.navigationBarColor = Color.rgb(14, 19, 18)

        root = FrameLayout(this)
        browser = WebView(this)
        browser.setBackgroundColor(Color.rgb(14, 17, 18))
        root.addView(
            browser,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        setContentView(root)

        browser.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            useWideViewPort = true
            loadWithOverviewMode = true
            mediaPlaybackRequiresUserGesture = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            allowFileAccess = false
            allowContentAccess = false
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(true)
        }
        CookieManager.getInstance().setAcceptCookie(true)
        // Some YouTube embeds depend on their own cookies. Never inject or extract
        // YouTube auth, and always leave playback inside the official player.
        CookieManager.getInstance().setAcceptThirdPartyCookies(browser, true)

        browser.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean {
                // Do not override iframe/video requests. Navigation rules only
                // apply to top-level links tapped by the user.
                if (!request.isForMainFrame) return false
                val uri = request.url
                if (uri.scheme == "https" && uri.host == trustedHost) return false
                if (uri.scheme == "https" || uri.scheme == "http") {
                    openExternal(uri)
                    return true
                }
                return true
            }
        }
        browser.webChromeClient = object : WebChromeClient() {
            override fun onShowCustomView(
                view: View,
                callback: WebChromeClient.CustomViewCallback
            ) {
                if (fullscreenView != null) {
                    callback.onCustomViewHidden()
                    return
                }
                fullscreenView = view
                fullscreenCallback = callback
                previousOrientation = requestedOrientation
                browser.visibility = View.INVISIBLE
                root.addView(
                    view,
                    FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                )
                window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            }

            override fun onHideCustomView() {
                exitFullscreen()
            }

            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message?
            ): Boolean {
                // YouTube's "open on YouTube" links should go to the system
                // browser, not replace the active Jotify player.
                if (!isUserGesture || resultMsg == null) return false
                val popup = WebView(this@JotifyOnlineActivity)
                popup.webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(
                        view: WebView,
                        request: WebResourceRequest
                    ): Boolean {
                        if (request.isForMainFrame) openExternal(request.url)
                        view.post { view.destroy() }
                        return true
                    }
                }
                val transport = resultMsg.obj as? WebView.WebViewTransport
                    ?: return false
                transport.webView = popup
                resultMsg.sendToTarget()
                return true
            }
        }
        browser.loadUrl(homeUrl)
    }

    private fun openExternal(uri: Uri) {
        if (uri.scheme != "http" && uri.scheme != "https") return
        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, "No browser available for this link", Toast.LENGTH_SHORT).show()
        }
    }

    private fun exitFullscreen() {
        val view = fullscreenView ?: return
        root.removeView(view)
        fullscreenView = null
        browser.visibility = View.VISIBLE
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        requestedOrientation = previousOrientation
        fullscreenCallback?.onCustomViewHidden()
        fullscreenCallback = null
    }

    private fun openClassicApp() {
        // Original Flutter/Audioservice entry remains compiled and installed.
        // No Hive database, downloads, or native playback code is altered.
        val nativeIntent = Intent().setClassName(
            this, "com.ryanheise.audioservice.AudioServiceActivity"
        )
        try {
            startActivity(nativeIntent)
        } catch (e: Exception) {
            Toast.makeText(this, "Classic player could not open", Toast.LENGTH_SHORT).show()
        }
    }

    @Deprecated("Use the Android back button to navigate Jotify")
    override fun onBackPressed() {
        if (fullscreenView != null) {
            exitFullscreen()
        } else if (browser.canGoBack()) {
            browser.goBack()
        } else {
            AlertDialog.Builder(this)
                .setTitle("Jotify")
                .setMessage("Keep listening online, open the classic/offline player, or exit?")
                .setPositiveButton("Classic / Offline") { _, _ -> openClassicApp() }
                .setNeutralButton("Exit") { _, _ -> finish() }
                .setNegativeButton("Stay here", null)
                .show()
        }
    }

    override fun onPause() {
        super.onPause()
        // Android and YouTube may pause when the app is backgrounded/locked.
        // Do not attempt to bypass these restrictions.
        browser.onPause()
    }

    override fun onResume() {
        super.onResume()
        browser.onResume()
    }

    override fun onDestroy() {
        exitFullscreen()
        root.removeView(browser)
        browser.destroy()
        super.onDestroy()
    }
}
