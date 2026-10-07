//
//  SwitcherColors.swift
//  Oriel
//

import SwiftUI

struct SwitcherColors {
    let colorScheme: ColorScheme
    let contrast: ColorSchemeContrast

    var panelBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.067, green: 0.086, blue: 0.106)
            : Color(red: 0.910, green: 0.925, blue: 0.945)
    }

    var border: Color {
        if contrast == .increased {
            return colorScheme == .dark
                ? Color(red: 0.376, green: 0.408, blue: 0.447)
                : Color(red: 0.659, green: 0.678, blue: 0.710)
        }
        return colorScheme == .dark
            ? Color(red: 0.204, green: 0.231, blue: 0.259)
            : Color(red: 0.847, green: 0.859, blue: 0.878)
    }

    var rowSurface: Color {
        colorScheme == .dark
            ? Color(red: 0.137, green: 0.157, blue: 0.176)
            : Color(red: 0.973, green: 0.976, blue: 0.984)
    }

    var keySurface: Color {
        colorScheme == .dark
            ? Color(red: 0.184, green: 0.196, blue: 0.208)
            : Color(red: 0.949, green: 0.953, blue: 0.961)
    }
}
