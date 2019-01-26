//
//  MUIView.swift
//  Framework
//
//  Created by Markus Moenig on 03.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class MMView : MMBaseView {

    var renderer        : MMRenderer!
    var textureLoader   : MTKTextureLoader!
    
    // --- Regions
    var leftRegion      : MMRegion?
    var topRegion       : MMRegion?
    var rightRegion     : MMRegion?
    var bottomRegion    : MMRegion?
    var editorRegion    : MMRegion?

    // --- Drawables
    var drawSphere      : MMDrawSphere!
    var drawBox         : MMDrawBox!
    var drawBoxGradient : MMDrawBoxGradient!
    var drawBoxedMenu   : MMDrawBoxedMenu!
    var drawTexture     : MMDrawTexture!
    var drawText        : MMDrawText!

    // --- Fonts
    var openSans        : MMFont?
    
    // --- Skin
    var skin            : MMSkin!;
    
    // --- Animations
    var animate         : [MMAnimate]
    
    // --- Widget References
    var widgetIdCounter : Int!
    
    var defaultFramerate = 10
    var maxFramerate = 60

    var maxFramerateLocks : Int = 0
    
    // --- Drawing
    
    var delayedDraws    : [MMWidget] = []

    // ---
    
    required init(coder: NSCoder) {
        animate = []
        super.init(coder: coder)
        
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
//        print("My GPU is: \(defaultDevice)")
        device = defaultDevice
        platformInit()

        guard let tempRenderer = MMRenderer( self ) else {
            print("MMRenderer failed to initialize")
            return
        }
        
        preferredFramesPerSecond = defaultFramerate
        
        renderer = tempRenderer
        textureLoader = MTKTextureLoader( device: defaultDevice )
        delegate = renderer
        
        hoverWidget = nil
        focusWidget = nil
        widgetIdCounter = 0
        skin = MMSkin()
        
        // Fonts
        openSans = MMFont( self, name: "OpenSans" )
        
        // --- Drawables
        drawSphere = MMDrawSphere( renderer )
        drawBox = MMDrawBox( renderer )
        drawBoxGradient = MMDrawBoxGradient( renderer )
        drawBoxedMenu = MMDrawBoxedMenu( renderer )
        drawTexture = MMDrawTexture( renderer )
        drawText = MMDrawText( renderer )
    }
    
    /// Build the user interface for this view. Called for each frame inside the renderer.
    func build()
    {
        // --- Animations
        
        var newAnimate : [MMAnimate] = []
        for anim in animate {
            anim.tick()
            if !anim.finished {
                newAnimate.append( anim )
            } else {
                unlockFramerate()
            }
        }
        animate = newAnimate
        
        // ---
        
//        print( renderer.cWidth, renderer.cHeight )
        delayedDraws = []
        let rect = MMRect( 0, 0, renderer.cWidth, renderer.cHeight )
        if let region = topRegion {
            region.rect.x = 0
            region.rect.y = 0
            region.rect.width = renderer.cWidth
            region.build()
            
            rect.y += region.rect.height
            rect.height -= region.rect.height
        }
        
        if let region = leftRegion {
            region.rect.x = rect.x
            region.rect.y = rect.y
            region.rect.height = rect.height
            region.build()
            
            rect.x += region.rect.width
            rect.width -= region.rect.width
        }
        
        if let region = bottomRegion {
            region.rect.x = rect.x
            region.rect.y = rect.y
            region.rect.width = rect.width
            region.build()
            
            rect.height -= region.rect.height
        }
        
        if let region = rightRegion {
            region.rect.copy( rect )
            region.build()
            
            rect.width -= region.rect.width
        }
        
        if let region = editorRegion {
            region.rect.copy( rect )
            region.build()
        }
        
        // --- Drag and drop ?
        if dragSource != nil {
            if let widget = dragSource!.previewWidget {
                widget.rect.x = mousePos.x - dragSource!.pWidgetOffset!.x
                widget.rect.y = mousePos.y - dragSource!.pWidgetOffset!.y
                widget.draw()
            }
        }
        
        // --- Delayed Draws
        
        for widget in delayedDraws {
            widget.draw()
        }
    }
    
    /// Regsiter the widget to the view
    func registerWidget( _ widget : MMWidget, region : MMRegion )
    {
        widgets.append( widget )
    }
    
    /// Gets a uniquge id for your widget
    func getWidgetId() -> Int
    {
        widgetIdCounter += 1
        return widgetIdCounter
    }
    
    /// Creates a MTLTexture from the given resource
    func loadTexture(_ name: String ) -> MTLTexture?
    {
        let path = Bundle.main.path(forResource: name, ofType: "tiff")!
        let data = NSData(contentsOfFile: path)! as Data
        
        let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps : false, .SRGB : false]
        
        return try? textureLoader.newTexture(data: data, options: options)
    }
    
    /// Initiate a drag operation
    func dragStarted(source: MMDragSource )
    {
        dragSource = source
        lockFramerate()
    }

    /// Increases the counter which locks the framerate at the max
    func lockFramerate()
    {
        maxFramerateLocks += 1
        preferredFramesPerSecond = maxFramerate
        print( "max framerate" )
    }
    
    /// Decreases the counter which locks the framerate and sets it back to the default rate when <= 0
    func unlockFramerate()
    {
        maxFramerateLocks -= 1
        if maxFramerateLocks <= 0 {
            preferredFramesPerSecond = defaultFramerate
            maxFramerateLocks = 0
            print( "framerate back to default" )
        }
    }

    /// Start animation
    func startAnimate(startValue: Float, endValue: Float, duration: Float, cb:@escaping (Float, Bool)->())
    {
        let anim = MMAnimate(startValue: startValue, endValue: endValue, duration: duration, cb: cb)
        animate.append(anim)
        lockFramerate()
    }
}
