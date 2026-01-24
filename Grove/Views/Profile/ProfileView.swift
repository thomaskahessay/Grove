import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

struct ProfileView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    private var selectedMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            appearanceMode = mode.rawValue
                        } label: {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundStyle(mode == selectedMode ? Color.groveSage : .secondary)
                                    .frame(width: 24)

                                Text(mode.rawValue)
                                    .foregroundStyle(Color.groveText)

                                Spacer()

                                if mode == selectedMode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.groveSage)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Appearance")
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
}
