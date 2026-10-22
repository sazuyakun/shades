import AVFoundation
import Foundation
import ShadesCommands
import ShadesCore
import ShadesTestSupport
import ShadesUI
import Testing

/// Quality gate 2: scripted Claude sessions over real HTTP against the real workspace and
/// engine, one per area: captions, sound, export, plugins, and cut-outs with stickers.
@MainActor
struct ClaudeScenarioTests {

  // MARK: Internal

  @Test
  func `captions from a transcript: read it, caption it, see it, undo it`() async throws {
    let workspace = try await ScenarioWorkspace.open(port: 47_490)
    defer { workspace.server.stop() }
    let client = MCPTestClient(port: 47_490)
    let chart = try await importMedia(
      VideoFixture.makeChart(seconds: 3),
      with: client,
      in: workspace,
    )
    let talk = try await importMedia(
      AudioFixture.makeBursts(seconds: 3, bursts: [(0.2, 1.4), (1.8, 2.4)]),
      with: client,
      in: workspace,
    )
    _ = try await client.tool("append_clip", ["media_id": .string(chart.uuidString)])
    _ = try await client.tool("append_clip", ["media_id": .string(talk.uuidString)])
    let package = try #require(workspace.documentURL)
    try await workspace.analysis.update(talk, in: package) { $0.transcript = transcript }

    let said = try await client.tool("get_transcript")
    #expect(said.resultText.contains("hello from shades"))
    let added = try await client.tool("add_captions", ["reveal": "pop"])
    #expect(added.resultText.contains("Added"), "\(added.resultText)")
    let captions = workspace.editor.project.timeline.tracks.filter { $0.kind == .text }
      .flatMap(\.clips)
    #expect(!captions.isEmpty)
    let frame = try await client.tool("render_frame", ["seconds": 1, "max_side": 320])
    let png = try #require(frame.resultImage)
    #expect(try GoldenFrame.matches(png, named: "scenario-captions", in: golden))
    _ = try await client.tool("undo")
    #expect(workspace.editor.project.timeline.tracks.allSatisfy { $0.kind != .text || $0.clips
        .isEmpty
    })
  }

  @Test
  func `sound: analyse speech, duck the music under it, then normalise loudness`() async throws {
    let workspace = try await ScenarioWorkspace.open(port: 47_491)
    defer { workspace.server.stop() }
    let client = MCPTestClient(port: 47_491)
    let talk = try await importMedia(
      AudioFixture.makeBursts(seconds: 6, bursts: [(1, 2.5), (3.5, 5)]),
      with: client,
      in: workspace,
    )
    let music = try await importMedia(
      AudioFixture.makeTone(seconds: 6, frequency: 330, amplitude: 0.3),
      with: client,
      in: workspace,
    )
    _ = try await client.tool("append_clip", ["media_id": .string(talk.uuidString)])
    _ = try await client.tool("place_on_top", ["media_id": .string(music.uuidString), "at": 0])
    _ = try await client.tool("analyze_audio", ["media_ids": [.string(talk.uuidString)]])
    await workspace.jobs.waitUntilIdle()

    let ducked = try await client.tool("duck_music", ["track": "A2", "level": 0.25])
    #expect(!ducked.isErrorResult, "\(ducked.resultText)")
    let musicClip = try #require(workspace.editor.project.timeline.allClips
      .first { $0.mediaID == music })
    #expect(musicClip.keyframes.contains { $0.property == .volume && $0.value < 0.5 })

    let gainBefore = workspace.editor.project.timeline.gain
    let loud = try await client.tool("normalize_loudness", ["target": -14])
    #expect(!loud.isErrorResult, "\(loud.resultText)")
    #expect(loud.resultText.contains("LUFS"))
    #expect(workspace.editor.project.timeline.gain != gainBefore)
  }

  @Test
  func `export a short movie, a frame, a GIF and captions`() async throws {
    let workspace = try await ScenarioWorkspace.open(port: 47_492)
    defer { workspace.server.stop() }
    let client = MCPTestClient(port: 47_492)
    let chart = try await importMedia(
      VideoFixture.makeChart(seconds: 2),
      with: client,
      in: workspace,
    )
    _ = try await client.tool("append_clip", ["media_id": .string(chart.uuidString)])
    _ = try await client.tool("add_text", [
      "text": "The end",
      "at": 0.5,
      "duration": 1,
      "words": [["text": "The", "start": 0, "end": 0.4], ["text": "end", "start": 0.4, "end": 1]],
    ])
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let requests: [JSONValue] = [
      ["kind": "youtube", "codec": "h264"],
      ["kind": "frame", "at": 1],
      ["kind": "gif", "start": 0, "end": 1],
      ["kind": "srt"],
    ]
    for request in requests {
      guard case .object(var arguments) = request else {
        continue
      }
      arguments["folder"] = .string(folder.path)
      arguments["name"] = "scenario"
      let queued = try await client.tool("export", .object(arguments))
      #expect(!queued.isErrorResult, "\(queued.resultText)")
    }
    await workspace.jobs.waitUntilIdle()
    let jobs = try await client.tool("get_jobs")
    #expect(!jobs.resultText.contains("failed"), "\(jobs.resultText)")

    let movie = AVURLAsset(url: folder.appending(path: "scenario.mp4"))
    #expect(abs(try await movie.load(.duration).seconds - 2) < 0.1)
    let track = try #require(try await movie.loadTracks(withMediaType: .video).first)
    let size = try await track.load(.naturalSize)
    #expect(size == CGSize(width: 1920, height: 1080))
    let frame = try Data(contentsOf: folder.appending(path: "scenario.png"))
    #expect(try PixelProbe.color(of: frame, x: 0.08, y: 0.3).red > 200, "the red bar")
    let gif = try Data(contentsOf: folder.appending(path: "scenario.gif"))
    #expect(gif.starts(with: Data("GIF8".utf8)))
    let srt = try String(contentsOf: folder.appending(path: "scenario.srt"), encoding: .utf8)
    #expect(srt.contains("00:00:00,500 --> 00:00:01,500") && srt.contains("The end"))
  }

  @Test
  func `a plugin's template, look, sound and overlay, used by name`() async throws {
    let workspace = try await ScenarioWorkspace.open(port: 47_493, plugins: makePlugin())
    defer { workspace.server.stop() }
    let client = MCPTestClient(port: 47_493)
    let listed = try await client.tool("list_plugins")
    for name in ["title", "cool", "teal", "whoosh", "leak"] {
      #expect(listed.resultText.contains(name), "list_plugins names \(name)")
    }
    let chart = try await importMedia(
      VideoFixture.makeChart(seconds: 3),
      with: client,
      in: workspace,
    )
    _ = try await client.tool("append_clip", ["media_id": .string(chart.uuidString)])
    let footage = try #require(workspace.editor.project.timeline.allClips.first)

    let titled = try await client.tool(
      "apply_template",
      ["name": "Scenario/title", "at": 0.5, "fields": ["name": "SHADES"]],
    )
    #expect(!titled.isErrorResult, "\(titled.resultText)")
    let looked = try await client.tool(
      "use_look",
      ["clip_ids": [.string(footage.id.uuidString)], "look": "cool"],
    )
    #expect(!looked.isErrorResult, "\(looked.resultText)")
    _ = try await client.tool("add_sound", ["sound": "whoosh", "at": 0.5])
    let laid = try await client.tool("add_overlay", ["overlay": "leak", "at": 1, "duration": 1])
    #expect(!laid.isErrorResult, "\(laid.resultText)")

    let timeline = workspace.editor.project.timeline
    #expect(timeline.allClips.contains { $0.text?.text == "SHADES" })
    #expect(timeline.clip(withID: footage.id)?.grade?.lut?.hasSuffix("teal.cube") == true)
    let media = workspace.editor.project.media
    let overlay = try #require(timeline.allClips.first { clip in
      media.first { $0.id == clip.mediaID }?.url.lastPathComponent == "leak.mov"
    })
    #expect(overlay.blend == .screen)
    #expect(timeline.tracks.contains { track in
      track.kind == .audio && track.clips.contains { clip in
        media.first { $0.id == clip.mediaID }?.url.lastPathComponent == "whoosh.wav"
      }
    })
    let frame = try await client.tool("render_frame", ["seconds": 1.5, "max_side": 320])
    let png = try #require(frame.resultImage)
    #expect(try GoldenFrame.matches(png, named: "scenario-plugin", in: golden))
  }

  @Test
  func `cut out the subject, put words behind it, and stick its cut-out on top`() async throws {
    let workspace = try await ScenarioWorkspace.open(port: 47_494)
    defer { workspace.server.stop() }
    let client = MCPTestClient(port: 47_494)
    let disc = try await importMedia(VideoFixture.makeDisc(seconds: 2), with: client, in: workspace)
    _ = try await client.tool("append_clip", ["media_id": .string(disc.uuidString)])
    let footage = try #require(workspace.editor.project.timeline.allClips.first)
    let queued = try await client.tool("make_cutout", ["engine": "visionForeground"])
    #expect(queued.resultText.contains("Queued"), "\(queued.resultText)")
    await workspace.jobs.waitUntilIdle()

    _ = try await client.tool(
      "add_text",
      ["text": "WORDS BEHIND THE SUBJECT", "at": 0, "duration": 2],
    )
    let words = try #require(workspace.editor.project.timeline.allClips.first { $0.text != nil })
    let behind = try await client.tool(
      "set_clip",
      ["clip_id": .string(words.id.uuidString), "depth_slot": "behindSubject", "y": -0.36],
    )
    #expect(!behind.isErrorResult, "\(behind.resultText)")
    let cut = try await client.tool(
      "cutout_from_frame",
      ["clip_id": .string(footage.id.uuidString), "at": 0.5, "engine": "visionForeground"],
    )
    #expect(!cut.isErrorResult, "\(cut.resultText)")
    let sticker = try #require(workspace.editor.project.media.last { $0.isStill })
    let stuck = try await client.tool(
      "add_sticker",
      ["media_id": .string(sticker.id.uuidString), "at": 0, "x": 0.3, "y": 0.25, "scale": 0.3],
    )
    #expect(!stuck.isErrorResult, "\(stuck.resultText)")

    let frame = try await client.tool("render_frame", ["seconds": 1.5, "max_side": 320])
    let png = try #require(frame.resultImage)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.5).red > 200, "the disc hides the words")
    #expect(try GoldenFrame.matches(png, named: "scenario-cutout-sticker", in: golden))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// "hello from shades" then "captions", as a speech model would hear the talk fixture.
  private let transcript = Transcript(
    segments: [
      TranscriptSegment(
        text: "hello from shades",
        start: MediaTime(seconds: 0.2),
        end: MediaTime(seconds: 1.4),
        words: [
          TranscriptWord(
            text: "hello",
            start: MediaTime(seconds: 0.2),
            end: MediaTime(seconds: 0.6),
          ),
          TranscriptWord(
            text: "from",
            start: MediaTime(seconds: 0.6),
            end: MediaTime(seconds: 0.9),
          ),
          TranscriptWord(
            text: "shades",
            start: MediaTime(seconds: 0.9),
            end: MediaTime(seconds: 1.4),
          ),
        ],
      ),
      TranscriptSegment(
        text: "captions",
        start: MediaTime(seconds: 1.8),
        end: MediaTime(seconds: 2.4),
        words: [
          TranscriptWord(
            text: "captions",
            start: MediaTime(seconds: 1.8),
            end: MediaTime(seconds: 2.4),
          )
        ],
      ),
    ],
    language: "en",
  )

  /// Imports the file at `url` over MCP and returns its media ID.
  private func importMedia(
    _ url: URL,
    with client: MCPTestClient,
    in workspace: Workspace,
  ) async throws -> Media.ID {
    let imported = try await client.tool("import_media", ["path": .string(url.path)])
    #expect(!imported.isErrorResult, "\(imported.resultText)")
    return try #require(workspace.editor.project.media.last?.id)
  }

  /// A plugin folder called Scenario: a `title` template (with a sound), a `cool` look using
  /// its `teal` LUT, a `whoosh` sound and a `leak` overlay.
  private func makePlugin() async throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)")
    for part in ["luts", "sounds", "overlays"] {
      try FileManager.default.createDirectory(
        at: folder.appending(path: part),
        withIntermediateDirectories: true,
      )
    }
    try Data("""
      {
        "name": "Scenario",
        "styles": {"big": {"size": 0.14, "color": "#FFD400"}},
        "looks": {
          "cool": {"grade": {"temperature": -0.6, "lut": "teal"}, "effects": {"vignette": 0.8}}
        },
        "templates": {
          "title": {
            "duration": 2,
            "layers": [{"text": "{name}", "style": "big", "sound": "whoosh"}]
          }
        }
      }
      """.utf8).write(to: folder.appending(path: "plugin.json"))
    _ = try LUTFixture.make(at: folder.appending(path: "luts/teal.cube")) { red, green, blue in
      (red * 0.6, green, min(blue * 1.2 + 0.1, 1))
    }
    try FileManager.default.copyItem(
      at: AudioFixture.makeTone(seconds: 0.5, frequency: 880),
      to: folder.appending(path: "sounds/whoosh.wav"),
    )
    try await FileManager.default.copyItem(
      at: VideoFixture.make(
        left: FixtureColor(red: 255, green: 140, blue: 40),
        right: FixtureColor(red: 0, green: 0, blue: 0),
        width: 320,
        height: 180,
      ),
      to: folder.appending(path: "overlays/leak.mov"),
    )
    return folder
  }

}
