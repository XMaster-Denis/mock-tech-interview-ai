import SwiftUI

extension View {
    @ViewBuilder
    func helpIfAvailable(_ text: LocalizedStringKey) -> some View {
        #if os(macOS)
        self.help(text)
        #else
        self
        #endif
    }

    @ViewBuilder
    func helpIfAvailable(_ text: String) -> some View {
        #if os(macOS)
        self.help(text)
        #else
        self
        #endif
    }
}
