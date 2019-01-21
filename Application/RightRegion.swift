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
        
        view.registerWidget(shapeListWidget, region: self)
        view.registerWidget(objectWidget.menuWidget, region: self)
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
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        label = MMTextLabel(view, font: view.openSans!, text:"", scale: 0.44 )//color: float4(0.506, 0.506, 0.506, 1.000))
        
        let objectMenuItems = [
            MMMenuItem( text: "Add Child Object", cb: {print("add child") } )
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
        }
        
        menuWidget.rect.x = rect.x + rect.width - 30 - 1
        menuWidget.rect.y = rect.y + 1
        menuWidget.rect.width = 30
        menuWidget.rect.height = 28
//        menuWidget.draw()
        mmView.delayedDraws.append( menuWidget )
        
        mmView.drawBox.draw( x: rect.x, y: rect.y+30, width: rect.width, height: rect.height-30, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
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
        
        app.rightRegion!.changed = app.rightRegion!.shapeList.selectAt(mouseDownPos.x,mouseDownPos.y)
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        if mouseIsDown && dragSource == nil {
            dragSource = app.leftRegion!.shapeSelector.createDragSource(mouseDownPos.x,mouseDownPos.y)
            dragSource?.sourceWidget = self
            mmView.dragStarted(source: dragSource!)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent) {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
    }
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: float4( 0, 0, 0, 1 ) )
    }
}
