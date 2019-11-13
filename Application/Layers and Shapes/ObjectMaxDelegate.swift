//
//  ObjectMaxDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ObjectMaxDelegate : NodeMaxDelegate {
    
    enum HoverMode
    {
        case None, SideSlider
    }
    
    enum LeftRegionMode
    {
        case Closed, Shapes, Materials
    }
    
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    var firstStart              : Bool = true
    var hoverMode               : HoverMode = .None

    var app                     : App!
    var gizmoContext            : Gizmo.GizmoContext = .ShapeEditor
    
    // Top Region
    var tabButton               : MMTabButtonWidget!
    
    var timelineButton          : MMButtonWidget!

    var screenButton            : MMScrollButton!
    var screenSize              : float2? = nil
    var screenList              : [Node?] = []

    var sceneButton             : MMScrollButton!
    var sceneNodes              : [Scene] = []
    var sceneNames              : [String] = []
    
    var currentScene            : Scene? = nil

    // Left Region
    var leftRegionMode          : LeftRegionMode = .Shapes
    var activeRegionMode        : LeftRegionMode = .Shapes

    var shapeSelector           : ShapeSelector!
    var shapeTexture            : MMTextureWidget!
    var shapeScrollArea         : ShapeScrollArea!
    var animating               : Bool = false
    var materialsTab            : MMTabWidget!
    
    var componentSelector       : MaterialSelector!
    var componentTexture        : MMTextureWidget!
    var componentScrollArea     : ComponentScrollArea!
    var compoundSelector        : MaterialSelector!
    var compoundTexture         : MMTextureWidget!
    var compoundScrollArea      : CompoundScrollArea!
    
    // Right Region
    var objectWidget            : ObjectWidget!
    var shapeListWidget         : ShapeListScrollArea!
    var shapeList               : ShapeList!
    var shapeListChanged        : Bool = true
    
    var materialListWidget      : MaterialListScrollArea!
    var materialList            : MaterialList!
    var materialListChanged     : Bool = true
    
    var materialType            : Object.MaterialType = .Body

    // Bottom Region
    var bottomRegionMode        : BottomRegionMode = .Open
    
    var timeline                : MMTimeline!
    var sequenceWidget          : SequenceWidget!

    // ---
    var currentObject           : Object?
    var camera                  : Camera = Camera()
    var patternState            : MTLRenderPipelineState?
    var dispatched              : Bool = false
    
    /// The currently displayed object
    var selObject               : Object? = nil
    
    /// Gizmo works on the selected object, gets disabled when shape gets selected
    var selObjectActive         : Bool = false

    var zoomBuffer              : Float = 0
    
    var sideSliderButton        : MMSideSliderWidget!
    
    let maxLeftRegionSize       : Float = 223

    override func activate(_ app: App)
    {
        self.app = app
        currentObject = app.nodeGraph.maximizedNode as? Object
        app.gizmo.setObject(currentObject)
        
        selObject = currentObject
        selObjectActive = false
        
        // Top Region
        if tabButton == nil {
            tabButton = MMTabButtonWidget(app.mmView)
            tabButton.addTab("Shapes")
            tabButton.addTab("Materials")

            timelineButton = MMButtonWidget( app.mmView, text: "Timeline" )
            sideSliderButton = MMSideSliderWidget(app.mmView)
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
            self.app.mmView.update()
        }
        
        currentScene = nil
        getOccurencesOf(currentObject!)
        sceneButton = MMScrollButton(app.mmView, items: sceneNames, index: 0)
        sceneButton.changed = { (index)->() in

            if index == 0 {
                self.currentScene = nil
            } else {
                self.currentScene = self.sceneNodes[index-1]
                self.currentScene!.updatePreview(nodeGraph: app.nodeGraph, hard: true)
            }
            
            self.app.mmView.update()
        }
        
        tabButton.clicked = { (event) -> Void in
            if self.tabButton.index == 0 {
                if self.leftRegionMode == .Materials {
                    self.setLeftRegionMode(.Shapes)
                }
            } else {
                if self.leftRegionMode == .Shapes {
                    self.setLeftRegionMode(.Materials)
                }
            }
        }
            
        timelineButton.clicked = { (event) -> Void in
            self.switchTimelineMode()
        }
        
        app.closeButton.clicked = { (event) -> Void in
            self.deactivate()
            app.nodeGraph.maximizedNode = nil
            app.nodeGraph.activate()
            app.closeButton.removeState(.Hover)
            app.closeButton.removeState(.Checked)
        }

        // Left Region
        if shapeSelector == nil {
            // Shapes
            shapeSelector = ShapeSelector(app.mmView, width : maxLeftRegionSize)
            shapeTexture = MMTextureWidget(app.mmView, texture: shapeSelector.fragment!.texture )
            shapeTexture.zoom = 2
            shapeScrollArea = ShapeScrollArea(app.mmView, app: app, delegate:self)
            
            // Materials
            
            componentSelector = MaterialSelector(app.mmView, width : maxLeftRegionSize, brand: .Components, materialFactory: app.materialFactory)
            componentTexture = MMTextureWidget(app.mmView, texture: componentSelector.fragment!.texture )
            componentTexture.zoom = 2
            componentScrollArea = ComponentScrollArea(app.mmView, app: app, delegate:self)
            
            compoundSelector = MaterialSelector(app.mmView, width : maxLeftRegionSize, brand: .Compounds, materialFactory: app.materialFactory)
            compoundTexture = MMTextureWidget(app.mmView, texture: compoundSelector.fragment!.texture )
            compoundTexture.zoom = 2
            compoundScrollArea = CompoundScrollArea(app.mmView, app: app, delegate:self)
            
            materialsTab = MMTabWidget(app.mmView)
            materialsTab.addTab("Component", widget: componentScrollArea)
            materialsTab.addTab("Compound", widget: compoundScrollArea)
        }

        // Right Region
        if objectWidget == nil {
            objectWidget = ObjectWidget(app.mmView, app: app, delegate:self)
            shapeListWidget = ShapeListScrollArea(app.mmView, app: app, delegate: self)
            shapeList = ShapeList(app.mmView)
            
            materialListWidget = MaterialListScrollArea(app.mmView, app: app, delegate: self)
            materialList = MaterialList(app.mmView)
        } else {
            updateObjectHierarchy(true)
        }
        app.rightRegion!.rect.width = 300

        // Editor Region
        if patternState == nil {
            let function = app.mmView.renderer!.defaultLibrary.makeFunction( name: "coordinateSystem" )
            patternState = app.mmView.renderer!.createNewPipelineState( function! )
        }
        
        // Bottom Region
        if timeline == nil {
            timeline = MMTimeline(app.mmView)
            timeline.changedCB = { (frame) in
                self.update()
            }
            sequenceWidget = SequenceWidget(app.mmView, app: app, delegate: self)
        }
        timeline.activate()

        sequenceWidget.listWidget.selectedItems = [currentObject!.sequences[0].uuid]
        sequenceWidget.listWidget.selectionChanged = { (items:[MMListWidgetItem]) -> Void in
            self.currentObject!.setSequence(sequence: items[0] as? MMTlSequence, timeline: self.app!.timeline)
            self.update()
        }
        
        app.mmView.registerWidgets( widgets: tabButton, timelineButton, objectWidget.menuWidget, objectWidget.objectListWidget, timeline, sequenceWidget.menuWidget, sequenceWidget, screenButton, sceneButton, app.closeButton)

        // Set Layouts
        if firstStart {
            app.leftRegion!.rect.width = maxLeftRegionSize
            leftRegionMode = .Closed
            setLeftRegionMode(.Shapes)
            
            timelineButton.addState( .Checked )
            app.bottomRegion!.rect.height = 130
        } else {
            if leftRegionMode == .Closed {
                app.leftRegion!.rect.width = 0
            } else {
                app.leftRegion!.rect.width = maxLeftRegionSize
            }
            
            if bottomRegionMode == .Closed {
                app.bottomRegion!.rect.height = 0
            } else {
                app.bottomRegion!.rect.height = 130
            }
            
            animating = true
            setLeftRegionMode(leftRegionMode)
            animating = false
        }
        
        let cameraProperties = currentObject!.properties
        if cameraProperties["prevMaxOffX"] != nil {
            camera.xPos = cameraProperties["prevMaxOffX"]!
        }
        if cameraProperties["prevMaxOffY"] != nil {
            camera.yPos = cameraProperties["prevMaxOffY"]!
        }
        if cameraProperties["prevMaxScale"] != nil {
            camera.zoom = cameraProperties["prevMaxScale"]!
        }
        update(true)
        firstStart = false
    }
    
    override func deactivate()
    {
        app!.nodeGraph.diskBuilder.getDisksFor(currentObject!, builder: app!.nodeGraph.builder, async: {
            let disks = self.currentObject!.disks
            if disks.count > 0 {
                if let objectRect = self.currentObject!.objectRect {
                    self.currentObject!.properties["prevOffX"] = objectRect.xPos + objectRect.width / 2
                    self.currentObject!.properties["prevOffY"] = -objectRect.yPos + objectRect.height / 2
                }
            }
            self.currentObject!.updatePreview(nodeGraph: self.app.nodeGraph, hard: true)
        })
        
        let occurences = app!.nodeGraph.getOccurencesOf(currentObject!)
        for occ in occurences {
            if let scene = occ as? Scene {
                scene.builderInstance = nil
            }
        }
        
        timeline.deactivate()
        app.mmView.deregisterWidgets( widgets: tabButton, timelineButton, shapeScrollArea, materialsTab, shapeListWidget, materialListWidget, objectWidget.menuWidget, objectWidget.objectListWidget, timeline, sequenceWidget, sequenceWidget.menuWidget, screenButton, sceneButton, app.closeButton)
        materialsTab.deregisterWidget()
        materialListWidget.deregisterWidgets()
    }
    
    /// Called when the project changes (Undo / Redo)
    override func setChanged()
    {
        shapeListChanged = true
        materialListChanged = true
    }
    
    /// Draw the background pattern
    func drawPattern(_ region: MMRegion)
    {
        let mmRenderer = app.mmView.renderer!
        
        let scaleFactor : Float = app.mmView.scaleFactor
        let settings: [Float] = [
                region.rect.width, region.rect.height,
                camera.xPos, camera.yPos,
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
            app.gizmo.rect.copy(region.rect)
            
            if let scene = currentScene, scene.builderInstance != nil {
                app.nodeGraph.sceneRenderer!.render(width: region.rect.width, height: region.rect.height, camera: camera, instance: scene.builderInstance!)
                app.mmView.drawTexture.draw(app.nodeGraph.sceneRenderer!.fragment.texture, x: region.rect.x, y: region.rect.y)
            } else {
                drawPattern(region)
            }
            
            if let instance = currentObject!.instance {
            
                if instance.texture == nil || instance.texture!.width != Int(region.rect.width) || instance.texture!.height != Int(region.rect.height) {
                    app.nodeGraph.builder.render(width: region.rect.width, height: region.rect.height, instance: currentObject!.instance!, camera: camera)
                }
                
                if let texture = instance.texture {
                    app.mmView.drawTexture.draw(texture, x: region.rect.x, y: region.rect.y)
                }
            }
            
            if let screen = screenSize {
                let x: Float = region.rect.x + region.rect.width / 2 - (camera.xPos + screen.x/2 * camera.zoom)
                let y: Float = region.rect.y + region.rect.height / 2 - (camera.yPos + screen.y/2 * camera.zoom)
                
                app.mmView.renderer!.setClipRect(region.rect)
                app.mmView.drawBox.draw( x: x, y: y, width: screen.x * camera.zoom, height: screen.y * camera.zoom, round: 0, borderSize: 2, fillColor : SIMD4<Float>(0.161, 0.165, 0.188, 0.5), borderColor: SIMD4<Float>(0.5, 0.5, 0.5, 0.5) )
                app.mmView.renderer.setClipRect()
            }
            
            app.gizmo.scale = camera.zoom
            app.gizmo.draw()
            
            app.changed = false
            
            app.mmView.renderer!.setClipRect(region.rect)

            // SideSlider
            sideSliderButton.rect.x = region.rect.x - 40
            sideSliderButton.rect.y = region.rect.y + (region.rect.height - 70) / 2
            sideSliderButton.rect.width = 70
            sideSliderButton.rect.height = 70
            sideSliderButton.draw()
            app.mmView.renderer.setClipRect()
        } else
        if region.type == .Top {
            region.layoutH( startX: 3, startY: 4 + 44, spacing: 10, widgets: tabButton)
            
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: timelineButton, app.closeButton)

            screenButton.rect.x = tabButton.rect.right() + 10
            screenButton.rect.y = 4 + 44
            screenButton.draw()
            
            sceneButton.rect.x = screenButton.rect.right() + 10
            sceneButton.rect.y = 4 + 44
            sceneButton.draw()
            
            tabButton.draw()
            timelineButton.draw()
            app.closeButton.draw()
        } else
        if region.type == .Left {
            let leftRegion = app.leftRegion!
            if leftRegionMode != .Closed {
                app.mmView.drawBox.draw( x: leftRegion.rect.x, y: leftRegion.rect.y, width: leftRegion.rect.width, height: leftRegion.rect.height, round: 0, borderSize: 0,  fillColor : SIMD4<Float>(0.169, 0.169, 0.169, 1.000), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
                if leftRegionMode == .Shapes {
                    shapeScrollArea.build(widget: shapeTexture, area: leftRegion.rect, xOffset:(leftRegion.rect.width - maxLeftRegionSize))
                } else
                if leftRegionMode == .Materials {
                    materialsTab.rect.copy(leftRegion.rect)
                    materialsTab.draw(xOffset: leftRegion.rect.width - maxLeftRegionSize)
                }
            } else {
                leftRegion.rect.width = 0
            }
        } else
        if region.type == .Right {
            let rightRegion = app.rightRegion!

            app.mmView.drawBox.draw( x: rightRegion.rect.x, y: rightRegion.rect.y, width: rightRegion.rect.width, height: rightRegion.rect.height, round: 0, borderSize: 0, fillColor: SIMD4<Float>(0.169, 0.169, 0.169, 1.000), borderColor: SIMD4<Float>(0.286, 0.286, 0.286, 1.000) )
            
            rightRegion.rect.width = 300
            rightRegion.rect.x = app.mmView.renderer.cWidth - rightRegion.rect.width
            
            objectWidget.rect.width = rightRegion.rect.width
            objectWidget.rect.height = rightRegion.rect.height * 1/3
            
            shapeListWidget.rect.width = rightRegion.rect.width
            shapeListWidget.rect.height = rightRegion.rect.height * 2/3
            
            materialListWidget.rect.width = rightRegion.rect.width
            materialListWidget.rect.height = rightRegion.rect.height * 2/3
            
            // Draw lists
            if activeRegionMode == .Shapes {
                rightRegion.layoutV(startX: rightRegion.rect.x, startY: rightRegion.rect.y, spacing: 0, widgets: objectWidget, shapeListWidget)
                shapeListWidget.draw()
            } else {
                rightRegion.layoutV(startX: rightRegion.rect.x, startY: rightRegion.rect.y, spacing: 0, widgets: objectWidget, materialListWidget)
                materialListWidget.draw()
            }
            
            objectWidget.draw()

            // Rebuild shape list
            if shapeListChanged {
                shapeList.build( width: shapeListWidget.rect.width, object: selObject!)
                // Remove gizmo focus from the selected object if it has selected shapes
                if selObject!.selectedShapes.count > 0 {
                    selObjectActive = false
                }
                shapeListChanged = false
            }
            
            // Rebuild material list
            if materialListChanged {
                materialList.build( width: materialListWidget.rect.width, object: selObject!, type: materialType)
                // Remove gizmo focus from the selected object if it has selected shapes
                //if selObject!.selectedMaterials.count > 0 {
                    selObjectActive = false
                //}
                materialListChanged = false
            }
            
            if activeRegionMode == .Shapes {
                shapeListWidget.build(widget: shapeList.textureWidget, area: MMRect( shapeListWidget.rect.x - 1, shapeListWidget.rect.y + 31, shapeListWidget.rect.width, shapeListWidget.rect.height - 35) )
                                
                // Erase Edges
                let cb : Float = 4
                app.mmView.drawBox.draw( x: rightRegion.rect.x - cb, y: rightRegion.rect.y + objectWidget.rect.height + 30 - cb, width: rightRegion.rect.width + 2*cb - 1, height: shapeListWidget.rect.height + 2 + 2*cb, round: 40, borderSize: 6, fillColor: float4(0,0,0,0), borderColor:  SIMD4<Float>(0.169, 0.169, 0.169, 1.000))
                
                // Draw Round Border
                app.mmView.drawBox.draw( x: rightRegion.rect.x, y: rightRegion.rect.y + objectWidget.rect.height + 30, width: rightRegion.rect.width - 1, height: shapeListWidget.rect.height + 2, round: 40, borderSize: 1, fillColor : SIMD4<Float>(0,0,0,0), borderColor: SIMD4<Float>(0.286, 0.286, 0.286, 1.000) )
            } else {
                let matRect = MMRect( materialListWidget.rect.x - 1, materialListWidget.rect.y + 31, materialListWidget.rect.width, materialListWidget.rect.height - 35)
                materialListWidget.build(widget: materialList.textureWidget, area: matRect)
                
                matRect.y -= 2
                matRect.height += 4
                app.mmView.renderer.setClipRect(matRect)
                
                // Erase Edges
                let cb : Float = 4
                app.mmView.drawBox.draw( x: rightRegion.rect.x - cb, y: rightRegion.rect.y + objectWidget.rect.height + 30 - cb, width: rightRegion.rect.width + 2*cb - 1, height: materialListWidget.rect.height + 2 + 2*cb, round: 40, borderSize: 6, fillColor: float4(0,0,0,0), borderColor:  SIMD4<Float>(0.169, 0.169, 0.169, 1.000))
                
                // Draw Round Border
                app.mmView.drawBox.draw( x: rightRegion.rect.x, y: rightRegion.rect.y + objectWidget.rect.height + 30, width: rightRegion.rect.width - 1, height: materialListWidget.rect.height + 2, round: 40, borderSize: 1, fillColor : SIMD4<Float>(0,0,0,0), borderColor: SIMD4<Float>(0.286, 0.286, 0.286, 1.000) )
                
                app.mmView.renderer.setClipRect()
            }
        } else
        if region.type == .Bottom {
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
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if hoverMode == .SideSlider {
            
            sideSliderButton.removeState(.Hover)
            setLeftRegionMode(tabButton.index == 0 ? .Shapes : .Materials )

            hoverMode = .None
            return
        }
            
        app.gizmo.mouseDown(event)
        if app.gizmo.hoverUITitle != nil {
            return
        }
        
        if app.gizmo.hoverState == .Inactive && currentObject!.instance != nil {
            let editorRegion = app.editorRegion!

            let object = app.nodeGraph.builder.getShapeAt(x: event.x - editorRegion.rect.x, y: event.y - editorRegion.rect.y, width: editorRegion.rect.width, height: editorRegion.rect.height, multiSelect: app.mmView.shiftIsDown, instance: currentObject!.instance!, camera: camera, frame: timeline.currentFrame)
            update()
            shapeListChanged = true
            if object != nil {
                selObject = object
                if selObject!.selectedShapes.count == 0 {
                    selObjectActive = false
                }
            } else
            if object == nil {
                selObject = currentObject
                selObjectActive = false
                selObject!.selectedShapes = []
            }
            app.gizmo.setObject(selObject, rootObject: currentObject, context: gizmoContext, materialType: materialType)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        app.gizmo.mouseUp(event)
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        // --- Side Slider
        hoverMode = .None
        let distToSideSlider : Float = simd_distance(float2(sideSliderButton.rect.x + sideSliderButton.rect.width/2, sideSliderButton.rect.y + sideSliderButton.rect.height/2), float2(event.x, event.y))
        if distToSideSlider <=  sideSliderButton.rect.width/2 {
            sideSliderButton.addState(.Hover)
            hoverMode = .SideSlider
            return
        } else {
            sideSliderButton.removeState(.Hover)
        }
        
        tabButton.hoverTab = nil
        materialsTab.hoverTab = nil
        app.gizmo.mouseMoved(event)
    }
    
    override func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        if firstTouch == true {
            zoomBuffer = currentObject!.properties["prevMaxScale"] != nil ? currentObject!.properties["prevMaxScale"]! : 1
        }
        
        camera.zoom = zoomBuffer * scale
        camera.zoom = max(0.1, camera.zoom)
        camera.zoom = min(1, camera.zoom)
        currentObject!.properties["prevMaxScale"] = camera.zoom
        update()
        app.mmView.update()
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS) || os(watchOS) || os(tvOS)
        // If there is a selected shape, don't scroll
        if currentObject!.getCurrentShape() != nil {
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
        
        currentObject!.properties["prevMaxOffX"] = camera.xPos
        currentObject!.properties["prevMaxOffY"] = camera.yPos
        currentObject!.properties["prevMaxScale"] = camera.zoom
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
    
    /// Finds scenes which contain an instance of this object
    func getOccurencesOf(_ node: Node)
    {
        sceneNodes = []
        sceneNames = ["Scene: None"]
        
        for n in app.nodeGraph.nodes {
            if let scene = n as? Scene {
                for inst in scene.objectInstances {
                    if inst.objectUUID == node.uuid {
                        if !sceneNodes.contains(scene) {
                            sceneNodes.append(scene)
                            sceneNames.append("Scene: " + scene.name)
                        }
                    }
                }
            }
        }
    }
    
    /// Controls the tab mode in the left region
    func setLeftRegionMode(_ mode: LeftRegionMode )
    {
        if mode == .Closed {
            app.mmView.deregisterWidgets( widgets: shapeScrollArea, materialsTab)
            materialsTab.deregisterWidget()
        } else
        if mode == .Shapes {
            materialListWidget.deregisterWidgets()
            app.mmView.deregisterWidgets( widgets: materialsTab, materialListWidget)
            materialsTab.deregisterWidget()
            app.mmView.registerWidgets( widgets: shapeScrollArea, shapeListWidget)
            activeRegionMode = .Shapes
            
            gizmoContext = .ShapeEditor
            app.gizmo.setObject(selObject, rootObject: currentObject, context: gizmoContext, materialType: materialType)
        } else
        if mode == .Materials {
            app.mmView.deregisterWidgets( widgets: shapeScrollArea, shapeListWidget)
            app.mmView.registerWidgets( widgets: materialsTab, materialListWidget)
            materialListWidget.registerWidgets()
            materialsTab.registerWidget()
            activeRegionMode = .Materials
            
            gizmoContext = .MaterialEditor
            app.gizmo.setObject(selObject, rootObject: currentObject, context: gizmoContext, materialType: materialType)
        }
        
        if animating { return }
        let leftRegion = app.leftRegion!
        if self.leftRegionMode == mode && leftRegionMode != .Closed {
            sideSliderButton.setMode(.Animating)
            app.mmView.startAnimate( startValue: leftRegion.rect.width, endValue: 0, duration: 500, cb: { (value,finished) in
                leftRegion.rect.width = value
                if finished {
                    self.animating = false
                    self.leftRegionMode = .Closed
                    DispatchQueue.main.async {
                        self.sideSliderButton.setMode(.Right)
                    }
                }
            } )
            animating = true
        } else if leftRegion.rect.width != maxLeftRegionSize {
            sideSliderButton.setMode(.Animating)
            app.mmView.startAnimate( startValue: leftRegion.rect.width, endValue: maxLeftRegionSize, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    DispatchQueue.main.async {
                        self.sideSliderButton.setMode(.Left)
                    }
                }
                leftRegion.rect.width = value
            } )
            animating = true
        }
        self.leftRegionMode = mode
    }
    
    func setSelectedObject(_ object: Object)
    {
        selObject = object
        selObject!.selectedShapes = []
        selObjectActive = true
        shapeListChanged = true
        materialListChanged = true
        app.gizmo.setObject(selObject!, rootObject: currentObject!, context: gizmoContext)
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
                    self.timelineButton.removeState( .Checked )
                }
            } )
            animating = true
        } else if bottomRegion.rect.height != 130 {
            
            app.mmView.startAnimate( startValue: bottomRegion.rect.height, endValue: 130, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.bottomRegionMode = .Open
                }
                bottomRegion.rect.height = value
            } )
            animating = true
        }
    }
    
    /// Updates the preview. hard does a rebuild, otherwise just a render
    override func update(_ hard: Bool = false, updateLists: Bool = false)
    {
        if hard {
            //fix? app.gizmo.setObject(selObject, rootObject: currentObject, context: gizmoContext, materialType: materialType)
            currentObject!.instance = app.nodeGraph.builder.buildObjects(objects: [currentObject!], camera: camera)
            
            if let scene = currentScene {
               scene.updatePreview(nodeGraph: app.nodeGraph, hard: true)
            }
        }
        
        if updateLists {
            materialListChanged = true
        }
        
        let region = app.editorRegion!
        if currentObject!.instance != nil {
            app.nodeGraph.builder.render(width: region.rect.width, height: region.rect.height, instance: currentObject!.instance!, camera: camera, frame: timeline.currentFrame)
        }
    }
    
    /// Updates the object hierarchy
    func updateObjectHierarchy(_ hard: Bool = false)
    {
        objectWidget.objectListWidget.xOffset = 0
        objectWidget.objectListWidget.yOffset = 0
        objectWidget.objectListWidget.objectTree = ObjectTree(currentObject!)
    }
    
    /// Returns the current material count for the current mode and object
    func materialCount() -> Int
    {
        if materialType == .Body {
            return currentObject!.bodyMaterials.count
        } else {
            return currentObject!.borderMaterials.count
        }
    }
    
    /// Removes the material index from the given material mode
    func removeMaterial(at: Int) -> Material
    {
        if materialType == .Body {
            return currentObject!.bodyMaterials.remove(at: at)
        } else {
            return currentObject!.borderMaterials.remove(at: at)
        }
    }
    
    /// Inset=rt the material at the index considering the given material mode
    func insertMaterial(_ material: Material, at: Int)
    {
        if materialType == .Body {
            currentObject!.bodyMaterials.insert(material, at: at)
        } else {
            currentObject!.borderMaterials.insert(material, at: at)
        }
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

/// The scroll area for the shape selectors
class ShapeScrollArea: MMScrollArea
{
    var app                 : App
    var mouseDownPos        : float2
    var mouseIsDown         : Bool = false
    
    var dragSource          : ShapeSelectorDrag? = nil
    var shapeAtMouse        : Shape?
    
    var delegate            : ObjectMaxDelegate!
    
    init(_ view: MMView, app: App, delegate: ObjectMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        mouseDownPos = float2()
        super.init(view, orientation:.Vertical)
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        mouseDownPos.x = event.x - rect.x
        mouseDownPos.y = event.y - rect.y - offsetY
        mouseIsDown = true
        shapeAtMouse = delegate.shapeSelector.selectAt(mouseDownPos.x,mouseDownPos.y)
        delegate.app.gizmo.setObject(delegate.selObject, rootObject: delegate.currentObject, context: delegate.gizmoContext, materialType: delegate.materialType)
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        if mouseIsDown && dragSource == nil {
            dragSource = delegate.shapeSelector.createDragSource(mouseDownPos.x,mouseDownPos.y)
            dragSource?.sourceWidget = self
            mmView.dragStarted(source: dragSource!)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent) {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
        mmView.unlockFramerate()
        mouseIsDown = false
    }
}

/// The scroll area for the component selectors
class ComponentScrollArea: MMScrollArea
{
    var app                 : App
    var mouseDownPos        : float2
    var mouseIsDown         : Bool = false
    
    var dragSource          : MaterialSelectorDrag? = nil
    var shapeAtMouse        : Material?
    
    var delegate            : ObjectMaxDelegate!
    
    init(_ view: MMView, app: App, delegate: ObjectMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        mouseDownPos = float2()
        super.init(view, orientation:.Vertical, widget: delegate.componentTexture)
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        mouseDownPos.x = event.x - rect.x
        mouseDownPos.y = event.y - rect.y - offsetY
        mouseIsDown = true
        shapeAtMouse = delegate.componentSelector.selectMaterialAt(mouseDownPos.x,mouseDownPos.y)
        delegate.app.gizmo.setObject(delegate.selObject, rootObject: delegate.currentObject, context: delegate.gizmoContext, materialType: delegate.materialType)
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        delegate.materialsTab.mouseMoved(event)
        if mouseIsDown && dragSource == nil {
            dragSource = delegate.componentSelector.createMaterialDragSource(mouseDownPos.x,mouseDownPos.y)
            dragSource?.sourceWidget = self
            mmView.dragStarted(source: dragSource!)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent) {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
        mmView.unlockFramerate()
        mouseIsDown = false
    }
}

/// The scroll area for the compound selectors
class CompoundScrollArea: MMScrollArea
{
    var app                 : App
    var mouseDownPos        : float2
    var mouseIsDown         : Bool = false
    
    var dragSource          : MaterialSelectorDrag? = nil
    var shapeAtMouse        : Material?
    
    var delegate            : ObjectMaxDelegate!
    
    init(_ view: MMView, app: App, delegate: ObjectMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        mouseDownPos = float2()
        super.init(view, orientation:.Vertical, widget: delegate.compoundTexture)
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        mouseDownPos.x = event.x - rect.x
        mouseDownPos.y = event.y - rect.y - offsetY
        mouseIsDown = true
        shapeAtMouse = delegate.compoundSelector.selectMaterialAt(mouseDownPos.x,mouseDownPos.y)
        delegate.app.gizmo.setObject(delegate.selObject, rootObject: delegate.currentObject, context: delegate.gizmoContext, materialType: delegate.materialType)
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        delegate.materialsTab.mouseMoved(event)
        if mouseIsDown && dragSource == nil {
            dragSource = delegate.compoundSelector.createMaterialDragSource(mouseDownPos.x,mouseDownPos.y)
            dragSource?.sourceWidget = self
            mmView.dragStarted(source: dragSource!)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent) {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
        mmView.unlockFramerate()
        mouseIsDown = false
    }
}

/// Object List Widget
class ObjectListWidget : MMWidget
{
    var app             : App
    var margin          : Float = 2
    var delegate        : ObjectMaxDelegate
    
    var objectSize      : float2 = float2(80,24)
    var objectMargin    : float2 = float2(10,10)
    
    var objectTree      : ObjectTree
    
    var xOffset         : Float = 0
    var yOffset         : Float = 0
    
    var dispatched      : Bool = false

    init(_ view: MMView, app: App, delegate: ObjectMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        objectTree = ObjectTree(delegate.currentObject!)
        super.init(view)
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        xOffset -= event.deltaX!
        yOffset -= event.deltaY!
        
        if !dispatched {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.mmView.unlockFramerate()
                self.dispatched = false
            }
            dispatched = true
        }
        
        if mmView.maxFramerateLocks == 0 {
            mmView.lockFramerate()
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        let selObject = getObjectAt(event.x, event.y)
        if selObject != nil {
            delegate.setSelectedObject(selObject!)
        }
    }
    
    func getObjectAt(_ xPos: Float, _ yPos: Float) -> Object?
    {
        for item in objectTree.flat {
            if item.rect.contains(xPos, yPos) {
                return item.object
            }
        }
        return nil
    }
    
    func draw(object: Object)
    {
        // Background
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 40, borderSize: 1, fillColor : SIMD4<Float>(0.098, 0.098, 0.098, 1.000), borderColor: SIMD4<Float>(0.286, 0.286, 0.286, 1.000) )
        
        //
        
        mmView.renderer.setClipRect(rect)
        var y : Float = 20
        
        func drawRow(items: [ObjectTreeItem])
        {
            let count : Float = Float(items.count)
            var x : Float = (rect.width - (count * objectSize.x + (count-1) *  objectMargin.x)) / 2
            
            for item in items
            {
                let fillColor : SIMD4<Float>
                let textColor : SIMD4<Float>

                item.rect.x = rect.x + x + xOffset
                item.rect.y = rect.y + y + yOffset
                item.rect.width = objectSize.x
                item.rect.height = objectSize.y

                if delegate.selObject!.uuid == item.object.uuid {
                    fillColor = SIMD4<Float>(0.537, 0.537, 0.537, 1.000)
                    textColor = SIMD4<Float>(0,0,0,1)
                } else {
                    fillColor = SIMD4<Float>(repeating: 0)
                    textColor = SIMD4<Float>(0.537, 0.537, 0.537, 1.000)
                }
                
                let borderSize : Float = 1
                
                mmView.drawBox.draw( x: item.rect.x + 1, y: item.rect.y, width: objectSize.x, height: objectSize.y, round: 6, borderSize: borderSize, fillColor: fillColor, borderColor: SIMD4<Float>(0.537, 0.537, 0.537, 1.000) )
                
                mmView.drawText.drawTextCentered(mmView.openSans, text: item.parentItem != nil ? item.object.name : "Root", x: item.rect.x, y: item.rect.y, width: objectSize.x, height: objectSize.y, scale: 0.3, color: textColor)
                
                if item.parentItem != nil {
                    let pRect = item.parentItem!.rect
                    let pX : Float = pRect.x + pRect.width / 2
                    let pY : Float = pRect.y + pRect.height - 1
                    
                    mmView.drawLine.draw(sx: pX, sy: pY, ex: item.rect.x + item.rect.width / 2, ey: item.rect.y + 1, radius: 1, fillColor: SIMD4<Float>(repeating: 1))
                }
                x += objectSize.x + objectMargin.x
            }
        }
        
        for row in objectTree.rows {
            drawRow(items: row)
            y += objectSize.y + objectMargin.y
        }
        mmView.renderer.setClipRect()
    }
}

/// The object widget in the right region
class ObjectWidget : MMWidget
{
    var app                 : App
    var label               : MMTextLabel
    var menuWidget          : MMMenuWidget
    var objectListWidget    : ObjectListWidget
    var delegate            : ObjectMaxDelegate
    
    init(_ view: MMView, app: App, delegate: ObjectMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        label = MMTextLabel(view, font: view.openSans, text:"", scale: 0.44 )//color: SIMD4<Float>(0.506, 0.506, 0.506, 1.000))
        objectListWidget = ObjectListWidget(view, app: app, delegate: delegate)
        
        // --- Object Menu
        var objectMenuItems = [
            MMMenuItem( text: "Add Child Object", cb: {} ),
            MMMenuItem( text: "Rename Object", cb: {} ),
            MMMenuItem( text: "Delete Object", cb: {} )
        ]
        menuWidget = MMMenuWidget( view, items: objectMenuItems )
        
        super.init(view)
        
        // Add Child CB
        menuWidget.items[0].cb = {
            let object = delegate.selObject!
            getStringDialog(view: view, title: "Add Child Object", message: "Object name", defaultValue: "New Object", cb: { (name) -> Void in
                let child = Object()
                child.name = name
                child.label?.setText(name)
                child.maxDelegate = delegate.currentObject!.maxDelegate
                object.childObjects.append(child)
                delegate.selObject = child
                delegate.shapeListChanged = true
                delegate.updateObjectHierarchy()
                
                func objectStatusChanged(_ object: Object, _ child: Object)
                {
                    self.mmView.undoManager!.registerUndo(withTarget: self) { target in
                        
                        if let index = object.childObjects.firstIndex(where: { $0.uuid == child.uuid }) {
                            object.childObjects.remove(at: index)
                            delegate.selObject = delegate.currentObject!
                            delegate.shapeListChanged = true
                            delegate.updateObjectHierarchy()
                            self.mmView.update()
                        } else {
                            object.childObjects.append(child)
                            delegate.selObject = child
                            delegate.shapeListChanged = true
                            delegate.updateObjectHierarchy()
                            self.mmView.update()
                        }
                        objectStatusChanged(object, child)
                    }
                }
                objectStatusChanged(object, child)
                self.mmView.update()
            } )
        }
        
        // Rename Child CB
        menuWidget.items[1].cb = {
            let object = delegate.selObject!
            getStringDialog(view: view, title: "Rename Object", message: "Enter new name", defaultValue: object.name, cb: { (name) -> Void in
                let oldName = object.name
                object.name = name
                object.label?.setText(name)
                delegate.app!.nodeGraph.updateMasterNodes(object)
                delegate.app!.nodeGraph.updateContent(.Objects)
                
                func objectNameChanged(_ oldName: String, _ newName: String)
                {
                    self.mmView.undoManager!.registerUndo(withTarget: self) { target in
                        object.name = newName
                        object.label?.setText(newName)
                        delegate.app!.nodeGraph.updateMasterNodes(object)
                        delegate.app!.nodeGraph.updateContent(.Objects)
                        objectNameChanged(newName, oldName)
                        self.mmView.update()
                    }
                }
                objectNameChanged(name, oldName)
                self.mmView.update()
            } )
        }
        
        // Delete Child CB
        menuWidget.items[2].cb = {
            let object = delegate.selObject!
            if object.uuid != delegate.currentObject!.uuid {
                
                // --- Get Parent
                var parentObject : Object? = nil
                func checkParent(_ parent: Object)
                {
                    for child in parent.childObjects {
                        if child.uuid == object.uuid {
                            parentObject = parent
                        } else {
                            checkParent(child)
                        }
                    }
                }
                
                let root = delegate.currentObject!
                checkParent(root)
                // ---
                
                if let parent = parentObject {
                
                    // Remove object from parent
                    if let index = parent.childObjects.firstIndex(where: { $0.uuid == object.uuid }) {
                        parent.childObjects.remove(at: index)
                        delegate.selObject = delegate.currentObject!
                        delegate.shapeListChanged = true
                        delegate.updateObjectHierarchy()
                        self.mmView.update()
                    }
                    
                    // Undo / Redo
                    func objectStatusChanged(_ object: Object, _ child: Object)
                    {
                        self.mmView.undoManager!.registerUndo(withTarget: self) { target in
                     
                            if let index = object.childObjects.firstIndex(where: { $0.uuid == child.uuid }) {
                                object.childObjects.remove(at: index)
                                delegate.selObject = delegate.currentObject!
                                delegate.shapeListChanged = true
                                delegate.updateObjectHierarchy()
                                delegate.app.updateObjectPreview(root)
                                self.mmView.update()
                            } else {
                                object.childObjects.append(child)
                                delegate.selObject = child
                                delegate.shapeListChanged = true
                                delegate.updateObjectHierarchy()
                                delegate.app.updateObjectPreview(root)
                                self.mmView.update()
                            }
                            objectStatusChanged(object, child)
                        }
                    }
                    objectStatusChanged(parent, object)
                    delegate.app.updateObjectPreview(root)
                    self.mmView.update()
                }
            }
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        //mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, borderSize: 1,  fillColor : SIMD4<Float>(0.275, 0.275, 0.275, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
        
        if let object = delegate.selObject {
            label.setText(object.name)
            label.drawCenteredY( x: rect.x + 14, y: rect.y, width: rect.width, height: 30 )
            
            objectListWidget.rect.x = rect.x
            objectListWidget.rect.y = rect.y + 30
            objectListWidget.rect.width = rect.width - 1
            objectListWidget.rect.height = rect.height - 30
            
            objectListWidget.draw(object: object)
        }
        
        menuWidget.rect.x = rect.x + rect.width - 45
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
    }
}

/// The scroll area for the shapes list in the right region
class ShapeListScrollArea: MMScrollArea
{
    var app                 : App
    var mouseDownPos        : float2
    var mouseIsDown         : Bool = false
    
    var label               : MMTextLabel
    var dragSource          : ShapeSelectorDrag? = nil
    var shapeAtMouse        : Shape?
    
    var delegate            : ObjectMaxDelegate!
    
    init(_ view: MMView, app: App, delegate: ObjectMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        label = MMTextLabel(view, font: view.openSans, text:"Shapes", scale: 0.44 )

        mouseDownPos = float2()
        super.init(view, orientation:.Vertical)
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        
        mouseMoved(event)

        mouseDownPos.x = event.x - rect.x
        mouseDownPos.y = event.y - rect.y - offsetY
        mouseIsDown = true

        let shapeList = delegate.shapeList!
        
        delegate.shapeListChanged = shapeList.selectAt(mouseDownPos.x, mouseDownPos.y, multiSelect: mmView.shiftIsDown)
        
        // --- Move up / down
        if shapeList.hoverState != .None {
            let object = delegate.currentObject
            if shapeList.hoverState == .HoverUp && object!.shapes.count > 1 && shapeList.hoverIndex > 0 {
                let shape = object!.shapes.remove(at: shapeList.hoverIndex)
                object!.shapes.insert(shape, at: shapeList.hoverIndex - 1)
            } else
            if shapeList.hoverState == .HoverDown && object!.shapes.count > 1 && shapeList.hoverIndex < object!.shapes.count-1 {
                    let shape = object!.shapes.remove(at: shapeList.hoverIndex)
                    object!.shapes.insert(shape, at: shapeList.hoverIndex + 1)
            } else
            if shapeList.hoverState == .Close && shapeList.hoverIndex >= 0 && shapeList.hoverIndex < object!.shapes.count {
                deleteAtIndex(index: shapeList.hoverIndex)
                delegate.shapeList.hoverAt(mouseDownPos.x, mouseDownPos.y)
                return
            }
            
            shapeList.hoverData[0] = -1
            shapeList.hoverIndex = -1
        }
        // ---
        
        if delegate.shapeListChanged {
            delegate.update(true)
            delegate.app.gizmo.setObject(delegate.selObject, rootObject: delegate.currentObject, context: delegate.gizmoContext, materialType: delegate.materialType)
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        if !mouseIsDown {
            if delegate.shapeList.hoverAt(event.x - rect.x, event.y - rect.y - offsetY) {
                delegate.shapeList.update()
                mmView.update()
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent) {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
    }
    
    func deleteAtIndex(index: Int)
    {
        let oldSelection = delegate.selObject!.selectedShapes
        let object = delegate.currentObject!
        let shape = object.shapes[index]

        func shapeStatusChanged(_ objectUUID: UUID,_ shape: Shape,_ index: Int)
        {
            let object = globalApp!.nodeGraph.getNodeForUUID(objectUUID) as! Object
            mmView.undoManager!.registerUndo(withTarget: self) { target in
                
                let localIndex = object.shapes.firstIndex(where: { $0.uuid == shape.uuid })
                if localIndex != nil {
                    object.shapes.remove(at: localIndex!)
                    object.selectedShapes = []
                    
                    self.delegate.shapeListChanged = true
                    self.delegate.app.gizmo.setObject(self.delegate.selObject!, context: .ShapeEditor)
                    self.delegate.update(true)
                    self.mmView.update()
                } else {
                    object.shapes.insert(shape, at: index)
                    object.selectedShapes = [shape.uuid]
                    
                    self.delegate.shapeListChanged = true
                    self.delegate.app.gizmo.setObject(self.delegate.selObject!, context: .ShapeEditor)
                    self.delegate.update(true)
                    self.mmView.update()
                }
                shapeStatusChanged(object.uuid, shape, index)
                self.app.updateObjectPreview(object)
            }
            globalApp!.nodeGraph.mmView.undoManager!.setActionName("Shape Removed")
        }
        
        shapeStatusChanged(object.uuid, shape, index)
        
        object.shapes.remove(at: index)
        object.selectedShapes = []
        
        self.delegate.shapeListChanged = true
        self.delegate.app.gizmo.setObject(self.delegate.selObject!, context: .ShapeEditor)
        self.delegate.update(true)
        self.mmView.update()
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        //mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, borderSize: 1,  fillColor : SIMD4<Float>(0.275, 0.275, 0.275, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
        
        label.drawCenteredY( x: rect.x + 10, y: rect.y, width: rect.width, height: 30 )
        
        //mmView.drawBox.draw( x: rect.x, y: rect.y + 30, width: rect.width, height: rect.height + 1 - 30, round: 0, borderSize: 1,  fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
    }
}

/// The scroll area for the material list in the right region
class MaterialListScrollArea: MMScrollArea
{
    var app                 : App
    var mouseDownPos        : float2
    var mouseIsDown         : Bool = false
    
    var label               : MMTextLabel
    var dragSource          : MaterialSelectorDrag? = nil
    var shapeAtMouse        : Material?
    
    var delegate            : ObjectMaxDelegate!
    
    var tabButton           : MMTabButtonWidget!
    var floatWidget         : MMFloatWidget!
    
    init(_ view: MMView, app: App, delegate: ObjectMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        mouseDownPos = float2()
        label = MMTextLabel(view, font: view.openSans, text:"Materials", scale: 0.44 )

        var borderlessSkin = MMSkinButton()
        borderlessSkin.margin = MMMargin( 4, 4, 4, 4 )
        borderlessSkin.borderSize = 0
        borderlessSkin.height = view.skin.Button.height - 5
        borderlessSkin.fontScale = 0.44
        borderlessSkin.round = 24
        
        tabButton = MMTabButtonWidget(view, skinToUse: borderlessSkin)

        tabButton.addTab("Interior")
        tabButton.addTab("Border")
        
        floatWidget = MMFloatWidget(view, range: float2(0, 40), int: true, value: 2)

        super.init(view, orientation:.Vertical)
        
        tabButton.clicked = { (event) -> Void in
            
            if self.tabButton.index == 0 {
                self.delegate.materialType = .Body
            } else {
                self.delegate.materialType = .Border
            }
            
            self.delegate.materialListChanged = true
            delegate.app.gizmo.setObject(delegate.selObject!, rootObject: delegate.currentObject, context: delegate.gizmoContext, materialType: delegate.materialType)
        }
        
        floatWidget.changed = { (value) -> Void in
            delegate.selObject!.properties["border"] = value
            delegate.update()
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        
        mouseMoved(event)
        
        mouseDownPos.x = event.x - rect.x
        mouseDownPos.y = event.y - rect.y - offsetY
        mouseIsDown = true
        
        let materialList = delegate.materialList!
        
        delegate.materialListChanged = delegate.materialList.selectAt(mouseDownPos.x,mouseDownPos.y, multiSelect: mmView.shiftIsDown)
        
        // --- Move up / down
        if materialList.hoverState != .None {
            if materialList.hoverState == .HoverUp && delegate.materialCount() > 1 && materialList.hoverIndex > 0 {
                let material = delegate.removeMaterial(at: materialList.hoverIndex)
                delegate.insertMaterial(material, at: materialList.hoverIndex - 1)
            } else
            if materialList.hoverState == .HoverDown && delegate.materialCount() > 1 && materialList.hoverIndex < delegate.materialCount()-1 {
                let material = delegate.removeMaterial(at: materialList.hoverIndex)
                delegate.insertMaterial(material, at: materialList.hoverIndex + 1)
            } else
            if materialList.hoverState == .Close && materialList.hoverIndex >= 0 && materialList.hoverIndex < delegate.materialCount()
            {
                deleteAtIndex(index: materialList.hoverIndex)
                delegate.materialList.hoverAt(mouseDownPos.x, mouseDownPos.y)
                return
            }
            
            materialList.hoverData[0] = -1
            materialList.hoverIndex = -1
        }
        // ---
        
        if delegate.materialListChanged {
            delegate.update(true)
            delegate.app.gizmo.setObject(delegate.selObject, rootObject: delegate.currentObject, context: delegate.gizmoContext, materialType: delegate.materialType)
        }
    }
    
    func deleteAtIndex(index: Int)
    {
        let object = delegate.currentObject!
        let materialType = delegate.materialType
        
        let material : Material
        if materialType == .Body {
            material = object.bodyMaterials[index]
        } else {
            material = object.borderMaterials[index]
        }
        
        func update()
        {
            delegate.materialListChanged = true
            delegate.app.gizmo.setObject(delegate.selObject!, rootObject: delegate.currentObject, context: .MaterialEditor, materialType: delegate.materialType)
            delegate.update(true)
            
            self.app.updateObjectPreview(object)
        }

        func materialStatusChanged(_ objectUUID: UUID, _ material: Material,_ index: Int, _ materialType: Object.MaterialType)
        {
            let object = globalApp!.nodeGraph.getNodeForUUID(objectUUID) as! Object
            
            mmView.undoManager!.registerUndo(withTarget: self) { target in
                
                if materialType == .Body {
                    let localIndex = object.bodyMaterials.firstIndex(where: { $0.uuid == material.uuid })
                    if localIndex != nil {
                        object.bodyMaterials.remove(at: localIndex!)
                        object.selectedBodyMaterials = []
                    } else {
                        object.bodyMaterials.insert(material, at: index)
                        object.selectedBodyMaterials = [material.uuid]
                    }
                } else
                if materialType == .Border {
                    let localIndex = object.borderMaterials.firstIndex(where: { $0.uuid == material.uuid })
                    if localIndex != nil {
                        object.borderMaterials.remove(at: localIndex!)
                        object.selectedBorderMaterials = []
                    } else {
                        object.borderMaterials.insert(material, at: index)
                        object.selectedBorderMaterials = [material.uuid]
                    }
                }
                materialStatusChanged(objectUUID, material, index, materialType)
                update()
            }
        }
        
        materialStatusChanged(object.uuid, material, index, materialType)
        
        if materialType == .Body {
            object.bodyMaterials.remove(at: index)
            object.selectedBodyMaterials = []
        } else {
            object.borderMaterials.remove(at: index)
            object.selectedBorderMaterials = []
        }
        
        update()
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        if !mouseIsDown {
            if delegate.materialList.hoverAt(event.x - rect.x, event.y - rect.y - offsetY) {
                delegate.materialList.update()
                mmView.update()
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent) {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
    }
    
    func registerWidgets()
    {
        mmView.registerWidgets(widgets: tabButton, floatWidget)
    }
    
    func deregisterWidgets()
    {
        mmView.deregisterWidgets(widgets: tabButton, floatWidget)
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        tabButton.rect.x = rect.x + 10
        tabButton.rect.y = rect.y + 3
        tabButton.draw()
        
        floatWidget.rect.copy( tabButton.rect )
        floatWidget.rect.x += tabButton.rect.width + 10
        floatWidget.rect.width = 90
        floatWidget.draw()
    }
}

/// Sequence widget for the bottom timeline
class SequenceWidget : MMWidget
{
    var app                 : App
    var label               : MMTextLabel
    var menuWidget          : MMMenuWidget
    
    var listWidget          : MMListWidget
    var items               : [MMListWidgetItem] = []
    
    var delegate            : ObjectMaxDelegate
    
    init(_ view: MMView, app: App, delegate: ObjectMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        label = MMTextLabel(view, font: view.openSans, text:"", scale: 0.44 )//color: SIMD4<Float>(0.506, 0.506, 0.506, 1.000))
        listWidget = MMListWidget(view)
        listWidget.itemRound = 14
        //listWidget.unitSize = 45

        // ---  Menu
        
        let sequenceMenuItems = [
            MMMenuItem( text: "Add", cb: {} ),
            MMMenuItem( text: "Rename", cb: {} ),
            MMMenuItem( text: "Delete", cb: {} )
        ]
        menuWidget = MMMenuWidget( view, items: sequenceMenuItems )
        
        super.init(view)
        
        // ---
        
        // Add Animation
        menuWidget.items[0].cb = {
            getStringDialog(view: view, title: "New Animation", message: "Animation name", defaultValue: "New Animation", cb: { (name) -> Void in
                let object = self.delegate.currentObject!
                let seq = MMTlSequence()
                seq.name = name
                object.sequences.append(seq)
                object.setSequence(sequence:seq, timeline: delegate.app!.timeline)
                self.listWidget.selectedItems = [seq.uuid]
                delegate.app!.nodeGraph.updateMasterNodes(object)
                
                self.mmView.update()
                
                func seqStatusChanged(_ object: Object, _ seq: MMTlSequence)
                {
                    self.mmView.undoManager!.registerUndo(withTarget: self) { target in
                        
                        if let index = object.sequences.firstIndex(where: { $0.uuid == seq.uuid }) {
                            object.sequences.remove(at: index)
                            self.listWidget.selectedItems = object.sequences.count > 0 ? [object.sequences[0].uuid] : []
                            delegate.app!.nodeGraph.updateMasterNodes(object)
                            self.mmView.update()
                        } else {
                            object.sequences.append(seq)
                            object.setSequence(sequence:seq, timeline: delegate.app!.timeline)
                            self.listWidget.selectedItems = [seq.uuid]
                            delegate.app!.nodeGraph.updateMasterNodes(object)
                            self.mmView.update()
                        }
                        seqStatusChanged(object, seq)
                    }
                }
                seqStatusChanged(object, seq)
            } )
        }
        
        // Rename Animation
        menuWidget.items[1].cb = {
            if var item = self.getCurrentItem() {
                getStringDialog(view: view, title: "Rename Animation", message: "New name", defaultValue: item.name, cb: { (name) -> Void in
                    let oldName = item.name
                    item.name = name
                    self.delegate.app!.nodeGraph.updateMasterNodes(self.delegate.currentObject!)
                    
                    let object = self.delegate.currentObject!
                    func seqNameChanged(_ oldName: String, _ newName: String)
                    {
                        self.mmView.undoManager!.registerUndo(withTarget: self) { target in
                            item.name = newName
                            self.delegate.app!.nodeGraph.updateMasterNodes(object)
                            self.mmView.update()
                            seqNameChanged(oldName, name)
                        }
                    }
                    seqNameChanged(name, oldName)
                    self.mmView.update()
                } )
            }
        }
        
        // Remove Animation
        menuWidget.items[2].cb = {
            if self.items.count < 2 { return }

            if let item = self.getCurrentItem() {
                let object = self.delegate.currentObject!
                
                object.sequences.remove(at: object.sequences.firstIndex(where: { $0.uuid == item.uuid })!)
                self.listWidget.selectedItems = [object.sequences[0].uuid]
                delegate.app!.nodeGraph.updateMasterNodes(object)
                self.mmView.update()
                var sequence : MMTlSequence? = nil
                
                for s in object.sequences {
                    if s.uuid == item.uuid {
                        sequence = s
                    }
                }
                
                if let seq = sequence {
                    func seqStatusChanged(_ object: Object, _ seq: MMTlSequence)
                    {
                        self.mmView.undoManager!.registerUndo(withTarget: self) { target in
                            
                            if let index = object.sequences.firstIndex(where: { $0.uuid == seq.uuid }) {
                                object.sequences.remove(at: index)
                                self.listWidget.selectedItems = object.sequences.count > 0 ? [object.sequences[0].uuid] : []
                                delegate.app!.nodeGraph.updateMasterNodes(object)
                                self.mmView.update()
                            } else {
                                object.sequences.append(seq)
                                object.setSequence(sequence:seq, timeline: delegate.app!.timeline)
                                self.listWidget.selectedItems = [seq.uuid]
                                delegate.app!.nodeGraph.updateMasterNodes(object)
                                self.mmView.update()
                            }
                            seqStatusChanged(object, seq)
                        }
                    }
                    seqStatusChanged(object, seq)
                }
            }
        }
    }
    
    func build(items: [MMListWidgetItem])
    {
        self.items = items
        listWidget.build(items: items)
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
        mmView.drawBox.draw( x: rect.x, y: rect.y - 3, width: rect.width, height: rect.height+2, round: 0, borderSize: 0, fillColor : SIMD4<Float>(0.169, 0.169, 0.169, 1.000))
        
        label.setText("Animation Sequence")
        label.drawCenteredY( x: rect.x + 10, y: rect.y, width: rect.width, height: 30 )
        
        menuWidget.rect.x = rect.x + rect.width - 45
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
        
        //mmView.drawBox.draw( x: rect.x, y: rect.y + 30, width: rect.width, height: rect.height - 31, round: 40, borderSize: 2,  fillColor : SIMD4<Float>(0, 0, 0, 0), borderColor: SIMD4<Float>(0.286, 0.286, 0.286, 1.000) )

        listWidget.rect.x = rect.x + 1
        listWidget.rect.y = rect.y + 32
        listWidget.rect.width = rect.width - 2
        listWidget.rect.height = rect.height - 35
        listWidget.draw()
        
        listWidget.drawRoundedBorder(backColor: SIMD4<Float>(0.169, 0.169, 0.169, 1.000), borderColor: SIMD4<Float>(0.286, 0.286, 0.286, 1.000))
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        let changed = listWidget.selectAt(event.x - rect.x, (event.y - rect.y) - 30, items: items)
        if changed {
            listWidget.build(items: items)
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        listWidget.mouseScrolled(event)
    }
}
