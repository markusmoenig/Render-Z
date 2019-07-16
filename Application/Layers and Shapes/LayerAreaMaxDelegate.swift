//
//  LayerMaxDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 24/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class LayerAreaMaxDelegate : NodeMaxDelegate {
    
    enum PointType {
        case None, Edge, Center, Control
    }
    
    enum MouseMode {
        case None, Dragging
    }
    
    enum SegmentType : Int {
        case Linear, Circle, Bezier, Smoothstep, SmoothMaximum
    }
    
    var app             : App!
    var mmView          : MMView!
    
    var mouseMode       : MouseMode = .None

    // Top Region
    var textureWidget   : MMTextureWidget!
    var animating       : Bool = false

    // ---
    var layerArea       : LayerArea!
    var masterLayer     : Layer!
    
    var camera          : Camera = Camera()
    var patternState    : MTLRenderPipelineState?
    var dispatched      : Bool = false
    
    var left            : Float = 0
    var bottom          : Float = 0
    var right           : Float = 0
    
    var startDrag       : float2 = float2()
    var startPoint      : float2 = float2()
    var xLimits         : float2 = float2()
    
    var previewTexture  : MTLTexture? = nil
    var builderInstance : BuilderInstance? = nil
    
    var builder         : Builder? = nil
    var timeline        : MMTimeline!
    
    var mouseWasDown    : Bool = false

    override func activate(_ app: App)
    {
        self.app = app
        mmView = app.mmView
        
        mouseWasDown = false
        
        timeline = MMTimeline(mmView)
        
        if builder == nil {
            builder = Builder( app.nodeGraph )
        }
        
        layerArea = (app.nodeGraph.maximizedNode as! LayerArea)
        masterLayer = (app.nodeGraph.currentMaster as! Layer)
        
        if layerArea.areaObject?.shapes.count == 0 {
            layerArea.areaObject?.addShape( app.shapeFactory.createShape("Box") )
            layerArea.areaObject?.properties["border"] = 0
            layerArea.areaObject?.bodyMaterials.append( app.materialFactory.createMaterial("Static") )
            
            let redMaterial = layerArea.areaObject?.bodyMaterials[0]
            
            redMaterial!.properties["value_x"] = 0.541
            redMaterial!.properties["value_y"] = 0.098
            redMaterial!.properties["value_z"] = 0.125
            redMaterial!.properties["value_w"] = 0.5
        }
        
        app.topRegion!.rect.width = 0
        app.leftRegion!.rect.width = 0
        app.rightRegion!.rect.width = 0
        app.bottomRegion!.rect.width = 0
        app.editorRegion!.rect.width = app.mmView.renderer.cWidth - 1
        
        app.closeButton.clicked = { (event) -> Void in
            self.deactivate()
            app.nodeGraph.maximizedNode = nil
            app.nodeGraph.activate()
            app.closeButton.removeState(.Hover)
            app.closeButton.removeState(.Checked)
        }

        // Editor Region

        app.mmView.registerWidgets( widgets: app.closeButton)
        
        if layerArea.properties["prevOffX"] != nil {
             camera.xPos = layerArea.properties["prevOffX"]!
        }
        if layerArea.properties["prevOffY"] != nil {
            camera.yPos = layerArea.properties["prevOffY"]!
        }
        if layerArea.properties["prevScale"] != nil {
            camera.zoom = layerArea.properties["prevScale"]!
        }
        
        masterLayer.updatePreview(nodeGraph: app.nodeGraph, hard: true)
        
        app.gizmo.setObject(layerArea.areaObject!, context: .ObjectEditor, customDelegate: self)
    }
    
    override func deactivate()
    {
        app.mmView.deregisterWidgets( widgets: app.closeButton)
        builder = nil
        //masterLayer.updatePreview(nodeGraph: app.nodeGraph, hard: true)
    }
    
    /// Called when the project changes (Undo / Redo)
    override func setChanged()
    {
//        shapeListChanged = true
    }
    
    /// Draw the background pattern
    func drawPattern(_ rect: MMRect)
    {
        let mmRenderer = app.mmView.renderer!
    
        if patternState == nil {
            let function = app.mmView.renderer!.defaultLibrary.makeFunction( name: "moduloPattern" )
            patternState = app.mmView.renderer!.createNewPipelineState( function! )
        }
        
        let scaleFactor : Float = app.mmView.scaleFactor
        let settings: [Float] = [
            rect.width, rect.height,
        ];
        
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( rect.x, rect.y, rect.width, rect.height, scale: scaleFactor ) )
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
            
            //mmView.renderer.setClipRect(region.rect)
            //app!.mmView.drawBox.draw( x: region.rect.x, y: region.rect.y, width: region.rect.width, height: region.rect.height, round: 0, borderSize: 0, fillColor : float4(1, 1, 1, 1.000), borderColor: float4(repeating:0) )
            
            let region = app.editorRegion!
            if let instance = masterLayer.builderInstance {
                
                if instance.texture == nil || instance.texture!.width != Int(region.rect.width) || instance.texture!.height != Int(region.rect.height) {
                    app.nodeGraph.builder.render(width: region.rect.width, height: region.rect.height, instance: instance, camera: camera)
                }
                
                if let texture = instance.texture {
                    app.mmView.drawTexture.draw(texture, x: region.rect.x, y: region.rect.y)
                }
            }
            
            let areaObject = layerArea.areaObject!

            let pos = float2(areaObject.properties["posX"]!, areaObject.properties["posY"]!)
            let size = float2(20 * areaObject.properties["scaleX"]!, 20 * areaObject.properties["scaleY"]!)
            
            app.nodeGraph.debugInstance!.clear()
            app.nodeGraph.debugInstance!.addBox(pos, size, 0, 0, float4(0.541, 0.098, 0.125, 0.8))
            app.nodeGraph.debugBuilder!.render(width: app.editorRegion!.rect.width, height: app.editorRegion!.rect.height, instance: app.nodeGraph.debugInstance!, camera: camera)
            app!.mmView.drawTexture.draw(app.nodeGraph.debugInstance!.texture!, x: region.rect.x, y: region.rect.y, zoom: 1)

            app.gizmo.rect.copy(region.rect)
            app.gizmo.scale = camera.zoom
            app.gizmo.draw()
            
            app.changed = false
        } else
        if region.type == .Top {
            //region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: addButton, removeButton, pointTypeButton )
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: app.closeButton)
            
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
        mouseMoved(event)
        app.gizmo.mouseDown(event)
        mouseWasDown = true
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if mouseWasDown {
            app.gizmo.mouseUp(event)
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        app.gizmo.mouseMoved(event)
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
        
        layerArea.properties["prevOffX"] = camera.xPos
        layerArea.properties["prevOffY"] = camera.yPos
        layerArea.properties["prevScale"] = camera.zoom
        
        if let instance = masterLayer.builderInstance {
            let region = app.editorRegion!
            app.nodeGraph.builder.render(width: region.rect.width, height: region.rect.height, instance: instance, camera: camera)
        }
        
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
    
    /// Return the camera (used by Gizmo)
    override func getCamera() -> Camera?
    {
        return camera
    }
    
    /// Return the timeline (used by Gizmo)
    override func getTimeline() -> MMTimeline?
    {
        return timeline
    }
}
