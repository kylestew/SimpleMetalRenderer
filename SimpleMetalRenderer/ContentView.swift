import SwiftUI

struct ContentView: View {
    var body: some View {
        MetalView()
            .ignoresSafeArea()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
