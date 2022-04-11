#include <metal_stdlib>
using namespace metal;

#include "ShaderDefinitions.h"

struct VertexOut {
    float4 pos [[position]];
    float4 color;
};

vertex VertexOut vertexShader(const device Vertex *vertexArray [[buffer(0)]],
                              unsigned int vid [[vertex_id]]) {
    Vertex in = vertexArray[vid];
    VertexOut out;
    out.pos = float4(in.pos.x, in.pos.y, 0, 1);
    out.color = in.color;
    return out;
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]]) {
    return interpolated.color;
}
