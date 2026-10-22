package org.sableos.titan2.camera.ui

import android.graphics.Matrix
import android.graphics.RectF
import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.InputDevice
import android.view.MotionEvent
import android.view.TextureView
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import org.sableos.titan2.camera.core.CameraAction
import org.sableos.titan2.camera.core.CameraDeviceProfile
import org.sableos.titan2.camera.core.DeckContext
import org.sableos.titan2.camera.core.DeckOrientation
import org.sableos.titan2.camera.core.DeckPresentation
import org.sableos.titan2.camera.core.DeckState
import org.sableos.titan2.camera.core.RecState
import org.sableos.titan2.camera.core.Size
import org.sableos.titan2.camera.core.TouchFallback
import org.sableos.titan2.camera.core.UiMode

// Pixel-angle and Compose presentation values are not permissions or runtime policy.
private const val HUD_HINT_SP = 11
private const val HUD_MUTED_ARGB = 0xFF8BA6B8
private const val QUARTER_TURN_DEGREES = 90f
private const val HALF_TURN_DEGREES = 180f
private const val SELECTED_MODE_ARGB = 0xFF55B9FF

/** One immutable rendering snapshot, with no control/permission ownership. */
internal data class CameraScreenInfo(
    val hud: String,
    val status: String,
    val warning: String?,
    val recording: RecState,
    val elapsedMs: Long
)

internal data class CameraScreenFrame(
    val deck: DeckState,
    val context: DeckContext?,
    val profile: CameraDeviceProfile,
    val previewAspect: Float,
    val presentation: DeckPresentation,
    val info: CameraScreenInfo
)

internal data class CameraScreenActions(
    val preview: @Composable (Modifier) -> Unit,
    val modeSelector: @Composable (Modifier) -> Unit,
    val revealTouch: () -> Unit,
    val action: (CameraAction) -> Unit,
    val dismissStrip: () -> Unit,
    val dismissLegend: () -> Unit
)

/** Pure Compose layout; real touch and key commands still use the activity's one action router. */
@Suppress("FunctionNaming")
@Composable
internal fun CameraScreenContent(frame: CameraScreenFrame, actions: CameraScreenActions) {
    val dc = frame.context
    Box(Modifier.fillMaxSize().background(Color.Black).safeDrawingPadding()) {
        actions.preview(
            Modifier.align(Alignment.Center).fillMaxWidth().aspectRatio(frame.previewAspect)
        )
        StatusOverlay(
            frame.info.hud,
            frame.info.status,
            frame.info.warning,
            Modifier.align(Alignment.TopStart).padding(8.dp)
        )
        if (frame.info.recording != RecState.Idle) {
            RecordingBadge(
                frame.info.recording,
                frame.info.elapsedMs,
                Modifier.align(Alignment.TopEnd).padding(8.dp)
            )
        }
        Column(Modifier.align(Alignment.BottomCenter).padding(bottom = 6.dp)) {
            if (
                DeckOrientation.touchChromeVisible(
                    frame.presentation,
                    frame.deck.touchChromeRevealed
                )
            ) {
                actions.modeSelector(
                    Modifier.align(Alignment.CenterHorizontally).padding(vertical = 2.dp)
                )
                if (dc != null) {
                    TouchControlBar(TouchFallback.controls(dc), actions.action, Modifier)
                }
            }
            Text(
                "H or ? shows the controls",
                color = Color(HUD_MUTED_ARGB),
                fontSize = HUD_HINT_SP.sp,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        }
        DeckOverlays(frame.deck, dc, frame.profile, actions.dismissStrip, actions.dismissLegend)
    }
}

/** Exact texture geometry policy extracted from the Activity; no changes to rotation behavior. */
internal fun transformCameraPreview(tv: TextureView, ps: Size, rotation: Int) {
    val vw = tv.width.toFloat()
    val vh = tv.height.toFloat()
    if (vw == 0f || vh == 0f) return
    val m = Matrix()
    val view = RectF(0f, 0f, vw, vh)
    val buf = RectF(0f, 0f, ps.h.toFloat(), ps.w.toFloat())
    val cx = view.centerX()
    val cy = view.centerY()
    when (rotation) {
        Surface.ROTATION_90, Surface.ROTATION_270 -> {
            buf.offset(cx - buf.centerX(), cy - buf.centerY())
            m.setRectToRect(view, buf, Matrix.ScaleToFit.FILL)
            val s = maxOf(vh / ps.h, vw / ps.w)
            m.postScale(s, s, cx, cy)
            m.postRotate(QUARTER_TURN_DEGREES * (rotation - Surface.ROTATION_180), cx, cy)
        }

        Surface.ROTATION_180 -> m.postRotate(HALF_TURN_DEGREES, cx, cy)
    }
    tv.setTransform(m)
}

@Suppress("FunctionNaming")
@Composable
internal fun CameraPreviewSurface(
    modifier: Modifier,
    onViewCreated: (TextureView) -> Unit,
    listener: TextureView.SurfaceTextureListener,
    onDirectScreenTap: () -> Unit
) {
    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            TextureView(ctx).apply {
                onViewCreated(this)
                surfaceTextureListener = listener
            }
        },
        update = { view ->
            // Trackpads and connected mice emit SOURCE_MOUSE: they must not be
            // reinterpreted as a physical touchscreen press on the preview.
            view.setOnTouchListener { _, event ->
                val touchScreen =
                    (event.source and InputDevice.SOURCE_TOUCHSCREEN) ==
                        InputDevice.SOURCE_TOUCHSCREEN
                val touchTool =
                    event.getToolType(0) == MotionEvent.TOOL_TYPE_FINGER ||
                        event.getToolType(0) == MotionEvent.TOOL_TYPE_STYLUS
                if (!touchScreen || !touchTool) {
                    false
                } else {
                    if (event.actionMasked == MotionEvent.ACTION_UP) {
                        onDirectScreenTap()
                    }
                    true
                }
            }
        }
    )
}

internal fun cameraSurfaceListener(
    onAvailable: (SurfaceTexture) -> Unit,
    onChanged: () -> Unit,
    onDestroyed: () -> Unit
): TextureView.SurfaceTextureListener = object : TextureView.SurfaceTextureListener {
    override fun onSurfaceTextureAvailable(st: SurfaceTexture, w: Int, h: Int) = onAvailable(st)

    override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, w: Int, h: Int) = onChanged()

    override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean {
        onDestroyed()
        return true
    }

    override fun onSurfaceTextureUpdated(st: SurfaceTexture) {
        // No per-frame work: TextureView draws the preview itself.
    }
}

@Suppress("FunctionNaming")
@Composable
internal fun CameraModeSelector(
    avail: List<UiMode>,
    selected: UiMode,
    enabled: Boolean,
    onSelect: (UiMode) -> Unit,
    modifier: Modifier
) {
    Row(modifier) {
        avail.forEach { m ->
            Text(
                m.label,
                fontSize = 14.sp,
                color = if (m == selected) Color(SELECTED_MODE_ARGB) else Color.White,
                modifier = Modifier.clickable(enabled = enabled) {
                    onSelect(m)
                }.padding(horizontal = 10.dp, vertical = 4.dp)
            )
        }
    }
}
