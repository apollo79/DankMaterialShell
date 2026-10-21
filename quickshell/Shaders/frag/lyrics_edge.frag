#version 450

// Alpha ramp for the lyrics viewport, computed from the texture coordinate so no mask texture
// or MultiEffect threshold is involved.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float edgeFade;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 color = texture(source, qt_TexCoord0);
    float fade = max(ubuf.edgeFade, 0.0001);
    float edge = smoothstep(0.0, fade, qt_TexCoord0.y)
               * smoothstep(0.0, fade, 1.0 - qt_TexCoord0.y);
    fragColor = color * edge * ubuf.qt_Opacity;
}
