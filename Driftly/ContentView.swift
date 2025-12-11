//
//  ContentView.swift
//  Driftly
//
//  Created by Don Noel on 12/11/25.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: DriftlyDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(DriftlyDocument()))
}
