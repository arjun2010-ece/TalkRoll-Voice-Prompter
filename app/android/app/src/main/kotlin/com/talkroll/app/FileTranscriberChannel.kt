package com.talkroll.app

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * Narration mode's analyser on Android. It needs no speech recogniser, so no microphone permission, no speech pack and
 * no network, and it works the same for every language: the recording is decoded to 16 kHz mono PCM with the platform's
 * own `MediaCodec`, and the stretches where someone is speaking are found from the loudness (pauses separate them).
 * Dart lines the script up with those stretches. Each stretch is returned as a word with empty text and its start and
 * end in seconds.
 *
 * One recording at a time; starting another cancels the first. Results arrive on the main thread.
 */
class FileTranscriberChannel(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.talkroll/transcribe")
    private val main = Handler(Looper.getMainLooper())

    private var run = 0
    private var pending: MethodChannel.Result? = null
    private var worker: Thread? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        cancel()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "cancel" -> {
                cancel()
                result.success(null)
            }
            "transcribe" -> {
                val path = call.argument<String>("path")
                if (path == null) return result.error("failed", "No recording was given.", null)
                analyse(path, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun cancel() {
        run++
        worker?.interrupt()
        worker = null
        pending?.error("cancelled", "Cancelled.", null)
        pending = null
    }

    private fun analyse(path: String, result: MethodChannel.Result) {
        cancel()
        val id = run
        pending = result
        worker = thread(name = "narration-analyse") {
            val spans = try {
                decodeTo16kMono(path) { f -> main.post { if (id == run) channel.invokeMethod("progress", f * 0.9) } }
                    ?.takeIf { it.isNotEmpty() }
                    ?.let { speechSpans(it) }
            } catch (e: Exception) {
                Log.w(TAG, "analysis failed", e)
                null
            }
            main.post {
                if (id != run) return@post
                val p = pending ?: return@post
                pending = null
                if (spans == null) {
                    p.error("failed", "Couldn't read this recording. Choose another one.", null)
                } else {
                    Log.i(TAG, "done: ${spans.size} spoken stretches")
                    p.success(spans.map { mapOf("w" to "", "s" to it[0], "e" to it[1]) })
                }
            }
        }
    }

    // --- Finding the speech ------------------------------------------------------------------------

    /**
     * The stretches of [pcm] (16 kHz mono 16-bit) in which someone is speaking, as [start, end] seconds. Loudness is
     * measured every 20 ms; the quiet level and the speech level are taken from the recording itself, so a recording
     * made softly or with background noise works too. Dips shorter than [MIN_PAUSE] are inside the speech; a pause is
     * anything longer. A recording with no clear difference between quiet and loud counts as one stretch.
     */
    private fun speechSpans(pcm: ByteArray): List<DoubleArray> {
        val samples = ByteBuffer.wrap(pcm).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        val frame = SAMPLE_RATE / 50
        val frames = samples.remaining() / frame
        val total = samples.remaining().toDouble() / SAMPLE_RATE
        if (frames < 10) return listOf(doubleArrayOf(0.0, total))
        val db = DoubleArray(frames)
        for (f in 0 until frames) {
            var sum = 0.0
            for (i in 0 until frame) {
                val v = samples.get(f * frame + i) / 32768.0
                sum += v * v
            }
            db[f] = 20 * log10(sqrt(sum / frame) + 1e-9)
        }
        val sorted = db.sortedArray()
        val floor = sorted[(frames * 0.10).toInt()]
        val peak = sorted[(frames * 0.95).toInt().coerceAtMost(frames - 1)]
        if (peak - floor < 12) return listOf(doubleArrayOf(0.0, total))
        val threshold = floor + (peak - floor) * 0.30

        val minPauseFrames = (MIN_PAUSE * 50).toInt()
        val minSpeechFrames = (MIN_SPEECH * 50).toInt()
        val spans = ArrayList<IntArray>()
        var start = -1
        var quiet = 0
        for (f in 0 until frames) {
            if (db[f] > threshold) {
                if (start < 0) start = f
                quiet = 0
            } else if (start >= 0) {
                quiet++
                if (quiet >= minPauseFrames) {
                    spans.add(intArrayOf(start, f - quiet + 1))
                    start = -1
                    quiet = 0
                }
            }
        }
        if (start >= 0) spans.add(intArrayOf(start, frames - quiet))
        val kept = spans.filter { it[1] - it[0] >= minSpeechFrames }.ifEmpty { spans }
        if (kept.isEmpty()) return listOf(doubleArrayOf(0.0, total))
        return kept.map { doubleArrayOf(it[0] / 50.0, it[1] / 50.0) }
    }

    // --- Decoding ----------------------------------------------------------------------------------

    /** The recording as 16 kHz, mono, 16-bit little-endian PCM. */
    private fun decodeTo16kMono(path: String, onProgress: (Double) -> Unit): ByteArray? {
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
        val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L
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
                        if (durationUs > 0 && mono.size % 20 == 0) onProgress((info.presentationTimeUs.toDouble() / durationUs).coerceIn(0.0, 1.0))
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
        const val TAG = "NarrationAnalyse"
        const val SAMPLE_RATE = 16000
        const val MIN_PAUSE = 0.22 // seconds of quiet that count as a pause
        const val MIN_SPEECH = 0.12 // shorter stretches are clicks and breaths
    }
}
