//
//  LayerMaxDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 24/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ObjectProfileMaxDelegate : NodeMaxDelegate {
    
    var app             : App!
    
    // Top Region
    var objectsButton   : MMButtonWidget!
    
    var textureWidget   : MMTextureWidget!
    var animating       : Bool = false

    // ---
    var currentProfile  : ObjectProfile!
    var camera          : Camera = Camera()
    var patternState    : MTLRenderPipelineState?
    var dispatched      : Bool = false

    override func activate(_ app: App)
    {
        self.app = app
        currentProfile = (app.nodeGraph.maximizedNode as! ObjectProfile)
        
        app.leftRegion!.rect.width = 0
        app.rightRegion!.rect.width = 0

        // Top Region
        if objectsButton == nil {
            objectsButton = MMButtonWidget( app.mmView, text: "Objects" )
        }
        objectsButton.clicked = { (event) -> Void in
         //   self.setLeftRegionMode(.Objects)
        }
        
        app.closeButton.clicked = { (event) -> Void in
            self.deactivate()
            app.nodeGraph.maximizedNode = nil
            app.nodeGraph.activate()
            app.closeButton.removeState(.Hover)
            app.closeButton.removeState(.Checked)
        }

        // Editor Region
        if patternState == nil {
            let function = app.mmView.renderer!.defaultLibrary.makeFunction( name: "moduloPattern" )
            patternState = app.mmView.renderer!.createNewPipelineState( function! )
        }

        app.mmView.registerWidgets( widgets: objectsButton, app.closeButton)
        
        update(true)
    }
    
    override func deactivate()
    {
        app.mmView.deregisterWidgets( widgets: objectsButton, app.closeButton)
        currentProfile!.updatePreview(nodeGraph: app.nodeGraph)
    }
    
    /// Called when the project changes (Undo / Redo)
    override func setChanged()
    {
//        shapeListChanged = true
    }
    
    /// Draw the background pattern
    func drawPattern(_ region: MMRegion)
    {
        let mmRenderer = app.mmView.renderer!
    
        let scaleFactor : Float = app.mmView.scaleFactor
        let settings: [Float] = [
            region.rect.width, region.rect.height,
            ];
        
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( region.rect.x, region.rect.y, region.rect.width, region.rect.height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( patternState! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    override func drawRegion(_ region: MMRegion)
    {
        if region.type == .Editor {
            
            region.rect.width = app.mmView.renderer.width - 1
            //drawPattern(region)
            
            app!.mmView.drawBox.draw( x: region.rect.x, y: region.rect.y, width: region.rect.width, height: region.rect.height, round: 0, borderSize: 0, fillColor : float4(0.098, 0.098, 0.098, 1.000), borderColor: float4(repeating:0) )
            app.changed = false
        } else
        if region.type == .Top {
            region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: objectsButton )
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: app.closeButton)
            
            objectsButton.draw()
            app.closeButton.draw()
        } else
        if region.type == .Left {
        } else
        if region.type == .Right {
        } else
        if region.type == .Bottom {
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS) || os(watchOS) || os(tvOS)
        // If there is a selected shape, don't scroll
        if getCurrentObject()?.getCurrentShape() != nil {
            return
        }
        camera.xPos -= event.deltaX! * 2
        camera.yPos -= event.deltaY! * 2
        #elseif os(OSX)
        if app.mmView.commandIsDown && event.deltaY! != 0 {
            camera.zoom += event.deltaY! * 0.003
            camera.zoom = max(0.1, camera.zoom)
            camera.zoom = min(1, camera.zoom)
        } else {
            camera.xPos += event.deltaX! * 2
            camera.yPos += event.deltaY! * 2
        }
        #endif

        update()
        
        if !dispatched {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.app.mmView.unlockFramerate()
                self.dispatched = false
            }
            dispatched = true
        }
        
        if app.mmView.maxFramerateLocks == 0 {
            app.mmView.lockFramerate()
        }
    }
}
