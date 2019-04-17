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
    var color       : float4? = nil
    
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
        listWidget.skin.selectionColor = float4(0.5,0.5,0.5,1)
        
        let propertyColor = float4(0.62, 0.506, 0.165, 1)
        let behaviorColor = float4(0.129, 0.216, 0.612, 1)

        var item : NodeListItem
        // --- Object
//        var item = NodeListItem("Object")
//        item.createNode = {
//            return Object()
//        }
//        items.append(item)
        // --- Object Physics
        item = NodeListItem("Physics Properties")
        item.color = propertyColor
        item.createNode = {
            return ObjectPhysics()
        }
        items.append(item)
        // --- Layer
//        item = NodeListItem("Layer")
//        item.createNode = {
//            return Layer()
//        }
//        items.append(item)
        // --- Behavior: Behavior Tree
        item = NodeListItem("Behavior Tree")
        item.createNode = {
            return BehaviorTree()
        }
        item.color = behaviorColor
        items.append(item)
        // --- Object Animation
        item = NodeListItem("Animation")
        item.createNode = {
            return ObjectAnimation()
        }
        item.color = behaviorColor
        items.append(item)
        // --- Behavior: Inverter
        item = NodeListItem("Inverter")
        item.createNode = {
            return Inverter()
        }
        item.color = behaviorColor
        items.append(item)
        // --- Behavior: Sequence
        item = NodeListItem("Sequence")
        item.createNode = {
            return Sequence()
        }
        item.color = behaviorColor
        items.append(item)
        // --- Behavior: Selector
        item = NodeListItem("Selector")
        item.createNode = {
            return Selector()
        }
        item.color = behaviorColor
        items.append(item)
        // --- Leave: Key Down
        item = NodeListItem("Key Down")
        item.createNode = {
            return KeyDown()
        }
        item.color = behaviorColor
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
