import Metal
import simd
import MetalKit

struct Light {
    var worldPosition = SIMD3<Float>(0, 0, 0)
    var color = SIMD3<Float>(0, 0, 0)
}

struct Material {
    var specularColor = SIMD3<Float>(1, 1, 1)
    var specularPower = Float(1)
    var baseColorTexture: MTLTexture?
}

class Node {
    let name: String
    weak var parent: Node?
    var children = [Node]()
    var modelMatrix = matrix_identity_float4x4
    var mesh: MTKMesh?
    var material = Material()

    init(named: String) {
        self.name = named
    }
}

class SceneGraph {
    var rootNode = Node(named: "Root")
    var ambientLightColor = SIMD3<Float>(0, 0, 0)
    var lights = [Light]()
}

