import SwiftUI

#if os(iOS)
struct AudioLevelView: View {
    let audioLevel: Float
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                Rectangle()
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .cornerRadius(2)
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .frame(height: 20)
        .padding(.horizontal, 8)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = audioLevel * 20
        let barIndex = Float(index)
        return barIndex < normalizedLevel ? CGFloat(20) : CGFloat(4)
    }

    private func barColor(for index: Int) -> Color {
        let normalizedLevel = audioLevel * 20
        let barIndex = Float(index)

        if !isRecording {
            return Color.gray.opacity(0.3)
        } else if barIndex >= normalizedLevel {
            return Color.gray.opacity(0.5)
        } else {
            let intensity = Float(index) / 20.0
            if intensity < 0.5 {
                return Color.green
            } else if intensity < 0.8 {
                return Color.orange
            } else {
                return Color.red
            }
        }
    }
}
#endif
