//
//  ExportDialog.swift
//  Render-Z
//
//  Created by Markus Moenig on 21/3/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit
import CloudKit

import AVFoundation
import Photos

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
    
    var fpsVar                  : NodeUINumber!
    var maxFramesVar            : NodeUINumber!

    var reflectionVar           : NodeUINumber!
    var sampleVar               : NodeUINumber!
    var statusVar               : NodeUIText!
    
    var settings                = PipelineRenderSettings()
    
    var exportInProgress        = false
    
    var videoSettings           : RenderSettings?
    var imageAnimator           : ImageAnimator?
    
    var currentFrame            : Int32 = 0
    var maxFrames               : Int32 = 10
    
    var timeline                : MMTimeline

    init(_ view: MMView) {
        
        if globalApp!.currentSceneMode == .ThreeD {
            pipeline = Pipeline3D(view)
        } else {
            pipeline = Pipeline2D(view)
        }
        timeline = globalApp!.artistEditor.timeline
        super.init(view, title: "Export", cancelText: "Cancel", okText: "Export")
        instantClose = false
        
        rect.width = 500
        rect.height = 360
        
        tabButton = MMTabButtonWidget(view)
        tabButton.addTab("Image")
        tabButton.addTab("Video")
        tabButton.clicked = { (event) in
            self.fpsVar.isDisabled = self.tabButton.index == 0
            self.maxFramesVar.isDisabled = self.tabButton.index == 0
        }
        
        c1Node = Node()
        c1Node?.rect.x = 60
        c1Node?.rect.y = 120
        
        c2Node = Node()
        c2Node?.rect.x = 280
        c2Node?.rect.y = 120
        
        hoverUIItem = nil
        hoverUITitle = nil
        hoverMode = .None
        
        widthVar = NodeUINumber(c1Node!, variable: "width", title: "Width", range: SIMD2<Float>(20, 4096), int: true, value: 800)
        c1Node!.uiItems.append(widthVar)
        
        heightVar = NodeUINumber(c1Node!, variable: "height", title: "Height", range: SIMD2<Float>(20, 4096), int: true, value: 600)
        c1Node!.uiItems.append(heightVar)
        
        fpsVar = NodeUINumber(c1Node!, variable: "fps", title: "FPS", range: SIMD2<Float>(1, 30), int: true, value: 10)
        fpsVar.isDisabled = true
        c1Node!.uiItems.append(fpsVar)
        
        statusVar = NodeUIText(c1Node!, variable: "status", title: "Status", value: "Ready")
        c1Node!.uiItems.append(statusVar)
        
        var reflections : Int = 2
        var samples     : Int = 4
        
        if let renderComp = getComponent(name: "Renderer") {
            reflections = getComponentPropertyInt(component: renderComp, name: "reflections", defaultValue: 2)
            samples = getComponentPropertyInt(component: renderComp, name: "antiAliasing", defaultValue: 4)
        }
        
        reflectionVar = NodeUINumber(c2Node!, variable: "reflections", title: "Reflections", range: SIMD2<Float>(1, 10), int: true, value: Float(reflections))
        c2Node!.uiItems.append(reflectionVar)
        
        sampleVar = NodeUINumber(c2Node!, variable: "samples", title: "AA Samples", range: SIMD2<Float>(1, 50), int: true, value: Float(samples))
        c2Node!.uiItems.append(sampleVar)
        
        maxFramesVar = NodeUINumber(c2Node!, variable: "maxFrames", title: "Max. Frames", range: SIMD2<Float>(1, 10000), int: true, value: 100)
        maxFramesVar.isDisabled = true
        c2Node!.uiItems.append(maxFramesVar)
        
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
        if exportInProgress {
            pipeline.cancel()
            
            if tabButton.index == 1 {
                self.finishVideoEncoding()
            }
            
            self.exportInProgress = false
            self.okButton.isDisabled = false
            self.okButton.removeState(.Checked)
            self.cancelButton!.removeState(.Checked)
            
            self.statusVar.value = "Finished"
            self.mmView.update()
        } else {
            cancelButton!.removeState(.Checked)
            _cancel()
        }
    }
    
    override func ok() {
        
        self.okButton.isDisabled = true
        settings.reflections = Int(reflectionVar.value)
        settings.samples = Int(sampleVar.value)
        
        if tabButton.index == 0 {
            settings.cbProgress = { (current, of) in
                self.statusVar.value = "\(current) of \(of) Samples"
                self.mmView.update()
            }
            
            settings.cbFinished = { (texture) in
                
                self.statusVar.value = "Finished"
                self.mmView.update()

                super.ok()
                if let image = self.makeCGIImage(texture: texture, forImage: true) {
                    globalApp!.mmFile.saveImage(image: image)
                    self._ok()
                }
                
                self.exportInProgress = false
                self.okButton.isDisabled = false
                self.okButton.removeState(.Checked)
            }
            
            exportInProgress = true
            pipeline.render(widthVar.value, heightVar.value, settings: settings)
        } else {
            
            #if os(OSX)
            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = false
            savePanel.title = "Select Image"
            savePanel.directoryURL =  globalApp!.mmFile.containerUrl
            savePanel.showsHiddenFiles = false
            savePanel.allowedFileTypes = ["mp4"]
            
            savePanel.beginSheetModal(for: self.mmView.window!) { (result) in
                if result == .OK {
                    self.startVideoEncoding(url: savePanel.url!)
                }
            }
            #else
            let fileManager = FileManager.default
            if let tmpDirURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
                let url = tmpDirURL.appendingPathComponent("render").appendingPathExtension("mp4")
                self.startVideoEncoding(url: url)
            }
            #endif
        }
    }
    
    func startVideoEncoding(url: URL)
    {
        videoSettings = RenderSettings()
        videoSettings!.size.width = CGFloat(widthVar.value)
        videoSettings!.size.height = CGFloat(heightVar.value)
        videoSettings!.fps = Int32(fpsVar.value)

        videoSettings!.outputURL = url
        
        imageAnimator = ImageAnimator(renderSettings: videoSettings!)
        currentFrame = 0
        maxFrames = Int32(maxFramesVar.value)
        
        timeline.currentFrame = 0
        
        ImageAnimator.removeFileAtURL(fileURL: videoSettings!.outputURL)
        self.imageAnimator!.videoWriter.start()
        
        settings.cbFinished = { (texture) in
                            
            let frameDuration = CMTimeMake(value: Int64(ImageAnimator.kTimescale / self.videoSettings!.fps), timescale: ImageAnimator.kTimescale)
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: self.currentFrame)
            self.currentFrame += 1
            
            self.statusVar.value = "\(self.currentFrame) of \(self.maxFrames) Frames"
            self.mmView.update()

            #if os(OSX)
            let imageMode = false
            #else
            let imageMode = true
            #endif
            
            if let image = self.makeCGIImage(texture: texture, forImage: imageMode) {
                let _ = self.imageAnimator!.videoWriter.addImage(image: image, withPresentationTime: presentationTime)
            }

            if self.currentFrame < self.maxFrames {
                self.timeline.currentFrame += Int(30/self.videoSettings!.fps)
                //print(self.timeline.currentFrame)
                self.pipeline.render(self.widthVar.value, self.heightVar.value, settings: self.settings)
            } else {
                self.finishVideoEncoding()
                self.exportInProgress = false
                self.okButton.isDisabled = false
                self.okButton.removeState(.Checked)
                self.statusVar.value = "Finished"
                self.mmView.update()
            }
        }
        settings.cbProgress = nil
        
        exportInProgress = true
        pipeline.render(widthVar.value, heightVar.value, settings: settings)
    }
    
    func finishVideoEncoding()
    {
        imageAnimator!.videoWriter.videoWriterInput.markAsFinished()
        imageAnimator!.videoWriter.videoWriter.finishWriting(completionHandler: {() in
            #if os(iOS)
            ImageAnimator.saveToLibrary(videoURL: self.videoSettings!.outputURL)
            #endif
        } )
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
    
    func makeCGIImage(texture: MTLTexture, forImage: Bool) -> CGImage?
    {
        if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .bgra8Unorm) {
        
            if forImage {
                globalApp!.currentPipeline!.codeBuilder.renderCopyAndSwap(convertTo, texture, syncronize: true)
            } else {
                globalApp!.currentPipeline!.codeBuilder.renderCopy(convertTo, texture, syncronize: true)
            }
            
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

struct RenderSettings {

    var size : CGSize = .zero
    var fps: Int32 = 6   // frames per second
    var avCodecKey = AVVideoCodecType.h264
    var videoFilename = "render"
    var videoFilenameExt = "mp4"

    var outputURL : URL!
}

class ImageAnimator {

    // Apple suggests a timescale of 600 because it's a multiple of standard video rates 24, 25, 30, 60 fps etc.
    static let kTimescale: Int32 = 600

    let settings: RenderSettings
    let videoWriter: VideoWriter
    var images: [CGImage]!

    var frameNum = 0

    class func saveToLibrary(videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                if !success {
                    //print("Could not save video to photo library:", error)
                }
            }
        }
    }

    class func removeFileAtURL(fileURL: URL) {
        do {
            try FileManager.default.removeItem(atPath: fileURL.path)
        }
        catch _ as NSError {
            // Assume file doesn't exist.
        }
    }

    init(renderSettings: RenderSettings) {
        settings = renderSettings
        videoWriter = VideoWriter(renderSettings: settings)
//        images = loadImages()
    }

    func render(appendPixelBuffers: ((VideoWriter)->Bool)?, completion: (()->Void)?) {

        // The VideoWriter will fail if a file exists at the URL, so clear it out first.
        ImageAnimator.removeFileAtURL(fileURL: settings.outputURL)

        videoWriter.start()
        videoWriter.render(appendPixelBuffers: appendPixelBuffers) {
            ImageAnimator.saveToLibrary(videoURL: self.settings.outputURL)
            completion?()
        }
    }
}

class VideoWriter {

    let renderSettings: RenderSettings

    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!

    var isReadyForData: Bool {
        return videoWriterInput?.isReadyForMoreMediaData ?? false
    }

    init(renderSettings: RenderSettings) {
        self.renderSettings = renderSettings
    }

    func start() {

        let avOutputSettings: [String: Any] = [
            AVVideoCodecKey: renderSettings.avCodecKey,
            AVVideoWidthKey: NSNumber(value: Float(renderSettings.size.width)),
            AVVideoHeightKey: NSNumber(value: Float(renderSettings.size.height))
        ]

        func createPixelBufferAdaptor() {
            let sourcePixelBufferAttributesDictionary = [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: NSNumber(value: Float(renderSettings.size.width)),
                kCVPixelBufferHeightKey as String: NSNumber(value: Float(renderSettings.size.height))
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
                                                                      sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        }

        func createAssetWriter(outputURL: URL) -> AVAssetWriter {
            guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4) else {
                fatalError("AVAssetWriter() failed")
            }

            guard assetWriter.canApply(outputSettings: avOutputSettings, forMediaType: AVMediaType.video) else {
                fatalError("canApplyOutputSettings() failed")
            }

            return assetWriter
        }

        videoWriter = createAssetWriter(outputURL: renderSettings.outputURL)
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)

        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        else {
            fatalError("canAddInput() returned false")
        }

        // The pixel buffer adaptor must be created before we start writing.
        createPixelBufferAdaptor()

        if videoWriter.startWriting() == false {
            fatalError("startWriting() failed")
        }

        videoWriter.startSession(atSourceTime: CMTime.zero)

        precondition(pixelBufferAdaptor.pixelBufferPool != nil, "nil pixelBufferPool")
    }

    func render(appendPixelBuffers: ((VideoWriter)->Bool)?, completion: (()->Void)?) {

        precondition(videoWriter != nil, "Call start() to initialze the writer")

        let queue = DispatchQueue(label: "mediaInputQueue")
        videoWriterInput.requestMediaDataWhenReady(on: queue) {
            let isFinished = appendPixelBuffers?(self) ?? false
            if isFinished {
                self.videoWriterInput.markAsFinished()
                self.videoWriter.finishWriting() {
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
            }
            else {
                // Fall through. The closure will be called again when the writer is ready.
            }
        }
    }

    func addImage(image: CGImage, withPresentationTime presentationTime: CMTime) -> Bool {

        precondition(pixelBufferAdaptor != nil, "Call start() to initialze the writer")

        //let pixelBuffer = VideoWriter.pixelBufferFromImage(image: image, pixelBufferPool: pixelBufferAdaptor.pixelBufferPool!, size: renderSettings.size)
        
        //let pixelBuffer = pixelBufferFromCGImage(image: image)

        #if os(OSX)
        let pixelBuffer = pixelBufferFromCGImage(image: image)
        #else
        let image = UIImage(cgImage: image)
        let pixelBuffer = VideoWriter.pixelBufferFromImage(image: image, pixelBufferPool: pixelBufferAdaptor.pixelBufferPool!, size: renderSettings.size)
        #endif
        
        return pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }

    func pixelBufferFromCGImage(image: CGImage) -> CVPixelBuffer {
        var pxbuffer: CVPixelBuffer? = nil
        let options: NSDictionary = [:]

        let width =  image.width
        let height = image.height
        let bytesPerRow = image.bytesPerRow

        let dataFromImageDataProvider = CFDataCreateMutableCopy(kCFAllocatorDefault, 0, image.dataProvider!.data)
        let x = CFDataGetMutableBytePtr(dataFromImageDataProvider)

        CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            x!,
            bytesPerRow,
            nil,
            nil,
            options,
            &pxbuffer
        )
        return pxbuffer!;
    }
    
    #if os(iOS)
    class func pixelBufferFromImage(image: UIImage, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer {
        var pixelBufferOut: CVPixelBuffer?

        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
        if status != kCVReturnSuccess {
          fatalError("CVPixelBufferPoolCreatePixelBuffer() failed")
        }

        let pixelBuffer = pixelBufferOut!

        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: data, width: Int(size.width), height: Int(size.height),
                              bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)

        context!.clear(CGRect(x:0,y: 0,width: size.width,height: size.height))

        let horizontalRatio = size.width / image.size.width
        let verticalRatio = size.height / image.size.height
        //aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
        let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit

        let newSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)

        let x = newSize.width < size.width ? (size.width - newSize.width) / 2 : 0
        let y = newSize.height < size.height ? (size.height - newSize.height) / 2 : 0

        context?.draw(image.cgImage!, in: CGRect(x:x,y: y, width: newSize.width, height: newSize.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
    #endif
}
