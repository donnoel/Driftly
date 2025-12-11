//
//  DriftlyApp.swift
//  Driftly
//
//  Created by Don Noel on 12/11/25.
//

import SwiftUI

@main
struct DriftlyApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: DriftlyDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
