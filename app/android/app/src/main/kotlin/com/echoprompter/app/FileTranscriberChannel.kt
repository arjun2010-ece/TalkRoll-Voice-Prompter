package com.echoprompter.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.ModelDownloadListener
import android.speech.RecognitionListener
import android.speech.RecognitionPart
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * Narration mode's transcriber on Android, with no extra library: the recording is decoded to 16 kHz mono PCM with the
 * platform's own `MediaCodec`, and played into the phone's on-device [SpeechRecognizer] through the same audio-source
 * pipe Voice mode uses. The recogniser's word timings (Android 14+) become the transcript. Nothing leaves the phone:
 * only the on-device recogniser is used, and a phone without one is refused (`unavailable`).
 *
 * One recording at a time; starting another cancels the first. Callbacks run on the main thread.
 */
class FileTranscriberChannel(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.echoprompter/transcribe")
    private val main = Handler(Looper.getMainLooper())

    private var run = 0
    private var recognizer: SpeechRecognizer? = null
    private var pending: MethodChannel.Result? = null
    private var writer: Thread? = null
    private var pipeRead: ParcelFileDescriptor? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        cancel()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(supported())
            "cancel" -> {
                cancel()
                result.success(null)
            }
            "transcribe" -> {
                val path = call.argument<String>("path")
                if (path == null) return result.error("failed", "No recording was given.", null)
                transcribe(path, call.argument<String>("language") ?: "en-US", result)
            }
            else -> result.notImplemented()
        }
    }

    private fun supported() =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)

    private fun cancel() {
        run++
        val r = recognizer
        recognizer = null
        runCatching { r?.cancel() }
        runCatching { r?.destroy() }
        runCatching { pipeRead?.close() }
        pipeRead = null
        writer?.interrupt()
        writer = null
        pending?.error("cancelled", "Cancelled.", null)
        pending = null
    }

    private fun fail(code: String, message: String) {
        val p = pending ?: return
        pending = null
        val r = recognizer
        recognizer = null
        runCatching { r?.destroy() }
        runCatching { pipeRead?.close() }
        pipeRead = null
        p.error(code, message, null)
    }

    private fun transcribe(path: String, language: String, result: MethodChannel.Result) {
        cancel()
        val id = run
        if (!supported()) {
            return result.error(
                "unavailable",
                "This phone has no on-device speech recognition, so Narration can't transcribe a recording here.",
                null,
            )
        }
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return result.error("denied", "Android needs microphone access for its speech recogniser, even for a file.", null)
        }
        pending = result
        thread(name = "narration-decode") {
            val pcm = try {
                decodeTo16kMono(path)
            } catch (e: Exception) {
                Log.w(TAG, "decode failed", e)
                null
            }
            main.post {
                if (id != run || pending == null) return@post
                if (pcm == null || pcm.isEmpty()) {
                    fail("failed", "Couldn't read this recording. Choose another one.")
                } else {
                    startRecognition(id, pcm, language)
                }
            }
        }
    }

    // --- Recognition -----------------------------------------------------------------------------

    private class Word(val text: String, val start: Double, val end: Double)

    private fun startRecognition(id: Int, pcm: ByteArray, language: String, retried: Boolean = false) {
        val pipe = try {
            ParcelFileDescriptor.createPipe()
        } catch (e: Exception) {
            return fail("failed", "Couldn't start the speech recogniser.")
        }
        pipeRead = pipe[0]
        val totalSeconds = pcm.size / (SAMPLE_RATE * 2.0)
        val words = ArrayList<Word>()
        var segmentFrom = 0.0 // seconds of audio already covered by earlier segments
        val writtenBytes = java.util.concurrent.atomic.AtomicInteger(0)

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, ParcelFileDescriptor.dup(pipe[0].fileDescriptor))
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, SAMPLE_RATE)
            putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                putExtra(RecognizerIntent.EXTRA_REQUEST_WORD_TIMING, true)
            }
        }

        fun collect(bundle: Bundle?) {
            val text = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.trim().orEmpty()
            val atSeconds = (writtenBytes.get() / 2.0) / SAMPLE_RATE
            val parts: List<RecognitionPart> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                bundle?.getParcelableArrayList(SpeechRecognizer.RECOGNITION_PARTS, RecognitionPart::class.java).orEmpty()
            } else {
                emptyList()
            }
            Log.i(TAG, "segment at ${"%.1f".format(atSeconds)}s: '$text' parts=${parts.size}")
            if (parts.isNotEmpty()) {
                for (p in parts) {
                    val w = p.rawText.trim()
                    if (w.isEmpty()) continue
                    val s = p.timestampMillis / 1000.0
                    words.add(Word(w, s, s))
                }
            } else if (text.isNotEmpty()) {
                // No word times on this phone: spread the segment's words across the audio it covered.
                val list = text.split(Regex("\\s+"))
                val span = (atSeconds - segmentFrom).coerceAtLeast(0.2)
                list.forEachIndexed { i, w ->
                    val s = segmentFrom + span * i / list.size
                    words.add(Word(w, s, segmentFrom + span * (i + 1) / list.size))
                }
            }
            segmentFrom = atSeconds
        }

        fun finish() {
            if (id != run) return
            val p = pending ?: return
            pending = null
            val r = recognizer
            recognizer = null
            runCatching { r?.destroy() }
            runCatching { pipeRead?.close() }
            pipeRead = null
            // A word's end is the next word's start (the recogniser gives starts); the last runs to the end.
            val out = words.mapIndexed { i, w ->
                val end = if (i + 1 < words.size) maxOf(words[i + 1].start, w.start) else maxOf(totalSeconds, w.start)
                mapOf("w" to w.text, "s" to w.start, "e" to end)
            }
            Log.i(TAG, "done: ${out.size} words in ${"%.1f".format(totalSeconds)}s")
            p.success(out)
        }

        val r = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onSegmentResults(segmentResults: Bundle) {
                if (id == run) collect(segmentResults)
            }

            override fun onEndOfSegmentedSession() = finish()

            override fun onResults(results: Bundle?) {
                if (id != run) return
                // Without segments, the final result is the whole transcript.
                if (words.isEmpty()) collect(results)
                finish()
            }

            override fun onError(error: Int) {
                if (id != run) return
                Log.w(TAG, "recognizer error $error at ${writtenBytes.get() / 2 / SAMPLE_RATE}s")
                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                        if (words.isNotEmpty()) finish() else fail("failed", "No speech was found in this recording.")
                    ERROR_LANGUAGE_UNAVAILABLE ->
                        if (!retried && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            downloadPack(id, pcm, language, intent)
                        } else {
                            fail("unavailable", "Narration needs the $language offline speech pack. Download it in the phone's speech settings, then try again.")
                        }
                    ERROR_LANGUAGE_NOT_SUPPORTED ->
                        fail("unavailable", "Narration needs the $language offline speech pack. Download it in the phone's speech settings, then try again.")
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                        fail("denied", "Android needs microphone access for its speech recogniser, even for a file.")
                    else -> if (words.isNotEmpty()) finish() else fail("failed", "Couldn't transcribe this recording. Choose another one.")
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (id == run) channel.invokeMethod("progress", (writtenBytes.get() / 2.0 / SAMPLE_RATE / totalSeconds).coerceIn(0.0, 1.0))
            }

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        // Feed the audio a little faster than it plays, then close the pipe so the session ends.
        writer = thread(name = "narration-feed") {
            try {
                FileOutputStream(pipe[1].fileDescriptor).use { out ->
                    val chunk = SAMPLE_RATE / 5 * 2 // 0.2 s
                    var pos = 0
                    val started = System.nanoTime()
                    while (pos < pcm.size && !Thread.currentThread().isInterrupted) {
                        val n = minOf(chunk, pcm.size - pos)
                        out.write(pcm, pos, n)
                        pos += n
                        writtenBytes.set(pos)
                        val target = pos / 2.0 / SAMPLE_RATE / FEED_SPEED
                        val ahead = target - (System.nanoTime() - started) / 1e9
                        if (ahead > 0) Thread.sleep((ahead * 1000).toLong())
                        if (pos % (chunk * 25) == 0) {
                            val fraction = (pos / 2.0 / SAMPLE_RATE / totalSeconds).coerceIn(0.0, 1.0)
                            main.post { if (id == run) channel.invokeMethod("progress", fraction) }
                        }
                    }
                }
            } catch (_: Exception) {
                // The pipe closed early: cancelled, or the recogniser stopped listening.
            } finally {
                runCatching { pipe[1].close() }
            }
        }
        try {
            r.startListening(intent)
        } catch (e: Exception) {
            Log.w(TAG, "startListening failed", e)
            fail("failed", "Couldn't start the speech recogniser.")
        }
    }

    /** The offline pack for [language] is missing: the speech service downloads it once, then the recording is retried. */
    private fun downloadPack(id: Int, pcm: ByteArray, language: String, intent: Intent) {
        val r = recognizer ?: return
        Log.i(TAG, "offline pack for $language is missing; asking the speech service to download it")
        runCatching { pipeRead?.close() }
        pipeRead = null
        writer?.interrupt()
        writer = null
        try {
            r.triggerModelDownload(intent, context.mainExecutor, object : ModelDownloadListener {
                override fun onProgress(completedPercent: Int) {
                    if (id == run) channel.invokeMethod("progress", completedPercent / 100.0 * 0.5)
                }

                override fun onSuccess() {
                    if (id != run) return
                    Log.i(TAG, "pack downloaded; retrying")
                    runCatching { recognizer?.destroy() }
                    recognizer = null
                    startRecognition(id, pcm, language, retried = true)
                }

                override fun onScheduled() {
                    if (id == run) fail("unavailable", "The $language speech pack is downloading in the background. Try again in a few minutes.")
                }

                override fun onError(error: Int) {
                    if (id == run) fail("unavailable", "Narration needs the $language offline speech pack, and it couldn't be downloaded (error $error).")
                }
            })
        } catch (e: Exception) {
            fail("unavailable", "Narration needs the $language offline speech pack. Download it in the phone's speech settings, then try again.")
        }
    }

    // --- Decoding ----------------------------------------------------------------------------------

    /** The recording as 16 kHz, mono, 16-bit little-endian PCM. */
    private fun decodeTo16kMono(path: String): ByteArray? {
        val extractor = MediaExtractor()
        extractor.setDataSource(path)
        var track = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                track = i
                format = f
                break
            }
        }
        if (track < 0 || format == null) return null
        extractor.selectTrack(track)
        val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(format, null, null, 0)
        codec.start()
        var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val mono = ArrayList<ShortArray>()
        var total = 0
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        try {
            while (!outputDone && !Thread.currentThread().isInterrupted) {
                if (!inputDone) {
                    val i = codec.dequeueInputBuffer(10_000)
                    if (i >= 0) {
                        val buf = codec.getInputBuffer(i)!!
                        val n = extractor.readSampleData(buf, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(i, 0, n, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, 10_000)
                when {
                    o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val f = codec.outputFormat
                        rate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                    o >= 0 -> {
                        val buf = codec.getOutputBuffer(o)!!
                        buf.order(ByteOrder.LITTLE_ENDIAN)
                        val shorts = buf.asShortBuffer()
                        val frames = shorts.remaining() / channels
                        val chunk = ShortArray(frames)
                        for (fr in 0 until frames) {
                            var sum = 0
                            for (c in 0 until channels) sum += shorts.get(fr * channels + c)
                            chunk[fr] = (sum / channels).toShort()
                        }
                        mono.add(chunk)
                        total += frames
                        codec.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            }
        } finally {
            runCatching { codec.stop() }
            codec.release()
            extractor.release()
        }
        // Join, then resample to 16 kHz by linear interpolation (plenty for speech).
        val all = ShortArray(total)
        var at = 0
        for (c in mono) {
            c.copyInto(all, at)
            at += c.size
        }
        val outLen = (total.toLong() * SAMPLE_RATE / rate).toInt()
        val bytes = ByteBuffer.allocate(outLen * 2).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until outLen) {
            val pos = i.toDouble() * rate / SAMPLE_RATE
            val i0 = pos.toInt().coerceAtMost(total - 1)
            val i1 = (i0 + 1).coerceAtMost(total - 1)
            val f = pos - i0
            bytes.putShort((all[i0] + (all[i1] - all[i0]) * f).toInt().toShort())
        }
        return bytes.array()
    }

    private companion object {
        const val TAG = "NarrationTranscribe"
        const val SAMPLE_RATE = 16000
        const val FEED_SPEED = 4.0 // how much faster than real time the audio is fed
        const val ERROR_LANGUAGE_NOT_SUPPORTED = 12
        const val ERROR_LANGUAGE_UNAVAILABLE = 13
    }
}
