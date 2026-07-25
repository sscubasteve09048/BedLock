//
//  ConfettiView.swift
//  BedLock
//
//  A lightweight celebration overlay: a burst of colored shapes that fall
//  and fade out. Triggered on a perfect day, a new badge, or a level-up.
//  Pure SwiftUI, no external dependencies.
//
import SwiftUI

struct ConfettiView: View {
    /// Flips to true to trigger a burst; the view resets itself afterward.
    @Binding var isActive: Bool

    private let pieceCount = 40
    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    @State private var pieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 0.4)
                    .rotationEffect(.degrees(piece.rotation))
                    .position(x: piece.x, y: piece.y)
                    .opacity(piece.opacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                burst()
            }
        }
    }

    private func burst() {
        let screenWidth = UIScreen.main.bounds.width
        pieces = (0..<pieceCount).map { _ in
            ConfettiPiece(
                x: Double.random(in: 0...screenWidth),
                y: -20,
                size: Double.random(in: 6...12),
                color: colors.randomElement() ?? .yellow,
                rotation: Double.random(in: 0...360),
                opacity: 1
            )
        }

        withAnimation(.easeIn(duration: 1.6)) {
            for index in pieces.indices {
                pieces[index].y = Double.random(in: 400...900)
                pieces[index].rotation += Double.random(in: 180...720)
            }
        }
        withAnimation(.easeIn(duration: 1.6).delay(0.6)) {
            for index in pieces.indices {
                pieces[index].opacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            pieces = []
            isActive = false
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    let size: Double
    let color: Color
    var rotation: Double
    var opacity: Double
}

#Preview {
    @Previewable @State var active = false
    return VStack {
        Button("Celebrate") { active = true }
    }
    .overlay(ConfettiView(isActive: $active))
}
