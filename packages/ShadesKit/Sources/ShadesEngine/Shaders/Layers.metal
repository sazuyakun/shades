// Draws one clip as a layer of the frame: upright (applying its rotation), fitted inside the
// frame, then placed in 3D by the clip's transform and the camera, and blended by its opacity.
// Compiled at runtime by MetalRenderer, so new effects can be added without rebuilding.
#include <metal_stdlib>
using namespace metal;

// Must match `FrameUniforms` in FrameUniforms.swift.
struct FrameUniforms {
  float4x4 transform; // layer corner (pixels from the frame's centre, y up) → screen, with perspective
  float4 matrix;      // a, b, c, d of the upright→stored mapping (CGAffineTransform order)
  float2 fit;         // how much of the frame the fitted upright picture covers, per axis
  float2 offset;      // translation of the upright→stored mapping
  float2 frameSize;   // output size in pixels
  float opacity;      // 0 invisible … 1 solid
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
  float2 screen [[center_no_perspective]]; // where in the frame, 0…1 from the top left
  float opacity;
};

vertex VertexOut layerVertex(uint id [[vertex_id]], constant FrameUniforms &u [[buffer(0)]]) {
  const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
  const float2 uprightUVs[4] = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
  float2 pixel = corners[id] * u.fit * u.frameSize * 0.5;
  float4 position = u.transform * float4(pixel, 0, 1);
  float2 upright = uprightUVs[id];
  VertexOut out;
  out.position = position;
  out.uv = float2(
    u.matrix.x * upright.x + u.matrix.z * upright.y + u.offset.x,
    u.matrix.y * upright.x + u.matrix.w * upright.y + u.offset.y
  );
  float2 onScreen = position.xy / position.w;
  out.screen = float2(onScreen.x * 0.5 + 0.5, 0.5 - onScreen.y * 0.5);
  out.opacity = u.opacity;
  return out;
}

// Must match `LayerLook` in LayerLook.swift.
struct LayerLook {
  float2 texel;       // one source pixel, in uv units (for blur and halation)
  float exposure;     // stops
  float contrast;
  float saturation;
  float temperature;  // -1 cool … 1 warm
  float tint;         // -1 green … 1 magenta
  float lift;
  float gamma;
  float gain;
  float lutAmount;    // 0 = no LUT
  float grain;
  float vignette;
  float halation;
  float blur;
  float keyRed;
  float keyGreen;
  float keyBlue;
  float keyTolerance; // 0 = no key
  float keySoftness;
  float seed;         // changes every frame, for grain
  int blend;          // BlendMode's order: normal, add, screen, multiply, overlay, softLight, lighten, darken
  int masked;         // draw only inside the subject's mask
  int hasCurves;
  int isAdjustment;   // the source is the frame so far (an adjustment clip)
};

static float hash(float2 p) {
  p = fract(p * float2(443.897, 441.423));
  p += dot(p, p.yx + 19.19);
  return fract((p.x + p.y) * p.x);
}

static float luma(float3 c) {
  return dot(c, float3(0.2126, 0.7152, 0.0722));
}

// The source, softened by `blur` (a small disc of taps around the point).
static float4 sampleSoft(texture2d<half> source, sampler s, float2 uv, constant LayerLook &look) {
  float4 color = float4(source.sample(s, uv));
  if (look.blur <= 0) {
    return color;
  }
  float radius = look.blur * 24.0;
  float4 sum = color;
  for (int i = 0; i < 12; i++) {
    float angle = float(i) * 0.5235988;
    float ring = (i % 2 == 0) ? 1.0 : 0.5;
    float2 offset = float2(cos(angle), sin(angle)) * look.texel * radius * ring;
    sum += float4(source.sample(s, uv + offset));
  }
  return sum / 13.0;
}

static float3 grade(float3 c, constant LayerLook &look, texture3d<float> lut, texture2d<float> curves, sampler s) {
  c *= exp2(look.exposure);
  c *= float3(1 + look.temperature * 0.1, 1 - look.tint * 0.08, 1 - look.temperature * 0.1);
  c = c * look.gain + look.lift * (1 - c);
  c = pow(max(c, 0.0), float3(1.0 / max(look.gamma, 0.01)));
  c = (c - 0.5) * look.contrast + 0.5;
  c = mix(float3(luma(c)), c, look.saturation);
  c = saturate(c);
  if (look.hasCurves != 0) {
    c = float3(curves.sample(s, float2(c.r, 0.5)).r, curves.sample(s, float2(c.g, 0.5)).g, curves.sample(s, float2(c.b, 0.5)).b);
  }
  if (look.lutAmount > 0) {
    float size = float(lut.get_width());
    float3 at = c * ((size - 1) / size) + 0.5 / size;
    c = mix(c, lut.sample(s, at).rgb, look.lutAmount);
  }
  return c;
}

static float3 blendWith(float3 base, float3 top, int mode) {
  switch (mode) {
    case 1: return min(base + top, 1.0);
    case 2: return 1 - (1 - base) * (1 - top);
    case 3: return base * top;
    case 4: return select(1 - 2 * (1 - base) * (1 - top), 2 * base * top, base < 0.5);
    case 5: return select(base + (2 * top - 1) * (sqrt(base) - base), base - (1 - 2 * top) * base * (1 - base), top < 0.5);
    case 6: return max(base, top);
    case 7: return min(base, top);
    default: return top;
  }
}

// Draws one layer: its picture keyed, graded and given its effects, then mixed with what's under
// it by its blend mode (or, for an adjustment clip, the frame so far, graded in place).
fragment float4 layerFragment(
  VertexOut in [[stage_in]],
  texture2d<half> source [[texture(0)]],
  texture2d<half> mask [[texture(1)]],
  texture2d<half> backdrop [[texture(2)]],
  texture3d<float> lut [[texture(3)]],
  texture2d<float> curves [[texture(4)]],
  constant LayerLook &look [[buffer(0)]]
) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  float2 uv = look.isAdjustment != 0 ? in.screen : in.uv;
  texture2d<half> picture = look.isAdjustment != 0 ? backdrop : source;
  float4 color = sampleSoft(picture, linearSampler, uv, look);
  float alpha = color.a;
  float3 rgb = alpha > 0 ? color.rgb / alpha : color.rgb;
  if (look.keyTolerance > 0) {
    float distance = length(rgb - float3(look.keyRed, look.keyGreen, look.keyBlue));
    alpha *= smoothstep(look.keyTolerance, look.keyTolerance + max(look.keySoftness, 0.001), distance);
  }
  rgb = grade(rgb, look, lut, curves, linearSampler);
  if (look.halation > 0) {
    float3 glow = float3(0);
    for (int i = 0; i < 8; i++) {
      float angle = float(i) * 0.7853982;
      float2 offset = float2(cos(angle), sin(angle)) * look.texel * 18.0;
      float3 tap = float3(picture.sample(linearSampler, uv + offset).rgb);
      glow += max(tap - 0.75, 0.0);
    }
    rgb += float3(1.0, 0.35, 0.15) * luma(glow / 8.0) * look.halation * 3.0;
  }
  if (look.vignette > 0) {
    float2 centered = in.screen - 0.5;
    rgb *= 1 - look.vignette * smoothstep(0.3, 0.75, length(centered * float2(1.0, 0.85)));
  }
  if (look.grain > 0) {
    float noise = hash(in.position.xy + look.seed * 61.7) - 0.5;
    rgb += noise * look.grain * 0.18 * (1.0 - abs(luma(rgb) - 0.5));
  }
  rgb = saturate(rgb);
  alpha *= in.opacity;
  if (look.masked != 0) {
    alpha *= float(mask.sample(linearSampler, in.screen).r);
  }
  if (look.blend == 0 && look.isAdjustment == 0) {
    return float4(rgb, alpha);
  }
  float3 under = float3(backdrop.sample(linearSampler, in.screen).rgb);
  return float4(mix(under, blendWith(under, rgb, look.blend), alpha), 1);
}

// A cut-out's gray value, written into the one-channel mask.
fragment half4 matteFragment(VertexOut in [[stage_in]], texture2d<half> source [[texture(0)]]) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  return half4(source.sample(linearSampler, in.uv).r, 0, 0, 1);
}
