//
//  LayerMaxDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 24/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class SceneMaxDelegate : NodeMaxDelegate {
    
    enum HoverMode
    {
        case None, SideSlider
    }
    
    enum LeftRegionMode
    {
        case Closed, Objects
    }
    
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    var app             : App!
    var mmView          : MMView!

    var hoverMode       : HoverMode = .None
    
    // Top Region
    var timelineButton  : MMButtonWidget!
    
    var screenButton    : MMScrollButton!
    var screenSize      : float2? = nil

    // Left Region
    var leftRegionMode  : LeftRegionMode = .Objects
    var avObjectList    : AvailableObjectList!

    var animating       : Bool = false
    
    // Right Region
    var objectList      : ObjectList!
    var shapeListChanged: Bool = true
    
    // Bottom Region
    var bottomRegionMode: BottomRegionMode = .Open
    
    var sideSliderButton: MMSideSliderWidget!
    var timeline        : MMTimeline!
    var sequenceWidget  : SequenceWidget!

    // ---
    var currentScene    : Scene?
    var camera          : Camera = Camera()
    var patternState    : MTLRenderPipelineState?
    var dispatched      : Bool = false
    
    var screenList      : [Node?] = []

    var zoomBuffer      : Float = 0
    
    override func activate(_ app: App)
    {
        self.app = app
        self.mmView = app.mmView
        currentScene = app.nodeGraph.maximizedNode as? Scene
        
        // Top Region
        if timelineButton == nil {
            timelineButton = MMButtonWidget( app.mmView, text: "Timeline" )
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
        
        avObjectList = AvailableObjectList(app.mmView, app:app)
        
        app.leftRegion!.rect.width = 200
        
        // Right Region
        if objectList == nil {
            objectList = ObjectList(app.mmView, app:app, delegate: self)
        } else {
            objectList!.rebuildList()
        }
        app.rightRegion!.rect.width = 300

        // Editor Region
        if patternState == nil {
            let function = app.mmView.renderer!.defaultLibrary.makeFunction( name: "moduloPattern" )
            patternState = app.mmView.renderer!.createNewPipelineState( function! )
            
            sideSliderButton = MMSideSliderWidget(app.mmView)
        }
        
        // Bottom Region
        
        if timeline == nil {
            timeline = MMTimeline(app.mmView)
            timeline.changedCB = { (frame) in
                self.update()
            }
            //sequenceWidget = SequenceWidget(app.mmView, app: app, delegate: self)
        }
        timeline.activate()
        
        app.mmView.registerWidgets( widgets: timelineButton, app.closeButton, screenButton, avObjectList, objectList.menuWidget, objectList)
        
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
        
        //update()
        updateGizmo()
    }
    
    override func deactivate()
    {
        timeline.deactivate()
        app.mmView.deregisterWidgets( widgets: timelineButton, app.closeButton, screenButton, avObjectList, objectList.menuWidget, objectList)
        //currentScene!.updatePreview(nodeGraph: app.nodeGraph)
        
        for inst in currentScene!.objectInstances {
            inst.properties = inst.instance!.properties
        }
        
        app.nodeGraph.updateNodes()
        currentScene!.updatePreview(nodeGraph: app.nodeGraph)
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
            app.gizmo.rect.copy(region.rect)
            drawPattern(region)
            
            if let texture = app.nodeGraph.sceneRenderer.fragment.texture, currentScene!.builderInstance != nil {
                if currentScene!.updateStatus != .Valid {
                    update(currentScene!.updateStatus == .NeedsHardUpdate)
                    currentScene!.updateStatus = .Valid
                }
                if Float(texture.width) != region.rect.width || Float(texture.height) != region.rect.height {
                    app.nodeGraph.sceneRenderer.render(width: region.rect.width, height: region.rect.height, camera: camera, instance: currentScene!.builderInstance!)
                    app.nodeGraph.mmView.update()
                } else {
                    app.mmView.drawTexture.draw(texture, x: region.rect.x, y: region.rect.y)
                }
            }
            
            mmView.renderer!.setClipRect(region.rect)
            if let screen = screenSize {
                let x: Float = region.rect.x + region.rect.width / 2 - (camera.xPos + screen.x/2 * camera.zoom)
                let y: Float = region.rect.y + region.rect.height / 2 - (camera.yPos + screen.y/2 * camera.zoom)
                
                mmView.drawBox.draw( x: x, y: y, width: screen.x * camera.zoom, height: screen.y * camera.zoom, round: 0, borderSize: 2, fillColor : float4(0.161, 0.165, 0.188, 0.5), borderColor: float4(0.5, 0.5, 0.5, 0.5) )
            }
            
            app.gizmo.scale = camera.zoom
            app.gizmo.draw()
            app.changed = false
            
            // SideSlider
            sideSliderButton.rect.x = region.rect.x - 40
            sideSliderButton.rect.y = region.rect.y + (region.rect.height - 70) / 2
            sideSliderButton.rect.width = 70
            sideSliderButton.rect.height = 70
            sideSliderButton.draw()
            mmView.renderer.setClipRect()
        } else
        if region.type == .Top {
            //region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: objectsButton )
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: timelineButton, app.closeButton)
            
            timelineButton.draw()
            app.closeButton.draw()
            
            screenButton.rect.x = region.rect.x + 10
            screenButton.rect.y = 4 + 44
            screenButton.draw()
        } else
        if region.type == .Left {
            let leftRegion = app.leftRegion!
            if leftRegionMode != .Closed {
                
                app.mmView.drawBox.draw( x: leftRegion.rect.x, y: leftRegion.rect.y, width: leftRegion.rect.width, height: leftRegion.rect.height, round: 0, borderSize: 0,  fillColor : float4( 0.169, 0.169, 0.169, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
                
                avObjectList!.rect.copy(leftRegion.rect)
                avObjectList!.draw()
            } else {
                leftRegion.rect.width = 0
            }
        } else
        if region.type == .Right {
            
            let rightRegion = app.rightRegion!

            rightRegion.rect.width = 300
            rightRegion.rect.x = app.mmView.renderer.cWidth - rightRegion.rect.width
            
            mmView.drawBox.draw( x: rightRegion.rect.x, y: rightRegion.rect.y, width: rightRegion.rect.width, height: rightRegion.rect.height, round: 0, borderSize: 1,  fillColor : float4(0.169, 0.169, 0.169, 1))
            
            objectList.rect.width = rightRegion.rect.width
            objectList.rect.height = rightRegion.rect.height
            
            rightRegion.layoutV(startX: rightRegion.rect.x, startY: rightRegion.rect.y, spacing: 0, widgets: objectList)
            
            objectList.draw()
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
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseMoved(event)
        if hoverMode == .SideSlider {
            
            sideSliderButton.removeState(.Hover)
            self.setLeftRegionMode(.Objects)

            hoverMode = .None
            return
        } else {
            app.gizmo.mouseDown(event)
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
        
        //
        app.gizmo.mouseMoved(event)
    }
    
    override func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        if firstTouch == true {
            zoomBuffer = currentScene!.properties["prevMaxScale"] != nil ? currentScene!.properties["prevMaxScale"]! : 1
        }
        
        camera.zoom = zoomBuffer * scale
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

        currentScene!.properties["prevMaxOffX"] = camera.xPos
        currentScene!.properties["prevMaxOffY"] = camera.yPos
        currentScene!.properties["prevMaxScale"] = camera.zoom
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
        } else if leftRegion.rect.width != 200 {
            sideSliderButton.setMode(.Animating)
            app.mmView.startAnimate( startValue: leftRegion.rect.width, endValue: 200, duration: 500, cb: { (value,finished) in
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
    
    /// Returns the current object which is the first object in the selectedObjects array
    func getCurrentObject() -> Object?
    {
        if currentScene!.selectedObjects.isEmpty { return nil }
        
        for inst in currentScene!.objectInstances {
            if inst.uuid == currentScene!.selectedObjects[0] {
                return inst.instance
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
    
    func updateGizmo()
    {
        let object = getCurrentObject()
        app.gizmo.setObject(object, context: .ObjectEditor, inSceneEditor: true)
    }
    
    /// Updates the preview. hard does a rebuild, otherwise just a render
    override func update(_ hard: Bool = false, updateLists: Bool = false)
    {
        if hard == true {
            currentScene!.updatePreview(nodeGraph: app.nodeGraph, hard: true)
            updateGizmo()
        } else {
            currentScene!.updateStatus = .NeedsUpdate
        }
            
        let region = app.editorRegion!
        if let scene = currentScene {
            if let instance = scene.builderInstance {
                app.nodeGraph.sceneRenderer.render(width: region.rect.width, height: region.rect.height, camera: camera, instance: instance)
            }
        }
        
        if updateLists {
            objectList.rebuildList()
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

class AvailableObjectListItem : MMListWidgetItem
{
    var name         : String = ""
    var uuid         : UUID = UUID()
    var color       : float4? = nil
}

struct AvailableObjectListItemDrag : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : float2? = float2()
    var node            : Node? = nil
    var name            : String = ""
}

class AvailableObjectList : MMWidget
{
    var app                 : App
    
    var listWidget          : MMListWidget
    var items               : [AvailableObjectListItem] = []
    
    var mouseIsDown         : Bool = false
    var dragSource          : AvailableObjectListItemDrag?
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        
        listWidget = MMListWidget(view)
        
        for node in app.nodeGraph.nodes {
            if node.type == "Object" {
                let item = AvailableObjectListItem()
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
    func createDragSource(_ x: Float,_ y: Float) -> AvailableObjectListItemDrag?
    {
        if let listItem = listWidget.getCurrentItem() {
            let item = listItem as! AvailableObjectListItem
            var drag = AvailableObjectListItemDrag()
            
            drag.id = "AvailableObjectItem"
            drag.name = item.name
            drag.pWidgetOffset!.x = x
            drag.pWidgetOffset!.y = y.truncatingRemainder(dividingBy: listWidget.unitSize)
            
            for node in app.nodeGraph.nodes {
                if item.uuid == node.uuid {
                    drag.node = node
                }
            }
            
            let texture = listWidget.createShapeThumbnail(item: listItem)
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

// Object Instance List on the Right

class ObjectListItem : MMListWidgetItem
{
    var name         : String = ""
    var uuid         : UUID = UUID()
    var color       : float4? = nil
}

class ObjectList : MMWidget
{
    var app                 : App
    
    var label               : MMTextLabel
    var menuWidget          : MMMenuWidget

    var listWidget          : MMListWidget
    var items               : [ObjectListItem] = []
    
    var mouseIsDown         : Bool = false
    var delegate            : SceneMaxDelegate
    
    init(_ view: MMView, app: App, delegate: SceneMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        listWidget = MMListWidget(view)
        listWidget.supportsClose = true
        listWidget.itemRound = 14

        label = MMTextLabel(view, font: view.openSans, text: "Object Instances", scale: 0.44 )
        label.textYOffset = 0
        
        let menuItems = [
            MMMenuItem( text: "Rename Instance", cb: {} ),
            MMMenuItem( text: "Remove Instance", cb: {} )
        ]
        menuWidget = MMMenuWidget( view, items: menuItems )
        
        super.init(view)
        
        rebuildList()
        // Rename Instance
        menuWidget.items[0].cb = {
            if let item = self.listWidget.getCurrentItem() {
                getStringDialog(view: view, title: "Rename Instance", message: "New name", defaultValue: item.name, cb: { (name) -> Void in
                    
                    for instance in delegate.currentScene!.objectInstances {
                        if instance.uuid == item.uuid {
                            if instance.name != name {
                                
                                func nameChanged(_ oldName: String,_ newName: String)
                                {
                                    self.mmView.undoManager!.registerUndo(withTarget: self) { target in
                                        nameChanged(newName, oldName)
                                        instance.name = newName
                                        self.rebuildList()
                                    }
                                }
                                
                                nameChanged(name, instance.name)
                                instance.name = name
                            }
                            break
                        }
                    }
                    self.rebuildList()
                } )
            }
        }
        // Remove Instance
        menuWidget.items[1].cb = {
            if let item = self.listWidget.getCurrentItem() {
                if let index = self.listWidget.items.firstIndex(where: {$0.uuid == item.uuid}) {
                    self.deleteAt(index)
                }
            }
        }
    }
    
    func rebuildList()
    {
        items = []
        for instance in delegate.currentScene!.objectInstances {
            for node in app.nodeGraph.nodes {
                if node.uuid == instance.objectUUID {
                    
                    let item = ObjectListItem()
                    item.name = instance.name
                    item.uuid = instance.uuid
                    items.append(item)
                }
            }
        }
        listWidget.selectedItems = delegate.currentScene!.selectedObjects
        listWidget.build(items: items, fixedWidth: 300, supportsUpDown: false, supportsClose: true)
        mmView.update()
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        // --- Menu
        //mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, borderSize: 1,  fillColor : float4(0.275, 0.275, 0.275, 1), borderColor: float4( 0, 0, 0, 1 ) )
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
        
        // --- List
        //mmView.drawBox.draw( x: rect.x, y: rect.y + 30, width: rect.width, height: rect.height - 30, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        listWidget.rect.x = rect.x
        listWidget.rect.y = rect.y + 30
        listWidget.rect.width = rect.width
        listWidget.rect.height = rect.height - 30
        
        listWidget.drawRoundedBorder(backColor: SIMD4<Float>(0.169, 0.169, 0.169, 1.000), borderColor: SIMD4<Float>(0.286, 0.286, 0.286, 1.000))
        
        listWidget.draw()
    }
    
    func deleteAt(_ itemIndex: Int)
    {
        if itemIndex >= 0 && itemIndex < items.count {
            let uuid = listWidget.items[itemIndex].uuid
            
            if let index = delegate.currentScene!.objectInstances.firstIndex(where: { $0.uuid == uuid }) {
            
                func instanceStatusChanged(_ instance: ObjectInstance)
                {
                    mmView.undoManager!.registerUndo(withTarget: self) { target in
                        
                        if let index = self.delegate.currentScene!.objectInstances.firstIndex(where: { $0.uuid == instance.uuid }) {
                            self.delegate.currentScene!.objectInstances.remove(at: index)
                            self.listWidget.removeFromSelection(instance.uuid)
                            
                            self.delegate.currentScene!.updatePreview(nodeGraph: self.delegate.app.nodeGraph, hard: true)
                            self.delegate.update(true, updateLists: true)
                        } else {
                            self.delegate.currentScene!.objectInstances.append(instance)
                            self.listWidget.selectedItems = [instance.uuid]
                            self.delegate.currentScene!.updatePreview(nodeGraph: self.delegate.app.nodeGraph, hard: true)
                            self.delegate.update(true, updateLists: true)
                        }
                        instanceStatusChanged(instance)
                    }
                }
                
                let instance = delegate.currentScene!.objectInstances[index]
                instanceStatusChanged(instance)
                
                delegate.currentScene!.objectInstances.remove(at: index)
                delegate.update(true, updateLists: false)
            }
            listWidget.removeFromSelection(uuid)
        }
        delegate.currentScene!.selectedObjects = listWidget.selectedItems
        rebuildList()
        listWidget.build(items: items, fixedWidth: 300, supportsUpDown: false, supportsClose: true)
        delegate.updateGizmo()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        let changed = listWidget.selectAt(event.x - rect.x, (event.y - rect.y) - 30, items: items)
        if changed {
            if listWidget.hoverState == .Close {
                deleteAt(listWidget.hoverIndex)
            } else {
                delegate.currentScene!.selectedObjects = listWidget.selectedItems
                rebuildList()
                listWidget.build(items: items, fixedWidth: 300, supportsUpDown: false, supportsClose: true)
                delegate.updateGizmo()
            }
        }
        mouseIsDown = true
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if !mouseIsDown {
            if listWidget.hoverAt(event.x - rect.x, (event.y - rect.y) - 30) {
                listWidget.update()
                mmView.update()
            }
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
