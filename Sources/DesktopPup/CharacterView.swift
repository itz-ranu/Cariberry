import SwiftUI

/// Picks which species' art to draw. Every call site that used to say `DogView(pose:)`
/// says `CharacterView(species:pose:)` instead: the pose/emotion/behaviour system
/// doesn't know or care which species is on screen, only this switch does.
struct CharacterView: View {
    var species: Species
    var pose: DogPose

    var body: some View {
        switch species {
        case .dog: DogView(pose: pose)
        case .cat: CatView(pose: pose)
        }
    }
}
