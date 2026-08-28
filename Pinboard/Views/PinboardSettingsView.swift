//
//  PinboardSettingsView.swift
//  Pinboard
//

import SwiftUI

struct PinboardSettingsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Settings Yet",
            systemImage: "gearshape",
            description: Text("Pinboard will place future preferences here.")
        )
        .frame(width: 460, height: 220)
    }
}
