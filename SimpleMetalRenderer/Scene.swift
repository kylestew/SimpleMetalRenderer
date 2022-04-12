import Foundation
import simd
import Metal

struct Light {
    var worldPosition = SIMD3<Float>(0, 0, 0)
    var color = SIMD3<Float>(0, 0, 0)
}

struct Material {
    var specularColor = SIMD3<Float>(1, 1, 1)
    var specularPower = Float(1)
    var baseColorTexture: MTLTexture?
};
