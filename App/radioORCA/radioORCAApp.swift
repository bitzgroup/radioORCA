import SwiftUI

@main
struct RadioORCAApp: App {
    @StateObject private var viewModel = RadioViewModel()
    @State private var isFavoritesPresented = false

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, isFavoritesPresented: $isFavoritesPresented)
        }
        .windowResizability(.contentSize)
        .commands {
            RadioCommands(viewModel: viewModel, isFavoritesPresented: $isFavoritesPresented)
        }
    }
}
