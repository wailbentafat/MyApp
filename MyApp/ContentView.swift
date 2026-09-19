import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "swift")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text("Hello, World!")
                .font(.title)
                .bold()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
