//
//  LaunchScreen.swift
//  EFB Agent
//
//  Launch screen view
//

import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        VStack {
            Image(systemName: "shield.checkered")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            Text("EFB Agent")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

