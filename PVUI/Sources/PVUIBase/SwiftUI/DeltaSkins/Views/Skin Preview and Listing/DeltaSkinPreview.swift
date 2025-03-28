import SwiftUI

/// Preview component for a skin in the list
public struct DeltaSkinPreview: View {
    let skin: DeltaSkinProtocol
    let traits: DeltaSkinTraits

    public init(skin: DeltaSkinProtocol, traits: DeltaSkinTraits) {
        self.skin = skin
        self.traits = traits
    }

    public var body: some View {
        VStack {
            if skin.supports(traits) {
                DeltaSkinScreensView(
                    skin: skin,
                    traits: traits,
                    containerSize: CGSize(width: 200, height: 200)
                )
                .frame(width: 200, height: 200)
            } else {
                Text("Unsupported Configuration")
                    .foregroundStyle(.secondary)
            }

            Text(skin.name)
                .font(.headline)
        }
    }
}

//#Preview {
//    DeltaSkinPreview(
//        skin: try! DeltaSkin(fileURL: TestSkinResources.gbcSunriseURL),
//        traits: DeltaSkinTraits(
//            device: .iphone,
//            displayType: .standard,
//            orientation: .portrait
//        )
//    )
//}
