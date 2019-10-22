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
        case All, Object, Scene, Game, ObjectOverview, SceneOverview
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
        
        // --- Object
        item = NodeListItem("Object")
        item.createNode = {
            return Object()
        }
        addNodeItem(item, type: .Function, displayType: .ObjectOverview)
        
        // --- Scene
        item = NodeListItem("Scene")
        item.createNode = {
            return Scene()
        }
        addNodeItem(item, type: .Function, displayType: .SceneOverview)
        
        // -------------------------------
        /*
        // --- Object Profile
        item = NodeListItem("3D Profile")
        item.createNode = {
            return ObjectProfile()
        }
        addNodeItem(item, type: .Property, displayType: .Object)*/
        // --- Object Physics
        item = NodeListItem("Instance Props")
        item.createNode = {
            return ObjectInstanceProps()
        }
        addNodeItem(item, type: .Property, displayType: .Object)
        // --- Object Physics
        item = NodeListItem("Physical Props")
        item.createNode = {
            return ObjectPhysics()
        }
        addNodeItem(item, type: .Property, displayType: .Object)
        // --- Object Collisions
        item = NodeListItem("Collision Props")
        item.createNode = {
            return ObjectCollision()
        }
        addNodeItem(item, type: .Property, displayType: .Object)
        // --- Object Render
        item = NodeListItem("Render Props")
        item.createNode = {
            return ObjectRender()
        }
        addNodeItem(item, type: .Property, displayType: .Object)
        // --- Object Glow
        item = NodeListItem("Glow Effect")
        item.createNode = {
            return ObjectGlow()
        }
        addNodeItem(item, type: .Property, displayType: .Object)
        // --- Scene Area
        item = NodeListItem("Area")
        item.createNode = {
            return SceneArea()
        }
        addNodeItem(item, type: .Property, displayType: .Scene)
        // --- Scene Device Orientation
        item = NodeListItem("Device Orientation")
        item.createNode = {
            return SceneDeviceOrientation()
        }
        addNodeItem(item, type: .Property, displayType: .Scene)
        // --- Scene Gravity
        item = NodeListItem("Gravity")
        item.createNode = {
            return SceneGravity()
        }
        addNodeItem(item, type: .Property, displayType: .Scene)
        // --- Scene Light
        item = NodeListItem("Light")
        item.createNode = {
            return SceneLight()
        }
        addNodeItem(item, type: .Property, displayType: .Scene)
        // --- Game Platform OSX
        item = NodeListItem("Platform: OSX")
        item.createNode = {
            return GamePlatformOSX()
        }
        addNodeItem(item, type: .Property, displayType: .Game)
        // --- Game Platform IOS
        item = NodeListItem("Platform: iOS")
        item.createNode = {
            return GamePlatformIPAD()
        }
        addNodeItem(item, type: .Property, displayType: .Game)
        // --- Game Platform TVOS
        item = NodeListItem("Platform: tvOS")
        item.createNode = {
            return GamePlatformTVOS()
        }
        addNodeItem(item, type: .Property, displayType: .Game)
        
        // --- Variable Value
        item = NodeListItem("Variable: Float")
        item.createNode = {
            return FloatVariable()
        }
        addNodeItem(item, type: .Property, displayType: .All)
        
        // --- Float2 Value
        item = NodeListItem("Variable: Float2")
        item.createNode = {
            return Float2Variable()
        }
        addNodeItem(item, type: .Property, displayType: .All)
        
        // --- Float3 Value
        item = NodeListItem("Variable: Float3")
        item.createNode = {
            return Float3Variable()
        }
        addNodeItem(item, type: .Property, displayType: .All)
        
        // --- Variable Value
        item = NodeListItem("Variable: Direction")
        item.createNode = {
            return DirectionVariable()
        }
        addNodeItem(item, type: .Property, displayType: .All)
        
        // --- Object Animation
        item = NodeListItem("Play Animation")
        item.createNode = {
            return ObjectAnimation()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        // --- Object Animation
        item = NodeListItem("Get Animation State")
        item.createNode = {
            return ObjectAnimationState()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        // --- Object Apply Force
        item = NodeListItem("Apply Force")
        item.createNode = {
            return ObjectApplyForce()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        // --- Object Apply Directional Force
        item = NodeListItem("Apply Dir. Force")
        item.createNode = {
            return ObjectApplyDirectionalForce()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        // --- Instance Collision Any
        item = NodeListItem("Collision (Any)")
        item.createNode = {
            return ObjectCollisionAny()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        // --- Instance Collision With
        item = NodeListItem("Collision With")
        item.createNode = {
            return ObjectCollisionWith()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        // --- Instance Distance To
        item = NodeListItem("Distance To")
        item.createNode = {
            return ObjectDistanceTo()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        // --- Object Reset
        item = NodeListItem("Reset Instance")
        item.createNode = {
            return ResetObject()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        // --- Object Touch Layer Area
        item = NodeListItem("Touches Area ?")
        item.createNode = {
            return ObjectTouchSceneArea()
        }
        addNodeItem(item, type: .Function, displayType: .Object)
        
        // --- Scene Finished
        item = NodeListItem("Finished")
        item.createNode = {
            return SceneFinished()
        }
        addNodeItem(item, type: .Function, displayType: .Scene)
        
        // --- Game Play Scene
        item = NodeListItem("Play Scene")
        item.createNode = {
            return GamePlayScene()
        }
        addNodeItem(item, type: .Function, displayType: .Game)
        
        // --- Behavior: Behavior Tree
        item = NodeListItem("Behavior Tree")
        item.createNode = {
            return BehaviorTree()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)
        // --- Behavior: Execute Behavior Tree
        item = NodeListItem("Execute Tree")
        item.createNode = {
            return ExecuteBehaviorTree()
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
        // --- Behavior: Succeeder
        item = NodeListItem("Succeeder")
        item.createNode = {
            return Succeeder()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)
        // --- Behavior: Repeater
        item = NodeListItem("Repeater")
        item.createNode = {
            return Repeater()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)
        // --- Leaf: Click in Scene Area
        item = NodeListItem("Click in Area")
        item.createNode = {
            return ClickInSceneArea()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)
        // --- Leaf: Key Down
        item = NodeListItem("OSX: Key Down")
        item.createNode = {
            return KeyDown()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)
        // --- Leaf: Accelerometer
        item = NodeListItem("iOS: Accelerometer")
        item.createNode = {
            return Accelerometer()
        }
        addNodeItem(item, type: .Behavior, displayType: .All)

        // --- Arithmetic
        item = NodeListItem("Add(Float2, Float2)")
        item.createNode = {
            return AddFloat2Variables()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Sub(Float2, Float2)")
        item.createNode = {
            return SubtractFloat2Variables()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Mult(Const, Float2)")
        item.createNode = {
            return MultiplyConstFloat2Variable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Copy(Float2, Float2)")
        item.createNode = {
            return CopyFloat2Variables()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Reflect(Float2, Float2)")
        item.createNode = {
            return ReflectFloat2Variables()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Test(Float2)")
        item.createNode = {
            return TestFloat2Variable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Limit(Float2)")
        item.createNode = {
            return LimitFloat2Range()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Animate(Float)")
        item.createNode = {
            return AnimateFloatVariable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Add(Const, Float)")
        item.createNode = {
            return AddConstFloatVariable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)

        item = NodeListItem("Sub(Const, Float)")
        item.createNode = {
            return SubtractConstFloatVariable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Reset(Float)")
        item.createNode = {
            return ResetFloatVariable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Copy(Const, Float)")
        item.createNode = {
            return SetFloatVariable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Copy(Float, Float)")
        item.createNode = {
            return CopyFloatVariables()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Test(Float)")
        item.createNode = {
            return TestFloatVariable()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Random(Direction)")
        item.createNode = {
            return RandomDirection()
        }
        addNodeItem(item, type: .Arithmetic, displayType: .All)
        
        item = NodeListItem("Stop Variable Anims")
        item.createNode = {
            return StopVariableAnimations()
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
            if (item.displayType == .All && displayType.rawValue < 4 ) || item.displayType == displayType {
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
    
    /// Create a drag item
    func createDragSource(_ x: Float,_ y: Float) -> NodeListDrag?
    {
        if let listItem = listWidget.getCurrentItem() {
            let item = listItem as! NodeListItem
            var drag = NodeListDrag()
            
            drag.id = "NodeItem"
            drag.name = item.name
            drag.pWidgetOffset!.x = x
            drag.pWidgetOffset!.y = y.truncatingRemainder(dividingBy: listWidget.unitSize)
            
            drag.node = item.createNode!()
            
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
