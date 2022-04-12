import Metal
import MetalKit

import simd

struct Uniforms {
    var modelViewMatrix: float4x4
    var projectionMatrix: float4x4
}

class Renderer: NSObject {

    typealias float3 = SIMD3<Float>

    // reference to GPU hardware
    let device: MTLDevice

    // responsible for creating and organizing MTLCommandBuffers each frame (submitting to GPU)
    let commandQueue: MTLCommandQueue

    // sets the information for the draw (shader functions, color depth) and how to read vertex data
    let pipelineState: MTLRenderPipelineState

    // mesh
    let mesh: MTKMesh

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

        // load mesh to render
        do {
            mesh = try MTKMesh(mesh: Primitive.makeCube(device: device, size: 1.0),
                               device: device)
        } catch let error {
            fatalError(error.localizedDescription)
        }

        // build pipeline
        do {
            pipelineState = try Renderer.buildRenderPipeline(
                device: device,
                pixelFormat: metalView.colorPixelFormat,
                vertexDescriptor: MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)!)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private static func buildRenderPipeline(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        vertexDescriptor: MTLVertexDescriptor
    ) throws -> MTLRenderPipelineState  {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        // add shaders to pipeline
        let library = device.makeDefaultLibrary()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // set the output pixel format to match the pixel format of the metal kit view
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

        // compile the configured pipeline descriptor to a  pipeline state object
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
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
        let modelMatrix = float4x4(rotationAbout: float3(0, 1, 0), by: angle) * float4x4(scaleBy: 0.5)

        let viewMatrix = float4x4(translationBy: float3(0, 0, -2))
        let modelViewMatrix = viewMatrix * modelMatrix

        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3,
                                        aspectRatio: aspectRatio,
                                        nearZ: 0.1,
                                        farZ: 100)

        var uniforms = Uniforms(modelViewMatrix: modelViewMatrix, projectionMatrix: projectionMatrix)

        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)

        // enable our render pipeline
        renderEncoder.setRenderPipelineState(pipelineState)

        // drawing commands...
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
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
