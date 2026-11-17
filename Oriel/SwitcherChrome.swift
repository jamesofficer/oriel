//
//  SwitcherChrome.swift
//  Oriel
//
//  The parts that the letter list and the search view both show.
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
