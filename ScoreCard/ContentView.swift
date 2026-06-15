import SwiftUI

struct ContentView: View {
    @StateObject private var vm = RoundViewModel()

    var body: some View {
        Group {
            if vm.round == nil {
                HomeView()
                    .environmentObject(vm)
            } else {
                ScorecardView()
                    .environmentObject(vm)
            }
        }
        .animation(.easeInOut, value: vm.round?.id)
    }
}

#Preview {
    ContentView()
}
