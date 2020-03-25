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

    enum HoverMode          : Float {
        case None, NodeUI, NodeUIMouseLocked
    }
    
    var hoverMode               : HoverMode = .None
    
    var hoverUIItem             : NodeUI? = nil
    var hoverUITitle            : NodeUI? = nil
    
    var c1Node                  : Node? = nil
    var c2Node                  : Node? = nil
    
    var tabButton               : MMTabButtonWidget!
    
    var pipeline                : Pipeline
    
    var widthVar                : NodeUINumber!
    var heightVar               : NodeUINumber!

    init(_ view: MMView) {
        
        if globalApp!.currentSceneMode == .ThreeD {
            pipeline = Pipeline3D(view)
        } else {
            pipeline = Pipeline2D(view)
        }
        
        super.init(view, title: "Export Dialog", cancelText: "Cancel", okText: "Export")
        instantClose = false
        
        rect.width = 600
        rect.height = 300
        
        tabButton = MMTabButtonWidget(view)
        tabButton.addTab("Image")
        tabButton.addTab("Video")
        
        c1Node = Node()
        c1Node?.rect.x = 60
        c1Node?.rect.y = 120
        
        c2Node = Node()
        c2Node?.rect.x = 380
        c2Node?.rect.y = 120
        
        hoverUIItem = nil
        hoverUITitle = nil
        hoverMode = .None
        
        widthVar = NodeUINumber(c1Node!, variable: "width", title: "Width", range: SIMD2<Float>(20, 4096), int: true, value: 800)
        c1Node!.uiItems.append(widthVar)
        
        heightVar = NodeUINumber(c1Node!, variable: "height", title: "Height", range: SIMD2<Float>(20, 4096), int: true, value: 600)
        c1Node!.uiItems.append(heightVar)
        
        let reflectionVar = NodeUINumber(c2Node!, variable: "reflections", title: "Reflections", range: SIMD2<Float>(1, 10), int: true, value: 2)
        c2Node!.uiItems.append(reflectionVar)
        
        let sampleVar = NodeUINumber(c2Node!, variable: "samples", title: "AA Samples", range: SIMD2<Float>(1, 50), int: true, value: 4)
        c2Node!.uiItems.append(sampleVar)
        
        c1Node?.setupUI(mmView: mmView)
        c2Node?.setupUI(mmView: mmView)
        
        widgets.append(tabButton)
        widgets.append(self)
        
        pipeline.build(scene: globalApp!.project.selected!)
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
        
        let settings = PipelineRenderSettings()
        settings.cbFinished = { (texture) in
            
            print("finished")
            super.ok()
            
            if let image = self.makeCGIImage(texture: texture) {
                globalApp!.mmFile.saveImage(image: image)
                self._ok()
            }
            
            self.okButton.removeState(.Checked)
        }
        
        pipeline.render(widthVar.value, heightVar.value, settings: settings)
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if hoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseMoved(event)
            return
        }
        
        // Disengage hover types for the ui items
        if hoverUIItem != nil {
            hoverUIItem!.mouseLeave()
        }
        
        if hoverUITitle != nil {
            hoverUITitle?.titleHover = false
            hoverUITitle = nil
            mmView.update()
        }
        
        let oldHoverMode = hoverMode
        
        hoverUIItem = nil
        hoverUITitle = nil
        hoverMode = .None
                
        func checkNodeUI(_ node: Node)
        {
            // --- Look for NodeUI item under the mouse, master has no UI
            let uiItemX = rect.x + node.rect.x
            var uiItemY = rect.y + node.rect.y
            let uiRect = MMRect()
            
            for uiItem in node.uiItems {
                
                if uiItem.supportsTitleHover {
                    uiRect.x = uiItem.titleLabel!.rect.x - 2
                    uiRect.y = uiItem.titleLabel!.rect.y - 2
                    uiRect.width = uiItem.titleLabel!.rect.width + 4
                    uiRect.height = uiItem.titleLabel!.rect.height + 6
                    
                    if uiRect.contains(event.x, event.y) {
                        uiItem.titleHover = true
                        hoverUITitle = uiItem
                        mmView.update()
                        return
                    }
                }
                
                uiRect.x = uiItemX
                uiRect.y = uiItemY
                uiRect.width = uiItem.rect.width
                uiRect.height = uiItem.rect.height
                
                if uiRect.contains(event.x, event.y) {
                    
                    hoverUIItem = uiItem
                    hoverMode = .NodeUI
                    hoverUIItem!.mouseMoved(event)
                    mmView.update()
                    return
                }
                uiItemY += uiItem.rect.height
            }
        }
        
        if let node = c1Node {
            checkNodeUI(node)
        }
        
        if let node = c2Node, hoverMode == .None {
            checkNodeUI(node)
        }
        
        if oldHoverMode != hoverMode {
            mmView.update()
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        #endif

        #if os(OSX)
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
        }
        #endif
        
        if hoverMode == .NodeUI {
            hoverUIItem!.mouseDown(event)
            hoverMode = .NodeUIMouseLocked
            //globalApp?.mmView.mouseTrackWidget = self
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if hoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseUp(event)
        }
        
        #if os(iOS)
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
        }
        #endif
        
        hoverMode = .None
        mmView.mouseTrackWidget = nil
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0) {
        super.draw(xOffset: xOffset, yOffset: yOffset)

        tabButton.rect.y = rect.y + 40
        tabButton.rect.x = rect.x + (rect.width - tabButton.rect.width) / 2
        tabButton.draw()
        
        if let node = c1Node {
            
            let uiItemX : Float = rect.x + node.rect.x
            var uiItemY : Float = rect.y + node.rect.y
            
            for uiItem in node.uiItems {
                uiItem.rect.x = uiItemX
                uiItem.rect.y = uiItemY
                uiItemY += uiItem.rect.height
            }
            
            for uiItem in node.uiItems {
                uiItem.draw(mmView: mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: 1)
            }
        }
        
        if let node = c2Node {
                        
            let uiItemX : Float = rect.x + node.rect.x
            var uiItemY : Float = rect.y + node.rect.y
            
            for uiItem in node.uiItems {
                uiItem.rect.x = uiItemX
                uiItem.rect.y = uiItemY
                uiItemY += uiItem.rect.height
            }
            
            for uiItem in node.uiItems {
                uiItem.draw(mmView: mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: 1)
            }
        }
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
