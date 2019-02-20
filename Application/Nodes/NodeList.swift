//
//  NodeList.swift
//  Shape-Z
//
//  Created by Markus Moenig on 16/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class NodeListItem : MMListWidgetItem
{
    var name         : String = ""
    var uuid         : UUID = UUID()
    
    var createNode   : (() -> Node)? = nil
    
    init(_ name: String)
    {
        self.name = name
    }
}

struct NodeListDrag : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : float2? = float2()
    var node            : Node? = nil
    var name            : String = ""
}

class NodeList : MMWidget
{
    var app                 : App
    
    var listWidget          : MMListWidget
    var items               : [NodeListItem] = []
    
    var mouseIsDown         : Bool = false
    var dragSource          : NodeListDrag?
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        
        listWidget = MMListWidget(view)
        
        // --- Object
        var item = NodeListItem("Object")
        item.createNode = {
            return Object()
        }
        items.append(item)
        // --- Object Physics
        item = NodeListItem("Object Physics")
        item.createNode = {
            return ObjectPhysics()
        }
        items.append(item)

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
            dragSource?.sourceWidget = self
            mmView.dragStarted(source: dragSource!)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
        mmView.unlockFramerate()
    }
    
    /// Create a drag item for the given position
    func createDragSource(_ x: Float,_ y: Float) -> NodeListDrag?
    {
        let listItem = listWidget.itemAt(x, y, items: items)

        if listItem != nil {
            
            let item = listItem as! NodeListItem
            var drag = NodeListDrag()
            
            drag.id = "NodeItem"
            drag.name = item.name
            drag.pWidgetOffset!.x = x
            drag.pWidgetOffset!.y = y.truncatingRemainder(dividingBy: listWidget.unitSize)
            
            drag.node = item.createNode!()
            
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
