//
//  RightRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class RightRegion: MMRegion
{
    var app             : App
    var objectWidget    : ObjectWidget
    var shapeListWidget : ShapeListScrollArea
    
    var shapeList       : ShapeList
    
    var changed         : Bool = false
    
    init( _ view: MMView, app: App )
    {
        self.app = app
        
        objectWidget = ObjectWidget(view, app: app)
        shapeListWidget = ShapeListScrollArea(view, app: app)
        
        shapeList = ShapeList(view)
        
        super.init( view, type: .Right )
        
        view.registerWidget(shapeListWidget)
        view.registerWidget(objectWidget.menuWidget)
        view.registerWidget(objectWidget.objectEditorWidget)
    }
    
    override func build()
    {
        rect.width = 300
        rect.x = mmView.renderer.cWidth - rect.width
        
        objectWidget.rect.width = rect.width
        objectWidget.rect.height = rect.height * 1/3
        
        shapeListWidget.rect.width = rect.width
        shapeListWidget.rect.height = rect.height * 2/3
        
        layoutV(startX: rect.x, startY: rect.y, spacing: 0, widgets: objectWidget, shapeListWidget)
        
        super.build()

        objectWidget.draw()
        shapeListWidget.draw()
        
        if changed {
            shapeList.build( width: shapeListWidget.rect.width, object: app.layerManager.getCurrentLayer().getCurrentObject()!)
            changed = false
        }
        shapeListWidget.build(widget: shapeList.textureWidget, area: MMRect( shapeListWidget.rect.x, shapeListWidget.rect.y+1, shapeListWidget.rect.width, shapeListWidget.rect.height-2) )
    }
    
    func buildList()
    {
        shapeList.build( width: shapeListWidget.rect.width, object: app.layerManager.getCurrentLayer().getCurrentObject()!)
    }
}

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

/// The scroll area for the shapes list
class ShapeListScrollArea: MMScrollArea
{
    var app                 : App
    var mouseDownPos        : float2
    var mouseIsDown         : Bool = false
    
    var dragSource          : ShapeSelectorDrag? = nil
    var shapeAtMouse        : Shape?
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        mouseDownPos = float2()
        super.init(view, orientation:.Vertical)
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        
        mouseDownPos.x = event.x - rect.x
        mouseDownPos.y = event.y - rect.y
        mouseIsDown = true
        
        let shapeList = app.rightRegion!.shapeList
        
        app.rightRegion!.changed = shapeList.selectAt(mouseDownPos.x,mouseDownPos.y, multiSelect: mmView.shiftIsDown)
        
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
        
        if app.rightRegion!.changed {
            app.gizmo.setObject(app.layerManager.getCurrentObject())
            app.layerManager.getCurrentLayer().build()
            app.editorRegion?.result = nil
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        if !mouseIsDown {
            if app.rightRegion!.shapeList.hoverAt(event.x - rect.x, event.y - rect.y) {
                app.rightRegion!.shapeList.update()
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
