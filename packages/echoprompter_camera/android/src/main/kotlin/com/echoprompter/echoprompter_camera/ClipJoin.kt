package com.echoprompter.echoprompter_camera

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File

/**
 * Joins the keeper clips of a section-by-section run, in the order given, into one MP4 with Media3 Transformer.
 * Each clip keeps its own picture and sound; a clip filmed in another orientation is fitted into the first clip's frame.
 */
@UnstableApi
internal object ClipJoin {
    /** Must be called on a thread with a Looper (the main thread). [done] gets the error message, or null on success. */
    fun join(context: Context, clips: List<File>, output: File, done: (String?) -> Unit): Transformer {
        val frames = clips.map { frameOf(it) }
        val frame = frames.first()
        val items = clips.mapIndexed { i, clip ->
            val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(clip)))
            // Clips of one size are joined as filmed; only one of another size is fitted into the first clip's frame.
            if (frames[i] != frame) {
                item.setEffects(Effects(
                    emptyList<AudioProcessor>(),
                    listOf(Presentation.createForWidthAndHeight(frame.first, frame.second, Presentation.LAYOUT_SCALE_TO_FIT)),
                ))
            }
            item.build()
        }
        val composition = Composition.Builder(EditedMediaItemSequence(items)).build()
        val encoder = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(10_000_000).build())
            .build()
        val transformer = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoder)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) = done(null)
                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) =
                    done(exportException.message ?: "The clips could not be joined")
            })
            .build()
        transformer.start(composition, output.path)
        return transformer
    }

    /** The clip's upright (display) size. */
    private fun frameOf(file: File): Pair<Int, Int> {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(file.path)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt() ?: 1920
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt() ?: 1080
            val rotation = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
            return if (rotation % 180 == 90) h to w else w to h
        } finally {
            r.release()
        }
    }
}
