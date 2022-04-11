import Metal
import MetalKit

class Renderer: NSObject {

    // reference to GPU hardware
    let device: MTLDevice

    // responsible for creating and organizing MTLCommandBuffers each frame (submitting to GPU)
    let commandQueue: MTLCommandQueue

    // sets the information for the draw (shader functions, color depth) and how to read vertex data
    let pipelineState: MTLRenderPipelineState

    let vertexBuffer: MTLBuffer

    init?(metalView: MTKView) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            fatalError("GPU not available")
        }
        self.device = device
        self.commandQueue = commandQueue
        metalView.device = device

        vertexBuffer = Renderer.generateMesh(device: device)

        do {
            pipelineState = try Renderer.buildRenderPipeline(
                device: device,
                pixelFormat: metalView.colorPixelFormat)
//                vertexDescriptor: MTKMetalVertexDescriptorFromModelIO(mdlMesh.vertexDescriptor)!)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private static func generateMesh(device: MTLDevice) -> MTLBuffer {
        let vertices = [
            Vertex(color: [1, 0, 0, 1], pos: [-1, -1]),
            Vertex(color: [0, 1, 0, 1], pos: [0, 1]),
            Vertex(color: [0, 0, 1, 1], pos: [1, -1])
        ]

        return device.makeBuffer(bytes: vertices,
                                 length: vertices.count * MemoryLayout<Vertex>.stride,
                                 options: [])!
    }

    private static func buildRenderPipeline(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat
//        vertexDescriptor: MTLVertexDescriptor
    ) throws -> MTLRenderPipelineState  {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        // add shaders to pipeline
        let library = device.makeDefaultLibrary()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")

//        pipelineDescriptor.vertexDescriptor = vertexDescriptor

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

        // enable our render pipeline
        renderEncoder.setRenderPipelineState(pipelineState)

        // drawing commands...
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

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
