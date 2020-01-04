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
    var color        : SIMD4<Float>? = SIMD4<Float>(0.5, 0.5, 0.5, 1)
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

class FragItem
{
    let char            : String
    var items           : [SourceListItem] = []
    
    var rect            : MMRect = MMRect()

    init(_ char: String)
    {
        self.char = char
    }
}

class CodeFragList : MMWidget
{
    var listWidget          : MMTreeWidget
    
    var items               : [FragItem] = []
    
    var fragArea            : MMRect = MMRect()
    
    var mouseIsDown         : Bool = false
    var mouseDownPos    : SIMD2<Float> = SIMD2<Float>()
    
    var font                : MMFont
    var fontScale           : Float = 0.40
    
    var hoverItem           : FragItem? = nil
    var selectedItem        : FragItem? = nil
    
    var dragSource          : SourceListDrag?
        
    override init(_ view: MMView)
    {
        font = view.openSans

        listWidget = MMTreeWidget(view)
        listWidget.skin.selectionColor = SIMD4<Float>(0.5,0.5,0.5,1)
        listWidget.itemRound = 0
        listWidget.textOnly = true
        listWidget.unitSize -= 5
        listWidget.itemSize -= 5

        super.init(view)

        var item = FragItem("A")
        items.append(item)
        item.items.append( SourceListItem("abs", CodeFragment(.Primitive, "float" ) ) )
        
        item = FragItem("F")
        items.append(item)
        item.items.append( SourceListItem("float (variable)", CodeFragment(.VariableDefinition, "float", "", [.Selectable, .Dragable, .Monitorable], ["float"], "float" ) ) )
        
        item = FragItem("G")
        items.append(item)
        item.items.append( SourceListItem("GlobalTime", CodeFragment(.Primitive, "float", "GlobalTime", [.Selectable], nil, "float" ) ) )
        
        item = FragItem("I")
        items.append(item)
        item.items.append( SourceListItem("int (variable)", CodeFragment(.VariableDefinition, "int", "", [.Selectable, .Dragable, .Monitorable], ["int"], "int" ) ) )
        
        item = FragItem("S")
        items.append(item)
        item.items.append( SourceListItem("sin", CodeFragment(.Primitive, "float", "sin", [.Selectable], ["float|float2|float3|float4"], "input" ) ) )
        item.items.append( SourceListItem("smoothstep", CodeFragment(.Primitive, "float", "smoothstep", [.Selectable] ) ) )
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
        
        let lineHeight = font.getLineHeight(fontScale)
        
        var cX : Float = 4
        let cY : Float = rect.y + rect.height - 40
        
        let tempRect = MMRect()
        
        for item in items {
            font.getTextRect(text: item.char, scale: fontScale, rectToUse: tempRect)
            mmView.drawText.drawText(font, text: item.char, x: cX + (lineHeight - tempRect.width)/2, y: cY, scale: fontScale, color: mmView.skin.Widget.textColor)
            
            item.rect.x = cX
            item.rect.y = cY
            item.rect.width = lineHeight
            item.rect.height = lineHeight
            
            if hoverItem === item || selectedItem === item {
                let alpha : Float = selectedItem === item ? 0.7 : 0.5
                mmView.drawBox.draw( x: item.rect.x, y: item.rect.y, width: item.rect.width, height: item.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
            }

            cX += lineHeight
        }
        
        listWidget.rect.x = rect.x
        listWidget.rect.y = rect.y
        listWidget.rect.width = rect.width
        listWidget.rect.height = rect.height - 40
        
        listWidget.draw(xOffset: globalApp!.leftRegion!.rect.width - 200)
        
        if selectedItem == nil {
            selectItem(items[0])
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        if listWidget.rect.contains(event.x, event.y) && selectedItem != nil {
            let changed = listWidget.selectAt(event.x - rect.x, (event.y - rect.y), items: selectedItem!.items)
            if changed {
                
                listWidget.build(items: selectedItem!.items, fixedWidth: 200)
              //  mmView.update()
            }
            return
        }
        mouseMoved(event)
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
        if listWidget.rect.contains(event.x, event.y) {
            listWidget.mouseUp(event)
            return
        }
    }
    
    //override func mouseLeave(_ event: MMMouseEvent) {
    //    hoverItem = nil
    //}
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if listWidget.rect.contains(event.x, event.y) {
            let dist = distance(mouseDownPos, SIMD2<Float>(event.x, event.y))
            if dist > 5 {
                if mouseIsDown && dragSource == nil {
                    
                    dragSource = createDragSource(event.x - rect.x, event.y - rect.y)
                    if dragSource != nil {
                        dragSource?.sourceWidget = self
                        mmView.dragStarted(source: dragSource!)
                    }
                }
                return
            }
        }
        
        if mmView.dragSource != nil {
            return
        }
        
        let oldHoverItem = hoverItem
        hoverItem = nil
        for item in items {
            if item.rect.contains(event.x, event.y) {
                
                hoverItem = item
                #if os(OSX)
                if mouseIsDown {
                    if selectedItem !== item {
                        selectItem(item)
                    }
                }
                #else
                if selectedItem !== item {
                    selectItem(item)
                }
                #endif
                break
            }
        }
        
        if oldHoverItem !== hoverItem {
            mmView.update()
        }
    }
    
    func selectItem(_ item: FragItem)
    {
        selectedItem = item
        listWidget.selectedItems = []
        listWidget.build(items: item.items, fixedWidth: 200)
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        listWidget.mouseScrolled(event)
    }
    
    /// Create a drag item
    func createDragSource(_ x: Float,_ y: Float) -> SourceListDrag?
    {
        if let listItem = listWidget.getCurrentItem(), listItem.children == nil {
            if let item = listItem as? SourceListItem, item.codeFragment != nil {
                var drag = SourceListDrag()
                
                drag.id = "SourceFragmentItem"
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
    
    override func dragTerminated() {
        dragSource = nil
        mmView.unlockFramerate()
        mouseIsDown = false
    }
}
