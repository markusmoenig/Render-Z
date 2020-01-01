//
//  SceneList.swift
//  Render-Z
//
//  Created by Markus Moenig on 1/1/20.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class SceneListItem : MMTreeWidgetItem
{
    enum SourceType : Int {
        case Variable
    }
    
    var name         : String = ""
    var uuid         : UUID = UUID()
    var color        : SIMD4<Float>? = nil
    var children     : [MMTreeWidgetItem]? = nil
    var folderOpen   : Bool = false
        
    init(_ name: String)
    {
        self.name = name
    }
}

struct SceneListDrag : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : SIMD2<Float>? = SIMD2<Float>()
    var name            : String = ""
    
    var codeFragment    : CodeFragment? = nil
}

class SceneList : MMWidget
{
    var treeWidget          : MMTreeWidget
    
    var items               : [SceneListItem] = []
    //var filteredItems       : [SourceListItem] = []
    
    var mouseIsDown         : Bool = false
    var dragSource          : SceneListDrag?
    
    override init(_ view: MMView)
    {        
        treeWidget = MMTreeWidget(view)
        treeWidget.skin.selectionColor = SIMD4<Float>(0.5,0.5,0.5,1)
        treeWidget.itemRound = 0
        treeWidget.textOnly = true
        treeWidget.unitSize -= 5
        treeWidget.itemSize -= 5

        super.init(view)

        var item        : SceneListItem
        var parent      : SceneListItem

        /*
        item = SourceListItem("Object")
        item.color = SIMD4<Float>(0.5,0.5,0.5,1)
        items.append(item)
        
        // --- Scene
        item = SourceListItem("Scene")
        item.color = SIMD4<Float>(0.5,0.5,0.5,1)
        items.append(item)*/

        parent = SceneListItem("Scene")
        parent.color = SIMD4<Float>(0.5,0.5,0.5,1)
        items.append(parent)

        item = SceneListItem("Screen Object")
        item.color = SIMD4<Float>(0.5,0.5,0.5,1)
        addSubNodeItem(parent, item)
        
        treeWidget.build(items: items, fixedWidth: 200)
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
    
    func addSubNodeItem(_ item: SceneListItem,_ subItem: SceneListItem)
    {
        subItem.color = item.color
        if item.children == nil {
            item.children = []
        }
        item.children!.append(subItem)
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )

        treeWidget.rect.x = rect.x
        treeWidget.rect.y = rect.y
        treeWidget.rect.width = rect.width
        treeWidget.rect.height = rect.height
        
        treeWidget.draw(xOffset: globalApp!.leftRegion!.rect.width - 200)
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        let changed = treeWidget.selectAt(event.x - rect.x, (event.y - rect.y), items: items)
        if changed {
            treeWidget.build(items: items, fixedWidth: 200)
        }
        mouseIsDown = true
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        /*
        if mouseIsDown && dragSource == nil {
            dragSource = createDragSource(event.x - rect.x, event.y - rect.y)
            if dragSource != nil {
                dragSource?.sourceWidget = self
                mmView.dragStarted(source: dragSource!)
            }
        }*/
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
    func createDragSource(_ x: Float,_ y: Float) -> SceneListDrag?
    {
        if let listItem = treeWidget.getCurrentItem(), listItem.children == nil {
            if let item = listItem as? SceneListItem {
                var drag = SceneListDrag()
                
                drag.id = "SceneItem"
                drag.name = item.name
                drag.pWidgetOffset!.x = x
                drag.pWidgetOffset!.y = y.truncatingRemainder(dividingBy: treeWidget.unitSize)
                                                
                let texture = treeWidget.createShapeThumbnail(item: listItem)
                drag.previewWidget = MMTextureWidget(mmView, texture: texture)
                drag.previewWidget!.zoom = 2
                
                return drag
            }
        }
        return nil
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        treeWidget.mouseScrolled(event)
    }
}
