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
    var mouseDownPos        : SIMD2<Float> = SIMD2<Float>()
    
    var font                : MMFont
    var fontScale           : Float = 0.40
    
    var hoverItem           : FragItem? = nil
    var selectedItem        : FragItem? = nil
    
    var dragSource          : SourceListDrag?
    var buildIt             : Bool = true
    
    static var openWidth    : Float = 120
        
    override init(_ view: MMView)
    {
        font = view.openSans

        listWidget = MMTreeWidget(view)
        listWidget.skin.selectionColor = SIMD4<Float>(0.5,0.5,0.5,1)
        listWidget.itemRound = 0
        listWidget.textOnly = true
        listWidget.unitSize -= 5
        listWidget.itemSize -= 5
        
        listWidget.selectionColor = SIMD4<Float>(0.2, 0.2, 0.2, 1)

        super.init(view)

        var item = FragItem("A")
        items.append(item)
        item.items.append( SourceListItem("abs", CodeFragment(.Primitive, "float", "abs", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("acos", CodeFragment(.Primitive, "float", "acos", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("asin", CodeFragment(.Primitive, "float", "asin", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("atan", CodeFragment(.Primitive, "float", "atan", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("atan2", CodeFragment(.Primitive, "float", "atan2", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4", "float|float2|float3|float4"], "input0" ) ) )
        
        item = FragItem("B")
        items.append(item)
        item.items.append( SourceListItem("break", CodeFragment(.Primitive, "block", "break")) )

        item = FragItem("C")
        items.append(item)
        item.items.append( SourceListItem("clamp", CodeFragment(.Primitive, "float", "clamp", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4", "float|float2|float3|float4", "float|float2|float3|float4"], "input0"  ) ) )
        item.items.append( SourceListItem("cos", CodeFragment(.Primitive, "float", "cos", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("cross", CodeFragment(.Primitive, "float3", "cross", [.Selectable, .Dragable, .Targetable], ["float3|float4", "float3|float4"], "input" ) ) )
        
        item = FragItem("D")
        items.append(item)
        item.items.append( SourceListItem("degrees", CodeFragment(.Primitive, "float", "degrees", [.Selectable, .Dragable, .Targetable], ["float"], "float" ) ) )
        item.items.append( SourceListItem("distance", CodeFragment(.Primitive, "float", "distance", [.Selectable, .Dragable, .Targetable], ["float2|float3|float4", "float2|float3|float4"], "float" ) ) )
        item.items.append( SourceListItem("dot", CodeFragment(.Primitive, "float", "dot", [.Selectable, .Dragable, .Targetable], ["float2|float3|float4", "float2|float3|float4"], "float" ) ) )

        item = FragItem("E")
        items.append(item)
        item.items.append( SourceListItem("exp", CodeFragment(.Primitive, "float", "exp", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("exp2", CodeFragment(.Primitive, "float", "exp2", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        
        item = FragItem("F")
        items.append(item)
        item.items.append( SourceListItem("float", CodeFragment(.VariableDefinition, "float", "", [.Selectable, .Dragable, .Monitorable], ["float"], "float" ) ) )
        item.items.append( SourceListItem("float2", CodeFragment(.VariableDefinition, "float2", "", [.Selectable, .Dragable, .Monitorable], ["float2"], "float2" ) ) )
        item.items.append( SourceListItem("float3", CodeFragment(.VariableDefinition, "float3", "", [.Selectable, .Dragable, .Monitorable], ["float3"], "float3" ) ) )
        item.items.append( SourceListItem("float4", CodeFragment(.VariableDefinition, "float4", "", [.Selectable, .Dragable, .Monitorable], ["float4"], "float4" ) ) )
        item.items.append( SourceListItem("floor", CodeFragment(.Primitive, "float", "floor", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("for", CodeFragment(.Primitive, "block", "for")) )
        item.items.append( SourceListItem("fract", CodeFragment(.Primitive, "float", "fract", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("function", CodeFragment(.Primitive, "float", "function")) )
        
        item = FragItem("G")
        items.append(item)
        item.items.append( SourceListItem("GlobalTime", CodeFragment(.Primitive, "float", "GlobalTime", [.Selectable, .Dragable, .Targetable], nil, "float" ) ) )
        
        item = FragItem("I")
        items.append(item)
        item.items.append( SourceListItem("if (...)", CodeFragment(.Primitive, "block", "if")))
        item.items.append( SourceListItem("if (...) else ", CodeFragment(.Primitive, "block", "if else")))
        item.items.append( SourceListItem("int", CodeFragment(.VariableDefinition, "int", "", [.Selectable, .Dragable, .Monitorable], ["int"], "int" ) ) )
        //?? item.items.append( SourceListItem("inversesqrt", CodeFragment(.Primitive, "float", "inversesqrt", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        
        item = FragItem("L")
        items.append(item)
        item.items.append( SourceListItem("length", CodeFragment(.Primitive, "float", "length", [.Selectable, .Dragable, .Targetable], ["float2|float3|float4"], "float" ) ) )
        item.items.append( SourceListItem("log", CodeFragment(.Primitive, "float", "log", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("log2", CodeFragment(.Primitive, "float", "log2", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        
        item = FragItem("M")
        items.append(item)
        item.items.append( SourceListItem("max", CodeFragment(.Primitive, "float", "max", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4", "float|float2|float3|float4"], "input0"  ) ) )
        item.items.append( SourceListItem("min", CodeFragment(.Primitive, "float", "min", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4", "float|float2|float3|float4"], "input0"  ) ) )
        item.items.append( SourceListItem("mix", CodeFragment(.Primitive, "float", "mix", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4", "float|float2|float3|float4", "float"], "input0"  ) ) )
        item.items.append( SourceListItem("mod", CodeFragment(.Primitive, "float", "mod", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4", "float|float2|float3|float4"], "input0"  ) ) )
        
        item = FragItem("N")
        items.append(item)
        item.items.append( SourceListItem("normalize", CodeFragment(.Primitive, "float2", "normalize", [.Selectable, .Dragable, .Targetable], ["float2|float3|float4"], "input0" ) ) )
        
        item = FragItem("P")
        items.append(item)
        item.items.append( SourceListItem("pow", CodeFragment(.Primitive, "float", "pow", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4", "float|float2|float3|float4"], "input0" ) ) )
        
        item = FragItem("R")
        items.append(item)
        item.items.append( SourceListItem("radians", CodeFragment(.Primitive, "float", "radians", [.Selectable, .Dragable, .Targetable], ["float"], "float" ) ) )
        item.items.append( SourceListItem("reflect", CodeFragment(.Primitive, "float2", "reflect", [.Selectable, .Dragable, .Targetable], ["float2|float3|float4", "float2|float3|float4"], "input0"  ) ) )
        item.items.append( SourceListItem("refract", CodeFragment(.Primitive, "float2", "refract", [.Selectable, .Dragable, .Targetable], ["float2|float3|float4", "float2|float3|float4", "float"], "input0"  ) ) )
        
        item = FragItem("S")
        items.append(item)
        item.items.append( SourceListItem("sign", CodeFragment(.Primitive, "float", "sign", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("sin", CodeFragment(.Primitive, "float", "sin", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("smoothstep", CodeFragment(.Primitive, "float", "smoothstep", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4", "float|float2|float3|float4", "float"], "input0"  ) ) )
        item.items.append( SourceListItem("sqrt", CodeFragment(.Primitive, "float", "sqrt", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("step", CodeFragment(.Primitive, "float", "step", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4", "float|float2|float3|float4"], "input0"  ) ) )
        
        item = FragItem("T")
        items.append(item)
        item.items.append( SourceListItem("tan", CodeFragment(.Primitive, "float", "tan", [.Selectable, .Dragable, .Targetable], ["float|float2|float3|float4"], "input0" ) ) )
        item.items.append( SourceListItem("toGamma", CodeFragment(.Primitive, "float4", "toGamma", [.Selectable, .Dragable, .Targetable], ["float4"], "float4" ) ) )
        item.items.append( SourceListItem("toLinear", CodeFragment(.Primitive, "float4", "toLinear", [.Selectable, .Dragable, .Targetable], ["float4"], "float4" ) ) )
        
        item = FragItem("U")
        items.append(item)
        item.items.append( SourceListItem("uint", CodeFragment(.VariableDefinition, "uint", "", [.Selectable, .Dragable, .Monitorable], ["uint"], "uint" ) ) )
        //item.items.append( SourceListItem("uint2", CodeFragment(.VariableDefinition, "uint2", "", [.Selectable, .Dragable, .Monitorable], ["uint2"], "uint2" ) ) )
        //item.items.append( SourceListItem("uint3", CodeFragment(.VariableDefinition, "uint3", "", [.Selectable, .Dragable, .Monitorable], ["uint3"], "uint3" ) ) )
        //item.items.append( SourceListItem("uint4", CodeFragment(.VariableDefinition, "uint4", "", [.Selectable, .Dragable, .Monitorable], ["uint4"], "uint4" ) ) )
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if buildIt {
            selectItem(items[0])
            listWidget.build(items: selectedItem!.items, fixedWidth: CodeFragList.openWidth)
            buildIt = false
        }

        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
        
        let lineHeight = font.getLineHeight(fontScale)
        let radius : Float = lineHeight * 0.75
        
        var cX : Float = 15
        var cY : Float = rect.y + rect.height - 140
        
        let tempRect = MMRect()
        
        for (index,item) in items.enumerated() {
            font.getTextRect(text: item.char, scale: fontScale, rectToUse: tempRect)
            mmView.drawText.drawText(font, text: item.char, x: cX + (radius - tempRect.width)/2, y: cY - 2, scale: fontScale, color: mmView.skin.Widget.textColor)
            
            item.rect.x = cX
            item.rect.y = cY
            item.rect.width = lineHeight
            item.rect.height = lineHeight
            
            if hoverItem === item || selectedItem === item {
                let alpha : Float = selectedItem === item ? 0.7 : 0.5
                mmView.drawSphere.draw( x: item.rect.x - radius / 2, y: item.rect.y - radius / 2, radius: radius, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
            }
            
            if (index+1) % 4 == 0 {
                cX = 15
                cY += lineHeight * 1.7
            } else {
                cX += lineHeight * 1.5
            }
        }
        
        listWidget.rect.x = rect.x
        listWidget.rect.y = rect.y
        listWidget.rect.width = rect.width
        listWidget.rect.height = rect.height - 140
        
        listWidget.draw(xOffset: globalApp!.leftRegion!.rect.width - CodeFragList.openWidth)
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        if listWidget.rect.contains(event.x, event.y) && selectedItem != nil {
            let changed = listWidget.selectAt(event.x - rect.x, (event.y - rect.y), items: selectedItem!.items)
            if changed {
                
                listWidget.build(items: selectedItem!.items, fixedWidth: CodeFragList.openWidth)
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
                    
        for item in item.items{
            item.color = item.codeFragment!.fragmentType == .Primitive ? mmView.skin.Code.name : mmView.skin.Code.reserved
        }
        
        listWidget.build(items: item.items, fixedWidth: CodeFragList.openWidth)
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
