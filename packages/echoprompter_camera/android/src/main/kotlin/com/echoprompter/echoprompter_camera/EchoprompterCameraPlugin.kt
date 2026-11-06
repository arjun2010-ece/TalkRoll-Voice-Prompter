package com.echoprompter.echoprompter_camera

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Application
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.media.*
import android.os.*
import android.provider.MediaStore
import android.util.Log
import android.view.Surface
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.io.IOException
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Camera2 preview into a Flutter texture, plus a recorder where ONE
 * AudioRecord feeds both the AAC track and the speech engine (16 kHz mono).
 */
class EchoprompterCameraPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var textures: TextureRegistry
    private var activity: Activity? = null
    private val main = Handler(Looper.getMainLooper())
    private var audioSink: EventChannel.EventSink? = null
    private var eventSink: EventChannel.EventSink? = null

    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var entry: TextureRegistry.SurfaceTextureEntry? = null
    private var camera: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var facingFront = false
    private var cameraId = ""
    private var sensorOrientation = 0
    private var previewSize = android.util.Size(1920, 1080)
    // Bumped by every stopPreview so a camera that finishes opening afterwards is closed, not leaked.
    private var previewGen = 0

    private var audio: AudioCapture? = null
    private var recorder: Recorder? = null

    // The recording's audio for the speech recogniser: capture thread -> queue -> writer thread -> pipe.
    @Volatile private var speechQueue: ArrayBlockingQueue<ByteArray>? = null
    @Volatile private var speechDecimator: Decimator? = null
    private var speechRead: ParcelFileDescriptor? = null
    private var speechWrite: ParcelFileDescriptor? = null

    // MARK: FlutterPlugin

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        textures = b.textureRegistry
        SpeechAudioBridge.opener = ::openSpeechPipe
        SpeechAudioBridge.closer = ::closeSpeechPipe
        MethodChannel(b.binaryMessenger, "com.echoprompter/camera").setMethodCallHandler(this)
        EventChannel(b.binaryMessenger, "com.echoprompter/camera/audio").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(a: Any?, s: EventChannel.EventSink) { audioSink = s; ensureAudio() }
            override fun onCancel(a: Any?) { audioSink = null; releaseAudioIfUnused() }
        })
        EventChannel(b.binaryMessenger, "com.echoprompter/camera/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(a: Any?, s: EventChannel.EventSink) { eventSink = s }
            override fun onCancel(a: Any?) { eventSink = null }
        })
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) { teardown() }
    private val lifecycle = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityPaused(a: Activity) { if (a == activity && recorder != null) finishRecording("interrupted") }
        override fun onActivityCreated(a: Activity, s: Bundle?) {}
        // Release the microphone in the background; reopen it for a still-subscribed speech listener.
        override fun onActivityStarted(a: Activity) { if (a == activity && (audioSink != null || speechQueue != null)) ensureAudio() }
        override fun onActivityResumed(a: Activity) {}
        override fun onActivityStopped(a: Activity) {
            if (a == activity && recorder == null) { audio?.stop(); audio = null }
        }
        override fun onActivitySaveInstanceState(a: Activity, s: Bundle) {}
        override fun onActivityDestroyed(a: Activity) {}
    }
    private var lifecycleApp: Application? = null

    private fun attach(act: Activity) {
        activity = act
        if (lifecycleApp == null) {
            lifecycleApp = act.application.also { it.registerActivityLifecycleCallbacks(lifecycle) }
        }
    }

    private fun detach() {
        lifecycleApp?.unregisterActivityLifecycleCallbacks(lifecycle)
        lifecycleApp = null
        activity = null
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) = attach(b.activity)
    override fun onDetachedFromActivity() = detach()
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = attach(b.activity)
    override fun onDetachedFromActivityForConfigChanges() = detach()

    // MARK: Channel

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "startPreview" -> startPreview(call.argument<String>("facing") == "front", result)
                "stopPreview" -> { stopPreview(); result.success(null) }
                "startRecording" -> {
                    startRecording(call.argument<Boolean>("landscape") ?: false, call.argument<Int>("height") ?: 1080, call.argument<String>("narrationPath"))
                    result.success(null)
                }
                "narrationTick" -> {
                    recorder?.narrationTick((call.argument<Int>("positionMs") ?: 0) * 1000L, call.argument<Boolean>("playing") ?: false)
                    result.success(null)
                }
                "pauseRecording" -> { recorder?.pause(); result.success(null) }
                "resumeRecording" -> { recorder?.resume(); result.success(null) }
                "stopRecording" -> finishRecording(call.argument<String>("reason") ?: "user") { result.success(it) }
                "joinClips" -> joinClips(call.argument<List<String>>("paths") ?: emptyList(), result)
                "saveToGallery" -> { saveToGallery(call.argument<String>("path")!!); result.success(null) }
                "headphonesConnected" -> result.success(headphones())
                "setReferenceRoute" -> result.success(null) // reference audio always plays on the speaker
                "setInputPreference" -> {
                    preferHeadsetMic = call.argument<Boolean>("headset") ?: true
                    audio?.route(context, preferHeadsetMic)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("camera", e.message, null)
        }
    }

    /** Voice mode listens through a connected headset microphone; Audio mode must hear the speaker, so it uses the built-in one. */
    @Volatile private var preferHeadsetMic = true

    private fun headphones(): Boolean {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any {
            it.type in listOf(
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_USB_HEADSET,
            )
        }
    }

    // MARK: Preview

    private fun displayRotationDegrees(): Int {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        return when (wm.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> 90; Surface.ROTATION_180 -> 180; Surface.ROTATION_270 -> 270; else -> 0
        }
    }

    /** Degrees the sensor image must be rotated clockwise to appear upright. */
    private fun upright(display: Int) =
        if (facingFront) (sensorOrientation + display) % 360 else (sensorOrientation - display + 360) % 360

    @SuppressLint("MissingPermission")
    private fun startPreview(front: Boolean, result: MethodChannel.Result) {
        stopPreview()
        facingFront = front
        val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val want = if (front) CameraCharacteristics.LENS_FACING_FRONT else CameraCharacteristics.LENS_FACING_BACK
        cameraId = mgr.cameraIdList.firstOrNull { mgr.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == want }
            ?: throw IllegalStateException("No ${if (front) "front" else "back"} camera")
        val ch = mgr.getCameraCharacteristics(cameraId)
        sensorOrientation = ch.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
        val map = ch.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)!!
        previewSize = map.getOutputSizes(SurfaceTexture::class.java)
            .filter { it.width * 9 == it.height * 16 && it.height <= 1080 }
            .maxByOrNull { it.width } ?: map.getOutputSizes(SurfaceTexture::class.java).first()

        val gen = previewGen
        val thread = HandlerThread("echoprompter-camera").also { it.start() }
        cameraThread = thread
        cameraHandler = Handler(thread.looper)
        val e = textures.createSurfaceTexture().also { entry = it }
        e.surfaceTexture().setDefaultBufferSize(previewSize.width, previewSize.height)

        var replied = false
        mgr.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(device: CameraDevice) {
                if (gen != previewGen) {
                    // stopPreview ran while the camera was opening.
                    device.close()
                    if (!replied) { replied = true; main.post { result.error("cancelled", "Preview stopped", null) } }
                    return
                }
                camera = device
                createSession(listOf(Surface(e.surfaceTexture())))
                val display = displayRotationDegrees()
                val swap = (upright(display) / 90) % 2 == 1
                // Flutter's texture layer already applies the sensor rotation, so
                // Dart only compensates for the display rotation.
                val turns = (360 - display) % 360 / 90
                if (!replied) {
                    replied = true
                    main.post {
                        result.success(mapOf(
                            "textureId" to e.id(),
                            "width" to if (swap) previewSize.height else previewSize.width,
                            "height" to if (swap) previewSize.width else previewSize.height,
                            "mirrored" to facingFront,
                            "quarterTurns" to turns,
                        ))
                    }
                }
            }
            override fun onDisconnected(d: CameraDevice) {
                d.close()
                if (camera === d) { camera = null; session = null }
                if (recorder != null) main.post { finishRecording("interrupted") }
            }
            override fun onError(d: CameraDevice, err: Int) {
                d.close()
                if (camera === d) { camera = null; session = null }
                if (!replied) { replied = true; main.post { result.error("camera", "Camera error $err", null) } }
            }
        }, cameraHandler)
    }

    private fun createSession(extra: List<Surface>, record: Boolean = false) {
        val device = camera ?: return
        session?.close()
        val surfaces = extra
        val builder = device.createCaptureRequest(if (record) CameraDevice.TEMPLATE_RECORD else CameraDevice.TEMPLATE_PREVIEW)
        surfaces.forEach { builder.addTarget(it) }
        builder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
        builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
        device.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(s: CameraCaptureSession) {
                session = s
                s.setRepeatingRequest(builder.build(), null, cameraHandler)
            }
            override fun onConfigureFailed(s: CameraCaptureSession) { emit(mapOf("type" to "error", "message" to "session")) }
        }, cameraHandler)
    }

    private fun stopPreview() {
        previewGen++
        if (recorder != null) finishRecording("user")
        session?.close(); session = null
        camera?.close(); camera = null
        entry?.release(); entry = null
        cameraThread?.quitSafely(); cameraThread = null
    }

    // MARK: Audio (shared by file and speech)

    private fun ensureAudio() {
        if (audio == null) {
            audio = AudioCapture { pcm48k, ptsUs ->
                recorder?.onAudio(pcm48k, ptsUs)
                SpeechAudioBridge.level = rms(pcm48k)
                val decimator = speechDecimator
                speechQueue?.let { q ->
                    val pcm16k = decimator?.process(pcm48k) ?: return@let
                    val bytes = ByteBuffer.allocate(pcm16k.size * 2).order(ByteOrder.LITTLE_ENDIAN)
                        .apply { asShortBuffer().put(pcm16k) }.array()
                    if (!q.offer(bytes)) {
                        q.poll()
                        q.offer(bytes)
                    }
                }
                val sink = audioSink
                if (sink != null) {
                    val out = downsampleTo16kFloat(pcm48k)
                    main.post { sink.success(out) }
                }
            }.also { it.start(context, preferHeadsetMic) }
        }
    }

    private fun rms(pcm: ShortArray): Float {
        if (pcm.isEmpty()) return 0f
        var sum = 0.0
        for (v in pcm) {
            val x = v / 32768.0
            sum += x * x
        }
        return Math.sqrt(sum / pcm.size).toFloat()
    }

    /**
     * Opens the pipe the recogniser reads the microphone from, starting the capture if needed (the same
     * capture records a take's audio). Null if the microphone can't be opened.
     */
    private fun openSpeechPipe(): ParcelFileDescriptor? {
        speechRead?.let { return it }
        try {
            ensureAudio()
        } catch (_: Exception) {
            audio = null
            return null
        }
        val pipe = try {
            ParcelFileDescriptor.createPipe()
        } catch (_: IOException) {
            return null
        }
        // About 0.5 s of audio, like the reference's 12 reads of at least 4096 bytes.
        val q = ArrayBlockingQueue<ByteArray>(26)
        speechRead = pipe[0]
        speechWrite = pipe[1]
        speechDecimator = Decimator()
        speechQueue = q
        Thread {
            try {
                ParcelFileDescriptor.AutoCloseOutputStream(pipe[1]).use { out ->
                    while (speechQueue === q) {
                        val bytes = q.poll(10, TimeUnit.MILLISECONDS) ?: continue
                        out.write(bytes)
                    }
                }
            } catch (_: Exception) {
                // The recogniser stopped reading, or the pipe was closed.
            }
        }.apply { name = "echoprompter-speech-audio" }.start()
        return pipe[0]
    }

    private fun closeSpeechPipe() {
        speechQueue = null
        speechDecimator = null
        try { speechWrite?.close() } catch (_: IOException) {}
        try { speechRead?.close() } catch (_: IOException) {}
        speechWrite = null
        speechRead = null
        releaseAudioIfUnused()
    }

    /** Stops the microphone once no take, speech pipe or sample stream needs it. */
    private fun releaseAudioIfUnused() {
        if (recorder == null && speechQueue == null && audioSink == null) { audio?.stop(); audio = null }
    }

    private fun downsampleTo16kFloat(pcm: ShortArray): ByteArray {
        val n = pcm.size / 3
        val bb = ByteBuffer.allocate(n * 4).order(ByteOrder.nativeOrder())
        for (i in 0 until n) {
            val avg = (pcm[i * 3] + pcm[i * 3 + 1] + pcm[i * 3 + 2]) / 3f
            bb.putFloat(avg / 32768f)
        }
        return bb.array()
    }

    // MARK: Recording

    @SuppressLint("MissingPermission")
    private fun startRecording(landscape: Boolean, height: Int, narrationPath: String?) {
        check(recorder == null) { "Already recording" }
        val e = entry ?: error("No preview")
        // Narration takes are filmed without the microphone: the narration file is added to the video when the take stops.
        if (narrationPath == null) ensureAudio()
        narrationFile = narrationPath?.let { File(it) }
        // Orientation is locked by Dart while recording, so the display rotation
        // now is the file's orientation ([landscape] is informational).
        val hint = upright(displayRotationDegrees())
        val file = File(context.cacheDir, "echoprompter_${System.currentTimeMillis()}.mp4")
        val r = Recorder(file, previewSize.width, previewSize.height, hint, withAudio = narrationPath == null) { reason -> main.post { finishRecording(reason) } }
        recorder = r
        // A Narration take doesn't record the microphone, so its service must not claim the microphone type (Android refuses
        // that without the microphone permission, which a Narration take no longer asks for).
        context.startForegroundService(Intent(context, RecordingService::class.java).putExtra("withMic", narrationPath == null))
        createSession(listOf(Surface(e.surfaceTexture()), r.videoSurface), record = true)
        r.start()
    }

    // The narration file of the take being recorded (Narration mode), or null when the microphone is the soundtrack.
    private var narrationFile: File? = null

    /**
     * Ends the take. [reply] gets the result (null if nothing was recording). A Narration take is joined with its
     * narration on a background thread first, so [reply] and the event come a moment later.
     */
    private fun finishRecording(reason: String, reply: ((Map<String, Any>?) -> Unit)? = null) {
        val r = recorder
        if (r == null) { reply?.invoke(null); return }
        recorder = null
        val narration = narrationFile
        narrationFile = null
        val (path, durationMs) = r.stop()
        val done = { finalPath: String, narrationFailed: Boolean ->
            context.stopService(Intent(context, RecordingService::class.java))
            entry?.let { createSession(listOf(Surface(it.surfaceTexture()))) }
            releaseAudioIfUnused()
            if (reason != "user") emit(mapOf("type" to reason, "path" to finalPath, "durationMs" to durationMs.toInt(), "narrationFailed" to narrationFailed))
            reply?.invoke(mapOf("path" to finalPath, "durationMs" to durationMs.toInt(), "reason" to reason, "narrationFailed" to narrationFailed))
        }
        if (narration == null) {
            if (reason == "user") { done(path, false); return }
            // An interrupted take: the camera closed before the microphone stopped, so the audio ends where the last video
            // frame does (a normal stop is left exactly as recorded).
            Thread {
                try {
                    NarrationMux.trimAudioToVideo(File(path), r.videoEndUs, r.orientationHint)
                } catch (e: Exception) {
                    Log.e("EchoPrompterCamera", "Could not end the audio at the last video frame", e)
                }
                main.post { done(path, false) }
            }.start()
            return
        }
        Thread {
            // If the narration cannot be added (or never played) the file stays the take as filmed, and the app is told.
            var finalPath = path
            var failed = false
            // An interrupted take ends its narration at the last video frame too.
            val segments = r.narrationSegments(if (reason == "user") Long.MAX_VALUE else r.videoEndUs)
            if (segments.isEmpty()) {
                failed = true
            } else {
                val output = File(context.cacheDir, "echoprompter_${System.currentTimeMillis()}_n.mp4")
                try {
                    NarrationMux.mux(File(path), narration, segments, r.orientationHint, output)
                    File(path).delete()
                    finalPath = output.path
                } catch (e: Exception) {
                    Log.e("EchoPrompterCamera", "Could not add the narration to the video", e)
                    output.delete()
                    failed = true
                }
            }
            main.post { done(finalPath, failed) }
        }.start()
    }

    private var joiner: androidx.media3.transformer.Transformer? = null

    /** Joins the clips (in the order given) into one video in the cache folder and replies with its path. */
    @androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
    private fun joinClips(paths: List<String>, result: MethodChannel.Result) {
        if (paths.isEmpty() || joiner != null) { result.error("join", "Nothing to join", null); return }
        val out = File(context.cacheDir, "echoprompter_joined_${System.currentTimeMillis()}.mp4")
        try {
            joiner = ClipJoin.join(context, paths.map { File(it) }, out) { error ->
                joiner = null
                if (error == null) result.success(out.path) else { out.delete(); result.error("join", error, null) }
            }
        } catch (e: Exception) {
            joiner = null
            out.delete()
            result.error("join", e.message, null)
        }
    }

    private fun saveToGallery(path: String) {
        val src = File(path)
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, src.name)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= 29) put(MediaStore.Video.Media.RELATIVE_PATH, "DCIM/EchoPrompter")
        }
        val uri = context.contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("The gallery could not create the video")
        try {
            val out = context.contentResolver.openOutputStream(uri) ?: throw IOException("The gallery could not open the video")
            out.use { o -> src.inputStream().use { it.copyTo(o) } }
        } catch (e: Exception) {
            // Don't leave an empty or partial video in the gallery; the take itself stays in app storage.
            try { context.contentResolver.delete(uri, null, null) } catch (_: Exception) {}
            throw e
        }
    }

    private fun emit(m: Map<String, Any>) = main.post { eventSink?.success(m) }

    private fun teardown() {
        closeSpeechPipe()
        SpeechAudioBridge.opener = null
        SpeechAudioBridge.closer = null
        stopPreview(); audio?.stop(); audio = null
    }
}

/**
 * 48 kHz → 16 kHz for the speech recogniser. Google's on-device engine runs at 16 kHz: fed 48 kHz it rebuilds
 * itself at every session start ("Must re-create SODA due to changed sample rate"), which costs about 0.8 s
 * on the emulator before it hears anything. A windowed-sinc low-pass keeps what is above 8 kHz from folding
 * back. Chunks must be a multiple of 3 samples (the capture trims them).
 */
private class Decimator {
    private val taps = FloatArray(TAPS).also { h ->
        val mid = (TAPS - 1) / 2.0
        var sum = 0.0
        for (n in 0 until TAPS) {
            val x = n - mid
            val sinc = if (x == 0.0) 2 * CUTOFF else Math.sin(2 * Math.PI * CUTOFF * x) / (Math.PI * x)
            val hamming = 0.54 - 0.46 * Math.cos(2 * Math.PI * n / (TAPS - 1))
            h[n] = (sinc * hamming).toFloat()
            sum += h[n]
        }
        for (n in 0 until TAPS) h[n] = (h[n] / sum).toFloat()
    }
    private val history = FloatArray(TAPS - 1)

    fun process(input: ShortArray): ShortArray {
        val buf = FloatArray(history.size + input.size)
        history.copyInto(buf)
        for (i in input.indices) buf[history.size + i] = input[i].toFloat()
        val out = ShortArray(input.size / 3)
        for (k in out.indices) {
            val newest = history.size + 3 * k + 2
            var acc = 0f
            for (j in 0 until TAPS) acc += taps[j] * buf[newest - j]
            out[k] = acc.coerceIn(-32768f, 32767f).toInt().toShort()
        }
        buf.copyInto(history, 0, buf.size - history.size)
        return out
    }

    private companion object {
        const val TAPS = 47
        const val CUTOFF = 7200.0 / 48000.0
    }
}

/** 48 kHz mono PCM16 from a headset microphone when one is connected and wanted, else the built-in one. */
private class AudioCapture(val onData: (ShortArray, Long) -> Unit) {
    private var record: AudioRecord? = null
    private var thread: Thread? = null
    @Volatile private var running = false

    @SuppressLint("MissingPermission")
    fun start(context: Context, preferHeadset: Boolean) {
        val rate = 48000
        val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        // The plain microphone source, as the reference's shared capture uses for recognition and the take.
        val r = AudioRecord(MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, min * 2)
        record = r
        route(context, preferHeadset)
        r.startRecording()
        running = true
        thread = Thread {
            val buf = ShortArray(rate / 50) // 20 ms
            while (running) {
                val n = r.read(buf, 0, buf.size)
                if (n > 0) onData(buf.copyOf(n - n % 3), SystemClock.elapsedRealtimeNanos() / 1000)
            }
        }.also { it.start() }
    }

    /**
     * Picks the input as the reference's shared capture does: a USB headset, USB device, wired headset or
     * Bluetooth SCO microphone, in that order, otherwise the built-in microphone.
     */
    fun route(context: Context, preferHeadset: Boolean) {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val inputs = am.getDevices(AudioManager.GET_DEVICES_INPUTS).filter { it.isSource }
        val headset = if (preferHeadset) {
            HEADSET_ORDER.firstNotNullOfOrNull { type -> inputs.firstOrNull { it.type == type } }
        } else null
        (headset ?: inputs.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC })?.let { record?.setPreferredDevice(it) }
    }

    private companion object {
        val HEADSET_ORDER = listOf(
            AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        )
    }

    fun stop() {
        running = false
        thread?.join(500)
        record?.stop(); record?.release(); record = null
    }
}

/** H.264 + AAC into an MP4. Video comes from [videoSurface]; audio is pushed. */
private class Recorder(
    val file: File, w: Int, h: Int, val orientationHint: Int,
    // False for a Narration take: the file has no audio track, the narration is joined to it afterwards.
    private val withAudio: Boolean,
    val onFailure: (String) -> Unit,
) {
    private val videoCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    private val audioCodec: MediaCodec? = if (withAudio) MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC) else null
    private val muxer = MediaMuxer(file.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    val videoSurface: Surface
    private var videoTrack = -1
    private var audioTrack = -1
    private var muxerStarted = false
    private val lock = Object()
    private var startUs = 0L
    private var lastPtsUs = 0L
    // Paused spans in the recorder's raw clock; samples inside are dropped and
    // later ones are shifted back so the file has no gap.
    private val pauses = mutableListOf<LongArray>()
    private var vThread: Thread? = null
    @Volatile private var running = false
    // Set when the video encoder never signals the end of the take (the camera was closed under it, e.g. the app went to
    // the background), so the drain thread stops waiting for it.
    @Volatile private var abandonVideo = false

    init {
        val vf = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 10_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        videoCodec.configure(vf, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        videoSurface = videoCodec.createInputSurface()
        if (audioCodec != null) {
            val af = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, 48000, 1).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
            }
            audioCodec.configure(af, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        }
        muxer.setOrientationHint(orientationHint)
    }

    fun start() {
        startUs = SystemClock.elapsedRealtimeNanos() / 1000
        videoCodec.start(); audioCodec?.start()
        running = true
        vThread = Thread {
            try {
                drain(videoCodec, true)
            } catch (_: IllegalStateException) {
                // The codec was stopped while this thread waited on it; the take is already ending.
            }
        }.also { it.start() }
    }

    private fun nowUs() = SystemClock.elapsedRealtimeNanos() / 1000

    fun pause() {
        synchronized(pauses) {
            if (pauses.lastOrNull()?.get(1) != Long.MAX_VALUE) pauses.add(longArrayOf(nowUs(), Long.MAX_VALUE))
        }
    }

    fun resume() {
        synchronized(pauses) {
            pauses.lastOrNull()?.takeIf { it[1] == Long.MAX_VALUE }?.set(1, nowUs())
        }
    }

    // Narration: the stretches of the narration file heard during the take, on the take's timeline (see narrationTick).
    private val narrationHeard = mutableListOf<NarrationSegment>()
    private var narrationOpen = false
    // Timeline time of the first video frame: the file's picture starts there.
    @Volatile private var firstVideoUs = -1L

    /**
     * Where the narration file is now and whether it is playing. Playback that carries on from the last tick extends
     * the open stretch; a pause, a jump or a restart starts a new one.
     */
    fun narrationTick(positionUs: Long, playing: Boolean) {
        synchronized(narrationHeard) {
            val t = if (running && playing) timeline(nowUs()) else -1L
            if (t < 0) { narrationOpen = false; return }
            val last = narrationHeard.lastOrNull()
            if (narrationOpen && last != null && Math.abs(last.audioStartUs + (t - last.videoStartUs) - positionUs) < 150_000L) {
                last.lengthUs = t - last.videoStartUs
            } else {
                narrationHeard.add(NarrationSegment(t, positionUs, 0))
                narrationOpen = true
            }
        }
    }

    /**
     * The stretches heard, timed from the file's first video frame. What played before that frame is cut off, and ones
     * too short to matter are left out.
     */
    fun narrationSegments(videoEndUs: Long = Long.MAX_VALUE): List<NarrationSegment> = synchronized(narrationHeard) {
        val origin = maxOf(firstVideoUs, 0L)
        // [videoEndUs] (the last video frame, on the take's timeline) cuts off what played after the picture ended.
        val end = if (videoEndUs == Long.MAX_VALUE) Long.MAX_VALUE else videoEndUs - origin
        narrationHeard.map {
            val cut = maxOf(origin - it.videoStartUs, 0L)
            val start = it.videoStartUs + cut - origin
            NarrationSegment(start, it.audioStartUs + cut, minOf(it.lengthUs - cut, end - start))
        }.filter { it.lengthUs > 50_000L }
    }

    /** Timeline time of the last video frame written. */
    val videoEndUs: Long get() = lastPtsUs

    /** Recording-timeline timestamp for a raw one, or -1 if it falls inside a pause. */
    private fun timeline(rawUs: Long): Long {
        synchronized(pauses) {
            var shift = 0L
            for (p in pauses) {
                if (rawUs >= p[1]) shift += p[1] - p[0] else if (rawUs >= p[0]) return -1
            }
            return (rawUs - startUs - shift).coerceAtLeast(0)
        }
    }

    fun onAudio(pcm: ShortArray, ptsUs: Long) {
        val audioCodec = audioCodec ?: return
        if (!running) return
        val t = timeline(ptsUs)
        if (t < 0) return
        val i = audioCodec.dequeueInputBuffer(0)
        if (i < 0) return
        val buf = audioCodec.getInputBuffer(i)!!
        buf.clear()
        buf.asShortBuffer().put(pcm)
        audioCodec.queueInputBuffer(i, 0, pcm.size * 2, t, 0)
        drainAudioOnce()
    }

    private fun drainAudioOnce() {
        val audioCodec = audioCodec ?: return
        val info = MediaCodec.BufferInfo()
        while (true) {
            val idx = audioCodec.dequeueOutputBuffer(info, 0)
            when {
                idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> addTrack(audioCodec.outputFormat, false)
                idx >= 0 -> { write(audioCodec, idx, info, false); }
                else -> return
            }
        }
    }

    private fun addTrack(format: MediaFormat, video: Boolean) = synchronized(lock) {
        if (video) videoTrack = muxer.addTrack(format) else audioTrack = muxer.addTrack(format)
        if (videoTrack >= 0 && (audioTrack >= 0 || !withAudio) && !muxerStarted) { muxer.start(); muxerStarted = true; lock.notifyAll() }
    }

    private fun write(codec: MediaCodec, idx: Int, info: MediaCodec.BufferInfo, video: Boolean) {
        val data = codec.getOutputBuffer(idx)!!
        if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
            synchronized(lock) {
                while (!muxerStarted && running) lock.wait(50)
                if (muxerStarted) {
                    // Video timestamps arrive in the camera's CLOCK_BOOTTIME base.
                    val t = if (video) timeline(info.presentationTimeUs) else info.presentationTimeUs
                    if (t >= 0) {
                        if (video) { info.presentationTimeUs = t; lastPtsUs = t; if (firstVideoUs < 0) firstVideoUs = t }
                        muxer.writeSampleData(if (video) videoTrack else audioTrack, data, info)
                    }
                }
            }
        }
        codec.releaseOutputBuffer(idx, false)
    }

    private fun drain(codec: MediaCodec, video: Boolean) {
        val info = MediaCodec.BufferInfo()
        while (!abandonVideo) {
            val idx = codec.dequeueOutputBuffer(info, 10_000)
            when {
                idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> addTrack(codec.outputFormat, video)
                idx >= 0 -> {
                    val eos = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    write(codec, idx, info, video)
                    if (eos) return
                }
            }
        }
    }

    /** Returns file path and duration in ms. */
    fun stop(): Pair<String, Long> {
        running = false
        try {
            videoCodec.signalEndOfInputStream()
            vThread?.join(2000)
            if (vThread?.isAlive == true) {
                // No end-of-stream came. Let the drain thread leave the codec alone before the codec is stopped.
                abandonVideo = true
                vThread?.join(1000)
            }
            drainAudioOnce()
            audioCodec?.stop(); videoCodec.stop()
            synchronized(lock) { if (muxerStarted) muxer.stop() }
        } catch (_: Exception) {
            onFailure("error")
        } finally {
            audioCodec?.release(); videoCodec.release(); muxer.release(); videoSurface.release()
        }
        return file.path to lastPtsUs / 1000
    }
}
