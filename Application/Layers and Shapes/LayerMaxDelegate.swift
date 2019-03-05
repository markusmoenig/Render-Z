//
//  LayerMaxDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 24/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class LayerMaxDelegate : NodeMaxDelegate {
    
    enum LeftRegionMode
    {
        case Closed, Objects
    }
    
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    var app             : App!
    
    // Top Region
    var objectsButton   : MMButtonWidget!
    var timelineButton  : MMButtonWidget!

    // Left Region
    var leftRegionMode  : LeftRegionMode = .Objects
    var avObjectList    : AvailableObjectList!

    var shapeSelector   : ShapeSelector!
    var textureWidget   : MMTextureWidget!
    var animating       : Bool = false
    
    // Right Region
    var objectList      : ObjectList!
    var shapeListChanged: Bool = true
    
    // Bottom Region
    var bottomRegionMode: BottomRegionMode = .Open
    
    var timeline        : MMTimeline!
    var sequenceWidget  : SequenceWidget!

    // ---
    var currentLayer    : Layer?
    var camera          : Camera = Camera()
    var patternState    : MTLRenderPipelineState?
    var dispatched      : Bool = false

    override func activate(_ app: App)
    {
        self.app = app
        currentLayer = app.nodeGraph.maximizedNode as? Layer
        
        // Top Region
        if objectsButton == nil {
            objectsButton = MMButtonWidget( app.mmView, text: "Objects" )
            timelineButton = MMButtonWidget( app.mmView, text: "Timeline" )
        }
        objectsButton.clicked = { (event) -> Void in
            self.setLeftRegionMode(.Objects)
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
        
        objectsButton.addState( .Checked )
        app.leftRegion!.rect.width = 200
        
        // Right Region
        if objectList == nil {
            objectList = ObjectList(app.mmView, app:app, delegate: self)
        }
        app.rightRegion!.rect.width = 300

        // Editor Region
        if patternState == nil {
            let function = app.mmView.renderer!.defaultLibrary.makeFunction( name: "moduloPattern" )
            patternState = app.mmView.renderer!.createNewPipelineState( function! )
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

        /*
        sequenceWidget.listWidget.selectedItems = []//[currentObject!.sequences[0].uuid]
        sequenceWidget.listWidget.selectionChanged = { (items:[MMListWidgetItem]) -> Void in
            self.currentObject!.currentSequence = items[0] as? MMTlSequence
            self.update()
        }
         
        //timelineButton.addState( .Checked )
        //app.bottomRegion!.rect.height = 100
        
        app.mmView.registerWidgets( widgets: shapesButton, materialsButton, timelineButton, scrollArea, shapeListWidget, objectWidget.menuWidget, objectWidget.objectEditorWidget, timeline, sequenceWidget.menuWidget, sequenceWidget, app.closeButton)
        */
        
        app.mmView.registerWidgets( widgets: objectsButton, timelineButton, app.closeButton, avObjectList, objectList)
        
        update(true)
    }
    
    override func deactivate()
    {
//        timeline.deactivate()
        app.mmView.deregisterWidgets( widgets: objectsButton, timelineButton, app.closeButton, avObjectList, objectList)
        currentLayer!.updatePreview(nodeGraph: app.nodeGraph)
        
        for inst in currentLayer!.objectInstances {
            inst.properties = inst.instance!.properties
        }
        
        currentLayer!.updatePreview(nodeGraph: app.nodeGraph, hard: true)
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
            
            if let instance = currentLayer!.instance {
            
                if instance.texture == nil || instance.texture!.width != Int(region.rect.width) || instance.texture!.height != Int(region.rect.height) {
                    app.nodeGraph.builder.render(width: region.rect.width, height: region.rect.height, instance: instance, camera: camera)
                }
                
                if let texture = instance.texture {
                    
                    app.mmView.drawTexture.draw(texture, x: region.rect.x, y: region.rect.y)
                }
            }
             
            app.gizmo.draw()
            app.changed = false
            
        } else
        if region.type == .Top {
            region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: objectsButton )
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: timelineButton, app.closeButton)
            
            objectsButton.draw()
            timelineButton.draw()
            app.closeButton.draw()
        } else
        if region.type == .Left {
            let leftRegion = app.leftRegion!
            if leftRegionMode != .Closed {
                
                app.mmView.drawBox.draw( x: leftRegion.rect.x, y: leftRegion.rect.y, width: leftRegion.rect.width, height: leftRegion.rect.height, round: 0, borderSize: 0,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
                
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
        app.gizmo.mouseDown(event)
        /*
        if app.gizmo.hoverState == .Inactive && currentObject!.instance != nil {
            let editorRegion = app.editorRegion!
//            app.layerManager.getShapeAt(x: event.x - editorRegion.rect.x, y: event.y - editorRegion.rect.y, multiSelect: app.mmView.shiftIsDown)
            
//            func getShapeAt( x: Float, y: Float, width: Float, height: Float, multiSelect: Bool = false, instance: BuilderInstance, camera: Camera, timeline: MMTimeline)

            app.builder.getShapeAt(x: event.x - editorRegion.rect.x, y: event.y - editorRegion.rect.y, width: editorRegion.rect.width, height: editorRegion.rect.height, multiSelect: app.mmView.shiftIsDown, instance: currentObject!.instance!, camera: camera, timeline: timeline)
            update()
        }*/
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        app.gizmo.mouseUp(event)
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        app.gizmo.mouseMoved(event)
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
         camera.xPos += event.deltaX! * 2
         camera.yPos += event.deltaY! * 2
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
                    self.objectsButton.removeState( .Checked )
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
    
    /// Rebuilds the shape list in the right region
    func buildShapeList()
    {
//        shapeList.build( width: shapeListWidget.rect.width, object: currentObject!)
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
        if currentLayer!.selectedObjects.isEmpty { return nil }
        
        for inst in currentLayer!.objectInstances {
            if inst.uuid == currentLayer!.selectedObjects[0] {
                return inst.instance
            }
        }
        
        return nil
    }
    
    func updateGizmo()
    {
        let object = getCurrentObject()
        app.gizmo.setObject(object, context: .ObjectEditor)
    }
    
    /// Updates the preview. hard does a rebuild, otherwise just a render
    override func update(_ hard: Bool = false)
    {
        if hard {
            let objects = currentLayer!.createInstances(nodeGraph: app.nodeGraph)
            
            currentLayer!.instance = app.nodeGraph.builder.buildObjects(objects: objects, camera: camera)
            updateGizmo()
        } else {
            let region = app.editorRegion!
            if currentLayer!.instance != nil {
                app.nodeGraph.builder.render(width: region.rect.width, height: region.rect.height, instance: currentLayer!.instance!, camera: camera)
            }
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

/*
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
        
        label = MMTextLabel(view, font: view.openSans, text:"", scale: 0.44 )//color: float4(0.506, 0.506, 0.506, 1.000))
        listWidget = MMListWidget(view)
        
        // ---  Menu
        
        let sequenceMenuItems = [
            MMMenuItem( text: "Add", cb: {} ),
            MMMenuItem( text: "Rename", cb: {} ),
            MMMenuItem( text: "Delete", cb: {print("add child") } )
        ]
        menuWidget = MMMenuWidget( view, items: sequenceMenuItems )
        
        super.init(view)
        
        // ---
        
        menuWidget.items[0].cb = {
            let object = self.delegate.currentObject!
            let seq = MMTlSequence()
            seq.name = "New Animation"
            object.sequences.append(seq)
            object.currentSequence = seq
            self.listWidget.selectedItems = [seq.uuid]
        }
        
        menuWidget.items[1].cb = {
            var item = self.getCurrentItem()
            if item != nil {
                getStringDialog(view: view, title: "Rename Animation", message: "New name", defaultValue: item!.name, cb: { (name) -> Void in
                    item!.name = name
                } )
            }
        }
        
        menuWidget.items[2].cb = {
            if self.items.count < 2 { return }

            var item = self.getCurrentItem()

            let object = self.delegate.currentObject!
            object.sequences.remove(at: object.sequences.index(where: { $0.uuid == item!.uuid })!)
            self.listWidget.selectedItems = [object.sequences[0].uuid]
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
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, borderSize: 1,  fillColor : float4(0.275, 0.275, 0.275, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        label.setText("Animation Sequence")
        label.drawYCentered( x: rect.x + 10, y: rect.y, width: rect.width, height: 30 )
        
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
            listWidget.build(items: items)
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        listWidget.mouseScrolled(event)
    }
}
*/

class AvailableObjectListItem : MMListWidgetItem
{
    var name         : String = ""
    var uuid         : UUID = UUID()
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
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        listWidget.rect.x = rect.x
        listWidget.rect.y = rect.y
        listWidget.rect.width = rect.width
        listWidget.rect.height = rect.height
        
        listWidget.drawWithXOffset(xOffset: app.leftRegion!.rect.width - 200)
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
        let listItem = listWidget.itemAt(x, y, items: items)
        
        if listItem != nil {
            
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

class ObjectListItem : MMListWidgetItem
{
    var name         : String = ""
    var uuid         : UUID = UUID()
}

class ObjectList : MMWidget
{
    var app                 : App
    
    var listWidget          : MMListWidget
    var items               : [ObjectListItem] = []
    
    var mouseIsDown         : Bool = false
    var delegate            : LayerMaxDelegate
    
    init(_ view: MMView, app: App, delegate: LayerMaxDelegate)
    {
        self.app = app
        self.delegate = delegate
        
        listWidget = MMListWidget(view)
        
        super.init(view)
        rebuildList()
    }
    
    func rebuildList()
    {
        items = []
        for instance in delegate.currentLayer!.objectInstances {
            for node in app.nodeGraph.nodes {
                if node.uuid == instance.objectUUID {
                    
                    let item = ObjectListItem()
                    item.name = node.name + " Instance"
                    item.uuid = instance.uuid
                    items.append(item)
                }
            }
        }
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
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        listWidget.rect.x = rect.x
        listWidget.rect.y = rect.y
        listWidget.rect.width = rect.width
        listWidget.rect.height = rect.height
        
        listWidget.draw()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        let changed = listWidget.selectAt(event.x - rect.x, (event.y - rect.y), items: items)
        if changed {
            delegate.currentLayer!.selectedObjects = listWidget.selectedItems
            rebuildList()
            listWidget.build(items: items, fixedWidth: 300)
            delegate.updateGizmo()
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
