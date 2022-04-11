import MetalKit
import SwiftUI

struct MetalView: UIViewRepresentable {

    let view: MTKView
    let renderer: Renderer

    init() {
        self.view = MTKView.init(frame: .zero)
        guard let renderer = Renderer(metalView: view) else {
            fatalError("Cannot create GPU pipeline")
        }
        self.renderer = renderer
        self.view.delegate = renderer
        self.view.clearColor = MTLClearColor(red: 0.1, green: 0.57, blue: 0.25, alpha: 1)
    }

    func makeUIView(context: Context) -> MTKView {
        view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
    }
}
