/// What Claude reads when it connects (and from `get_guide`): how Shades thinks and how to edit
/// well with its tools.
enum Guide {
  static let text = """
    Shades is a video editor you drive with these tools. Everything you change shows live in \
    the editor, glows purple, appears in the History pane and can be undone.

    The timeline
    - The picture is always 4:3 (2880×2160 or 1440×1080). Clips of any shape are fitted inside \
    it, upright and centered. 9:16 and 16:9 versions are only canvases added at export.
    - Tracks are labeled V1, V2… (video, V1 at the bottom, higher tracks drawn on top) and A1, \
    A2… (sound only). A video clip plays its own sound unless it was detached.
    - All times are seconds on the timeline and snap to whole frames. Clips on one track never \
    overlap; gaps are allowed and show black.
    - Each layer has a depth slot: inFront (default), behindSubject, insideSubject or \
    replaceBackground, relative to the person cut out of the clips below.

    Working well
    1. Start with get_project to see media, tracks, clip IDs and the playhead.
    2. import_media, then place with append_clip, insert_clip, overwrite_clip or place_on_top \
    (B-roll). Use source_start / source_end to place just part of a file.
    3. Edit with split_clip, trim_clip (ripple keeps things tight), move_clip, delete_clips \
    (ripple closes the gap), join_clips, set_clip, detach_audio.
    4. For many changes at once use batch: one undo step, all or nothing.
    5. Check your work with render_frame at the moments you changed. Look before you say done.
    6. If something went wrong, undo. Every tool call is one undo step.

    Text, speech and cut-outs
    - Text clips live on text tracks (T1, T2…), drawn above the video: add_text, set_text.
    - transcribe, then get_transcript for word timings; add_captions turns them into text clips. \
    polish_propose finds silences, fillers, retakes and jump cuts; polish_apply applies them.
    - make_cutout finds the subject of a clip's media (a background job; watch get_jobs). Then \
    a layer above set to behindSubject shows between the background and the person. \
    auto_reframe crops 16:9 footage to 4:3 around the subject.

    Animation
    - set_keyframes animates x, y, scale, rotation or opacity: values at moments inside the \
    clip. Each keyframe's easing (linear, easeIn, easeOut, easeInOut, hold, spring, bouncy) \
    shapes the move to the next one. remove_keyframes takes them away.
    - track_motion follows a box through a video clip (a background job) and saves a named \
    path; follow then makes any layer move with it, or with the cut-out's subject.

    Projects: list_projects, new_project and open_project. Point the user at clips with \
    select_clips. Heavy footage plays from proxies; render_frame always uses the originals.

    Errors come back as plain words saying what went wrong and what to do; read them and retry.
    """
}
