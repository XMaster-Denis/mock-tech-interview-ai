#if os(iOS)
import SwiftUI

extension View {
    @ViewBuilder
    func helpIfAvailable(_ text: LocalizedStringKey) -> some View {
        self
    }

    @ViewBuilder
    func helpIfAvailable(_ text: String) -> some View {
        self
    }
}
#endif
