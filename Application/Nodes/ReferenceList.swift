//
//  ReferenceList.swift
//  Shape-Z
//
//  Created by Markus Moenig on 8/7/2562 BE.
//  Copyright © 2562 Markus Moenig. All rights reserved.
//

import Foundation

class ReferenceItem {
    
    var uuid                : UUID!
    var classUUID           : UUID!

    var name                : MMTextLabel
    var category            : MMTextLabel
    var color               : float4 = float4()

    init(_ mmView: MMView)
    {
        name = MMTextLabel(mmView, font: mmView.openSans, text: "")
        category = MMTextLabel(mmView, font: mmView.openSans, text: "")
    }
}

class ReferenceList {
    
    enum Mode {
        case Variables, ObjectInstances, LayerAreas, Animations, BehaviorTrees
    }
    
    var currentMode         : Mode = .Variables
    
    var nodeGraph           : NodeGraph!

    var rect                : MMRect = MMRect()
    var offsetY             : Float = 0
    var isActive            : Bool = false
    var itemHeight          : Float = 48

    var refs                : [ReferenceItem] = []
    
    var dispatched          : Bool = false
    
    var selectedUUID        : UUID? = nil
    var selectedItem        : ReferenceItem? = nil

    var dragSource          : ReferenceListDrag? = nil
    var mouseIsDown         : Bool = false

    init(_ nodeGraph: NodeGraph)
    {
        self.nodeGraph = nodeGraph
    }
    
    func createVariableList()
    {
        currentMode = .Variables
        refs = []
        var selfOffset : Int = 0
        for node in nodeGraph.nodes
        {
            if node.type == "Float Variable" || node.type == "Direction Variable" || node.type == "Float2 Variable" {
                let belongsToMaster = nodeGraph.currentMaster!.subset!.contains(node.uuid)
                if node.properties["access"]! == 1 && !belongsToMaster {
                    continue
                }
                
                let item = ReferenceItem(nodeGraph.mmView)
                
                let name : String = node.name + " (" + node.type + ")"
                
                let master = nodeGraph.getMasterForNode(node)!
                var category : String = master.type + ": " + master.name
                if belongsToMaster {
                    category += " - Self"
                }
                
                item.name.setText( name, scale: 0.4)
                item.category.setText(category, scale: 0.3)
                item.color = nodeGraph.mmView.skin.Node.propertyColor
                item.uuid = node.uuid
                item.classUUID = master.uuid

                if belongsToMaster {
                    refs.insert(item, at: selfOffset)
                    selfOffset += 1
                } else {
                    refs.append(item)
                }
            }
        }
    }
    
    func createBehaviorTreesList()
    {
        currentMode = .BehaviorTrees
        refs = []
        var selfOffset : Int = 0
        for node in nodeGraph.nodes
        {
            if node.type == "Behavior Tree" {
                let belongsToMaster = nodeGraph.currentMaster!.subset!.contains(node.uuid)
                //if node.properties["access"]! == 1 && !belongsToMaster {
                //    continue
                //}
                
                let item = ReferenceItem(nodeGraph.mmView)
                
                let name : String = node.name
                
                let master = nodeGraph.getMasterForNode(node)!
                var category : String = master.type + ": " + master.name
                if belongsToMaster {
                    category += " - Self"
                }
                
                item.name.setText( name, scale: 0.4)
                item.category.setText(category, scale: 0.3)
                item.color = nodeGraph.mmView.skin.Node.behaviorColor
                item.uuid = node.uuid
                item.classUUID = master.uuid
                
                if belongsToMaster {
                    refs.insert(item, at: selfOffset)
                    selfOffset += 1
                } else {
                    refs.append(item)
                }
            }
        }
    }
    
    func createLayerAreaList()
    {
        currentMode = .LayerAreas
        refs = []
        for node in nodeGraph.nodes
        {
            if node.type == "Layer Area" {
                let item = ReferenceItem(nodeGraph.mmView)
                
                let name : String = node.name + " (" + node.type + ")"
                
                let master = nodeGraph.getMasterForNode(node)!
                let category : String = master.type + ": " + master.name
                
                item.name.setText( name, scale: 0.4)
                item.category.setText(category, scale: 0.3)
                item.color = nodeGraph.mmView.skin.Node.propertyColor
                item.uuid = node.uuid
                item.classUUID = master.uuid
                
                refs.append(item)
            }
        }
    }
    
    func createInstanceList()
    {
        currentMode = .ObjectInstances
        refs = []
        var selfOffset : Int = 0
        for node in nodeGraph.nodes
        {
            if let layer = node as? Layer {

                for inst in layer.objectInstances {
                    let belongsToMaster = nodeGraph.currentMaster!.uuid == inst.objectUUID
                    let item = ReferenceItem(nodeGraph.mmView)
                    
                    var name : String = inst.name
                    let category : String = layer.name
                    
                    if belongsToMaster {
                        name += " - Self"
                    }
                    
                    item.name.setText( name, scale: 0.4)
                    item.category.setText(category, scale: 0.3)
                    item.color = nodeGraph.mmView.skin.Node.functionColor
                    item.uuid = inst.uuid
                    item.classUUID = layer.uuid
                    
                    if belongsToMaster {
                        refs.insert(item, at: selfOffset)
                        selfOffset += 1
                    } else {
                        refs.append(item)
                    }
                }
            }
        }
    }
    
    func createAnimationList()
    {
        currentMode = .Animations
        refs = []
        for node in nodeGraph.nodes
        {
            if let layer = node as? Layer {
                
                for inst in layer.objectInstances {
                    
                    if let object = nodeGraph.getNodeForUUID(inst.objectUUID) as? Object {
                        for seq in object.sequences {
                            let item = ReferenceItem(nodeGraph.mmView)
                        
                            let name : String = seq.name
                            let category : String = object.name
                        
                            item.name.setText( name, scale: 0.4)
                            item.category.setText(category, scale: 0.3)
                            item.color = nodeGraph.mmView.skin.Node.functionColor
                            item.uuid = seq.uuid
                            item.classUUID = inst.uuid
                        
                            refs.append(item)
                        }
                    }
                }
            }
        }
    }
    
    func draw()
    {
        let mmView = nodeGraph.mmView
        
        if offsetY < -(Float(refs.count) * itemHeight - rect.height) {
            offsetY = -(Float(refs.count) * itemHeight - rect.height)
        }
        
        if offsetY > 0 {
            offsetY = 0
        }
        
        var y : Float = rect.y + offsetY + 1
        
        let scrollRect = MMRect(rect)
        scrollRect.shrink(2,2)
        mmView?.renderer.setClipRect(scrollRect)
        
        for item in refs {
         
            if y + itemHeight < scrollRect.y || y > scrollRect.bottom() {
                y += itemHeight
                continue
            }
            
            let isSelected = selectedUUID == item.uuid
            
            mmView?.drawBox.draw(x: scrollRect.x, y: y, width: scrollRect.width, height: itemHeight, round: 12, fillColor: isSelected ? shadeColor(item.color, 0.25) : item.color)
            
            item.name.drawRightCenteredY(x: scrollRect.x, y: y, width: scrollRect.width - 5, height: 30)
            item.category.drawRightCenteredY(x: scrollRect.x, y: y + 20, width: scrollRect.width - 5, height: 30)

            y += itemHeight
        }
        mmView?.renderer.setClipRect()

        mmView?.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 2, fillColor: float4(0,0,0,0), borderColor: float4(0.173, 0.173, 0.173, 1.000))
    }
    
    func mouseDown(_ event: MMMouseEvent)
    {
        let index : Float = (event.y - rect.y - offsetY) / itemHeight
        let intIndex = Int(index)
        
        if intIndex >= 0 && intIndex < refs.count {
            selectedUUID = refs[intIndex].uuid
            selectedItem = refs[intIndex]
        }
        
        mouseIsDown = true
    }
    
    func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
    }
    
    func mouseMoved(_ event: MMMouseEvent)
    {
        if mouseIsDown && dragSource == nil {
            dragSource = createDragSource(event.x - rect.x, event.y - rect.y)
            if dragSource != nil {
                dragSource?.sourceWidget = nodeGraph.app!.editorRegion!.widget
                nodeGraph.mmView.dragStarted(source: dragSource!)
            }
        }
    }
    
    func mouseScrolled(_ event: MMMouseEvent)
    {
        offsetY += event.deltaY! * 4
        
        if !dispatched {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.nodeGraph.mmView.unlockFramerate()
                self.dispatched = false
            }
            dispatched = true
        }
        
        if nodeGraph.mmView.maxFramerateLocks == 0 {
            nodeGraph.mmView.lockFramerate()
        }
    }
    
    func mouseEnter(_ event:MMMouseEvent)
    {
    }
    
    func mouseLeave(_ event:MMMouseEvent)
    {
    }
    
    func keyDown(_ event: MMKeyEvent)
    {
    }
    
    func keyUp(_ event: MMKeyEvent)
    {
    }
    
    /// Create a drag item
    func createDragSource(_ x: Float,_ y: Float) -> ReferenceListDrag?
    {
        if selectedItem == nil {
            return nil
        }
        
        let item = selectedItem!
        var node = nodeGraph.getNodeForUUID(selectedUUID!)
        var name : String = ""
        var type : String = ""
        
        if node != nil && (currentMode == .Variables || currentMode == .LayerAreas || currentMode == .BehaviorTrees) {
            name = node!.name
            type = node!.type
        } else
        if currentMode == .ObjectInstances {
            node = nodeGraph.getNodeForUUID(item.classUUID)
            name = item.name.text
            type = "Object Instance"
        } else
        if currentMode == .Animations {
            node = nodeGraph.nodes[0]//nodeGraph.getNodeForUUID(item.classUUID)
            name = item.name.text
            type = "Animation"
        }
        
        if node != nil {
            
            var drag = ReferenceListDrag()
            
            drag.id = type
            drag.name = name
            drag.pWidgetOffset!.x = 0
            drag.pWidgetOffset!.y = 0
            
            drag.node = node
            drag.previewWidget = ReferenceThumb(nodeGraph.mmView, item: selectedItem!)
            
            drag.refItem = selectedItem!
            
            return drag
        }
        return nil
    }
    
    /// Update the current list (after undo / redo etc).
    func update() {
        if isActive == false {
            return
        }
        if currentMode == .Variables {
            createVariableList()
        }
        if currentMode == .ObjectInstances {
            createInstanceList()
        }
        if currentMode == .LayerAreas {
            createLayerAreaList()
        }
        if currentMode == .Animations {
            createAnimationList()
        }
        if currentMode == .BehaviorTrees {
            createBehaviorTreesList()
        }
    }
    
    /// Activates and switches to the given type
    func switchTo(id: String, selected: UUID? = nil)
    {
        isActive = true
        if id == "Float Variable" || id == "Direction Variable" || id == "Float2 Variable" {
            createVariableList()
            nodeGraph.previewInfoMenu.setText("Variables")
        }
        if id == "Object Instance" {
            createInstanceList()
            nodeGraph.previewInfoMenu.setText("Object Instances")
        }
        if id == "Layer Area" {
            createLayerAreaList()
            nodeGraph.previewInfoMenu.setText("Layer Areas")
        }
        if id == "Animation" {
            createAnimationList()
            nodeGraph.previewInfoMenu.setText("Animations")
        }
        if id == "Behavior Tree" {
            createBehaviorTreesList()
            nodeGraph.previewInfoMenu.setText("Behavior Trees")
        }
        
        if selected != nil {
            setSelected(selected!)
        } else
        if selectedUUID != nil {
            setSelected(selectedUUID!)
        }
    }
    
    /// Sets (and makes visible) the currently selected item
    func setSelected(_ uuid: UUID)
    {
        selectedUUID = nil
        selectedItem = nil
        
        for item in refs {
            if item.uuid == uuid {
                selectedUUID = uuid
                selectedItem = item
                
                break
            }
        }
    }
}

class ReferenceThumb : MMWidget {

    var item            : ReferenceItem
    
    init(_ mmView: MMView, item: ReferenceItem) {
        self.item = item
        super.init(mmView)
        
        rect.width = item.name.rect.width + 20
        rect.height = 30
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0) {
        
        var color : float4 = item.color
        color.w = 0.5

        mmView.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 12, fillColor: color)
        item.name.drawCentered(x: rect.x, y: rect.y, width: rect.width - 5, height: 30)
    }
}

struct ReferenceListDrag : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : float2? = float2()
    var node            : Node? = nil
    var name            : String = ""
    
    var refItem         : ReferenceItem!
}
