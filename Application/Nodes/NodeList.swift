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
    enum DisplayType : Int {
        case All, Object, Layer, Scene, Game
    }
    
    var name         : String = ""
    var uuid         : UUID = UUID()
    var color        : float4? = nil
    var displayType  : DisplayType = .All
    
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
    var filteredItems       : [NodeListItem] = []
    
    var mouseIsDown         : Bool = false
    var dragSource          : NodeListDrag?
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        
        listWidget = MMListWidget(view)
        listWidget.skin.selectionColor = float4(0.5,0.5,0.5,1)
        
        super.init(view)

        var item : NodeListItem

        // --- Object Profile
        item = NodeListItem("3D Profile")
        item.createNode = {
            return ObjectProfile()
        }
        addNodeItem(item, type: .Property, displayType: .Object)
        // --- Object Physics
        item = NodeListItem("Physics Properties")
        item.createNode = {
            return ObjectPhysics()
        }
        addNodeItem(item, type: .Property, displayType: .Object)
        // --- Game Platform OSX
        item = NodeListItem("Platform: OSX")
        item.createNode = {
            return GamePlatformOSX()
        }
        addNodeItem(item, type: .Property, displayType: .Game)
        // --- Game Platform IPAD
        item = NodeListItem("Platform: iPAD")
        item.createNode = {
            return GamePlatformIPAD()
        }
        addNodeItem(item, type: .Property, displayType: .Game)
        
        // --- Variable Value
        item = NodeListItem("Variable: Direction")
        item.createNode = {
            return DirectionVariable()
        }
        addNodeItem(item, type: .Property, displayType: .All)
        
        // --- Variable Value
        item = NodeListItem("Variable: Value")
        item.createNode = {
            return ValueVariable()
        }
        addNodeItem(item, type: .Property, displayType: .All)
        
        // --- Object Animation
        item = NodeListItem("Animation")
        item.createNode = {
            return ObjectAnimation()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        // --- Object Apply Force
        item = NodeListItem("Apply Force")
        item.createNode = {
            return ObjectApplyForce()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        
        
        // --- Behavior: Behavior Tree
        item = NodeListItem("Behavior Tree")
        item.createNode = {
            return BehaviorTree()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)
        // --- Behavior: Inverter
        item = NodeListItem("Inverter")
        item.createNode = {
            return Inverter()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)
        // --- Behavior: Sequence
        item = NodeListItem("Sequence")
        item.createNode = {
            return Sequence()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)
        // --- Behavior: Selector
        item = NodeListItem("Selector")
        item.createNode = {
            return Selector()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)
        // --- Leave: Key Down
        item = NodeListItem("OSX: Key Down")
        item.createNode = {
            return KeyDown()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)

        // --- Arithmetic
        item = NodeListItem("Add Value")
        item.createNode = {
            return AddValueVariable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Reset Value")
        item.createNode = {
            return ResetValueVariable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        // ---
        switchTo(.Object)
    }
    
    /// Adds a given node list item and assigns the brand and display type of the node
    func addNodeItem(_ item: NodeListItem, type: Node.Brand, displayType: NodeListItem.DisplayType)
    {
        if type == .Behavior {
            item.color = mmView.skin.Node.behaviorColor
        } else
        if type == .Property {
            item.color = mmView.skin.Node.propertyColor
        } else
        if type == .Function {
            item.color = mmView.skin.Node.functionColor
        } else
        if type == .Arithmetic {
            item.color = mmView.skin.Node.arithmeticColor
        }
        item.displayType = displayType
        items.append(item)
    }
    
    /// Switches the type of the displayed node list items
    func switchTo(_ displayType: NodeListItem.DisplayType)
    {
        filteredItems = []
        for item in items {
            if item.displayType == .All || item.displayType == displayType {
                filteredItems.append(item)
            }
        }
        listWidget.build(items: filteredItems, fixedWidth: 200)
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
        let changed = listWidget.selectAt(event.x - rect.x, (event.y - rect.y), items: filteredItems)
        if changed {
            listWidget.build(items: filteredItems, fixedWidth: 200)
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
        let listItem = listWidget.itemAt(x, y, items: filteredItems)

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
