//
//  ObjectMaxDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ObjectMaxDelegate : NodeMaxDelegate {
    
    enum LeftRegionMode
    {
        case Closed, Shapes, Materials
    }
    
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    var app             : App!
    
    // Top Region
    var shapesButton    : MMButtonWidget!
    var materialsButton : MMButtonWidget!
    var timelineButton  : MMButtonWidget!
    
    // Left Region
    var leftRegionMode  : LeftRegionMode = .Shapes
    
    var shapeSelector   : ShapeSelector!
    var textureWidget   : MMTextureWidget!
    var scrollArea      : ShapeScrollArea!
    var animating       : Bool = false
    
    // Right Region
    var objectWidget    : ObjectWidget!
    var shapeListWidget : ShapeListScrollArea!
    var shapeList       : ShapeList!
    var shapeListChanged: Bool = true
    
    // Bottom Region
    var bottomRegionMode: BottomRegionMode = .Open
    
    var timeline        : MMTimeline!
    var sequenceWidget  : SequenceWidget!

    // ---
    var currentObject   : Object?
    var camera          : Camera = Camera()
    var patternState    : MTLRenderPipelineState?
    var dispatched      : Bool = false
    
    /// The currently displayed object
    var selObject       : Object? = nil
    
    /// Gizmo works on the selected object, gets disabled when shape gets selected
    var selObjectActive : Bool = false

    override func activate(_ app: App)
    {
        self.app = app
        currentObject = app.nodeGraph.maximizedNode as? Object
        app.gizmo.setObject(currentObject)
        
        selObject = currentObject
        selObjectActive = false

        // Top Region
        if shapesButton == nil {
            shapesButton = MMButtonWidget( app.mmView, text: "Shapes" )
            materialsButton = MMButtonWidget( app.mmView, text: "Materials" )
            timelineButton = MMButtonWidget( app.mmView, text: "Timeline" )
        }
        shapesButton.clicked = { (event) -> Void in
            self.setLeftRegionMode(.Shapes)
            self.materialsButton.removeState(.Checked)
        }
        
        materialsButton.clicked = { (event) -> Void in
            self.setLeftRegionMode(.Materials)
            self.shapesButton.removeState(.Checked)
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
            shapeSelector = ShapeSelector(app.mmView, width : 200)
            textureWidget = MMTextureWidget(app.mmView, texture: shapeSelector.fragment!.texture )
            textureWidget.zoom = 2
            
            scrollArea = ShapeScrollArea(app.mmView, app: app, delegate:self)
        }
        
        shapesButton.addState( .Checked )
        app.leftRegion!.rect.width = 200
        
        // Right Region
        if objectWidget == nil {
            objectWidget = ObjectWidget(app.mmView, app: app, delegate:self)
            shapeListWidget = ShapeListScrollArea(app.mmView, app: app, delegate: self)
            shapeList = ShapeList(app.mmView)
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
            self.currentObject!.currentSequence = items[0] as? MMTlSequence
            self.update()
        }
        timelineButton.addState( .Checked )
        app.bottomRegion!.rect.height = 100
        
        app.mmView.registerWidgets( widgets: shapesButton, materialsButton, timelineButton, scrollArea, shapeListWidget, objectWidget.menuWidget, objectWidget.objectListWidget, timeline, sequenceWidget.menuWidget, sequenceWidget, app.closeButton)

        update(true)
    }
    
    override func deactivate()
    {
        timeline.deactivate()
        app.mmView.deregisterWidgets( widgets: shapesButton, materialsButton, timelineButton, scrollArea, shapeListWidget, objectWidget.menuWidget, objectWidget.objectListWidget, timeline, sequenceWidget, sequenceWidget.menuWidget, app.closeButton)
        
        currentObject!.updatePreview(nodeGraph: app.nodeGraph, hard: true)
    }
    
    /// Called when the project changes (Undo / Redo)
    override func setChanged()
    {
        shapeListChanged = true
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
            drawPattern(region)
            
            if let instance = currentObject!.instance {
            
                if instance.texture == nil || instance.texture!.width != Int(region.rect.width) || instance.texture!.height != Int(region.rect.height) {
                    app.nodeGraph.builder.render(width: region.rect.width, height: region.rect.height, instance: currentObject!.instance!, camera: camera)
                }
                
                if let texture = instance.texture {
                    
                    app.mmView.drawTexture.draw(texture, x: region.rect.x, y: region.rect.y)
                }
            }
             
            app.gizmo.draw()
            app.changed = false
        } else
        if region.type == .Top {
            region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: shapesButton, materialsButton )
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: timelineButton, app.closeButton)
            
            shapesButton.draw()
            materialsButton.draw()
            timelineButton.draw()
            app.closeButton.draw()
        } else
        if region.type == .Left {
            let leftRegion = app.leftRegion!
            if leftRegionMode != .Closed {
                app.mmView.drawBox.draw( x: leftRegion.rect.x, y: leftRegion.rect.y, width: leftRegion.rect.width, height: leftRegion.rect.height, round: 0, borderSize: 0,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
                scrollArea.build(widget: textureWidget, area: leftRegion.rect, xOffset:(leftRegion.rect.width - 200))
            } else {
                leftRegion.rect.width = 0
            }
        } else
        if region.type == .Right {
            let rightRegion = app.rightRegion!

            rightRegion.rect.width = 300
            rightRegion.rect.x = app.mmView.renderer.cWidth - rightRegion.rect.width
            
            objectWidget.rect.width = rightRegion.rect.width
            objectWidget.rect.height = rightRegion.rect.height * 1/3
            
            shapeListWidget.rect.width = rightRegion.rect.width
            shapeListWidget.rect.height = rightRegion.rect.height * 2/3
            
            rightRegion.layoutV(startX: rightRegion.rect.x, startY: rightRegion.rect.y, spacing: 0, widgets: objectWidget, shapeListWidget)
            
            objectWidget.draw()
            shapeListWidget.draw()
            
            if shapeListChanged {
                shapeList.build( width: shapeListWidget.rect.width, object: selObject!)
                
                // Remove gizmo focus from the selected object if it has selected shapes
                if selObject!.selectedShapes.count > 0 {
                    selObjectActive = false
                }
                shapeListChanged = false
            }
            shapeListWidget.build(widget: shapeList.textureWidget, area: MMRect( shapeListWidget.rect.x, shapeListWidget.rect.y+1, shapeListWidget.rect.width, shapeListWidget.rect.height-2) )
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
        app.gizmo.mouseDown(event)
        
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
            app.gizmo.setObject(selObject, rootObject: currentObject)
        }
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
                    self.shapesButton.removeState( .Checked )
                    self.materialsButton.removeState( .Checked )
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
    
    func setSelectedObject(_ object: Object)
    {
        selObject = object
        selObject!.selectedShapes = []
        selObjectActive = true
        shapeListChanged = true
        app.gizmo.setObject(selObject!, rootObject: currentObject!, context: .ObjectEditor)
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
    
    /// Updates the preview. hard does a rebuild, otherwise just a render
    override func update(_ hard: Bool = false)
    {
        if hard {
            app.gizmo.setObject(selObject, rootObject: currentObject)
            currentObject!.instance = app.nodeGraph.builder.buildObjects(objects: [currentObject!], camera: camera)
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

/// The scroll area for the shapes
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
        mouseDownPos.y = event.y - rect.y
        mouseIsDown = true
        shapeAtMouse = delegate.shapeSelector.selectAt(mouseDownPos.x,mouseDownPos.y)
        delegate.app.gizmo.setObject(delegate.selObject, rootObject: delegate.currentObject)
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
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        //
        
        mmView.renderer.setClipRect(rect)
        var y : Float = 5
        
        func drawRow(items: [ObjectTreeItem])
        {
            let count : Float = Float(items.count)
            var x : Float = (rect.width - (count * objectSize.x + (count-1) *  objectMargin.x)) / 2
            
            for item in items
            {
                let fillColor : float4
                
                item.rect.x = rect.x + x + xOffset
                item.rect.y = rect.y + y + yOffset
                item.rect.width = objectSize.x
                item.rect.height = objectSize.y

                if delegate.selObject!.uuid == item.object.uuid {
                    if delegate.selObjectActive {
                        fillColor = app.mmView.skin.Widget.selectionColor
                    } else {
                        fillColor = float4( 0.5, 0.5, 0.5, 1 )
                    }
                } else {
                    fillColor = float4(0)
                }
                
                let borderSize : Float = 2
                
                mmView.drawBox.draw( x: item.rect.x + 1, y: item.rect.y, width: objectSize.x, height: objectSize.y, round: 6, borderSize: borderSize,  fillColor : fillColor, borderColor: float4( 1 ) )
                
                mmView.drawText.drawTextCentered(mmView.openSans, text: item.parentItem != nil ? item.object.name : "Root", x: item.rect.x, y: item.rect.y, width: objectSize.x, height: objectSize.y, scale: 0.3, color: float4(0,0,0,1))
                
                if item.parentItem != nil {
                    let pRect = item.parentItem!.rect
                    let pX : Float = pRect.x + pRect.width / 2
                    let pY : Float = pRect.y + pRect.height - 1
                    
                    mmView.drawLine.draw(sx: pX, sy: pY, ex: item.rect.x + item.rect.width / 2, ey: item.rect.y + 1, radius: 1, fillColor: float4(1))
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
        
        label = MMTextLabel(view, font: view.openSans, text:"", scale: 0.44 )//color: float4(0.506, 0.506, 0.506, 1.000))
        objectListWidget = ObjectListWidget(view, app: app, delegate: delegate)
        
        // --- Object Menu
        let objectMenuItems = [
            MMMenuItem( text: "Add Child Object", cb: {
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
                } )
            } ),
            MMMenuItem( text: "Rename Object", cb: {
                let object = delegate.selObject!
                getStringDialog(view: view, title: "Rename Object", message: "Enter new name", defaultValue: object.name, cb: { (name) -> Void in
                    object.name = name
                    object.label?.setText(name)
                } )
            } ),
            MMMenuItem( text: "Delete Object", cb: {print("delete child") } )
        ]
        menuWidget = MMMenuWidget( view, items: objectMenuItems )
        
        super.init(view)
    }
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, borderSize: 1,  fillColor : float4(0.275, 0.275, 0.275, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        if let object = delegate.selObject {
            label.setText(object.name)
            label.drawCenteredY( x: rect.x + 10, y: rect.y, width: rect.width, height: 30 )
            
            objectListWidget.rect.x = rect.x
            objectListWidget.rect.y = rect.y + 30
            objectListWidget.rect.width = rect.width
            objectListWidget.rect.height = rect.height - 30
            
            objectListWidget.draw(object: object)
        }
        
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
    }
}

/// The scroll area for the shapes list in the right region
class ShapeListScrollArea: MMScrollArea
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
        mouseDownPos.y = event.y - rect.y
        mouseIsDown = true
        
        let shapeList = delegate.shapeList!
        
        delegate.shapeListChanged = shapeList.selectAt(mouseDownPos.x,mouseDownPos.y, multiSelect: mmView.shiftIsDown)
        
        // --- Move up / down
        if shapeList.hoverData[0] != -1 {
            let object = delegate.currentObject
            if shapeList.hoverUp && object!.shapes.count > 1 && shapeList.hoverIndex > 0 {
                let shape = object!.shapes.remove(at: shapeList.hoverIndex)
                object!.shapes.insert(shape, at: shapeList.hoverIndex - 1)
            } else
                if !shapeList.hoverUp && object!.shapes.count > 1 && shapeList.hoverIndex < object!.shapes.count-1 {
                    let shape = object!.shapes.remove(at: shapeList.hoverIndex)
                    object!.shapes.insert(shape, at: shapeList.hoverIndex + 1)
            }
            
            shapeList.hoverData[0] = -1
            shapeList.hoverIndex = -1
        }
        // ---
        
        if delegate.shapeListChanged {
            delegate.update(true)
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        if !mouseIsDown {
            if delegate.shapeList.hoverAt(event.x - rect.x, event.y - rect.y) {
                delegate.shapeList.update()
            }
        }
        //        if mouseIsDown && dragSource == nil {
        //            dragSource = app.leftRegion!.shapeSelector.createDragSource(mouseDownPos.x,mouseDownPos.y)
        //            dragSource?.sourceWidget = self
        //            mmView.dragStarted(source: dragSource!)
        //        }
    }
    
    override func mouseUp(_ event: MMMouseEvent) {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
    }
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height + 1, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: float4( 0, 0, 0, 1 ) )
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
            listWidget.build(items: items)
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        listWidget.mouseScrolled(event)
    }
}
