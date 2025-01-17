//
//  View.swift
//  Cyte
//
//  Created by Shaun Narayan on 9/04/23.
//

import Foundation
import AVKit
import SwiftUI
import Vision

extension Date {
    var dayOfYear: Int {
        return Calendar.current.ordinality(of: .day, in: .year, for: self)!
    }
}

struct StackedShape: Shape {
    let shapes: [AnyShape]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        for shape in shapes {
            path.addPath(shape.path(in: rect))
        }
        return path
    }
}

extension View {
    func cutout<S: Shape>(_ shapes: [S]) -> some View {
        let anyShapes = shapes.map(AnyShape.init)
        return self.clipShape(StackedShape(shapes: anyShapes), style: FillStyle(eoFill: true))
    }
}

extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(minX)
        hasher.combine(minY)
        hasher.combine(maxX)
        hasher.combine(maxY)
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}

func secondsToReadable(seconds: Double) -> String {
    var (hr,  minf) = modf(seconds / 3600)
    let (min, secf) = modf(60 * minf)
    let days = Int(hr / 24)
    hr -= (Double(days) * 24.0)
    var res = ""
    if days > 0 {
        res += "\(days) days, "
    }
    if hr > 0 {
        res += "\(Int(hr)) hours, "
    }
    if min > 0 {
        res += "\(Int(min)) minutes, "
    }
    res += "\(Int(60 * secf)) seconds"
    return res
}

func procVisionResult(request: VNRequest, error: Error?, minConfidence: Float = 0.45) -> [(String, CGRect)] {
    guard let observations =
            request.results as? [VNRecognizedTextObservation] else {
        return []
    }
    let recognizedStringsAndRects: [(String, CGRect)] = observations.compactMap { observation in
        // Find the top observation.
        guard let candidate = observation.topCandidates(1).first else { return ("", .zero) }
        if observation.confidence < minConfidence { return ("", .zero) }
        
        // Find the bounding-box observation for the string range.
        let stringRange = candidate.string.startIndex..<candidate.string.endIndex
        let boxObservation = try? candidate.boundingBox(for: stringRange)
        
        // Get the normalized CGRect value.
        let boundingBox = boxObservation?.boundingBox ?? .zero
        
        // Convert the rectangle from normalized coordinates to image coordinates.
        return (candidate.string, boundingBox)
    }
    return recognizedStringsAndRects
}

#if os(macOS)
extension NSImage {
    ///
    /// This is used as a background color for contexts related to an app, like chart axis etc
    ///
    var averageColor: Color? {
        if self.tiffRepresentation == nil { return nil }
        guard let inputImage = CIImage(data: self.tiffRepresentation!) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return Color(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, opacity: Double(bitmap[3]) / 255)
    }
}
typealias UIImage = NSImage

extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)

        return cgImage(forProposedRect: &proposedRect,
                       context: nil,
                       hints: nil)
    }

    convenience init?(named name: String) {
        self.init(named: Name(name))
    }
}
#else
extension UIImage {
    ///
    /// This is used as a background color for contexts related to an app, like chart axis, etc
    ///
    var averageColor: Color? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return Color(red: Double(bitmap[0]) / 255, green: Double(bitmap[1]) / 255, blue: Double(bitmap[2]) / 255, opacity: Double(bitmap[3]) / 255)
    }
}
struct AppIcon {
    let image: UIImage?
    
    init(bundleID: String) {
        self.image = AppIconFetcher.icon(forBundleID: bundleID)
    }
}
#endif

class BundleCache: ObservableObject {
    @Published var bundleImageCache: [String: UIImage] = [:]
    @Published var bundleColorCache : Dictionary<String, Color> = ["": Color.gray]
    
    func getColor(bundleID: String) -> Color? {
        if bundleColorCache[bundleID] != nil {
            return bundleColorCache[bundleID]!
        }
        return Color.gray
    }
    
    func setCache(bundleID: String, image: UIImage) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                self.bundleImageCache[bundleID] = image
                self.bundleColorCache[bundleID] = self.bundleImageCache[bundleID]!.averageColor
            }
        }
    }
    
    func getIcon(bundleID: String) -> UIImage {
        if bundleImageCache[bundleID] != nil {
            return bundleImageCache[bundleID]!
        }
#if os(macOS)
        guard let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path(percentEncoded: false)
        else {
            URLSession.shared.dataTask(with: FavIcon(bundleID)[.m]) { (data, response, error) in
                guard let imageData = data else { return }
                self.setCache(bundleID: bundleID, image: UIImage(data:imageData)!)
            }.resume()
            return UIImage()
        }
        
        guard FileManager.default.fileExists(atPath: path)
        else { return UIImage() }
        
        let icon = NSWorkspace.shared.icon(forFile: path)
#else
        let icon = AppIcon(bundleID: bundleID).image!
#endif
        Task {
            setCache(bundleID: bundleID, image: icon)
        }
        return icon
    }
}
