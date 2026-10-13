// Draws the source frame into the output frame, scaled to fit with black bars.
// Compiled at runtime by MetalRenderer, so new effects can be added without rebuilding.
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex VertexOut fitVertex(uint id [[vertex_id]], constant float2 &scale [[buffer(0)]]) {
  const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
  const float2 uvs[4] = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
  VertexOut out;
  out.position = float4(corners[id] * scale, 0, 1);
  out.uv = uvs[id];
  return out;
}

fragment half4 passthroughFragment(VertexOut in [[stage_in]], texture2d<half> source [[texture(0)]]) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  return source.sample(linearSampler, in.uv);
}
