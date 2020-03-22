//
//  ExportDialog.swift
//  Render-Z
//
//  Created by Markus Moenig on 21/3/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit
import CloudKit

class ExportDialog: MMDialog {

    init(_ view: MMView) {
        super.init(view, title: "Choose Library Item", cancelText: "Cancel", okText: "Export")
        
        rect.width = 800
        rect.height = 600

        widgets.append(self)
    }
    
    func show()
    {
        mmView.showDialog(self)
    }
    
    override func cancel() {
        super.cancel()
        cancelButton!.removeState(.Checked)
    }
    
    override func ok() {
        super.ok()
        
        if let texture = globalApp!.currentPipeline!.finalTexture {
            if let image = makeCGIImage(texture: texture) {
                globalApp!.mmFile.saveImage(image: image)
            }
        }
        
        okButton.removeState(.Checked)
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0) {
        super.draw(xOffset: xOffset, yOffset: yOffset)

    }
    
    func makeCGIImage(texture: MTLTexture) -> CGImage?
    {
        if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .bgra8Unorm) {
        
            globalApp!.currentPipeline!.codeBuilder.renderCopyAndSwap(convertTo, texture, syncronize: true)
            
            let width = convertTo.width
            let height = convertTo.height
            let pixelByteCount = 4 * MemoryLayout<UInt8>.size
            let imageBytesPerRow = width * pixelByteCount
            let imageByteCount = imageBytesPerRow * height
            
            let imageBytes = UnsafeMutableRawPointer.allocate(byteCount: imageByteCount, alignment: pixelByteCount)
            defer {
                imageBytes.deallocate()
            }

            convertTo.getBytes(imageBytes,
                             bytesPerRow: imageBytesPerRow,
                             from: MTLRegionMake2D(0, 0, width, height),
                             mipmapLevel: 0)
            guard let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB) else { return nil }
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            guard let bitmapContext = CGContext(data: nil,
                                                width: width,
                                                height: height,
                                                bitsPerComponent: 8,
                                                bytesPerRow: imageBytesPerRow,
                                                space: colorSpace,
                                                bitmapInfo: bitmapInfo) else { return nil }
            bitmapContext.data?.copyMemory(from: imageBytes, byteCount: imageByteCount)
            let image = bitmapContext.makeImage()
            return image
        }
        return nil
    }
}
