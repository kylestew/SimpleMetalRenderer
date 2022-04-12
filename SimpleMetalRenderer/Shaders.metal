#include <metal_stdlib>
using namespace metal;

#include "ShaderDefinitions.h"

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 eyeNormal;
    float4 eyePosition;
    float2 texCoords;
};

struct Uniforms {
    float4x4 modelViewMatrix;
    float4x4 projectionMatrix;
};

vertex VertexOut vertexShader(VertexIn vertexIn [[stage_in]],
                           constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vertexOut;
    vertexOut.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(vertexIn.position, 1);

//    return vertexIn[0].position;
//    Vertex in = vertexArray[vid];
//    VertexOut out;
//    out.pos = float4(in.pos.x, in.pos.y, 0, 1);
//    out.color = in.color;
//    return out;
//    return vertexIn.position;

    return vertexOut;
}

//fragment float4 fragmentShader(VertexOut interpolated [[stage_in]]) {
fragment float4 fragmentShader(VertexOut fragmentIn [[stage_in]]) {
    return float4(1, 0, 1, 1);
}
