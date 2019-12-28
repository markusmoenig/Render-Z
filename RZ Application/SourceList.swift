//
//  SourceList.swift
//  Shape-Z
//
//  Created by Markus Moenig on 26/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class SourceListItem : MMTreeWidgetItem
{
    enum SourceType : Int {
        case Variable
    }
    
    var name         : String = ""
    var uuid         : UUID = UUID()
    var color        : SIMD4<Float>? = nil
    var children     : [MMTreeWidgetItem]? = nil
    var folderOpen   : Bool = false
    
    let sourceType   : SourceType = .Variable
    
    let codeFragment : CodeFragment?
        
    init(_ name: String,_ codeFragment: CodeFragment? = nil)
    {
        self.name = name
        self.codeFragment = codeFragment
    }
}

struct SourceListDrag : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : SIMD2<Float>? = SIMD2<Float>()
    var name            : String = ""
    
    var codeFragment    : CodeFragment? = nil
}

class SourceList : MMWidget
{
    var listWidget          : MMTreeWidget
    
    var items               : [SourceListItem] = []
    //var filteredItems       : [SourceListItem] = []
    
    var mouseIsDown         : Bool = false
    var dragSource          : SourceListDrag?
    
    override init(_ view: MMView)
    {        
        listWidget = MMTreeWidget(view)
        listWidget.skin.selectionColor = SIMD4<Float>(0.5,0.5,0.5,1)
        listWidget.itemRound = 0
        
        super.init(view)

        var item        : SourceListItem
        var parent      : SourceListItem

        /*
        item = SourceListItem("Object")
        item.color = SIMD4<Float>(0.5,0.5,0.5,1)
        items.append(item)
        
        // --- Scene
        item = SourceListItem("Scene")
        item.color = SIMD4<Float>(0.5,0.5,0.5,1)
        items.append(item)*/

        parent = SourceListItem("Variables")
        parent.color = SIMD4<Float>(0.5,0.5,0.5,1)
        items.append(parent)

        item = SourceListItem("Float", CodeFragment(.VariableDefinition, "float"))
        item.color = SIMD4<Float>(0.5,0.5,0.5,1)
        addSubNodeItem(parent, item)
        
        listWidget.build(items: items, fixedWidth: 200)
    }
    
    /*
    /// Adds a given node list item and assigns the brand and display type of the node
    @discardableResult func addNodeItem(_ item: SourceListItem, type: Node.Brand, displayType: SourceListItem.DisplayType) -> NodeListItem
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
        return item
    }*/
    
    func addSubNodeItem(_ item: SourceListItem,_ subItem: SourceListItem)
    {
        subItem.color = item.color
        if item.children == nil {
            item.children = []
        }
        item.children!.append(subItem)
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 1,  fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )

        listWidget.rect.x = rect.x
        listWidget.rect.y = rect.y
        listWidget.rect.width = rect.width
        listWidget.rect.height = rect.height
        
        listWidget.draw(xOffset: globalApp!.leftRegion!.rect.width - 200)
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
    
    /// Create a drag item
    func createDragSource(_ x: Float,_ y: Float) -> SourceListDrag?
    {
        if let listItem = listWidget.getCurrentItem(), listItem.children == nil {
            if let item = listItem as? SourceListItem, item.codeFragment != nil {
                var drag = SourceListDrag()
                
                drag.id = "SourceItem"
                drag.name = item.name
                drag.pWidgetOffset!.x = x
                drag.pWidgetOffset!.y = y.truncatingRemainder(dividingBy: listWidget.unitSize)
                
                drag.codeFragment = item.codeFragment
                                
                let texture = listWidget.createShapeThumbnail(item: listItem)
                drag.previewWidget = MMTextureWidget(mmView, texture: texture)
                drag.previewWidget!.zoom = 2
                
                return drag
            }
        }
        return nil
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        listWidget.mouseScrolled(event)
    }
}
