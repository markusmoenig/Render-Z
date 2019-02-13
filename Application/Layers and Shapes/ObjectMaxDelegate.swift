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

    var patternState    : MTLRenderPipelineState?
    var dispatched      : Bool = false

    override func activate(_ app: App)
    {
        self.app = app
        
        // Top Region
        shapesButton = MMButtonWidget( app.mmView, text: "Shapes" )
        shapesButton.clicked = { (event) -> Void in
            self.setLeftRegionMode(.Shapes)
            self.materialsButton.removeState(.Checked)
        }
        
        materialsButton = MMButtonWidget( app.mmView, text: "Materials" )
        materialsButton.clicked = { (event) -> Void in
            self.setLeftRegionMode(.Materials)
            self.shapesButton.removeState(.Checked)
        }
            
        timelineButton = MMButtonWidget( app.mmView, text: "Timeline" )
        timelineButton.clicked = { (event) -> Void in
            self.switchTimelineMode()
        }
        
        // Left Region
        shapeSelector = ShapeSelector(app.mmView, width : 200)
        textureWidget = MMTextureWidget(app.mmView, texture: shapeSelector.fragment!.texture )
        textureWidget.zoom = 2
        
        scrollArea = ShapeScrollArea(app.mmView, app: app, delegate:self)
        shapesButton.addState( .Checked )
        app.leftRegion!.rect.width = 200
        
        // Right Region
        objectWidget = ObjectWidget(app.mmView, app: app)
        shapeListWidget = ShapeListScrollArea(app.mmView, app: app, delegate: self)
        shapeList = ShapeList(app.mmView)
        app.rightRegion!.rect.width = 300

        // Editor Region
        let function = app.mmView.renderer!.defaultLibrary.makeFunction( name: "moduloPattern" )
        patternState = app.mmView.renderer!.createNewPipelineState( function! )
        
        // Bottom Region
        timeline = app.objectTimeline
        timeline.changedCB = { (frame) in
            app.editorRegion?.result = nil
        }
        sequenceWidget = SequenceWidget(app.mmView, app: app)
        timelineButton.addState( .Checked )
        app.bottomRegion!.rect.height = 100
        
        app.mmView.registerWidgets( widgets: shapesButton, materialsButton, timelineButton, scrollArea, shapeListWidget, objectWidget.menuWidget, objectWidget.objectEditorWidget, timeline, sequenceWidget)
    }
    
    override func deactivate()
    {
        app.mmView.deregisterWidgets( widgets: shapesButton, materialsButton, timelineButton, scrollArea, shapeListWidget, objectWidget.menuWidget, objectWidget.objectEditorWidget, timeline, sequenceWidget)
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
            
             if app.editorRegion!.result == nil || app.layerManager.width != region.rect.width || app.layerManager.height != region.rect.height {
                app.editorRegion!.compute()
             }
             
             if let texture = app.editorRegion!.result {
                app.mmView.drawTexture.draw(texture, x: region.rect.x, y: region.rect.y)
             }
             
             app.gizmo.draw()
             
             app.changed = false
        } else
        if region.type == .Top {
            region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: shapesButton, materialsButton )
            region.layoutHFromRight( startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: timelineButton )
            
            shapesButton.draw()
            materialsButton.draw()
            timelineButton.draw()
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
                shapeList.build( width: shapeListWidget.rect.width, object: app.layerManager.getCurrentLayer().getCurrentObject()!)
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
                timeline.draw(app.layerManager.getCurrentLayer().sequence, uuid:app.layerManager.getCurrentUUID())
                
                // Sequence area
                sequenceWidget.rect.copy( region.rect )
                sequenceWidget.rect.x = region.rect.right() - app.rightRegion!.rect.width
                sequenceWidget.rect.width = app.rightRegion!.rect.width
                sequenceWidget.draw()
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        app.gizmo.mouseDown(event)
        
        if app.gizmo.hoverState == .Inactive {
            let editorRegion = app.editorRegion!
            app.layerManager.getShapeAt(x: event.x - editorRegion.rect.x, y: event.y - editorRegion.rect.y, multiSelect: app.mmView.shiftIsDown)
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
         if app.layerManager.getCurrentObject()?.getCurrentShape() != nil {
            return
         }
         app.layerManager.camera[0] -= event.deltaX! * 2
         app.layerManager.camera[1] -= event.deltaY! * 2
         #elseif os(OSX)
         app.layerManager.camera[0] += event.deltaX! * 2
         app.layerManager.camera[1] += event.deltaY! * 2
         #endif
         
         app.editorRegion!.compute()
        
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
    
    /// Rebuilds the shape list in the right region
    func buildShapeList()
    {
        shapeList.build( width: shapeListWidget.rect.width, object: app.layerManager.getCurrentLayer().getCurrentObject()!)
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
                    //? self.app.topRegion!.timelineButton.removeState( .Checked )
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
    }
}

/// The object widget in the right region
class ObjectWidget : MMWidget
{
    var app                 : App
    var label               : MMTextLabel
    var menuWidget          : MMMenuWidget
    var objectEditorWidget  : ObjectEditorWidget
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        
        label = MMTextLabel(view, font: view.openSans, text:"", scale: 0.44 )//color: float4(0.506, 0.506, 0.506, 1.000))
        objectEditorWidget = ObjectEditorWidget(view, app: app)
        
        // --- Object Menu
        let objectMenuItems = [
            MMMenuItem( text: "Add Child Object", cb: {print("add child") } ),
            MMMenuItem( text: "Rename Object", cb: {
                let object = app.layerManager.getCurrentObject()!
                getStringDialog(view: view, title: "Rename Object", message: "Enter new name", defaultValue: object.name, cb: { (name) -> Void in
                    object.name = name
                } )
            } ),
            MMMenuItem( text: "Delete Object", cb: {print("add child") } )
        ]
        menuWidget = MMMenuWidget( view, items: objectMenuItems )
        
        super.init(view)
    }
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, borderSize: 1,  fillColor : float4(0.275, 0.275, 0.275, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        if let object = app.layerManager.getCurrentObject() {
            label.setText(object.name)
            label.drawYCentered( x: rect.x + 10, y: rect.y, width: rect.width, height: 30 )
            
            objectEditorWidget.rect.x = rect.x
            objectEditorWidget.rect.y = rect.y + 30
            objectEditorWidget.rect.width = rect.width
            objectEditorWidget.rect.height = rect.height - 30
            
            objectEditorWidget.draw(layer: app.layerManager.getCurrentLayer(), object: object)
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
            let object = app.layerManager.getCurrentObject()
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
            app.gizmo.setObject(app.layerManager.getCurrentObject())
            app.layerManager.getCurrentLayer().build()
            app.editorRegion?.result = nil
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
    //    var menuWidget          : MMMenuWidget
    //    var objectEditorWidget  : ObjectEditorWidget
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        
        label = MMTextLabel(view, font: view.openSans, text:"", scale: 0.44 )//color: float4(0.506, 0.506, 0.506, 1.000))
        //        objectEditorWidget = ObjectEditorWidget(view, app: app)
        
        /*
         // --- Object Menu
         let objectMenuItems = [
         MMMenuItem( text: "Add Child Object", cb: {print("add child") } ),
         MMMenuItem( text: "Rename Object", cb: {
         let object = app.layerManager.getCurrentObject()!
         getStringDialog(view: view, title: "Rename Object", message: "Enter new name", defaultValue: object.name, cb: { (name) -> Void in
         object.name = name
         } )
         } ),
         MMMenuItem( text: "Delete Object", cb: {print("add child") } )
         ]
         menuWidget = MMMenuWidget( view, items: objectMenuItems )
         */
        
        super.init(view)
    }
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, borderSize: 1,  fillColor : float4(0.275, 0.275, 0.275, 1), borderColor: float4( 0, 0, 0, 1 ) )
        
        label.setText("Current Sequence")
        label.drawYCentered( x: rect.x + 10, y: rect.y, width: rect.width, height: 30 )
    }
}
