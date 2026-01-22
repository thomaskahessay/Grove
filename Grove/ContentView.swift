import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                Text("Home")
            }

            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                Text("Progress")
            }

            Tab("Social", systemImage: "person.2.fill") {
                Text("Social")
            }

            Tab("Profile", systemImage: "person.fill") {
                Text("Profile")
            }
        }
        .tint(.groveSage)
    }
}

#Preview {
    ContentView()
}
