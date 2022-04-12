import Metal
import MetalKit
import simd

struct VertexUniforms {
    var modelMatrix: float4x4
    var viewProjectionMatrix: float4x4
    var normalMatrix: float3x3
}

struct FragmentUniforms {
    var cameraWorldPosition = SIMD3<Float>(0, 0, 0)
    var ambientLightColor = SIMD3<Float>(0, 0, 0)
    var specularColor = SIMD3<Float>(1, 1, 1)
    var specularPower = Float(1)
    var light0 = Light()
    var light1 = Light()
    var light2 = Light()
}

class Renderer: NSObject {

    typealias float3 = SIMD3<Float>

    // reference to GPU hardware
    let device: MTLDevice

    // responsible for creating and organizing MTLCommandBuffers each frame (submitting to GPU)
    let commandQueue: MTLCommandQueue

    // sets the information for the draw (shader functions, color depth) and how to read vertex data
    let renderPipeline: MTLRenderPipelineState

    // specifies the depth and stencil config used in render pass
    let depthStencilState: MTLDepthStencilState

    // defines how a texture should be sampled
    let samplerState: MTLSamplerState

    // how we layout the memory for our vertex buffer when loading our mesh
    let vertexDescriptor: MDLVertexDescriptor

    var baseColorTexture: MTLTexture?

    var meshes: [MTKMesh] = []

    // animation
    var time: Float = 0
    let fps: Int

    init?(metalView: MTKView) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            fatalError("GPU not available")
        }
        self.device = device
        self.commandQueue = commandQueue
        metalView.device = device

        fps = metalView.preferredFramesPerSecond

        vertexDescriptor = Renderer.buildVertexDescriptor()
        depthStencilState = Renderer.buildDepthStencilState(device: device)
        renderPipeline = Renderer.buildRenderPipeline(device: device,
                                                      mtkView: metalView,
                                                      vertexDescriptor: vertexDescriptor)
        samplerState = Renderer.buildSamplerState(device: device)

        super.init()

        loadResources()
    }

    private static func buildVertexDescriptor() -> MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size * 3, bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size * 6, bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
        return vertexDescriptor
    }

    private static func buildSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }

    private static func buildDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
    }

    private static func buildRenderPipeline(
        device: MTLDevice,
        mtkView: MTKView,
        vertexDescriptor: MDLVertexDescriptor
    ) -> MTLRenderPipelineState  {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        // add shaders to pipeline
        let library = device.makeDefaultLibrary()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")

        let mtlVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

        // set the output pixel format to match the pixel format of the metal kit view
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        // compile the configured pipeline descriptor to a  pipeline state object
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state object: \(error)")
        }
    }

    private func loadResources() {
        let modelURL = Bundle.main.url(forResource: "rubber_toy", withExtension: "obj")!
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        do {
            (_, meshes) = try MTKMesh.newMeshes(asset: asset, device: device)
        } catch {
            fatalError("Could not extract meshes from Model I/O asset")
        }

        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [.generateMipmaps: true, .SRGB: true]
        baseColorTexture = try? textureLoader.newTexture(name: "tiles_baseColor",
                                                         scaleFactor: 1.0,
                                                         bundle: nil,
                                                         options: options)
    }

}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard
            // get an available command buffer
            let commandBuffer = commandQueue.makeCommandBuffer(),
            // get the default MTLRenderPassDescriptor from the MTKView (input/output configuration)
            let descriptor = view.currentRenderPassDescriptor,
            // compile renderPassDescriptor to an MTLRenderCommandEncoder
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        time += 1 / Float(fps)
        let angle = -time
        let modelMatrix = float4x4(rotationAbout: float3(0, 1, 0), by: angle)
                * float4x4(scaleBy: 0.5)
                * float4x4(translationBy: float3(0, -0.5, 0))

        let cameraWorldPosition = float3(0, 0, 2)
        let viewMatrix = float4x4(translationBy: -cameraWorldPosition)
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3,
                                        aspectRatio: aspectRatio,
                                        nearZ: 0.1,
                                        farZ: 100)
        let viewProjectionMatrix = projectionMatrix * viewMatrix

        var uniforms = VertexUniforms(modelMatrix: modelMatrix,
                                      viewProjectionMatrix: viewProjectionMatrix,
                                      normalMatrix: modelMatrix.normalMatrix)

        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)

        var material = Material()
        material.specularPower = 200
        material.specularColor = float3(0.8, 0.8, 0.8)
        let light0 = Light(worldPosition: float3(2, 2, 2), color: float3(1, 0, 0))
        let light1 = Light(worldPosition: float3(-2, 2, 2), color: float3(0, 1, 0))
        let light2 = Light(worldPosition: float3(0, -2, 2), color: float3(0, 0, 1))

        var fragmentUniforms = FragmentUniforms(cameraWorldPosition: cameraWorldPosition,
                                                ambientLightColor: float3(0.1, 0.1, 0.1),
                                                specularColor: material.specularColor,
                                                specularPower: material.specularPower,
                                                light0: light0,
                                                light1: light1,
                                                light2: light2)
        renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)

        // bind texture and sampler
        renderEncoder.setFragmentTexture(baseColorTexture, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        // enable our render pipeline (with depth stencil)
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setDepthStencilState(depthStencilState)

        // drawing commands...
        for mesh in meshes {
            renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
            for submesh in mesh.submeshes {
                renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer.buffer,
                                                    indexBufferOffset: submesh.indexBuffer.offset)
            }
        }

        // we're finished encoding drawing commands
        renderEncoder.endEncoding()

        // tell Metal to send the rendering result to the MTKView when rendering completes
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }

        // send the encoded command buffer to the GPU
        commandBuffer.commit()
    }
}
