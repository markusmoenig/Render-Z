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
    var drawCube        : MMDrawCube!
    var drawCubeGradient : MMDrawCubeGradient!
    var drawTexture     : MMDrawTexture!
    var drawText        : MMDrawText!

    // --- Fonts
    var openSans        : MMFont?
    
    // --- Skin
    var skin            : MMSkin!;
    
    // --- Widget References
    var widgetIdCounter : Int!
    
    var defaultFramerate = 10
    var maxFramerate = 60

    // ---
    
    required init(coder: NSCoder) {
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
        drawCube = MMDrawCube( renderer )
        drawCubeGradient = MMDrawCubeGradient( renderer )
        drawTexture = MMDrawTexture( renderer )
        drawText = MMDrawText( renderer )
    }
    
    /// Build the user interface for this view. Called for each frame inside the renderer.
    func build()
    {
        let rect = MMRect( 0, 0, renderer.cWidth, renderer.cHeight )
        if let region = topRegion {
            region.rect.x = 0
            region.rect.y = 0
            region.rect.width = renderer.cWidth
            region.build()
            
            rect.y += region.rect.height
            rect.height -= region.rect.height
        }
        
        if let region = bottomRegion {
            region.rect.copy( rect )
            region.build()
            
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
        
        if let region = rightRegion {
            region.rect.copy( rect )
            region.build()
            
            rect.width -= region.rect.width
        }
        
        if let region = editorRegion {
            region.rect.copy( rect )
            region.build()
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
}
