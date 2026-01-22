#if os(macOS)
import SwiftUI

extension View {
    @ViewBuilder
    func helpIfAvailable(_ text: LocalizedStringKey) -> some View {
        self.help(text)
    }

    @ViewBuilder
    func helpIfAvailable(_ text: String) -> some View {
        self.help(text)
    }
}
#endif
