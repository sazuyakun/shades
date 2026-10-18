// Draws one clip as a layer of the frame: upright (applying its rotation), fitted inside the
// frame, then moved, scaled and rotated by the clip's transform and blended by its opacity.
// Compiled at runtime by MetalRenderer, so new effects can be added without rebuilding.
#include <metal_stdlib>
using namespace metal;

// Must match `FrameUniforms` in FrameUniforms.swift.
struct FrameUniforms {
  float4 matrix;      // a, b, c, d of the upright→stored mapping (CGAffineTransform order)
  float2 fit;         // how much of the frame the fitted upright picture covers, per axis
  float2 offset;      // translation of the upright→stored mapping
  float2 frameSize;   // output size in pixels
  float2 position;    // clip offset as a fraction of the frame (x right, y down)
  float scale;        // clip size relative to fitting the frame
  float rotation;     // clockwise, in radians
  float opacity;      // 0 invisible … 1 solid
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
  float2 screen;     // where in the frame, 0…1 from the top left
  float opacity;
};

vertex VertexOut layerVertex(uint id [[vertex_id]], constant FrameUniforms &u [[buffer(0)]]) {
  const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
  const float2 uprightUVs[4] = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
  // Work in pixels from the frame's centre (y up) so rotation keeps the picture's shape.
  float2 halfSize = u.frameSize * 0.5;
  float2 pixel = corners[id] * u.fit * halfSize * u.scale;
  float s = sin(-u.rotation);
  float c = cos(-u.rotation);
  pixel = float2(pixel.x * c - pixel.y * s, pixel.x * s + pixel.y * c);
  pixel += float2(u.position.x, -u.position.y) * u.frameSize;
  float2 upright = uprightUVs[id];
  VertexOut out;
  out.position = float4(pixel / halfSize, 0, 1);
  out.uv = float2(
    u.matrix.x * upright.x + u.matrix.z * upright.y + u.offset.x,
    u.matrix.y * upright.x + u.matrix.w * upright.y + u.offset.y
  );
  out.screen = float2(pixel.x / u.frameSize.x + 0.5, 0.5 - pixel.y / u.frameSize.y);
  out.opacity = u.opacity;
  return out;
}

fragment half4 layerFragment(VertexOut in [[stage_in]], texture2d<half> source [[texture(0)]]) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  half4 color = source.sample(linearSampler, in.uv);
  return half4(color.rgb, color.a * half(in.opacity));
}

// The layer drawn only where the subject's mask (the base clip's cut-out, drawn into a frame-sized
// mask first) is, for the cut-out subject and inside-subject layers.
fragment half4 maskedLayerFragment(VertexOut in [[stage_in]], texture2d<half> source [[texture(0)]], texture2d<half> mask [[texture(1)]]) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  half4 color = source.sample(linearSampler, in.uv);
  half subject = mask.sample(linearSampler, in.screen).r;
  return half4(color.rgb, color.a * half(in.opacity) * subject);
}

// A cut-out's gray value, written into the one-channel mask.
fragment half4 matteFragment(VertexOut in [[stage_in]], texture2d<half> source [[texture(0)]]) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  return half4(source.sample(linearSampler, in.uv).r, 0, 0, 1);
}
