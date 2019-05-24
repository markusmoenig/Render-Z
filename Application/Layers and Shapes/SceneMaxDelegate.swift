//
//  LayerMaxDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 24/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

class SceneMaxDelegate : NodeMaxDelegate {
    
    enum LeftRegionMode
    {
        case Closed, Layers
    }
    
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    enum HoverMode {
        case None, Center, NorthWest, North, NorthEast, East, SouthEast, South, SouthWest, West
    }
    
    var app             : App!
    var mmView          : MMView!
    
    var hoverMode       : HoverMode = .None
    var dragMode        : HoverMode = .None
    
    var dragPos         : float2 = float2()
    var dragSize        : float2 = float2()
    var dragMousePos    : float2 = float2()

    // Top Region
    var layersButton    : MMButtonWidget!
    
    var screenButton    : MMScrollButton!
    var screenSize      : float2? = nil

    //var timelineButton  : MMButtonWidget!

    // Left Region
    var leftRegionMode  : LeftRegionMode = .Layers
    var avLayerList     : AvailableLayerList!

    var shapeSelector   : ShapeSelector!
    var textureWidget   : MMTextureWidget!
    var animating       : Bool = false
    
    // Right Region
    var layerList       : LayerList!
    var shapeListChanged: Bool = true
    
    // Bottom Region
    var bottomRegionMode: BottomRegionMode = .Open
    
    var timeline        : MMTimeline!
    var sequenceWidget  : SequenceWidget!

    // ---
    var currentScene    : Scene?
    var camera          : Camera = Camera()
    var patternState    : MTLRenderPipelineState?
    var dispatched      : Bool = false
    
    var layerNodes      : [Layer] = []
    var screenList      : [Node?] = []

    override func activate(_ app: App)
    {
        self.app = app
        self.mmView = app.mmView
        currentScene = app.nodeGraph.maximizedNode as? Scene
        
        // Top Region
        if layersButton == nil {
            layersButton = MMButtonWidget( app.mmView, text: "Layers" )
            //timelineButton = MMButtonWidget( app.mmView, text: "Timeline" )
        }
        
        screenSize = nil
        screenButton = MMScrollButton(app.mmView, items: getScreenList(), index: 0)
        screenButton.changed = { (index)->() in
            if let osx = self.screenList[index] as? GamePlatformOSX {
                self.screenSize = osx.getScreenSize()
            } else
            if let ipad = self.screenList[index] as? GamePlatformIPAD {
                self.screenSize = ipad.getScreenSize()
            } else {
                self.screenSize = nil
            }
            self.mmView.update()
        }

        layersButton.clicked = { (event) -> Void in
            self.setLeftRegionMode(.Layers)
        }

        //timelineButton.clicked = { (event) -> Void in
        //    self.switchTimelineMode()
        //}
        
        app.closeButton.clicked = { (event) -> Void in
            self.deactivate()
            app.nodeGraph.maximizedNode = nil
            app.nodeGraph.activate()
            app.closeButton.removeState(.Hover)
            app.closeButton.removeState(.Checked)
        }

        // Left Region
        
        avLayerList = AvailableLayerList(app.mmView, app:app)
        
        layersButton.addState( .Checked )
        app.leftRegion!.rect.width = 200
        
        // Right Region
        if layerList == nil {
            layerList = LayerList(app.mmView, app:app, delegate: self)
        }
        app.rightRegion!.rect.width = 300

        // Editor Region
        if patternState == nil {
            let function = app.mmView.renderer!.defaultLibrary.makeFunction( name: "moduloPattern" )
            patternState = app.mmView.renderer!.createNewPipelineState( function! )
        }
        
        // Bottom Region

        //
        
        app.mmView.registerWidgets( widgets: layersButton, app.closeButton, screenButton, avLayerList, layerList.menuWidget, layerList)
        
        let cameraProperties = currentScene!.properties
        if cameraProperties["prevMaxOffX"] != nil {
            camera.xPos = cameraProperties["prevMaxOffX"]!
        }
        if cameraProperties["prevMaxOffY"] != nil {
            camera.yPos = cameraProperties["prevMaxOffY"]!
        }
        if cameraProperties["prevMaxScale"] != nil {
            camera.zoom = cameraProperties["prevMaxScale"]!
        }
        
        updateLayerNodes()
        for layer in layerNodes {
            layer.updatePreview(nodeGraph: app.nodeGraph, hard: true)
        }
    }
    
    override func deactivate()
    {
//        timeline.deactivate()
        app.mmView.deregisterWidgets( widgets: layersButton, app.closeButton, screenButton, avLayerList, layerList.menuWidget, layerList)
        
        currentScene!.updatePreview(nodeGraph: app.nodeGraph, hard: true)
    }
    
    /// Collects the nodes in the scene
    func updateLayerNodes()
    {
        layerNodes = []
        
        for layerUUID in currentScene!.layers {
            for node in app.nodeGraph.nodes {
                if layerUUID == node.uuid {
                    layerNodes.append(node as! Layer)
                }
            }
        }
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
            drawPattern(region)
            
            for layer in layerNodes {
                
                if currentScene!.properties[layer.uuid.uuidString + "_posX"] == nil {
                    currentScene!.properties[layer.uuid.uuidString + "_posX"] = 0
                    currentScene!.properties[layer.uuid.uuidString + "_posY"] = 0
                    currentScene!.properties[layer.uuid.uuidString + "_width"] = 400
                    currentScene!.properties[layer.uuid.uuidString + "_height"] = 400
                }
                
                if currentScene!.properties[layer.uuid.uuidString + "_width"] == nil {
                    currentScene!.properties[layer.uuid.uuidString + "_width"] = 400
                    currentScene!.properties[layer.uuid.uuidString + "_height"] = 400
                }
                
                if layer.builderInstance == nil {
                    layer.updatePreview(nodeGraph: app.nodeGraph, hard: true)
                }
                
                if let instance = layer.builderInstance {
                    if instance.texture == nil || instance.texture!.width != Int(region.rect.width) || instance.texture!.height != Int(region.rect.height) {
                        updateLayerPreview(layer, region.rect.width, region.rect.height)
                    }
                    
                    if let texture = instance.texture {
                        app.mmView.drawTexture.draw(texture, x: region.rect.x, y: region.rect.y)
                    }
                }
            }
            
            if let screen = screenSize {
                let x: Float = region.rect.x + region.rect.width / 2 - (camera.xPos + screen.x/2 * camera.zoom)
                let y: Float = region.rect.y + region.rect.height / 2 - (camera.yPos + screen.y/2 * camera.zoom)
                
                app.mmView.renderer!.setClipRect(region.rect)
                app.mmView.drawBox.draw( x: x, y: y, width: screen.x * camera.zoom, height: screen.y * camera.zoom, round: 0, borderSize: 2, fillColor : float4(0.161, 0.165, 0.188, 0.5), borderColor: float4(0.5, 0.5, 0.5, 0.5) )
                app.mmView.renderer.setClipRect()
            }
            
            // --- Draw Gizmo
            
            if let layer = getCurrentLayer() {
                
                mmView.renderer.setClipRect(region.rect)
                
                let x : Float = region.rect.x + region.rect.width / 2 - (currentScene!.properties[layer.uuid.uuidString + "_posX"]! + camera.xPos)// * camera.zoom
                let y : Float = region.rect.y + region.rect.height / 2 - (currentScene!.properties[layer.uuid.uuidString + "_posY"]! + camera.yPos)// * camera.zoom
                let width = currentScene!.properties[layer.uuid.uuidString + "_width"]! * camera.zoom
                let height = currentScene!.properties[layer.uuid.uuidString + "_height"]! * camera.zoom
                let halfWidth = width / 2; let halfHeight = height / 2
                let radius : Float = 15; let halfRadius = radius / 2

                app.mmView.drawSphere.draw(x: x - radius/2, y: y - radius/2, radius: radius/2, borderSize: 0, fillColor: hoverMode == .Center ? float4(1,1,1,0.8) : float4(0.5,0.5,0.5,0.8), borderColor: float4(repeating:0))
                
                app.mmView.drawBox.draw(x: x - halfWidth, y: y - halfHeight, width: radius, height: radius, borderSize: 0, fillColor: hoverMode == .NorthWest ? float4(1,1,1,0.8) : float4(0.5,0.5,0.5,0.8), borderColor: float4(repeating:0))
                
                app.mmView.drawBox.draw(x: x - halfRadius, y: y - halfHeight, width: radius, height: radius, borderSize: 0, fillColor: hoverMode == .North ? float4(1,1,1,0.8) : float4(0.5,0.5,0.5,0.8), borderColor: float4(repeating:0))
                
                app.mmView.drawBox.draw(x: x + halfWidth - radius, y: y - halfHeight, width: radius, height: radius, borderSize: 0, fillColor: hoverMode == .NorthEast ? float4(1,1,1,0.8) : float4(0.5,0.5,0.5,0.8), borderColor: float4(repeating:0))
                
                app.mmView.drawBox.draw(x: x + halfWidth - radius, y: y - halfRadius, width: radius, height: radius, borderSize: 0, fillColor: hoverMode == .East ? float4(1,1,1,0.8) : float4(0.5,0.5,0.5,0.8), borderColor: float4(repeating:0))
                
                app.mmView.drawBox.draw(x: x + halfWidth - radius, y: y + halfHeight - radius, width: radius, height: radius, borderSize: 0, fillColor: hoverMode == .SouthEast ? float4(1,1,1,0.8) : float4(0.5,0.5,0.5,0.8), borderColor: float4(repeating:0))
                
                app.mmView.drawBox.draw(x: x - halfRadius, y: y + halfHeight - radius, width: radius, height: radius, borderSize: 0, fillColor: hoverMode == .South ? float4(1,1,1,0.8) : float4(0.5,0.5,0.5,0.8), borderColor: float4(repeating:0))
                
                app.mmView.drawBox.draw(x: x - halfWidth, y: y + halfHeight - radius, width: radius, height: radius, borderSize: 0, fillColor: hoverMode == .SouthWest ? float4(1,1,1,0.8) : float4(0.5,0.5,0.5,0.8), borderColor: float4(repeating:0))
                
                app.mmView.drawBox.draw(x: x - halfWidth, y: y - halfRadius, width: radius, height: radius, borderSize: 0, fillColor: hoverMode == .West ? float4(1,1,1,0.8) : float4(0.5,0.5,0.5,0.8), borderColor: float4(repeating:0))
                
                mmView.renderer.setClipRect()
            }
            
        } else
        if region.type == .Top {
            region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: layersButton )
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: app.closeButton)
            
            layersButton.draw()
            app.closeButton.draw()
            
            screenButton.rect.x = region.rect.x + 200
            screenButton.rect.y = 4 + 44
            screenButton.draw()
        } else
        if region.type == .Left {
            let leftRegion = app.leftRegion!
            if leftRegionMode != .Closed {
                
                app.mmView.drawBox.draw( x: leftRegion.rect.x, y: leftRegion.rect.y, width: leftRegion.rect.width, height: leftRegion.rect.height, round: 0, borderSize: 0,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
                
                avLayerList!.rect.copy(leftRegion.rect)
                avLayerList!.draw()
            } else {
                leftRegion.rect.width = 0
            }
        } else
        if region.type == .Right {
            let rightRegion = app.rightRegion!

            rightRegion.rect.width = 300
            rightRegion.rect.x = app.mmView.renderer.cWidth - rightRegion.rect.width
            
            layerList.rect.width = rightRegion.rect.width
            layerList.rect.height = rightRegion.rect.height
            
            rightRegion.layoutV(startX: rightRegion.rect.x, startY: rightRegion.rect.y, spacing: 0, widgets: layerList)
            
            layerList.draw()
        } else
        if region.type == .Bottom {
            /*
            region.rect.y = app.mmView.renderer.cHeight - region.rect.height
            if region.rect.height > 0 {
                
                // Timeline area
                timeline.rect.copy( region.rect )
                timeline.rect.width -= app.rightRegion!.rect.width
                timeline.draw(currentObject!.currentSequence!, uuid:currentObject!.uuid)
                
                // Sequence area
                sequenceWidget.rect.copy( region.rect )
                sequenceWidget.rect.x = region.rect.right() - app.rightRegion!.rect.width
                sequenceWidget.rect.width = app.rightRegion!.rect.width
                sequenceWidget.build(items: currentObject!.sequences)
                sequenceWidget.draw()
            }*/
        }
    }
    
    func updateLayerPreview(_ layer: Layer,_ width: Float,_ height: Float) {
        layer.builderInstance?.layerGlobals!.position.x = currentScene!.properties[layer.uuid.uuidString + "_posX" ]!
        layer.builderInstance?.layerGlobals!.position.y =  currentScene!.properties[layer.uuid.uuidString + "_posY" ]!
        
        layer.builderInstance?.layerGlobals!.limiterSize.x = currentScene!.properties[layer.uuid.uuidString + "_width" ]!
        layer.builderInstance?.layerGlobals!.limiterSize.y = currentScene!.properties[layer.uuid.uuidString + "_height" ]!
        
        app.nodeGraph.builder.render(width: width, height: height, instance: layer.builderInstance!, camera: camera)
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseMoved(event)
        dragMode = hoverMode
        
        if dragMode == .None {
            return
        }
        
        if let layer = getCurrentLayer() {
            dragMousePos = float2(event.x, event.y)
            dragPos = float2(currentScene!.properties[layer.uuid.uuidString + "_posX"]!, currentScene!.properties[layer.uuid.uuidString + "_posY"]!)
            dragSize = float2(currentScene!.properties[layer.uuid.uuidString + "_width"]!, currentScene!.properties[layer.uuid.uuidString + "_height"]!)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        dragMode = .None
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        let region = app.editorRegion!
        
        if dragMode != .None {
            let minSize : Float = 50
            if let layer = getCurrentLayer() {
                if dragMode == .Center {
                    currentScene!.properties[layer.uuid.uuidString + "_posX"] = dragPos.x + dragMousePos.x - event.x
                    currentScene!.properties[layer.uuid.uuidString + "_posY"] = dragPos.y + dragMousePos.y - event.y
                }
                if dragMode == .NorthWest {
                    currentScene!.properties[layer.uuid.uuidString + "_width"] = max( minSize, dragSize.x + (dragMousePos.x - event.x) * 2 / camera.zoom)
                    currentScene!.properties[layer.uuid.uuidString + "_height"] = max( minSize, dragSize.y + (dragMousePos.y - event.y) * 2 / camera.zoom)
                } else
                if dragMode == .North{
                    currentScene!.properties[layer.uuid.uuidString + "_height"] = max( minSize, dragSize.y + (dragMousePos.y - event.y) * 2 / camera.zoom)
                } else
                if dragMode == .NorthEast {
                    currentScene!.properties[layer.uuid.uuidString + "_width"] = max( minSize, dragSize.x - (dragMousePos.x - event.x) * 2 / camera.zoom)
                    currentScene!.properties[layer.uuid.uuidString + "_height"] = max( minSize, dragSize.y + (dragMousePos.y - event.y) * 2 / camera.zoom)
                } else
                if dragMode == .East {
                    currentScene!.properties[layer.uuid.uuidString + "_width"] = max( minSize, dragSize.x - (dragMousePos.x - event.x) * 2 / camera.zoom)
                } else
                if dragMode == .SouthEast {
                    currentScene!.properties[layer.uuid.uuidString + "_width"] = max( minSize, dragSize.x - (dragMousePos.x - event.x) * 2 / camera.zoom)
                    currentScene!.properties[layer.uuid.uuidString + "_height"] = max( minSize, dragSize.y - (dragMousePos.y - event.y) * 2 / camera.zoom)
                } else
                if dragMode == .South {
                    currentScene!.properties[layer.uuid.uuidString + "_height"] = max( minSize, dragSize.y - (dragMousePos.y - event.y) * 2 / camera.zoom)
                } else
                if dragMode == .SouthWest {
                    currentScene!.properties[layer.uuid.uuidString + "_width"] = max( minSize, dragSize.x + (dragMousePos.x - event.x) * 2 / camera.zoom)
                    currentScene!.properties[layer.uuid.uuidString + "_height"] = max( minSize, dragSize.y - (dragMousePos.y - event.y) * 2 / camera.zoom)
                } else
                if dragMode == .West {
                    currentScene!.properties[layer.uuid.uuidString + "_width"] = max( minSize, dragSize.x + (dragMousePos.x - event.x) * 2 / camera.zoom)
                }
                
                updateLayerPreview(layer, region.rect.width, region.rect.height)
                mmView.update()
            }
            return
        }
        
        if let layer = getCurrentLayer() {
            
            let oldHoverMode = hoverMode
            hoverMode = .None

            let x : Float = region.rect.x + region.rect.width / 2 - (currentScene!.properties[layer.uuid.uuidString + "_posX"]! + camera.xPos)
            let y : Float = region.rect.y + region.rect.height / 2 - (currentScene!.properties[layer.uuid.uuidString + "_posY"]! + camera.yPos)
            let width = currentScene!.properties[layer.uuid.uuidString + "_width"]! * camera.zoom
            let height = currentScene!.properties[layer.uuid.uuidString + "_height"]! * camera.zoom
            let halfWidth = width / 2; let halfHeight = height / 2
            let radius : Float = 15; let halfRadius = radius / 2
            
            var dist = simd_distance(float2(x,y), float2(event.x, event.y))
            if dist <= radius {
                hoverMode = .Center
            }
            
            dist = simd_distance(float2(x-halfWidth+halfRadius,y-halfHeight+halfRadius), float2(event.x, event.y))
            if dist <= radius {
                hoverMode = .NorthWest
            }
            
            dist = simd_distance(float2(x,y-halfHeight+halfRadius), float2(event.x, event.y))
            if dist <= radius {
                hoverMode = .North
            }
            
            dist = simd_distance(float2(x+halfWidth-halfRadius,y-halfHeight+halfRadius), float2(event.x, event.y))
            if dist <= radius {
                hoverMode = .NorthEast
            }
            
            dist = simd_distance(float2(x+halfWidth-halfRadius,y), float2(event.x, event.y))
            if dist <= radius {
                hoverMode = .East
            }
            
            dist = simd_distance(float2(x+halfWidth-halfRadius,y+halfHeight-halfRadius), float2(event.x, event.y))
            if dist <= radius {
                hoverMode = .SouthEast
            }
            
            dist = simd_distance(float2(x,y+halfHeight-halfRadius), float2(event.x, event.y))
            if dist <= radius {
                hoverMode = .South
            }
            
            dist = simd_distance(float2(x-halfWidth+halfRadius,y+halfHeight-halfRadius), float2(event.x, event.y))
            if dist <= radius {
                hoverMode = .SouthWest
            }
            
            dist = simd_distance(float2(x-halfWidth+halfRadius,y), float2(event.x, event.y))
            if dist <= radius {
                hoverMode = .West
            }
            
            if oldHoverMode != hoverMode {
                mmView.update()
            }
        }
    }
    
    override func pinchGesture(_ scale: Float)
    {
        camera.zoom = scale
        camera.zoom = max(0.1, camera.zoom)
        camera.zoom = min(1, camera.zoom)
        currentScene!.properties["prevMaxScale"] = camera.zoom
        update()
        app.mmView.update()
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS) || os(watchOS) || os(tvOS)
        // If there is a selected shape, don't scroll
        if dragMode != .None {
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
        
        currentScene!.properties["prevMaxOffX"] = camera.xPos
        currentScene!.properties["prevMaxOffY"] = camera.yPos
        currentScene!.properties["prevMaxScale"] = camera.zoom

        for layer in layerNodes {
            if let instance = layer.builderInstance {
                let region = app.editorRegion!
                app.nodeGraph.builder.render(width: region.rect.width, height: region.rect.height, instance: instance, camera: camera)
            }
        }
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
    
    /// Controls the tab mode in the left region
    func setLeftRegionMode(_ mode: LeftRegionMode )
    {
        if animating { return }
        let leftRegion = app.leftRegion!
        if self.leftRegionMode == mode && leftRegionMode != .Closed {
            app.mmView.startAnimate( startValue: leftRegion.rect.width, endValue: 0, duration: 500, cb: { (value,finished) in
                leftRegion.rect.width = value
                if finished {
                    self.animating = false
                    self.leftRegionMode = .Closed
                    self.layersButton.removeState( .Checked )
                }
            } )
            animating = true
        } else if leftRegion.rect.width != 200 {
            
            app.mmView.startAnimate( startValue: leftRegion.rect.width, endValue: 200, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                }
                leftRegion.rect.width = value
            } )
            animating = true
        }
        self.leftRegionMode = mode
    }
    
    /// Switches the mode of the timeline (Open / Closed)
    func switchTimelineMode()
    {
        if animating { return }
        let bottomRegion = app.bottomRegion!
        
        if bottomRegionMode == .Open {
            app.mmView.startAnimate( startValue: bottomRegion.rect.height, endValue: 0, duration: 500, cb: { (value,finished) in
                bottomRegion.rect.height = value
                if finished {
                    self.animating = false
                    self.bottomRegionMode = .Closed
                }
            } )
            animating = true
        } else if bottomRegion.rect.height != 100 {
            
            app.mmView.startAnimate( startValue: bottomRegion.rect.height, endValue: 100, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.bottomRegionMode = .Open
                }
                bottomRegion.rect.height = value
            } )
            animating = true
        }
    }
    
    /// Returns the current layer which is the first layer in the selectedLayers array
    func getCurrentLayer() -> Layer?
    {
        if currentScene!.selectedLayers.isEmpty { return nil }
        
        for node in app.nodeGraph.nodes {
            if node.uuid == currentScene!.selectedLayers[0] {
                return node as? Layer
            }
        }
        return nil
    }
    
    /// Creates a list of the available screens in the game
    func getScreenList() -> [String]
    {
        var list = ["Screen: None"]
        screenList = [nil]
        
        if let osx = app.nodeGraph.getNodeOfType("Platform OSX") as? GamePlatformOSX {
            screenList.append(osx)
            list.append("Screen: OSX")
        }
        
        if let ipad = app.nodeGraph.getNodeOfType("Platform IPAD") as? GamePlatformIPAD {
            screenList.append(ipad)
            list.append("Screen: iPad")
        }

        return list
    }
    
    /// Updates the preview. hard does a rebuild, otherwise just a render
    override func update(_ hard: Bool = false, updateLists: Bool = false)
    {
        /*
        if hard {
            let objects = currentScene!.createInstances(nodeGraph: app.nodeGraph)
            
            currentScene!.builderInstance = app.nodeGraph.builder.buildObjects(objects: objects, camera: camera)
            updateGizmo()
        } else {
            let region = app.editorRegion!
            if currentScene!.builderInstance != nil {
                app.nodeGraph.builder.render(width: region.rect.width, height: region.rect.height, instance: currentScene!.builderInstance!, camera: camera)
            }
        }*/
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

class AvailableLayerListItem : MMListWidgetItem
{
    var name         : String = ""
    var uuid         : UUID = UUID()
    var color       : float4? = nil
}

struct AvailableLayerListItemDrag : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : float2? = float2()
    var node            : Node? = nil
    var name            : String = ""
}

class AvailableLayerList : MMWidget
{
    var app                 : App
    
    var listWidget          : MMListWidget
    var items               : [AvailableLayerListItem] = []
    
    var mouseIsDown         : Bool = false
    var dragSource          : AvailableLayerListItemDrag?
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        
        listWidget = MMListWidget(view)
        
        for node in app.nodeGraph.nodes {
            if node.type == "Layer" {
                let item = AvailableLayerListItem()
                item.name = node.name
                item.uuid = node.uuid
        
                items.append(item)
            }
        }
        
        // ---
        listWidget.build(items: items, fixedWidth: 200)
        
        super.init(view)
    }
    
    func getCurrentItem() -> MMListWidgetItem?
    {
        for item in items {
            if listWidget.selectedItems.contains( item.uuid ) {
                return item
            }
        }
        return nil
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        listWidget.rect.x = rect.x
        listWidget.rect.y = rect.y
        listWidget.rect.width = rect.width
        listWidget.rect.height = rect.height
        
        listWidget.draw(xOffset: app.leftRegion!.rect.width - 200)
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        let changed = listWidget.selectAt(event.x - rect.x, (event.y - rect.y), items: items)
        if changed {
            listWidget.build(items: items, fixedWidth: 200)
        }
        mouseIsDown = true
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if mouseIsDown && dragSource == nil {
            dragSource = createDragSource(event.x - rect.x, event.y - rect.y)
            if dragSource != nil {
                dragSource?.sourceWidget = self
                mmView.dragStarted(source: dragSource!)
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
        mmView.unlockFramerate()
        mouseIsDown = false
    }
    
    /// Create a drag item for the given position
    func createDragSource(_ x: Float,_ y: Float) -> AvailableLayerListItemDrag?
    {
        let listItem = listWidget.itemAt(x, y, items: items)
        
        if listItem != nil {
            
            let item = listItem as! AvailableLayerListItem
            var drag = AvailableLayerListItemDrag()
            
            drag.id = "AvailableLayerItem"
            drag.name = item.name
            drag.pWidgetOffset!.x = x
            drag.pWidgetOffset!.y = y.truncatingRemainder(dividingBy: listWidget.unitSize)
            
            for node in app.nodeGraph.nodes {
                if item.uuid == node.uuid {
                    drag.node = node
                }
            }
            
            let texture = listWidget.createShapeThumbnail(item: listItem!)
            drag.previewWidget = MMTextureWidget(mmView, texture: texture)
            drag.previewWidget!.zoom = 2
            
            return drag
        }
        return nil
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        listWidget.mouseScrolled(event)
    }
}

class SceneListItem : MMListWidgetItem
{
    var name            : String = ""
    var uuid            : UUID = UUID()
    var color           : float4? = nil
}

class LayerList : MMWidget
{
    var app                 : App
    
    var label               : MMTextLabel
    var menuWidget          : MMMenuWidget
    
    var listWidget          : MMListWidget
    var items               : [SceneListItem] = []
    
    var mouseIsDown         : Bool = false
    var delegate            : SceneMaxDelegate
    
    init(_ view: MMView, app: App, delegate: SceneMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        listWidget = MMListWidget(view)
        
        label = MMTextLabel(view, font: view.openSans, text: "Scene Layers", scale: 0.44 )
        listWidget = MMListWidget(view)
        
        // ---  Menu
        
        let menuItems = [
            MMMenuItem( text: "Remove Layer", cb: {} )
        ]
        menuWidget = MMMenuWidget( view, items: menuItems )
        
        super.init(view)
        rebuildList()
        
        // Rename Layer Instance
        menuWidget.items[0].cb = {
            var item = self.getCurrentItem()
            if item != nil {
                var foundIndex : Int? = nil
                for (index, layerUUID) in self.delegate.currentScene!.layers.enumerated() {
                    if layerUUID == item!.uuid {
                        foundIndex = index
                        break
                    }
                }
                if foundIndex != nil {
                    delegate.currentScene!.layers.remove(at: foundIndex!)
                    self.rebuildList()
                    self.delegate.update(true, updateLists: false)
                }
            }
        }
    }
    
    func rebuildList()
    {
        items = []
        
        for layerUUID in delegate.currentScene!.layers {
            for node in app.nodeGraph.nodes {
                if node.uuid == layerUUID {
                    
                    let item = SceneListItem()
                    item.name = node.name
                    item.uuid = node.uuid
                    items.append(item)
                }
            }
        }
        listWidget.selectedItems = delegate.currentScene!.selectedLayers
        listWidget.build(items: items, fixedWidth: 300)
    }
    
    func getCurrentItem() -> MMListWidgetItem?
    {
        for item in items {
            if listWidget.selectedItems.contains( item.uuid ) {
                return item
            }
        }
        return nil
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, borderSize: 1,  fillColor : float4(0.275, 0.275, 0.275, 1), borderColor: float4( 0, 0, 0, 1 ) )
        label.drawCenteredY( x: rect.x + 10, y: rect.y, width: rect.width, height: 30 )
        
        menuWidget.rect.x = rect.x + rect.width - 30 - 1
        menuWidget.rect.y = rect.y + 1
        menuWidget.rect.width = 30
        menuWidget.rect.height = 28
        
        if menuWidget.states.contains(.Opened) {
            mmView.delayedDraws.append( menuWidget )
        } else {
            menuWidget.draw()
            // --- Make focus area the size of the toolbar
            menuWidget.rect.x = rect.x
            menuWidget.rect.y = rect.y
            menuWidget.rect.width = rect.width
            menuWidget.rect.height = 30
        }
        
        mmView.drawBox.draw( x: rect.x, y: rect.y + 30, width: rect.width, height: rect.height - 30, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        listWidget.rect.x = rect.x
        listWidget.rect.y = rect.y + 30
        listWidget.rect.width = rect.width
        listWidget.rect.height = rect.height - 30
        
        listWidget.draw()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        let changed = listWidget.selectAt(event.x - rect.x, (event.y - rect.y) - 30, items: items)
        if changed {
            delegate.currentScene!.selectedLayers = listWidget.selectedItems
            rebuildList()
            listWidget.build(items: items, fixedWidth: 300)
        }
        mouseIsDown = true
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if mouseIsDown {

        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        listWidget.mouseScrolled(event)
    }
}
