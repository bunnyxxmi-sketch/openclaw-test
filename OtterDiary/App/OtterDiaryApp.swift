import SwiftUI

@main
struct OtterDiaryApp: App {
    @StateObject private var viewModel = DiaryViewModel()
    @AppStorage(AppAccentColor.storageKey) private var accentColorRawValue: String = AppAccentColor.defaultOption.rawValue

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView(viewModel: viewModel)
            }
            .tint(AppAccentColor(rawValue: accentColorRawValue)?.color ?? AppAccentColor.defaultOption.color)
        }
    }
}
