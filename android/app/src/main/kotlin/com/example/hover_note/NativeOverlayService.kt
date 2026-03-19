package com.example.hover_note

import com.example.hover_note.R
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import io.flutter.plugin.common.MethodChannel

/**
 * NativeOverlayService
 * --------------------
 * A foreground Service that uses Android's WindowManager to create
 * truly independent, individually-draggable floating overlay windows.
 *
 * Each note gets its OWN View added via windowManager.addView(),
 * so they can be positioned and dragged independently of each other.
 *
 * Communication with Flutter:
 *   Flutter  →  Native:  via MethodChannel calls (show/close)
 *   Native   →  Flutter: via MethodChannel.invokeMethod on the stored channel
 */
class NativeOverlayService : Service() {
    private val TAG = "NativeOverlayService"

    companion object {
        // Stores the MethodChannel so we can send events back to Flutter
        var methodChannel: MethodChannel? = null

        private const val CHANNEL_ID = "hover_note_overlay_channel"
        private const val NOTIFICATION_ID = 1001
    }

    // Map of note-ID → its currently-displayed overlay View
    private val overlayViews = HashMap<Int, View>()

    // Reference to the system WindowManager for adding/removing views
    private lateinit var windowManager: WindowManager

    // ──────────────────────────────────────────────
    // Service lifecycle
    // ──────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        // Get the system WindowManager — this is what lets us draw on top of other apps
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    /**
     * Called every time Flutter tells us to do something (show/close).
     * START_STICKY means Android will restart the service if it gets killed.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")
        // Must call startForeground() within 5 seconds of startForegroundService()
        startForegroundNotification()

        when (intent?.action) {
            "SHOW_OVERLAY" -> {
                val id = intent.getIntExtra("id", -1)
                val text = intent.getStringExtra("text") ?: ""
                val color = intent.getIntExtra("color", Color.BLACK)
                Log.d(TAG, "SHOW_OVERLAY: id=$id, text=$text, color=$color")
                if (id != -1) {
                    showOverlay(id, text, color)
                }
            }
            "CLOSE_OVERLAY" -> {
                val id = intent.getIntExtra("id", -1)
                if (id != -1) {
                    closeOverlay(id)
                }
            }
            "CLOSE_ALL" -> {
                closeAllOverlays()
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        closeAllOverlays()
        super.onDestroy()
    }

    // ──────────────────────────────────────────────
    // Foreground notification (required by Android for long-running services)
    // ──────────────────────────────────────────────

    /**
     * Android requires foreground services to show a persistent notification.
     * This creates a minimal, low-priority notification so it doesn't bother the user.
     */
    private fun startForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Hover Note Overlays",
                NotificationManager.IMPORTANCE_LOW  // Low = no sound, small icon only
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Hover Note")
                .setContentText("Notes are floating")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Hover Note")
                .setContentText("Notes are floating")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .build()
        }

        startForeground(NOTIFICATION_ID, notification)
    }

    // ──────────────────────────────────────────────
    // Core overlay logic
    // ──────────────────────────────────────────────

    /**
     * Creates a new floating overlay window for the given note.
     *
     * How it works:
     * 1. Creates LayoutParams with TYPE_APPLICATION_OVERLAY — this is the Android
     *    window type that allows drawing on top of all other apps.
     * 2. Builds a styled View with the note text, close button, and minimize button.
     * 3. Attaches a touch listener for drag-to-move.
     * 4. Adds the View to the WindowManager — it now floats independently!
     */
    private fun showOverlay(id: Int, text: String, color: Int) {
        Log.d(TAG, "showOverlay: creating overlay for id=$id")
        // If this note already has an overlay, remove the old one first
        if (overlayViews.containsKey(id)) {
            windowManager.removeView(overlayViews[id])
            overlayViews.remove(id)
        }

        // ── Layout Parameters ──
        // TYPE_APPLICATION_OVERLAY: draws on top of all apps (requires SYSTEM_ALERT_WINDOW permission)
        // FLAG_NOT_FOCUSABLE: lets touch events pass through to apps underneath when not touching the overlay
        // WRAP_CONTENT: the window sizes itself to fit its content
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, // was 280dp, now WRAP_CONTENT to allow for shadow padding
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT                // allows transparency/rounded corners
        )
        params.gravity = Gravity.TOP or Gravity.START  // position from top-left corner
        params.x = dpToPx(40) + (overlayViews.size * dpToPx(20))  // stagger each new overlay slightly
        params.y = dpToPx(100) + (overlayViews.size * dpToPx(60))

        // ── Build the View ──
        val overlayView = buildNoteView(id, text, color, params)

        // ── Add to WindowManager ──
        // This is the magic call — it makes the view float on top of everything!
        windowManager.addView(overlayView, params)
        overlayViews[id] = overlayView
    }

    /**
     * Removes a specific note's overlay from the screen.
     * Called when the user taps the close button, or from Flutter.
     */
    private fun closeOverlay(id: Int) {
        overlayViews[id]?.let { view ->
            windowManager.removeView(view)
            overlayViews.remove(id)

            // Tell Flutter that this overlay was closed (so it can update _activeOverlayIds)
            methodChannel?.invokeMethod("onOverlayClosed", mapOf("id" to id))
        }

        // If no overlays remain, stop the service entirely
        if (overlayViews.isEmpty()) {
            stopSelf()
        }
    }

    /**
     * Removes ALL overlay windows. Called when the service is destroyed
     * or when Flutter explicitly requests it.
     */
    private fun closeAllOverlays() {
        for ((id, view) in overlayViews) {
            windowManager.removeView(view)
            methodChannel?.invokeMethod("onOverlayClosed", mapOf("id" to id))
        }
        overlayViews.clear()
        stopSelf()
    }

    // ──────────────────────────────────────────────
    // View construction — builds the note card UI natively
    // ──────────────────────────────────────────────

    /**
     * Builds the complete overlay View for a single note.
     * Matches the Flutter _ExpandedView layout:
     *
     *   DraggableFrameLayout (outer container, handles drag)
     *     └─ LinearLayout HORIZONTAL (card with rounded corners + color)
     *          ├─ TextView (note text, left side, fills space)
     *          └─ LinearLayout VERTICAL (buttons: close + minimize, right side)
     */
    private fun buildNoteView(
        id: Int,
        text: String,
        color: Int,
        params: WindowManager.LayoutParams
    ): View {
        val context = this

        // ── Outer draggable container ──
        val container = DraggableFrameLayout(context, windowManager, params).apply {
            // Add padding to allow the shadow to draw without being clipped by the window edges
            val padding = dpToPx(20)
            setPadding(padding, padding, padding, padding)
            clipChildren = false
            clipToPadding = false
        }

        // ── Card: HORIZONTAL layout (text left, buttons right) ──
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dpToPx(12), dpToPx(12), dpToPx(12), dpToPx(12))
            gravity = Gravity.TOP
            
            // Set fixed width of 280dp so it stays consistent inside the padded container
            val cardWidth = dpToPx(280)
            layoutParams = FrameLayout.LayoutParams(cardWidth, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.CENTER
            }

            val bg = GradientDrawable().apply {
                setColor(color)
                cornerRadius = dpToPx(20).toFloat()
            }
            background = bg
            elevation = dpToPx(4).toFloat()
        }

        // ── Note text (left side, fills available width) ──
        val textView = TextView(context).apply {
            this.text = text
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            
            // Apply custom "Arista" font from assets
            try {
                typeface = Typeface.createFromAsset(context.assets, "fonts/Arista2.0.ttf")
            } catch (e: Exception) {
                typeface = Typeface.DEFAULT_BOLD
            }
            
            maxLines = 7
            ellipsize = android.text.TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f  // weight=1 → fills remaining space
            )
        }

        // ── 8dp spacer between text and buttons ──
        val spacer = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(8), 1)
        }

        // ── Button column (right side, vertically stacked) ──
        val buttonCol = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.TOP
        }

        // Close icon (✕) — white, 18sp, no background
        val closeIcon = TextView(context).apply {
            this.text = "✕"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            val size = dpToPx(24)
            layoutParams = LinearLayout.LayoutParams(size, size)
            setOnClickListener { closeOverlay(id) }
        }

        // 6dp spacer between close and minimize
        val iconSpacer = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(1, dpToPx(6))
        }

        // Minimize icon (—) — white, 18sp, no background
        val minimizeIcon = TextView(context).apply {
            this.text = "—"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            val size = dpToPx(24)
            layoutParams = LinearLayout.LayoutParams(size, size)
            setOnClickListener { toggleMinimize(id, text, color, params) }
        }

        buttonCol.addView(closeIcon)
        buttonCol.addView(iconSpacer)
        buttonCol.addView(minimizeIcon)

        // ── Dynamic Orientation based on Line Count ──
        // If 1-2 lines → Horizontal icons. 3+ lines → Vertical icons.
        textView.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                textView.viewTreeObserver.removeOnGlobalLayoutListener(this)
                val lines = textView.lineCount
                if (lines > 0) {
                    if (lines <= 2) {
                        if(lines<=1){
                            if(textView.text.length>32){
                                textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                            }else{
                                textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
                            }
                        }
                        buttonCol.orientation = LinearLayout.HORIZONTAL
                        buttonCol.gravity = Gravity.CENTER_VERTICAL
                        iconSpacer.layoutParams = LinearLayout.LayoutParams(dpToPx(6), 1)
                    } else {
                        buttonCol.orientation = LinearLayout.VERTICAL
                        buttonCol.gravity = Gravity.TOP
                        iconSpacer.layoutParams = LinearLayout.LayoutParams(1, dpToPx(6))
                    }
                }
            }
        })

        card.addView(textView)
        card.addView(spacer)
        card.addView(buttonCol)

        container.addView(card, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))

        return container
    }

    // ──────────────────────────────────────────────
    // Minimize / Bubble toggle
    // ──────────────────────────────────────────────

    /**
     * Minimizes a note overlay into a small colored bubble.
     * Matches Flutter _BubbleView: 60x60 circle with sticky note icon.
     */
    private fun toggleMinimize(id: Int, text: String, color: Int, params: WindowManager.LayoutParams) {
        val currentView = overlayViews[id] ?: return

        val isMinimized = currentView.tag == "minimized"

        windowManager.removeView(currentView)

        if (!isMinimized) {
            // → Minimize: create a colored circle with a note icon inside
            val bubbleSize = dpToPx(45)
            val bubblePadding = dpToPx(12) // Extra padding for shadow

            val bubble = FrameLayout(this).apply {
                tag = "minimized"
                setTag(R.id.note_id_tag, id)
                setTag(R.id.note_color_tag, color)
                setTag(R.id.note_text_tag, text)
                
                clipChildren = false
                clipToPadding = false
                
                // Tap to expand
                setOnClickListener {
                    Log.d(TAG, "Bubble tapped — expanding note id=$id")
                    val savedText = it.getTag(R.id.note_text_tag) as? String ?: ""
                    val savedColor = it.getTag(R.id.note_color_tag) as? Int ?: Color.BLACK
                    val savedId = it.getTag(R.id.note_id_tag) as? Int ?: -1
                    expandFromBubble(savedId, savedText, savedColor)
                }
            }

            // 1. The Circle View
            val circle = View(this).apply {
                layoutParams = FrameLayout.LayoutParams(bubbleSize, bubbleSize).apply {
                    gravity = Gravity.CENTER
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(color)
                }
                elevation = dpToPx(4).toFloat()
            }

            // 2. The Custom Note Icon (SVG)
            val icon = ImageView(this).apply {
                setImageResource(R.drawable.ic_note)
                // Icon size is 26dp (enough for the 45dp bubble)
                val iconSize = dpToPx(24)
                layoutParams = FrameLayout.LayoutParams(iconSize, iconSize).apply {
                    gravity = Gravity.CENTER
                }
                // HIGHER elevation than the circle to ensure visibility
                elevation = dpToPx(8).toFloat()
            }

            bubble.addView(circle)
            bubble.addView(icon)

            val bubbleParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            )
            bubbleParams.gravity = Gravity.TOP or Gravity.START
            bubbleParams.x = params.x
            bubbleParams.y = params.y
            
            // Add padding to bubble so the shadow isn't cut off inside the window
            bubble.setPadding(bubblePadding, bubblePadding, bubblePadding, bubblePadding)

            attachDragListener(bubble, bubbleParams)
            windowManager.addView(bubble, bubbleParams)
            overlayViews[id] = bubble
        } else {
            // → Expand: rebuild the full note view
            val expandedView = buildNoteView(id, text, color, params)
            windowManager.addView(expandedView, params)
            overlayViews[id] = expandedView
        }
    }

    /**
     * Expands a minimized bubble back to a full card view.
     * All data is stored on the bubble's view tags, so no Flutter roundtrip needed.
     */
    private fun expandFromBubble(id: Int, text: String, color: Int) {
        val currentView = overlayViews[id] ?: return

        // Get current position before removing
        val currentParams = currentView.layoutParams as WindowManager.LayoutParams
        val savedX = currentParams.x
        val savedY = currentParams.y

        windowManager.removeView(currentView)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = savedX
        params.y = savedY

        val expandedView = buildNoteView(id, text, color, params)
        windowManager.addView(expandedView, params)
        overlayViews[id] = expandedView
    }

    /**
     * Called from Flutter when it responds to "requestNoteData" with the full note info.
     * Replaces the minimized bubble with the full expanded card.
     */
    fun expandOverlay(id: Int, text: String, color: Int) {
        val currentView = overlayViews[id] ?: return

        // Get current position before removing
        val currentParams = currentView.layoutParams as WindowManager.LayoutParams
        val savedX = currentParams.x
        val savedY = currentParams.y

        windowManager.removeView(currentView)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = savedX
        params.y = savedY

        val expandedView = buildNoteView(id, text, color, params)
        windowManager.addView(expandedView, params)
        overlayViews[id] = expandedView
    }

    // ──────────────────────────────────────────────
    // Drag handling — makes each overlay independently movable
    // ──────────────────────────────────────────────

    /**
     * Attaches a touch listener to a View that lets the user drag it around the screen.
     *
     * How dragging works:
     * 1. ACTION_DOWN: record the initial touch position and window position
     * 2. ACTION_MOVE: calculate the delta (how far the finger moved) and update
     *    the window's x/y by that amount, then call updateViewLayout() to move it
     */
    private fun attachDragListener(view: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager.updateViewLayout(view, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    // If the finger barely moved, treat it as a tap (click)
                    val dx = Math.abs(event.rawX - initialTouchX)
                    val dy = Math.abs(event.rawY - initialTouchY)
                    if (dx < 10 && dy < 10) {
                        v.performClick()
                    }
                    true
                }
                else -> false
            }
        }
    }

    // ──────────────────────────────────────────────
    // Utility
    // ──────────────────────────────────────────────

    /** Converts dp (density-independent pixels) to actual screen pixels. */
    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}

/**
 * DraggableFrameLayout
 * --------------------
 * A custom FrameLayout that intercepts drag gestures to move the overlay window,
 * while still allowing taps/clicks to pass through to child views (buttons etc).
 *
 * How it works:
 * - onInterceptTouchEvent: monitors finger movement. If finger moves > 10px,
 *   it intercepts the touch and starts dragging. Children stop receiving events.
 * - onTouchEvent: actually moves the window via WindowManager.updateViewLayout().
 * - If the finger barely moves (< 10px), interception never happens, so children
 *   receive the full touch sequence and their onClick handlers fire normally.
 */
class DraggableFrameLayout(
    context: android.content.Context,
    private val windowManager: WindowManager,
    private val params: WindowManager.LayoutParams
) : FrameLayout(context) {

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isDragging = false

    private val DRAG_THRESHOLD = 10f

    override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
        when (ev.action) {
            MotionEvent.ACTION_DOWN -> {
                // Record starting positions
                initialX = params.x
                initialY = params.y
                initialTouchX = ev.rawX
                initialTouchY = ev.rawY
                isDragging = false
                return false  // Don't intercept yet — let children see the DOWN
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = Math.abs(ev.rawX - initialTouchX)
                val dy = Math.abs(ev.rawY - initialTouchY)
                if (dx > DRAG_THRESHOLD || dy > DRAG_THRESHOLD) {
                    isDragging = true
                    return true  // START intercepting — children stop receiving events
                }
            }
        }
        return false
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                // When no child consumed DOWN, it ends up here.
                // Return true to claim the touch sequence so we get MOVE/UP.
                initialX = params.x
                initialY = params.y
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                isDragging = false
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                // Calculate movement delta
                val dx = Math.abs(event.rawX - initialTouchX)
                val dy = Math.abs(event.rawY - initialTouchY)
                if (dx > DRAG_THRESHOLD || dy > DRAG_THRESHOLD) {
                    isDragging = true
                }
                if (isDragging) {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager.updateViewLayout(this, params)
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                isDragging = false
                return true
            }
        }
        return super.onTouchEvent(event)
    }
}
