import SwiftUI

@main
struct OtterDiaryApp: App {
    @StateObject private var viewModel = DiaryViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView(viewModel: viewModel)
            }
        }
    }
}
