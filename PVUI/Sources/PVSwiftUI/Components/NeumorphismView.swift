//
//  NeumorphismView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/22/24.
//


import SwiftUI

struct NeumorphismView: View {
    var body: some View {
        ZStack {
            color.BaseColor
                .edgesIgnoringSafeArea(.all)
            RoundedRectangle(cornerRadius: 10)
                .frame(width: 150, height: 150)
                .modifier(NeumorphismModifier())
        }
    }
}

struct NeumorphismModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(color.ForegroundColor)
            .shadow(color: color.LightShadowColor, radius: 2.9914936266447367, x: 2.7381441885964914, y: 2.7381441885964914)
            .shadow(color: color.DarkShadowColor, radius: 2.9914936266447367, x: -2.7381441885964914, y: -2.7381441885964914)
    }
}

class color {
    static let BaseColor: Color = Color(red: 0.16290172934532166, green: 0.16290172934532166, blue: 0.16290172934532166)
    static let LightShadowColor: Color = Color(red: 0.08447035402059555, green: 0.08447035402059555, blue: 0.08447035402059555)
    static let DarkShadowColor: Color = Color(red: 0.24133309721946716, green: 0.24133309721946716, blue: 0.24133309721946716)
    static let ForegroundColor: LinearGradient = LinearGradient(gradient: Gradient(colors: [Color(red: 0.16290172934532166, green: 0.16290172934532166, blue: 0.16290172934532166), Color(red: 0.16290172934532166, green: 0.16290172934532166, blue: 0.16290172934532166)]), startPoint: .topLeading, endPoint: .bottomTrailing)
}
