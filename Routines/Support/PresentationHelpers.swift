//
//  PresentationHelpers.swift
//  Routines
//

import SwiftUI

extension View {
    /// Presents `content` over the whole screen on platforms that have a
    /// full-screen presentation, and as a sheet on the Mac, which doesn't.
    func fullScreenPresentation<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(macOS)
        sheet(item: item, content: content)
        #else
        fullScreenCover(item: item, content: content)
        #endif
    }
}
