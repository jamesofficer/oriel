//
//  SwitcherChrome.swift
//  Oriel
//
//  The parts that two or more of the panel views show.
//

import SwiftUI

struct EscKeyCap: View {
    let colors: SwitcherColors

    var body: some View {
        Text("Esc")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .padding(.horizontal, 7)
            .frame(height: 28)
            .background(colors.keySurface, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(colors.border, lineWidth: 1)
            }
    }
}

struct LetterKeyCap: View {
    let letter: String
    var isDimmed = false
    let colors: SwitcherColors

    var body: some View {
        Text(letter)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(isDimmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .frame(width: 32, height: 32)
            .background(colors.keySurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(colors.border, lineWidth: 1)
            }
    }
}

extension View {
    func switcherPanelChrome(colors: SwitcherColors, opacity: Double) -> some View {
        background(colors.panelBackground.opacity(opacity), in: RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(colors.border, lineWidth: colors.contrast == .increased ? 1.5 : 1)
            }
    }
}
