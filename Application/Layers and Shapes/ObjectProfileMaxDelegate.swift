//
//  LayerMaxDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 24/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ObjectProfileMaxDelegate : NodeMaxDelegate {
    
    enum PointType {
        case None, Edge, Center, Control
    }
    
    enum MouseMode {
        case None, Dragging
    }
    
    var app             : App!
    var mmView          : MMView!
    
    var selPointType    : PointType = .None
    var selPointOff     : Int = 0
    
    var hoverPointType  : PointType = .None
    var hoverPointOff   : Int = 0
    
    var mouseMode       : MouseMode = .None

    // Top Region
    var objectsButton   : MMButtonWidget!
    
    var textureWidget   : MMTextureWidget!
    var animating       : Bool = false

    // ---
    var profile         : ObjectProfile!
    var masterObject    : Object!
    
    var camera          : Camera = Camera()
    var patternState    : MTLRenderPipelineState?
    var dispatched      : Bool = false
    
    var scale           : Float = 4
    var left            : Float = 0
    var bottom          : Float = 0
    var right           : Float = 0
    
    var startDrag       : float2 = float2()
    var startPoint      : float2 = float2()
    
    var previewTexture  : MTLTexture? = nil
    var builderInstance : BuilderInstance? = nil

    override func activate(_ app: App)
    {
        self.app = app
        mmView = app.mmView
        
        profile = (app.nodeGraph.maximizedNode as! ObjectProfile)
        masterObject = (app.nodeGraph.currentMaster as! Object)
        
        app.topRegion!.rect.width = 0
        app.leftRegion!.rect.width = 0
        app.rightRegion!.rect.width = 0
        app.bottomRegion!.rect.width = 0
        app.editorRegion!.rect.width = app.mmView.renderer.cWidth - 1

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
        
        if profile.properties["prevOffX"] != nil {
             camera.xPos = profile.properties["prevOffX"]!
        }
        if profile.properties["prevOffY"] != nil {
            camera.yPos = profile.properties["prevOffY"]!
        }
        if profile.properties["prevScale"] != nil {
            camera.zoom = profile.properties["prevScale"]!
        }
        
        update(true)
    }
    
    override func deactivate()
    {
        app.mmView.deregisterWidgets( widgets: objectsButton, app.closeButton)
        profile.updatePreview(nodeGraph: app.nodeGraph)
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
            
            app.editorRegion!.rect.width = app.mmView.renderer.cWidth - 1
            //drawPattern(region)
            
            app!.mmView.drawBox.draw( x: region.rect.x, y: region.rect.y, width: region.rect.width, height: region.rect.height, round: 0, borderSize: 0, fillColor : float4(0.098, 0.098, 0.098, 1.000), borderColor: float4(repeating:0) )
            mmView.drawTexture.draw(previewTexture!, x: region.rect.x, y: region.rect.y)
            drawGraph(region)
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
    
    func drawGraph(_ region: MMRegion)
    {
        left = region.rect.x + 20
        bottom = region.rect.y + region.rect.height - 40
        right = region.rect.x + region.rect.width - 40
        
        let lineColor = float4(0.5, 0.5, 0.5, 1)
        
        mmView.drawLine.draw(sx: left, sy: bottom, ex: right, ey: bottom, radius: 1, fillColor: lineColor)
        
        // --- Draw Edge Marker
        drawPoint(right, bottom - profile.properties["edgeHeight"]! * scale, isSelected: selPointType == .Edge, hasHover: hoverPointType == .Edge)
        
        // --- Draw Border Marker
        //let borderSize = masterObject.properties["border"]!
        //if borderSize > 0 {
        //    drawPoint(right - borderSize * scale, bottom - profile.properties["borderHeight"]!)
        //}

        // --- Draw Center Marker
        drawPoint(right - profile.properties["centerAt"]! * scale, bottom - profile.properties["centerHeight"]! * scale, isSelected: selPointType == .Center, hasHover: hoverPointType == .Center)
    }
    
    func drawPoint(_ x: Float,_ y : Float, isSelected: Bool = false, hasHover: Bool = false)
    {
        var pFillColor = float4(repeating: 1)
        var pBorderColor = float4( 0, 0, 0, 1)
        let radius : Float = 10

        if isSelected {
            let temp = pBorderColor
            pBorderColor = pFillColor
            pFillColor = temp
        } else
        if hasHover {
            pFillColor = pBorderColor
        }
        
        mmView.drawSphere.draw(x: x - radius, y: y - radius, radius: radius, borderSize: 3, fillColor: pFillColor, borderColor: pBorderColor)
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        selPointType = hoverPointType
        mouseMode = .Dragging
        startDrag.x = event.x; startDrag.y = event.y
        if selPointType == .Edge {
            startPoint.y = profile.properties["edgeHeight"]!
        } else
        if selPointType == .Center {
            startPoint.x = profile.properties["centerAt"]!
            startPoint.y = profile.properties["centerHeight"]!
        }
        
        mmView.mouseTrackWidget = app.editorRegion!.widget
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseMode = .None
        mmView.mouseTrackWidget = nil
        update()
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if mouseMode == .Dragging && (selPointType == .Center || selPointType == .Edge )
        {
            if selPointType == .Edge {
                profile.properties["edgeHeight"] = min( 100, max(0, startPoint.y - (event.y - startDrag.y) / scale))
            }
            if selPointType == .Center {
                profile.properties["centerAt"]! = max(0, startPoint.x - (event.x - startDrag.x) / scale)
                profile.properties["centerHeight"]! = min( 100, max(0, startPoint.y - (event.y - startDrag.y) / scale))
            }
            mmView.update()
            update()
        } else
        if mouseMode == .None {
            let radius : Float = 10
            let halfRadius = radius / 2
            
            let oldHoverPointType = hoverPointType
            hoverPointType = .None
            
            // --- Check for Edge / Center Hover
        
            var pY : Float = bottom - profile.properties["edgeHeight"]!*scale
            if event.x >= right - halfRadius && event.x <= right + halfRadius && event.y >= pY - halfRadius && event.y <= pY + halfRadius {
                hoverPointType = .Edge
            }
            
            let pX : Float = right - profile.properties["centerAt"]! * scale
            pY = bottom - profile.properties["centerHeight"]! * scale
            if event.x >= pX - halfRadius && event.x <= pX + halfRadius && event.y >= pY - halfRadius && event.y <= pY + halfRadius {
                hoverPointType = .Center
            }
            
            //drawPoint(right, bottom - profile.properties["edgeHeight"]!)

            if oldHoverPointType != hoverPointType {
                mmView.update()
            }
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS) || os(watchOS) || os(tvOS)
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
        
        profile.properties["prevOffX"] = camera.xPos
        profile.properties["prevOffY"] = camera.yPos
        profile.properties["prevScale"] = camera.zoom

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
    
    /// Updates the preview. hard does a rebuild, otherwise just a render
    override func update(_ hard: Bool = false, updateLists: Bool = false)
    {
        let size = float2(app.editorRegion!.rect.width, app!.editorRegion!.rect.height)
        if previewTexture == nil || Float(previewTexture!.width) != size.x || Float(previewTexture!.height) != size.y {
            previewTexture = app.nodeGraph.builder.compute!.allocateTexture(width: size.x, height: size.y, output: true)
        }
        
        _ = profile.execute(nodeGraph: app.nodeGraph, root: BehaviorTreeRoot(masterObject), parent: masterObject)
        
        if builderInstance == nil || hard {
            builderInstance = app.nodeGraph.builder.buildObjects(objects: [masterObject], camera: camera, preview: false)
        }
        
        if builderInstance != nil {
            app.nodeGraph.builder.render(width: size.x, height: size.y, instance: builderInstance!, camera: camera, outTexture: previewTexture)
        }
    }
}
