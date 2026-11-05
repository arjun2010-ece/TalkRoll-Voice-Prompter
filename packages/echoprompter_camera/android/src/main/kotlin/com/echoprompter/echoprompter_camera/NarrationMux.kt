package com.echoprompter.echoprompter_camera

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer

/**
 * A stretch of the narration file that played while the take was filmed: [lengthUs] of the file, starting at
 * [audioStartUs], heard [videoStartUs] after the first video frame (all in microseconds).
 */
internal class NarrationSegment(val videoStartUs: Long, val audioStartUs: Long, var lengthUs: Long)

/**
 * Narration takes are filmed without the microphone. This puts the narration file itself into the finished video,
 * wherever it was playing during the take (it can pause, jump back or restart), so the result does not depend on
 * the speaker, headphones or the volume. The picture is copied as it was filmed; only the narration is re-encoded.
 */
internal object NarrationMux {
    private const val TIMEOUT_US = 10_000L

    /** Writes a copy of [video] that carries the narration. Throws if the file has no audio or anything fails. */
    fun mux(video: File, narration: File, segments: List<NarrationSegment>, orientationHint: Int, output: File) {
        val soundtrack = File(output.parentFile, output.name + ".m4a")
        try {
            Soundtrack.write(narration, segments, soundtrack)
            join(video, soundtrack, orientationHint, output)
        } finally {
            soundtrack.delete()
        }
    }

    /** The video's samples as filmed plus the soundtrack's samples, without re-encoding either. */
    private fun join(video: File, soundtrack: File, orientationHint: Int, output: File) {
        val videoIn = MediaExtractor()
        val soundIn = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            videoIn.setDataSource(video.path)
            soundIn.setDataSource(soundtrack.path)
            val v = firstTrack(videoIn, "video/")
            val a = firstTrack(soundIn, "audio/")
            muxer = MediaMuxer(output.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer.setOrientationHint(orientationHint)
            val videoOut = muxer.addTrack(videoIn.getTrackFormat(v))
            val soundOut = muxer.addTrack(soundIn.getTrackFormat(a))
            videoIn.selectTrack(v)
            soundIn.selectTrack(a)
            // The soundtrack starts with the first video frame, whatever time that frame has in the file.
            val origin = maxOf(videoIn.sampleTime, 0L)
            muxer.start()
            copySamples(videoIn, muxer, videoOut, 0L)
            copySamples(soundIn, muxer, soundOut, origin)
            muxer.stop()
        } finally {
            try { muxer?.release() } catch (_: Exception) {}
            videoIn.release()
            soundIn.release()
        }
    }

    private fun firstTrack(x: MediaExtractor, prefix: String): Int =
        (0 until x.trackCount).firstOrNull { x.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith(prefix) == true }
            ?: throw IOException("No $prefix track")

    /**
     * An interrupted take (the camera closed first, the microphone kept going) has more audio than video. Writes a copy
     * of [file] over itself that ends its audio at [videoEndUs], the last video frame, without re-encoding anything.
     * Returns without touching the file if the audio does not run past the video. On failure the file is left as it was.
     */
    fun trimAudioToVideo(file: File, videoEndUs: Long, orientationHint: Int) {
        val temp = File(file.parentFile, file.name + ".trim.mp4")
        val x = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            x.setDataSource(file.path)
            val v = firstTrack(x, "video/")
            val a = (0 until x.trackCount).firstOrNull { x.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true } ?: return
            // The audio ends where its last sample starts, plus that sample's length (about 21 ms for AAC).
            x.selectTrack(a)
            var audioEndUs = 0L
            var seen = false
            val probe = ByteBuffer.allocate(4 * 1024 * 1024)
            while (x.readSampleData(probe, 0) >= 0) { audioEndUs = x.sampleTime; seen = true; x.advance() }
            if (!seen || audioEndUs <= videoEndUs + 50_000L) return
            x.unselectTrack(a)
            muxer = MediaMuxer(temp.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer.setOrientationHint(orientationHint)
            val videoOut = muxer.addTrack(x.getTrackFormat(v))
            val audioOut = muxer.addTrack(x.getTrackFormat(a))
            muxer.start()
            x.selectTrack(v)
            x.seekTo(0L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            copySamples(x, muxer, videoOut, 0L)
            x.unselectTrack(v)
            x.selectTrack(a)
            x.seekTo(0L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            copySamples(x, muxer, audioOut, 0L, videoEndUs)
            muxer.stop()
            muxer.release()
            muxer = null
            if (!temp.renameTo(file)) throw IOException("Could not replace ${file.name}")
        } finally {
            try { muxer?.release() } catch (_: Exception) {}
            x.release()
            temp.delete()
        }
    }

    /** Copies the track's samples that start at or before [endUs] (all of them by default). */
    private fun copySamples(x: MediaExtractor, muxer: MediaMuxer, track: Int, offsetUs: Long, endUs: Long = Long.MAX_VALUE) {
        val buf = ByteBuffer.allocate(4 * 1024 * 1024)
        val info = MediaCodec.BufferInfo()
        while (true) {
            buf.clear()
            val n = x.readSampleData(buf, 0)
            if (n < 0 || x.sampleTime > endUs) return
            info.set(0, n, x.sampleTime + offsetUs, if (x.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
            muxer.writeSampleData(track, buf, info)
            x.advance()
        }
    }

    /**
     * Decodes the played stretches of the narration, puts silence between them, and encodes the lot as AAC at the
     * narration's own sample rate and channel count (one pass, so nothing is held in memory).
     */
    private object Soundtrack {
        fun write(narration: File, segments: List<NarrationSegment>, output: File) {
            val x = MediaExtractor()
            var decoder: MediaCodec? = null
            var sink: AacSink? = null
            try {
                x.setDataSource(narration.path)
                val track = firstTrack(x, "audio/")
                x.selectTrack(track)
                val format = x.getTrackFormat(track)
                val rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                if (rate > 48000 || channels !in 1..2) throw IOException("Unsupported narration format: $rate Hz, $channels channels")
                decoder = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!).also {
                    it.configure(format, null, null, 0)
                    it.start()
                }
                sink = AacSink(output, rate, channels)
                for (s in segments.sortedBy { it.videoStartUs }) {
                    sink.silenceUntil(s.videoStartUs)
                    decodeSegment(x, decoder, sink, rate, channels, s.audioStartUs, s.audioStartUs + s.lengthUs)
                }
                sink.finish()
                sink = null
            } finally {
                try { decoder?.stop() } catch (_: Exception) {}
                decoder?.release()
                x.release()
                sink?.abort()
            }
        }

        /** Feeds the part of the file between [fromUs] and [toUs] to [sink]. */
        private fun decodeSegment(x: MediaExtractor, decoder: MediaCodec, sink: AacSink, rate: Int, channels: Int, fromUs: Long, toUs: Long) {
            x.seekTo(fromUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            decoder.flush()
            val frameBytes = channels * 2
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            while (true) {
                if (!inputDone) {
                    val i = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (i >= 0) {
                        val n = x.readSampleData(decoder.getInputBuffer(i)!!, 0)
                        val t = x.sampleTime
                        if (n < 0 || t > toUs) {
                            decoder.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(i, 0, n, t, 0)
                            x.advance()
                        }
                    }
                }
                val o = decoder.dequeueOutputBuffer(info, TIMEOUT_US)
                when {
                    o >= 0 -> {
                        val out = decoder.getOutputBuffer(o)!!
                        val startUs = info.presentationTimeUs
                        val frames = info.size / frameBytes
                        val first = if (startUs < fromUs) ((fromUs - startUs) * rate / 1_000_000L).toInt() else 0
                        val last = minOf(frames.toLong(), (toUs - startUs) * rate / 1_000_000L).toInt()
                        if (last > first) {
                            val bytes = ByteArray((last - first) * frameBytes)
                            out.position(info.offset + first * frameBytes)
                            out.get(bytes)
                            sink.pcm(bytes)
                        }
                        decoder.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0 || startUs >= toUs) return
                    }
                    o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val f = decoder.outputFormat
                        if (f.getInteger(MediaFormat.KEY_SAMPLE_RATE) != rate || f.getInteger(MediaFormat.KEY_CHANNEL_COUNT) != channels ||
                            (f.containsKey(MediaFormat.KEY_PCM_ENCODING) && f.getInteger(MediaFormat.KEY_PCM_ENCODING) != AudioFormat.ENCODING_PCM_16BIT)
                        ) throw IOException("The narration decodes to a format that cannot be used")
                    }
                }
            }
        }
    }

    /** AAC encoder into an audio-only MP4. PCM is pushed in order; its time is the number of frames written so far. */
    private class AacSink(output: File, private val rate: Int, channels: Int) {
        private val frameBytes = channels * 2
        private val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        private val muxer = MediaMuxer(output.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        private val info = MediaCodec.BufferInfo()
        private var track = -1
        private var muxerStarted = false
        private var frames = 0L

        init {
            val f = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, rate, channels).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
            }
            encoder.configure(f, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()
        }

        fun silenceUntil(us: Long) {
            val target = us * rate / 1_000_000L
            while (frames < target) {
                val n = minOf(target - frames, 4096L).toInt()
                pcm(ByteArray(n * frameBytes))
            }
        }

        fun pcm(bytes: ByteArray) {
            var at = 0
            while (at < bytes.size) {
                val i = encoder.dequeueInputBuffer(TIMEOUT_US)
                if (i < 0) { drain(); continue }
                val buf = encoder.getInputBuffer(i)!!
                buf.clear()
                val n = minOf(buf.remaining() - buf.remaining() % frameBytes, bytes.size - at)
                buf.put(bytes, at, n)
                encoder.queueInputBuffer(i, 0, n, frames * 1_000_000L / rate, 0)
                frames += n / frameBytes
                at += n
                drain()
            }
        }

        fun finish() {
            while (true) {
                val i = encoder.dequeueInputBuffer(TIMEOUT_US)
                if (i < 0) { drain(); continue }
                encoder.queueInputBuffer(i, 0, 0, frames * 1_000_000L / rate, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                break
            }
            while (!drain()) {}
            encoder.stop(); encoder.release()
            if (muxerStarted) muxer.stop()
            muxer.release()
        }

        fun abort() {
            try { encoder.stop() } catch (_: Exception) {}
            encoder.release()
            try { muxer.release() } catch (_: Exception) {}
        }

        /** Moves finished AAC frames to the muxer; true once the end of the stream came out. */
        private fun drain(): Boolean {
            while (true) {
                val o = encoder.dequeueOutputBuffer(info, 0)
                when {
                    o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    o >= 0 -> {
                        val out = encoder.getOutputBuffer(o)!!
                        if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0 && muxerStarted) {
                            out.position(info.offset)
                            out.limit(info.offset + info.size)
                            muxer.writeSampleData(track, out, info)
                        }
                        encoder.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return true
                    }
                    else -> return false
                }
            }
        }
    }
}
