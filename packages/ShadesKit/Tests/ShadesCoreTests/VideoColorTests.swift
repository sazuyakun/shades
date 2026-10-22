import Foundation
import ShadesCore
import Testing

struct VideoColorTests {

  @Test
  func `iPhone HDR is described as tone-mapped HLG`() {
    let color = VideoColor(
      primaries: "ITU_R_2020",
      transfer: "ITU_R_2100_HLG",
      matrix: "ITU_R_2020",
    )
    #expect(color.isHDR && color.isWideGamut)
    #expect(color.conversion == "HDR (HLG, Rec.2020) tone-mapped to Rec.709")
  }

  @Test
  func `P3 is wide colour and Rec.709 needs nothing`() {
    let p3 = VideoColor(primaries: "P3_D65", transfer: "ITU_R_709_2", matrix: "ITU_R_709_2")
    #expect(!p3.isHDR)
    #expect(p3.conversion == "Wide colour (P3) converted to Rec.709")
    let rec709 = VideoColor(primaries: "ITU_R_709_2", transfer: "ITU_R_709_2", matrix: nil)
    #expect(rec709.conversion == nil)
  }

  @Test
  func `media saved before colour tags opens without them`() throws {
    let json = """
      {"id":"6F3E2C1A-7B4D-4E5F-8A9B-0C1D2E3F4A5B","url":"file:///clip.mov",
       "duration":{"value":24,"timescale":24},"width":320,"height":180,
       "hasVideo":true,"hasAudio":false}
      """
    let media = try JSONDecoder().decode(Media.self, from: Data(json.utf8))
    #expect(media.color == nil)
  }

}
