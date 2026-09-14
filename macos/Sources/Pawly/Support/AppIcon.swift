import SwiftUI

/// Finder icon lookup is deferred until a row appears, then reused across
/// selection changes and navigation. This cache never stores file sizes.
struct AppIcon: View {
    let path: String
    let size: CGFloat
    @State private var image: NSImage?
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 128
        return cache
    }()

    static func clearCache() { cache.removeAllObjects() }

    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable() }
            else { Image(systemName: "app").resizable().foregroundStyle(Palette.muted) }
        }.frame(width: size, height: size)
            .task(id: path) {
                if let cached = Self.cache.object(forKey: path as NSString) {
                    image = cached
                } else {
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    Self.cache.setObject(icon, forKey: path as NSString)
                    image = icon
                }
            }
    }
}
