//
//  TodayView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct TodayView: View {
    var body: some View {
        VStack {
            Text("Today")
                .font(.largeTitle)
                .padding()
            
            Text("Today's view content")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TodayView()
}
