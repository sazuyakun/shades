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
    replaceBackground (set_clip depth_slot), relative to the person cut out of the clips below. \
    Layers can also tilt in 3D, move in depth and curve round an upright axis (tilt_x, \
    tilt_y, depth, bend), and set_clip crop \
    cuts each edge of a picture off (fractions of its width or height; the rest stays put).

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
    - Text clips live on text tracks (T1, T2…), drawn above the video: add_text, set_text. \
    add_text takes words (each word's start and end) to time its reveal to speech.
    - set_text path (points or svg_path) lays text along any line, curve or loop, letters \
    turning with it; align places it at the path's start, middle or end, spacing opens the \
    letters up, and pathOffset keyframes make it travel along. style arc bends it on a circle.
    - split_words turns a text or caption clip into one clip per word, each still where it sat: \
    then move, keyframe, tilt or set the depth slot of each word on its own (per-word layers).
    - transcribe, then get_transcript for word timings; add_captions turns them into text clips. \
    polish_propose finds silences, fillers, retakes and jump cuts; polish_apply applies them.
    - make_cutout finds the subject of a clip's media (a background job; watch get_jobs). Then \
    a layer above set to behindSubject shows between the background and the person. \
    auto_reframe crops 16:9 footage to 4:3 and pans with the subject like a calm camera \
    operator (steady, eased, never fast); locked: true keeps one framing instead, and \
    reframe_clip locks it wherever you say.

    Stickers and motion
    - import_media takes pictures too (PNG, JPEG). add_sticker drops one on top with a die-cut \
    border, a paper grain if asked, a motion preset and a sound; cutout_from_frame turns a \
    frame's subject into one.
    - apply_motion gives layers ready-made moves (pop, slideIn, float, orbit, scatter, stack).
    - add_drawing draws hand-drawn lines (points or SVG path data) that boil like hand \
    animation and can write themselves on and erase themselves off; set_drawing changes them.

    Animation
    - set_keyframes animates x, y, scale, rotation, opacity, volume or speed: values at \
    moments inside the clip. Each keyframe's easing (linear, easeIn, easeOut, easeInOut, hold, \
    spring, bouncy) shapes the move to the next one. remove_keyframes takes them away.
    - set_camera moves a camera over the whole picture (zoom, pan, rotate, tilt, dolly) with \
    keyframes; video tracks follow it, captions stay put.
    - track_motion follows a box through a video clip (a background job) and saves a named \
    path; follow then makes any layer move with it, or with the cut-out's subject.
    - Anything that moves blurs like film: set_shutter sets the timeline's shutter angle (180 \
    by default, 0 for none) and set_clip motion_blur scales it for one clip (0 keeps a layer \
    sharp, 2 doubles its smear).

    Speed
    - set_clip speed plays a video or sound clip faster or slower (0.1 to 10; 0.4 turns 60 fps \
    footage into smooth slow motion on a 24 fps timeline). The clip keeps its first and last \
    frames, so it gets shorter or longer and later clips on its track follow its end.
    - Speed ramps: set_keyframes with property speed, e.g. 1 at the take-off, 0.3 at the \
    peak, 1 on landing, eased. Each key sticks to the frame showing at its moment, so check \
    get_project afterwards: the clip's length and everything after it moved. \
    remove_keyframes property speed goes back to a steady speed.
    - Sound keeps its pitch when stretched, and is muted below 0.25 or above 4.
    - freeze_frame holds one frame for a while, splitting the clip around it (at the clip's \
    end, its last frame holds). A freeze is silent and can't be animated; push in on it with \
    set_camera.

    Colour and effects
    - set_look grades clips (exposure, contrast, saturation, temperature, tint, lift, gamma, \
    gain, curves, a LUT), adds grain, vignette, halation, blur or a green-screen key, and sets \
    blend modes (screen for flares on black, multiply for paper, overlay for grain plates).
    - add_adjustment puts a grade or film look over everything under it; captions stay clean.
    - Write your own effects: a .metal file defining float4 effect(float4 color, float2 uv, \
    float time, float amount, texture2d<half> source, sampler s) that returns the new colour. \
    Use it with set_look effects.shader (a path, or a plugin's shaders/ file); compile errors \
    come back to you to fix.
    - set_transition joins touching clips with a dissolve, dip, flash, whip, push, slices, \
    tiles or iris.

    Sound
    - set_clip fade_in / fade_out and volume; set_keyframes property volume for rides; \
    set_track volume, pan, muted and soloed for the mix (video tracks carry their clips' own \
    sound; pan moves stereo sound, mono stays centred). duck_music dips music under speech; \
    reduce_noise cleans background noise. normalize_loudness sets the final level for a \
    platform (youtube, instagram and tiktok -14 LUFS, podcast -16, broadcast -23), with a \
    limiter keeping true peaks under -1 dBTP; do it last and again after changing the sound.
    - add_sound drops a plugin's sound effect (or any sound file) at a moment. separate_stems \
    splits a clip into voice and music on their own tracks.

    Plugins (taste lives here)
    - list_plugins shows text styles, templates, stickers, overlays and sounds. apply_template \
    places a template with its fields filled; use_style restyles text; add_overlay lays an \
    overlay movie (light leak, dust) over the footage, screened by default. Write a plugin folder \
    (plugin.json plus stickers/, overlays/, sounds/, luts/, shaders/, fonts/) and it loads by \
    itself; a manifest problem shows in list_plugins.

    Export
    - add_short marks a stretch as a Reel/Short by name; set_short renames it or moves its \
    ends, remove_short unmarks it. The user sees shorts above the timeline and can change \
    them too. export kind youtube (16:9), shorts (each short on 9:16), frame, gif or srt; it \
    runs in the background and chimes when done.


    Projects: list_projects, new_project and open_project. Point the user at clips with \
    select_clips. Heavy footage plays from proxies; render_frame always uses the originals.

    Errors come back as plain words saying what went wrong and what to do; read them and retry.
    """
}
