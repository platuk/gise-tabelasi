import GameCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var path: [Int] = []
    @State private var showingHelp = false

    var body: some View {
        NavigationStack(path: $path) {
            LevelListView()
                .navigationTitle(Text("app.title"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingHelp = true
                        } label: {
                            Label("help.title", systemImage: "questionmark.circle")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Picker("language.picker", selection: languageBinding) {
                            Text(verbatim: "TR").tag("tr")
                            Text(verbatim: "EN").tag("en")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 110)
                    }
                }
                .navigationDestination(for: Int.self) { id in
                    if let level = model.pack?.level(withID: id) {
                        LevelView(level: level, path: $path)
                            .id("\(model.language)-\(id)")
                    }
                }
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .tint(Theme.marquee)
        .preferredColorScheme(.light)
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { model.language },
            set: { newValue in
                path = []
                model.setLanguage(newValue)
            }
        )
    }
}
