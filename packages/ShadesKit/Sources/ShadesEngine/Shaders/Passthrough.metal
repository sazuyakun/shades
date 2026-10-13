// Draws the source frame into the output frame upright (applying the clip's rotation) and
// scaled to fit with black bars. Compiled at runtime by MetalRenderer, so new effects can be
// added without rebuilding.
#include <metal_stdlib>
using namespace metal;

// Must match `FrameUniforms` in MetalRenderer.swift.
struct FrameUniforms {
  float2 scale;      // how much of the output the upright frame covers, per axis
  float2 offset;     // translation of the upright→stored coordinate mapping
  float4 matrix;     // a, b, c, d of the upright→stored mapping (CGAffineTransform order)
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex VertexOut fitVertex(uint id [[vertex_id]], constant FrameUniforms &uniforms [[buffer(0)]]) {
  const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
  const float2 uprightUVs[4] = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
  float2 upright = uprightUVs[id];
  VertexOut out;
  out.position = float4(corners[id] * uniforms.scale, 0, 1);
  out.uv = float2(
    uniforms.matrix.x * upright.x + uniforms.matrix.z * upright.y + uniforms.offset.x,
    uniforms.matrix.y * upright.x + uniforms.matrix.w * upright.y + uniforms.offset.y
  );
  return out;
}

fragment half4 passthroughFragment(VertexOut in [[stage_in]], texture2d<half> source [[texture(0)]]) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  return source.sample(linearSampler, in.uv);
}
