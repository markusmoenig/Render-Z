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
    var treeWidget          : SceneTreeWidget
        
    var mouseIsDown         : Bool = false
    var dragSource          : SceneListDrag?
    
    override init(_ view: MMView)
    {        
        treeWidget = SceneTreeWidget(view)
        treeWidget.skin.selectionColor = SIMD4<Float>(0.5,0.5,0.5,1)
        treeWidget.itemRound = 0
        treeWidget.textOnly = true
        treeWidget.unitSize -= 5
        treeWidget.itemSize -= 5

        super.init(view)
    }
    
    /// Sets the current scene to display
    func setScene(_ scene: Scene)
    {
        treeWidget.build(scene: scene, fixedWidth: 200)
    }
    
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
        let changed = treeWidget.selectAt(event.x - rect.x, (event.y - rect.y))
        if changed {
            treeWidget.build(scene: globalApp!.project.scenes[0], fixedWidth: 200)
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
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        treeWidget.mouseScrolled(event)
    }
}

// -------------------------------------------------------------------------------- TreeWidget

class SceneTreeWidget   : MMWidget
{
    enum HoverState {
        case None, HoverUp, HoverDown, Close
    }
    
    var hoverState      : HoverState = .None
    
    var fragment        : MMFragment?
    
    var width, height   : Float
    var spacing         : Float
    
    var unitSize        : Float
    var itemSize        : Float
    
    var hoverData       : [Float]
    var hoverBuffer     : MTLBuffer?
    var hoverIndex      : Int = -1
    
    var textureWidget   : MMTextureWidget
    var scrollArea      : MMScrollArea
    
    //var selectionChanged: ((_ item: [MMTreeWidgetItem])->())? = nil
    
    var skin            : MMSkinWidget
    
    var supportsUpDown  : Bool = false
    var supportsClose   : Bool = false
    
    var scene           : Scene? = nil
    
    var selectionShade  : Float = 0.25
    
    var itemRound       : Float = 0
    
    var textOnly        : Bool = false
    
    override init(_ view: MMView)
    {
        scrollArea = MMScrollArea(view, orientation: .Vertical)
        skin = view.skin.Widget
        
        width = 0
        height = 0
        
        fragment = MMFragment(view)
        fragment!.allocateTexture(width: 10, height: 10)
        
        spacing = 0
        unitSize = 35
        itemSize = 35

        textureWidget = MMTextureWidget( view, texture: fragment!.texture )

        hoverData = [-1,0]
        hoverBuffer = fragment!.device.makeBuffer(bytes: hoverData, length: hoverData.count * MemoryLayout<Float>.stride, options: [])!
        
        super.init(view)
        zoom = mmView.scaleFactor
        textureWidget.zoom = zoom
    }
    
    /// Build the source
    func build(scene: Scene, fixedWidth: Float? = nil, supportsUpDown: Bool = false, supportsClose: Bool = false)
    {
        width = fixedWidth != nil ? fixedWidth! : rect.width
        height = 0
        if width == 0 {
            width = 1
        }
    
        // --- Calculate height
        func getChildHeight(_ items: [StageItem]) {
            for item in items {
                if item.folderIsOpen == false {
                    height += unitSize
                } else {
                    height += itemSize
                    getChildHeight(item.children)
                }
                height += spacing
            }
        }
        
        for stage in scene.stages {
            if stage.folderIsOpen == false {
                height += unitSize
            } else {
                height += itemSize
                getChildHeight(stage.children)
            }
            height += spacing
        }
        
        height *= zoom
        if height == 0 { height = 1 }
        
        // ---
        
        self.scene = scene
        self.supportsUpDown = supportsUpDown
        self.supportsClose = supportsClose
        
        if self.fragment!.width != self.width * zoom || self.fragment!.height != self.height {
            self.fragment!.allocateTexture(width: self.width * zoom, height: self.height)
        }
        self.textureWidget.setTexture(self.fragment!.texture)
        self.update()
    }
    
    override func update()
    {
        memcpy(hoverBuffer!.contents(), hoverData, hoverData.count * MemoryLayout<Float>.stride)

        if fragment!.encoderStart() {
                        
            let left        : Float = 12
            var top         : Float = 0
            var indent      : Float = 0
            let indentSize  : Float = 4
            let fontScale   : Float = 0.44
            
            //var fontRect = MMRect()
            
            func drawStage(_ item: Stage) {
                
                let color = SIMD4<Float>(0.5, 0.5, 0.5, 1)
                if scene?.selectedUUID == item.uuid {
                    mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: shadeColor(color, selectionShade), fragment: fragment!)
                } else {
                    if textOnly == false {
                        mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: color, fragment: fragment!)
                    }
                }

                //fontRect = mmView.openSans.getTextRect(text: text, scale: fontScale, rectToUse: fontRect)
                
                let text : String = item.folderIsOpen == false ? "+" : "-"
                mmView.drawText.drawText(mmView.openSans, text: text, x: left + indent, y: top + 8, scale: fontScale, fragment: fragment)
                mmView.drawText.drawText(mmView.openSans, text: item.name, x: left + indent + 15, y: top + 8, scale: fontScale, fragment: fragment)
                
                top += unitSize
            }
            
            func drawItem(_ item: StageItem) {
                
                let color = SIMD4<Float>(0.5, 0.5, 0.5, 1)
                if scene?.selectedUUID == item.uuid {
                    mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: shadeColor(color, selectionShade), fragment: fragment!)
                } else {
                    if textOnly == false {
                        mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: color, fragment: fragment!)
                    }
                }

                //fontRect = mmView.openSans.getTextRect(text: text, scale: fontScale, rectToUse: fontRect)
                
                if item.children.count > 0 {
                    let text : String = item.folderIsOpen == false ? "+" : "-"
                    mmView.drawText.drawText(mmView.openSans, text: text, x: left + indent, y: top + 8, scale: fontScale, fragment: fragment)
                    mmView.drawText.drawText(mmView.openSans, text: item.name, x: left + indent + 15, y: top + 8, scale: fontScale, fragment: fragment)
                } else {
                    mmView.drawText.drawText(mmView.openSans, text: item.name, x: left + indent, y: top + 8, scale: fontScale, fragment: fragment)
                }
                
                top += unitSize
            }
            
            if let scene = self.scene {
                func drawChildren(_ items: [StageItem]) {
                    indent += indentSize
                    for item in items {
                        drawItem(item)
                        if item.folderIsOpen == true {
                            drawChildren(item.children)
                        }
                        height += spacing
                    }
                    indent -= indentSize
                }
                
                for stage in scene.stages {
                    drawStage(stage)
                    if stage.folderIsOpen == true {
                        drawChildren(stage.children)
                    }
                }
            }
            
            fragment!.encodeEnd()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        scrollArea.rect.copy(rect)
        scrollArea.build(widget:textureWidget, area: rect, xOffset: xOffset)
    }
    
    // Draws a round border around the widget
    func drawRoundedBorder(backColor: SIMD4<Float>, borderColor: SIMD4<Float>)
    {
        let cb : Float = 2
        // Erase Edges
        mmView.drawBox.draw( x: rect.x - cb + 1, y: rect.y - cb, width: rect.width + 2*cb - 2, height: rect.height + 2*cb, round: 30, borderSize: 4, fillColor: SIMD4<Float>(0,0,0,0), borderColor: backColor)
        
        mmView.drawBox.draw( x: rect.x - cb + 1, y: rect.y - cb, width: rect.width + 2*cb - 2, height: rect.height + 2*cb, round: 0, borderSize: 4, fillColor: SIMD4<Float>(0,0,0,0), borderColor: backColor)
        
        // Box Border
        mmView.drawBox.draw( x: rect.x, y: rect.y - 1, width: rect.width, height: rect.height + 2, round: 30, borderSize: 1, fillColor: SIMD4<Float>(0,0,0,0), borderColor: borderColor)
    }
    
    /// Select the item at the given relative mouse position
    @discardableResult func selectAt(_ x: Float,_ y: Float) -> Bool
    {
        var changed : Bool = false
        
        if let item = itemAt(x, y) {
            
            //print( item.name )
            if let stage = item as? Stage {
                stage.folderIsOpen = !stage.folderIsOpen
            }
            if let stageItem = item as? StageItem {
                stageItem.folderIsOpen = !stageItem.folderIsOpen
                //selectedItems = [stageItem.uuid]
                
                scene?.setSelected(stageItem)
                
               // if selectionChanged != nil {
               //     selectionChanged!( [item] )
               // }
            }

            changed = true
        }
        
        return changed
    }
    
    /// Returns the item at the given location
    @discardableResult func itemAt(_ x: Float,_ y: Float) -> Any?
    {
        let offset          : Float = y - scrollArea.offsetY
        var bottom          : Float = 0
        var selectedStage   : Stage? = nil
        var selectedItem    : StageItem? = nil

        func getChildHeight(_ items: [StageItem]) {
            for item in items {
                if item.folderIsOpen == false {
                    bottom += unitSize
                    if selectedItem == nil && bottom > offset {
                        selectedItem = item
                    }
                } else {
                    bottom += itemSize
                    if selectedItem == nil && bottom > offset {
                        selectedItem = item
                    }
                    getChildHeight(item.children)
                }
                bottom += spacing
            }
        }
        
        if let scene = self.scene {
            for stage in scene.stages {
                if stage.folderIsOpen == false {
                    bottom += unitSize
                    if selectedStage == nil && selectedItem == nil && bottom > offset {
                        selectedStage = stage
                    }
                } else {
                    bottom += itemSize
                    if selectedStage == nil && selectedItem == nil && bottom > offset {
                        selectedStage = stage
                    }
                    getChildHeight(stage.children)
                }
                height += spacing
            }
        }
        
        if selectedStage != nil {
            return selectedStage
        } else
        if selectedItem != nil {
            return selectedItem
        } else {
            return nil
        }
    }
    
    /// Sets the hover index for the given mouse position
    /*
    @discardableResult func hoverAt(_ x: Float,_ y: Float) -> Bool
    {
        let index : Float = y / (unitSize+spacing)
        hoverIndex = Int(index)
        let oldIndex = hoverData[0]
        hoverData[0] = -1
        hoverState = .None

        if hoverIndex >= 0 && hoverIndex < items.count {
            if supportsUpDown {
                if x >= 172 && x <= 201 {
                    hoverData[0] = Float(hoverIndex*3)
                    hoverState = .HoverUp
                } else
                if x >= 207 && x <= 235 {
                    hoverData[0] = Float(hoverIndex*3+1)
                    hoverState = .HoverDown
                }
            }
            if supportsClose {
                if x >= 262 && x <= 291 {
                    hoverData[0] = Float(hoverIndex*3+2)
                    hoverState = .Close
                }
            }
        }
        
        return hoverData[0] != oldIndex
    }*/
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        scrollArea.mouseScrolled(event)
    }
    
    /// Creates a thumbnail for the given item
    func createShapeThumbnail(item: MMTreeWidgetItem, customWidth: Float = 200) -> MTLTexture?
    {
        let width : Float = customWidth * zoom
        let height : Float = unitSize * zoom
        
        let texture = fragment!.allocateTexture(width: width, height: height, output: true)
                
        if fragment!.encoderStart(outTexture: texture) {
                        
            let left : Float = 6 * zoom
            let top : Float = 0
            let fontScale : Float = 0.22
            
            var fontRect = MMRect()
            
            var color = shadeColor(item.color!, selectionShade)
            color.w = 0.4
            mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: color, fragment: fragment!)
            
            fontRect = mmView.openSans.getTextRect(text: item.name, scale: fontScale, rectToUse: fontRect)
            mmView.drawText.drawText(mmView.openSans, text: item.name, x: left, y: top + 4 * zoom, scale: fontScale * zoom, fragment: fragment)
 
            fragment!.encodeEnd()
        }
        
        return texture
    }
    
    /// Creates a thumbnail for the given item
    func createGenericThumbnail(_ name: String,_ width: Float) -> MTLTexture?
    {
        let item = DummyTreeWidgetItem(name)
        item.name = name
       
        return createShapeThumbnail(item: item, customWidth: width)
   }
    
    /// Returns the item of the given uuid
    /*
    func itemOfUUID(_ uuid: UUID) -> MMTreeWidgetItem?
    {
        for item in items {
            if item.uuid == uuid {
                return item
            }
        }
        return nil
    }*/
    
    /// Return the current item (index 0 in selected items)
    /*
    func getCurrentItem() -> MMTreeWidgetItem?
    {
        var selected    : MMTreeWidgetItem? = nil
        
        if selectedItems.count == 0 {
            return nil
        }
        
        let uuid = selectedItems[0]
        
        func parseChildren(_ item: MMTreeWidgetItem) {
            for item in item.children! {
                if selected == nil && item.uuid == uuid {
                    selected = item
                }
                if item.folderOpen == true {
                    parseChildren(item)
                }
            }
        }
        
        for item in items {
            if selected == nil && item.uuid == uuid {
                selected = item
            }
            if item.folderOpen == true {
                parseChildren(item)
            }
        }
        
        return selected
    }*/
}
