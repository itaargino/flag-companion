//
//  ContentView.swift
//  FlagCompanion
//
//  Created by Isaque da Silva Targino on 17/10/26.
//

import LogStore
import SwiftUI

struct ContentView: View {
    private let version = LogFormat.currentVersion

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Log format version \(version)")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
