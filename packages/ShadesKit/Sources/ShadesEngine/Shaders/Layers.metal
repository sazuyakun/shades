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
  float bend;         // radians of arc the layer curves through across its width; 0 is flat
  int columns;        // strips the layer is cut into across, so it can curve
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
  float2 upright;     // where in the upright picture, 0…1 from its top left
  float aspect [[flat]]; // the upright picture's width over its height
  float2 screen [[center_no_perspective]]; // where in the frame, 0…1 from the top left
  float opacity;
};

// A point of the flat layer (pixels from its centre, y up), `z` pixels in front of it, curved
// round an upright axis: its width wraps an arc of `bend` radians, the middle staying put and
// the sides bending away.
static float3 bent(float2 pixel, float z, constant FrameUniforms &u) {
  if (u.bend == 0) {
    return float3(pixel, z);
  }
  float radius = u.fit.x * u.frameSize.x / u.bend;
  float angle = pixel.x / radius;
  float around = radius + z;
  return float3(around * sin(angle), pixel.y, around * cos(angle) - radius);
}

// Corner `id` of the layer's strip of `columns` slices, in the upright picture (0…1 from its top
// left): bottom and top corners in turn, from left to right.
static float2 stripCorner(uint id, constant FrameUniforms &u) {
  return float2(float(id / 2) / float(u.columns), id % 2 == 0 ? 1.0 : 0.0);
}

// Where a point of the upright picture is in the stored frame.
static float2 storedUV(float2 upright, constant FrameUniforms &u) {
  return float2(
    u.matrix.x * upright.x + u.matrix.z * upright.y + u.offset.x,
    u.matrix.y * upright.x + u.matrix.w * upright.y + u.offset.y
  );
}

vertex VertexOut layerVertex(uint id [[vertex_id]], constant FrameUniforms &u [[buffer(0)]]) {
  float2 upright = stripCorner(id, u);
  float2 pixel = float2(upright.x * 2 - 1, 1 - upright.y * 2) * u.fit * u.frameSize * 0.5;
  float4 position = u.transform * float4(bent(pixel, 0, u), 1);
  VertexOut out;
  out.position = position;
  out.uv = storedUV(upright, u);
  out.upright = upright;
  out.aspect = (u.fit.x * u.frameSize.x) / max(u.fit.y * u.frameSize.y, 1.0);
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
  float dip;          // fade towards black (or white) in a transition, 0 … 1
  float wipeProgress; // how far a transition's wipe has revealed the layer, 0 … 1
  int dipToWhite;
  int wipe;           // 0 none, 1 slices, 2 tiles, 3 iris
  float effectTime;   // seconds into the clip, for a plugin effect
  float effectAmount; // a plugin effect's strength, 0 … 1
  float qualifierHue;        // the grade's qualifier: hue picked (0 … 1)
  float qualifierHueWidth;
  float qualifierSaturation; // greyer colours aren't picked
  float qualifierLow;        // brightness range picked
  float qualifierHigh;
  float qualifierSoftness;
  float windowX;             // the grade's window: centre and size in the frame
  float windowY;
  float windowWidth;
  float windowHeight;
  float windowSoftness;
  int hasQualifier;
  int hasWindow;
  int windowIsEllipse;
  int windowInverted;
  float cropLeft;            // fractions of the upright picture cut off each edge
  float cropRight;
  float cropTop;
  float cropBottom;
  int maskCount;             // how many of the layer's masks are bound
  float footageLength; // seconds of source the shutter spans; 0 = no footage blur
  int footageTaps;     // the most taps a pixel of moving footage is smeared over
  float flowScale;     // a flow value's distance from 0.5 times this is pictures a second
  int transfer;              // 0 SDR, 1 HLG, 2 PQ: HDR is tone-mapped to SDR Rec.709
  int primaries;             // 0 Rec.709, 1 P3, 2 Rec.2020: wide gamuts are brought inside Rec.709
  float portalNesting;       // an endless zoom: each nested copy this many times smaller; 0 none
  float portalTravel;        // how far it has zoomed in, in copies
};

// Must match `LayerMaskShape` in LayerMaskShape.swift: one layer mask, placed for this frame.
struct LayerMaskShape {
  float x;            // centre and box size, fractions of the upright picture
  float y;
  float width;
  float height;
  float feather;      // fractions of the picture's height
  float expansion;
  float opacity;
  int kind;           // 0 rectangle, 1 ellipse, 2 path
  int inverted;
  int subtracts;
  int firstPoint;     // where its outline starts in the points buffer (box fractions)
  int pointCount;
};

static float hash(float2 p) {
  p = fract(p * float2(443.897, 441.423));
  p += dot(p, p.yx + 19.19);
  return fract((p.x + p.y) * p.x);
}

static float luma(float3 c) {
  return dot(c, float3(0.2126, 0.7152, 0.0722));
}

// A colour that isn't SDR Rec.709 brought into the working space: decoded to light, its gamut
// converted to Rec.709 (colours outside it clip), and HDR tone-mapped. Light is measured against
// reference white (203 nits, BT.2408): below 70% of it nothing changes, and brighter light rolls
// off smoothly towards SDR white, so faces and paper look as bright as in SDR footage while
// skies and lamps keep some detail. HLG is shown as on a 1000-nit screen (system gamma 1.2).
static float3 toWorkingSpace(float3 c, constant LayerLook &look) {
  float3 light;
  if (look.transfer == 1) {
    float3 scene = select((exp((c - 0.55991073) / 0.17883277) + 0.28466892) / 12.0, c * c / 3.0, c <= 0.5);
    light = 1000.0 / 203.0 * pow(max(luma(scene), 1e-6), 0.2) * scene;
  } else if (look.transfer == 2) {
    float3 p = pow(max(c, 0.0), 1.0 / 78.84375);
    light = 10000.0 / 203.0 * pow(max(p - 0.8359375, 0.0) / (18.8515625 - 18.6875 * p), 1.0 / 0.1593017578);
  } else {
    light = pow(max(c, 0.0), 2.4);
  }
  if (look.primaries == 1) {
    light = float3x3(float3(1.2249, -0.0420, -0.0197), float3(-0.2247, 1.0419, -0.0786), float3(0.0, 0.0, 1.0979)) * light;
  } else if (look.primaries == 2) {
    light = float3x3(float3(1.6605, -0.1246, -0.0182), float3(-0.5876, 1.1329, -0.1006), float3(-0.0728, -0.0083, 1.1187)) * light;
  }
  light = max(light, 0.0);
  if (look.transfer != 0) {
    float peak = max(light.r, max(light.g, light.b));
    float knee = 0.7;
    float mapped = peak <= knee ? peak : knee + (1.0 - knee) * (1.0 - exp(-(peak - knee) / (1.0 - knee)));
    light *= peak > 0 ? mapped / peak : 0.0;
  }
  return pow(min(light, 1.0), 1.0 / 2.4);
}

// The source at `uv`, smeared over `travel` (how far the footage there moves while the shutter
// is open, from `reachFragment`), with taps spread along the path.
static float4 sampleMoving(texture2d<half> source, texture2d<float> travel, sampler s, float2 uv, constant LayerLook &look) {
  float4 here = float4(source.sample(s, uv));
  if (look.footageLength <= 0) {
    return here;
  }
  float2 path = travel.sample(s, uv).rg;
  float2 size = float2(source.get_width(), source.get_height());
  int taps = min(int(round(length(path * size) / 1.5)), look.footageTaps);
  if (taps < 2) {
    return here;
  }
  float4 sum = float4(0);
  for (int i = 0; i < taps; i++) {
    sum += float4(source.sample(s, uv + path * (float(i) / float(taps - 1) - 0.5)));
  }
  return sum / float(taps);
}

// The source, smeared along its motion, then softened by `blur` (a small disc of taps around
// the point).
static float4 sampleSoft(texture2d<half> source, texture2d<float> travel, sampler s, float2 uv, constant LayerLook &look) {
  float4 color = sampleMoving(source, travel, s, uv, look);
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

// How much of the grade shows at a pixel: everywhere, or only in the qualifier's colours and
// inside (or outside) the window, with soft edges.
static float gradeMask(float3 c, float2 screen, constant LayerLook &look) {
  float amount = 1.0;
  if (look.hasQualifier != 0) {
    float high = max(c.r, max(c.g, c.b));
    float low = min(c.r, min(c.g, c.b));
    float chroma = high - low;
    float hue = 0.0;
    if (chroma > 0.0001) {
      if (high == c.r) { hue = fmod((c.g - c.b) / chroma + 6.0, 6.0); }
      else if (high == c.g) { hue = (c.b - c.r) / chroma + 2.0; }
      else { hue = (c.r - c.g) / chroma + 4.0; }
      hue /= 6.0;
    }
    float saturation = high > 0 ? chroma / high : 0.0;
    float distance = abs(hue - look.qualifierHue);
    distance = min(distance, 1.0 - distance);
    float soft = max(look.qualifierSoftness, 0.001);
    amount *= 1.0 - smoothstep(look.qualifierHueWidth, look.qualifierHueWidth + soft, distance);
    amount *= smoothstep(look.qualifierSaturation - soft, look.qualifierSaturation, saturation);
    float bright = luma(c);
    amount *= smoothstep(look.qualifierLow - soft, look.qualifierLow, bright);
    amount *= 1.0 - smoothstep(look.qualifierHigh, look.qualifierHigh + soft, bright);
  }
  if (look.hasWindow != 0) {
    float2 offset = (screen - float2(look.windowX, look.windowY)) / max(float2(look.windowWidth, look.windowHeight) * 0.5, 0.001);
    float edge = look.windowIsEllipse != 0 ? length(offset) : max(abs(offset.x), abs(offset.y));
    float inside = 1.0 - smoothstep(1.0 - look.windowSoftness, 1.0 + look.windowSoftness, edge);
    amount *= look.windowInverted != 0 ? 1.0 - inside : inside;
  }
  return amount;
}

// How much of a layer a transition's wipe shows at `screen` (0 hidden … 1 shown).
static float wipeMask(float2 screen, int wipe, float progress) {
  switch (wipe) {
    case 1: {
      float band = floor(screen.y * 8.0);
      float local = saturate((progress - band / 8.0 * 0.5) / 0.5);
      return step(screen.x, local);
    }
    case 2: {
      float order = hash(floor(screen * float2(6.0, 5.0)) + 3.17);
      return smoothstep(order * 0.8, order * 0.8 + 0.2, progress);
    }
    case 3: {
      float distance = length((screen - 0.5) * float2(1.3333, 1.0));
      float radius = progress * 0.85;
      return 1.0 - smoothstep(radius - 0.015, radius + 0.015, distance);
    }
    default: return 1.0;
  }
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

// How much of the upright picture's point `p` survives the crop: 1 inside, 0 outside, with a
// one-pixel soft edge so cut edges don't stair-step.
static float cropCoverage(float2 p, constant LayerLook &look) {
  if (look.cropLeft <= 0 && look.cropRight <= 0 && look.cropTop <= 0 && look.cropBottom <= 0) {
    return 1.0;
  }
  float2 pixel = max(fwidth(p), 0.00001);
  float2 low = saturate((p - float2(look.cropLeft, look.cropTop)) / pixel + 0.5);
  float2 high = saturate((float2(1 - look.cropRight, 1 - look.cropBottom) - p) / pixel + 0.5);
  return low.x * low.y * high.x * high.y;
}

// How far `p` is from a closed polygon's edge (negative inside), in `p`'s units.
static float polygonDistance(float2 p, float2 size, constant float2 *points, int count) {
  float2 first = (points[0] - 0.5) * size;
  float distance = dot(p - first, p - first);
  float side = 1.0;
  for (int i = 0, j = count - 1; i < count; j = i, i++) {
    float2 a = (points[i] - 0.5) * size;
    float2 b = (points[j] - 0.5) * size;
    float2 edge = b - a;
    float2 toPoint = p - a;
    float2 nearest = toPoint - edge * saturate(dot(toPoint, edge) / max(dot(edge, edge), 1e-10));
    distance = min(distance, dot(nearest, nearest));
    bool3 crossing = bool3(p.y >= a.y, p.y < b.y, edge.x * toPoint.y > edge.y * toPoint.x);
    if (all(crossing) || all(!crossing)) {
      side = -side;
    }
  }
  return side * sqrt(distance);
}

// How much of the layer its masks show at the upright picture's point `p`: each shape's soft
// coverage, inverted and faded as asked, added to or taken from the masks before it.
static float maskCoverage(float2 p, float aspect, constant LayerLook &look, constant LayerMaskShape *masks, constant float2 *points) {
  if (look.maskCount == 0) {
    return 1.0;
  }
  // why: distances are measured in picture heights, so circles stay round on any picture.
  float2 scale = float2(aspect, 1.0);
  float coverage = masks[0].subtracts != 0 ? 1.0 : 0.0;
  for (int i = 0; i < look.maskCount; i++) {
    LayerMaskShape mask = masks[i];
    float2 size = float2(mask.width, mask.height) * scale;
    float2 q = (p - float2(mask.x, mask.y)) * scale;
    float distance;
    if (mask.kind == 0) {
      float2 outside = abs(q) - size * 0.5;
      distance = length(max(outside, 0.0)) + min(max(outside.x, outside.y), 0.0);
    } else if (mask.kind == 1) {
      float2 radius = max(size * 0.5, 1e-5);
      distance = (length(q / radius) - 1.0) * min(radius.x, radius.y);
    } else {
      distance = polygonDistance(q, size, points + mask.firstPoint, mask.pointCount);
    }
    distance -= mask.expansion;
    float soft = max(mask.feather, fwidth(distance));
    float inside = 1.0 - smoothstep(-soft * 0.5, soft * 0.5, distance);
    inside = (mask.inverted != 0 ? 1.0 - inside : inside) * mask.opacity;
    coverage = mask.subtracts != 0 ? coverage * (1.0 - inside) : coverage + inside - coverage * inside;
  }
  return coverage;
}

// The layer's picture keyed, graded and given its effects: straight colour and alpha, before
// it's masked, wiped or mixed with what's under it.
// Where an endless zoom samples the picture: it holds a copy of itself `portalNesting` times
// smaller in its middle, and so on forever, and the view has zoomed `portalTravel` copies in.
// Each point is scaled by whole copies until it lands in the ring between the picture's edge
// and its first copy's.
static float2 portalUV(float2 uv, constant LayerLook &look) {
  if (look.portalNesting <= 1) {
    return uv;
  }
  float2 offset = (uv - 0.5) * pow(look.portalNesting, -fract(look.portalTravel));
  float size = max(max(abs(offset.x), abs(offset.y)) * 2.0, 1e-6);
  float copies = floor(-log(size) / log(look.portalNesting));
  return offset * pow(look.portalNesting, copies) + 0.5;
}

static float4 shade(VertexOut in, texture2d<half> picture, texture2d<float> travel, float2 uv, texture3d<float> lut, texture2d<float> curves, constant LayerLook &look, constant LayerMaskShape *masks, constant float2 *points, sampler s) {
  uv = portalUV(uv, look);
  float4 color = sampleSoft(picture, travel, s, uv, look);
  if (look.transfer != 0 || look.primaries != 0) {
    color.rgb = toWorkingSpace(color.rgb, look);
  }
  float alpha = color.a;
  float3 rgb = alpha > 0 ? color.rgb / alpha : color.rgb;
  alpha *= cropCoverage(in.upright, look) * maskCoverage(in.upright, in.aspect, look, masks, points);
  if (look.keyTolerance > 0) {
    float distance = length(rgb - float3(look.keyRed, look.keyGreen, look.keyBlue));
    alpha *= smoothstep(look.keyTolerance, look.keyTolerance + max(look.keySoftness, 0.001), distance);
  }
  rgb = mix(rgb, grade(rgb, look, lut, curves, s), gradeMask(rgb, in.screen, look));
  if (look.halation > 0) {
    float3 glow = float3(0);
    for (int i = 0; i < 8; i++) {
      float angle = float(i) * 0.7853982;
      float2 offset = float2(cos(angle), sin(angle)) * look.texel * 18.0;
      float3 tap = float3(picture.sample(s, uv + offset).rgb);
      if (look.transfer != 0 || look.primaries != 0) {
        tap = toWorkingSpace(tap, look);
      }
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
  return float4(rgb, alpha);
}

// The shaded colour faded by a transition's dip, masked and wiped, then mixed with what's under
// it by the blend mode (or, for an adjustment clip, written in place).
static float4 composite(float4 shaded, VertexOut in, texture2d<half> mask, texture2d<half> backdrop, constant LayerLook &look, sampler s) {
  float3 rgb = mix(shaded.rgb, look.dipToWhite != 0 ? float3(1) : float3(0), look.dip);
  rgb = saturate(rgb);
  float alpha = shaded.a * in.opacity * wipeMask(in.screen, look.wipe, look.wipeProgress);
  if (look.masked != 0) {
    alpha *= float(mask.sample(s, in.screen).r);
  }
  if (look.blend == 0 && look.isAdjustment == 0) {
    return float4(rgb, alpha);
  }
  float3 under = float3(backdrop.sample(s, in.screen).rgb);
  return float4(mix(under, blendWith(under, rgb, look.blend), alpha), 1);
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
  texture2d<float> travel [[texture(5)]],
  constant LayerLook &look [[buffer(0)]],
  constant LayerMaskShape *masks [[buffer(1)]],
  constant float2 *points [[buffer(2)]]
) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  float2 uv = look.isAdjustment != 0 ? in.screen : in.uv;
  texture2d<half> picture = look.isAdjustment != 0 ? backdrop : source;
  float4 shaded = shade(in, picture, travel, uv, lut, curves, look, masks, points, linearSampler);
  return composite(shaded, in, mask, backdrop, look, linearSampler);
}

// One moment of a moving layer, premultiplied and weighted by its share of the shutter (the
// quad's opacity), ready to be added into the layer's trail.
static float4 weighted(float4 shaded, VertexOut in) {
  float alpha = shaded.a * in.opacity;
  return float4(shaded.rgb * alpha, alpha);
}

// Adds one moment of a moving layer, keyed, graded and given its effects, into its trail.
fragment float4 sampleFragment(
  VertexOut in [[stage_in]],
  texture2d<half> source [[texture(0)]],
  texture3d<float> lut [[texture(3)]],
  texture2d<float> curves [[texture(4)]],
  texture2d<float> travel [[texture(5)]],
  constant LayerLook &look [[buffer(0)]],
  constant LayerMaskShape *masks [[buffer(1)]],
  constant float2 *points [[buffer(2)]]
) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  return weighted(shade(in, source, travel, in.uv, lut, curves, look, masks, points, linearSampler), in);
}

// Draws a moving layer's trail (its moments summed, so averaged) over the frame, then masks,
// wipes and mixes it like any layer.
fragment float4 trailFragment(
  VertexOut in [[stage_in]],
  texture2d<half> trail [[texture(0)]],
  texture2d<half> mask [[texture(1)]],
  texture2d<half> backdrop [[texture(2)]],
  constant LayerLook &look [[buffer(0)]]
) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  float4 sum = float4(trail.sample(linearSampler, in.screen));
  if (look.blur > 0) {
    float radius = look.blur * 24.0;
    for (int i = 0; i < 12; i++) {
      float angle = float(i) * 0.5235988;
      float ring = (i % 2 == 0) ? 1.0 : 0.5;
      float2 offset = float2(cos(angle), sin(angle)) * look.texel * radius * ring;
      sum += float4(trail.sample(linearSampler, in.screen + offset));
    }
    sum /= 13.0;
  }
  float alpha = saturate(sum.a);
  float3 rgb = alpha > 0 ? sum.rgb / sum.a : float3(0);
  return composite(float4(rgb, alpha), in, mask, backdrop, look, linearSampler);
}

// How far (in uv) the footage at `uv` moves while the shutter is open, from its optical flow.
// Motion within four stored steps of still is drift in the flow and its video, not movement; it
// fades in up to eight steps and is used at its full speed beyond (subtracting the drift would
// shorten every real smear).
static float2 travelAt(texture2d<half> flow, sampler s, float2 uv, constant LayerLook &look) {
  float2 speed = (float2(flow.sample(s, uv).rg) - 0.5) * look.flowScale;
  float step = look.flowScale / 255.0;
  return speed * smoothstep(4.0 * step, 8.0 * step, length(speed)) * look.footageLength;
}

// For each point of a flow frame, drawn at the flow's size, the travel that smears onto it: its
// own, or the longest of its neighbours' whose smear reaches it along their path. That's how a
// moving thing's blur spills past its edges onto the still background around it.
fragment float4 reachFragment(
  VertexOut in [[stage_in]],
  texture2d<half> flow [[texture(0)]],
  constant LayerLook &look [[buffer(0)]]
) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  float2 texel = 1.0 / float2(flow.get_width(), flow.get_height());
  float2 best = travelAt(flow, linearSampler, in.screen, look);
  for (int i = 0; i < 8; i++) {
    float angle = float(i) * 0.7853982;
    float2 direction = float2(cos(angle), sin(angle));
    for (int step = 1; step <= 24; step++) {
      float2 offset = direction * texel * float(step);
      float2 travel = travelAt(flow, linearSampler, in.screen + offset, look);
      float along = length(travel);
      if (along > length(best) && length(offset) <= along * 0.5
          && abs(dot(normalize(offset), travel / along)) > 0.9) {
        best = travel;
      }
    }
  }
  return float4(best, 0, 0);
}

// A cut-out's gray value, refined by the clip's `edge` (feather, choke, smoothing, as fractions
// of the picture's width), written into the one-channel mask. The matte is blurred over a disc
// wide enough for all three, then cut at a level that moves the edge by the choke, over a
// width set by the feather.
fragment half4 matteFragment(VertexOut in [[stage_in]], texture2d<half> source [[texture(0)]], constant float4 &edge [[buffer(0)]]) {
  constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
  float raw = source.sample(linearSampler, in.uv).r;
  if (edge.x <= 0 && edge.y == 0 && edge.z <= 0) {
    return half4(raw, 0, 0, 1);
  }
  float pixel = 1.0 / float(source.get_width());
  float radius = abs(edge.y) + edge.x * 0.5 + edge.z * 0.02 + pixel;
  // why: the radius is in picture widths; a step across the picture's height is a bigger share.
  float2 reach = float2(1.0, float(source.get_width()) / float(source.get_height())) * radius;
  float sum = raw;
  for (int ring = 1; ring <= 3; ring++) {
    for (int i = 0; i < 12; i++) {
      float angle = (float(i) + float(ring) * 0.5) * 0.5235988;
      sum += source.sample(linearSampler, in.uv + float2(cos(angle), sin(angle)) * reach * (float(ring) / 3.0)).r;
    }
  }
  float blurred = sum / 37.0;
  float level = 0.5 + edge.y / (2.0 * radius);
  float half_width = max(edge.x, pixel) / (4.0 * radius);
  return half4(smoothstep(level - half_width, level + half_width, blurred), 0, 0, 1);
}

// Must match `SolidUniforms` in SolidUniforms.swift.
struct Solid {
  float4x4 turn;   // the layer's own turn and the camera's: which way its faces point
  float depth;     // how deep the letters go, in pixels
  float bevel;     // how far the slope round their front edges reaches in, in pixels
  int slices;      // copies of the letters stacked through the depth
  int backFirst;   // 1 when the front faces the viewer: slices go from the back forward
};

struct SolidOut {
  float4 position [[position]];
  float2 uv;
  float2 upright;
  float aspect [[flat]];
  float behind;    // how far behind the front face this slice is, in pixels
  float turned;    // how far the bend has turned this point, in radians
};

// One slice of solid letters, `behind` pixels back from the front, placed like the layer.
vertex SolidOut solidVertex(
  uint id [[vertex_id]],
  uint instance [[instance_id]],
  constant FrameUniforms &u [[buffer(0)]],
  constant Solid &solid [[buffer(1)]]
) {
  int slice = solid.backFirst != 0 ? solid.slices - 1 - int(instance) : int(instance);
  float behind = solid.depth * float(slice) / float(max(solid.slices - 1, 1));
  float2 upright = stripCorner(id, u);
  float2 pixel = float2(upright.x * 2 - 1, 1 - upright.y * 2) * u.fit * u.frameSize * 0.5;
  SolidOut out;
  out.position = u.transform * float4(bent(pixel, -behind, u), 1);
  out.uv = storedUV(upright, u);
  out.upright = upright;
  out.aspect = (u.fit.x * u.frameSize.x) / max(u.fit.y * u.frameSize.y, 1.0);
  out.behind = behind;
  out.turned = u.bend == 0 ? 0.0 : pixel.x * u.bend / (u.fit.x * u.frameSize.x);
  return out;
}

// How far `uv` is inside the letters' edge, in pixels (negative outside).
static float inside(texture2d<half> distance, sampler s, float2 uv, constant Solid &solid) {
  return float(distance.sample(s, uv).r);
}

// One slice of solid letters: where they reach at its depth (pulled in by the bevel near the
// front), lit by a light above left as they turn. Premultiplied, stacked over the slices drawn
// before it.
fragment float4 solidFragment(
  SolidOut in [[stage_in]],
  texture2d<half> source [[texture(0)]],
  texture2d<half> distance [[texture(5)]],
  constant LayerLook &look [[buffer(0)]],
  constant LayerMaskShape *masks [[buffer(1)]],
  constant float2 *points [[buffer(2)]],
  constant Solid &solid [[buffer(3)]]
) {
  constexpr sampler s(filter::linear, address::clamp_to_edge);
  float edge = inside(distance, s, in.uv, solid) - max(solid.bevel - in.behind, 0.0);
  float cover = saturate(edge + 0.5) * cropCoverage(in.upright, look)
    * maskCoverage(in.upright, in.aspect, look, masks, points);
  if (cover <= 0) {
    discard_fragment();
  }
  float4 color = float4(source.sample(s, in.uv));
  float3 rgb = color.a > 0.004 ? color.rgb / color.a : color.rgb;
  float2 texel = 1.0 / float2(distance.get_width(), distance.get_height());
  float2 slope = float2(
    inside(distance, s, in.uv + float2(texel.x, 0), solid) - inside(distance, s, in.uv - float2(texel.x, 0), solid),
    inside(distance, s, in.uv - float2(0, texel.y), solid) - inside(distance, s, in.uv + float2(0, texel.y), solid)
  );
  float2 outward = length(slope) > 0.0001 ? -normalize(slope) : float2(0);
  bool isFace = edge > 1.5;
  float3 normal;
  if (in.behind < 0.5 && (solid.bevel < 0.5 || isFace)) {
    normal = float3(0, 0, 1);
  } else if (in.behind > solid.depth - 0.5 && isFace) {
    normal = float3(0, 0, -1);
  } else if (in.behind < solid.bevel) {
    normal = normalize(float3(outward, 1));
  } else {
    normal = float3(outward, 0);
  }
  float c = cos(in.turned);
  float n = sin(in.turned);
  normal = float3(normal.x * c + normal.z * n, normal.y, normal.z * c - normal.x * n);
  float3 facing = normalize((solid.turn * float4(normal, 0)).xyz);
  const float3 light = normalize(float3(-0.4, 0.55, 0.75));
  float shade = (0.35 + 0.65 * max(dot(facing, light), 0.0)) / (0.35 + 0.65 * light.z);
  return float4(rgb * shade * cover, cover);
}

// Adds one moment of a solid layer, weighted by its share of the shutter, into its trail.
fragment float4 addFragment(VertexOut in [[stage_in]], texture2d<half> moment [[texture(0)]]) {
  constexpr sampler s(filter::linear, address::clamp_to_edge);
  return float4(moment.sample(s, in.uv)) * in.opacity;
}

// The distance field of solid letters, by jump flooding. Seeds are the pixels on the ink's edge
// (with a neighbour on the other side); each pass, every pixel takes the nearest seed known to
// any pixel `step` away, `step` halving down to 1.

static bool isInk(texture2d<half, access::read> picture, int2 p) {
  int2 size = int2(picture.get_width(), picture.get_height());
  return picture.read(uint2(clamp(p, int2(0), size - 1))).a >= 0.5h;
}

// Marks each pixel on the ink's edge as its own nearest seed, and every other as having none.
kernel void edgeSeeds(
  texture2d<half, access::read> picture [[texture(0)]],
  texture2d<ushort, access::write> seeds [[texture(1)]],
  uint2 id [[thread_position_in_grid]]
) {
  if (id.x >= seeds.get_width() || id.y >= seeds.get_height()) {
    return;
  }
  int2 p = int2(id);
  bool ink = isInk(picture, p);
  bool edge = ink != isInk(picture, p + int2(1, 0)) || ink != isInk(picture, p - int2(1, 0))
    || ink != isInk(picture, p + int2(0, 1)) || ink != isInk(picture, p - int2(0, 1));
  seeds.write(edge ? ushort4(ushort(id.x), ushort(id.y), 0, 0) : ushort4(0xFFFF), id);
}

// One jump: the nearest seed among this pixel's and those of the eight pixels `step` away.
kernel void jumpFlood(
  texture2d<ushort, access::read> from [[texture(0)]],
  texture2d<ushort, access::write> to [[texture(1)]],
  constant int &step [[buffer(0)]],
  uint2 id [[thread_position_in_grid]]
) {
  int2 size = int2(to.get_width(), to.get_height());
  if (int(id.x) >= size.x || int(id.y) >= size.y) {
    return;
  }
  ushort2 best = ushort2(0xFFFF);
  float nearest = INFINITY;
  for (int dy = -1; dy <= 1; dy++) {
    for (int dx = -1; dx <= 1; dx++) {
      int2 q = int2(id) + int2(dx, dy) * step;
      if (any(q < 0) || any(q >= size)) {
        continue;
      }
      ushort2 seed = from.read(uint2(q)).xy;
      if (seed.x == 0xFFFF) {
        continue;
      }
      float2 offset = float2(seed) - float2(id);
      float distance = dot(offset, offset);
      if (distance < nearest) {
        nearest = distance;
        best = seed;
      }
    }
  }
  to.write(ushort4(best, 0, 0), id);
}

// The signed distance in pixels to the ink's edge, out to `reach`: positive inside. Half a pixel
// is added because the edge lies between an edge pixel and its neighbour across it.
kernel void signedDistance(
  texture2d<half, access::read> picture [[texture(0)]],
  texture2d<ushort, access::read> seeds [[texture(1)]],
  texture2d<half, access::write> field [[texture(2)]],
  constant float &reach [[buffer(0)]],
  uint2 id [[thread_position_in_grid]]
) {
  if (id.x >= field.get_width() || id.y >= field.get_height()) {
    return;
  }
  ushort2 seed = seeds.read(id).xy;
  float distance = seed.x == 0xFFFF ? reach : min(length(float2(seed) - float2(id)) + 0.5, reach);
  field.write(half4(isInk(picture, int2(id)) ? distance : -distance), id);
}
