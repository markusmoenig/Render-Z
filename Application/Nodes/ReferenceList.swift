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
        case Variables
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

    var dragSource          : NodeListDrag? = nil
    var mouseIsDown         : Bool = false

    init(_ nodeGraph: NodeGraph)
    {
        self.nodeGraph = nodeGraph
    }
    
    func createVariableList()
    {
        currentMode = .Variables
        refs = []
        for node in nodeGraph.nodes
        {
            if node.type == "Value Variable" || node.type == "Direction Variable" {
                let item = ReferenceItem(nodeGraph.mmView)
                
                let name : String = node.name + " (" + node.type + ")"
                
                let master = nodeGraph.getMasterForNode(node)!
                let category : String = master.type + ": " + master.name
                
                item.name.setText( name, scale: 0.4)
                item.category.setText(category, scale: 0.3)
                item.color = nodeGraph.mmView.skin.Node.propertyColor
                item.uuid = node.uuid
                
                refs.append(item)
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
        
        var y : Float = rect.y + offsetY
        
        mmView?.renderer.setClipRect(rect)
        
        for item in refs {
         
            if y + itemHeight < rect.y || y > rect.bottom() {
                y += itemHeight
                continue
            }
            
            let isSelected = selectedUUID == item.uuid
            
            mmView?.drawBox.draw(x: rect.x, y: y, width: rect.width, height: itemHeight, round: 12, fillColor: isSelected ? float4( 0.5, 0.5, 0.5, 1) : item.color)
            
            item.name.drawRightCenteredY(x: rect.x, y: y, width: rect.width - 5, height: 30)
            item.category.drawRightCenteredY(x: rect.x, y: y + 20, width: rect.width - 5, height: 30)

            y += itemHeight
        }
        
        mmView?.renderer.setClipRect()
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
    func createDragSource(_ x: Float,_ y: Float) -> NodeListDrag?
    {
        if selectedUUID == nil {
            return nil
        }
        let node = nodeGraph.getNodeForUUID(selectedUUID!)
        
        if node != nil {
            
            var drag = NodeListDrag()
            
            drag.id = node!.type
            drag.name = node!.name
            drag.pWidgetOffset!.x = 0
            drag.pWidgetOffset!.y = 0
            
            drag.node = node
            drag.previewWidget = ReferenceThumb(nodeGraph.mmView, item: selectedItem!)
            
            return drag
        }
        return nil
    }
    
    /// Update the current list (after undo / redo etc).
    func update() {
        if currentMode == .Variables {
            createVariableList()
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
