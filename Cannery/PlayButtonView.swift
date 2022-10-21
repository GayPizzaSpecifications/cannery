//
//  PlayButtonView.swift
//  macOS
//
//  Created by Alex Zenla on 5/1/22.
//

import Foundation
import SwiftUI

struct PlayButtonView: View {
    let action: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .background(.black)

            Image(systemName: "play.circle")
                .resizable()
                .foregroundColor(.accentColor)
                .frame(width: 400, height: 400, alignment: .center)
                .aspectRatio(contentMode: .fit)
                .onTapGesture {
                    action()
                }
        }
    }
}

struct PlayButtonView_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            PlayButtonView {}
                .frame(width: 500, height: 500)
        }
        .frame(minWidth: 600, minHeight: 600)
    }
}
