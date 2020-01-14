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

struct SceneListDrag    : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : SIMD2<Float>? = SIMD2<Float>()
    var name            : String = ""
    
    var codeFragment    : CodeFragment? = nil
}

class SceneInfoItem
{
    var name            : String
    var cb              : (()->())? = nil
    var rect            : MMRect = MMRect()
    var label           : MMTextLabel
    
    init(_ view: MMView,_ name: String,_ cb: (()->())? = nil)
    {
        self.name = name
        self.cb = cb
        
        label = MMTextLabel(view, font: view.openSans, text: name, scale: 0.4)
    }
}

class SceneList : MMWidget
{
    var treeWidget          : SceneTreeWidget
    var infoRect            : MMRect = MMRect()
        
    var mouseIsDown         : Bool = false
    var dragSource          : SceneListDrag?
    
    var infoItems           : [SceneInfoItem] = []
    var hoverInfoItem       : SceneInfoItem? = nil
    
    var currentScene        : Scene? = nil
    
    static var InfoHeight   : Float = 30
    
    override init(_ view: MMView)
    {        
        treeWidget = SceneTreeWidget(view)
        treeWidget.skin.selectionColor = SIMD4<Float>(0.5,0.5,0.5,1)
        treeWidget.itemRound = 0
        treeWidget.textOnly = true
        treeWidget.unitSize -= 5
        treeWidget.itemSize -= 5

        infoItems = [SceneInfoItem(view, "Render-Z")]
        
        super.init(view)
    }
    
    /// Sets the current scene to display
    func setScene(_ scene: Scene)
    {
        currentScene = scene
        treeWidget.build(scene: scene, fixedWidth: 200)
    }
    
    func updateTree() {
        if let scene = currentScene {
            treeWidget.build(scene: scene, fixedWidth: 200)
            mmView.update()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )

        treeWidget.rect.x = rect.x
        treeWidget.rect.y = rect.y
        treeWidget.rect.width = rect.width
        treeWidget.rect.height = rect.height - SceneList.InfoHeight
        
        treeWidget.draw(xOffset: globalApp!.leftRegion!.rect.width - 200)
        
        infoRect.x = rect.x
        infoRect.y = rect.y + treeWidget.rect.height
        infoRect.width = rect.width
        infoRect.height = SceneList.InfoHeight
        
        let infoItemWidth : Float = infoRect.width / Float(infoItems.count)
        
        var xOff : Float = infoRect.x
        for item in infoItems {
            item.rect.x = xOff
            item.rect.y = infoRect.y
            item.rect.width = infoItemWidth
            item.rect.height = SceneList.InfoHeight
            if item === hoverInfoItem {
                mmView.drawBox.draw( x: item.rect.x, y: item.rect.y, width: item.rect.width, height: item.rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.2, 0.2, 0.2, 1))
            }
            item.label.drawCentered(x: item.rect.x, y: item.rect.y, width: item.rect.width, height: item.rect.height)
            xOff += infoItemWidth
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if let infoItem = hoverInfoItem {
            infoItem.cb!()
        } else {
            let changed = treeWidget.selectAt(event.x - rect.x, (event.y - rect.y))
            if changed {
                treeWidget.build(scene: globalApp!.project.scenes[0], fixedWidth: 200)
                
                infoItems = []
                
                if let stage = treeWidget.infoAreaStage {
                    if stage.stageType == .PreStage {
                        infoItems = [
                            SceneInfoItem(mmView, "2D", { () in
                                globalApp!.currentSceneMode = .TwoD
                                if let scene = self.currentScene {
                                    scene.sceneMode = .TwoD
                                    self.updateTree()
                                    scene.setSelected(stage.getChildren()[0])
                                }
                                globalApp!.library.modeChanged()
                                self.treeWidget.update()
                            }),
                            SceneInfoItem(mmView, "3D", { () in
                                globalApp!.currentSceneMode = .ThreeD
                                if let scene = self.currentScene {
                                    self.updateTree()
                                    scene.setSelected(stage.getChildren()[0])
                                }
                                globalApp!.library.modeChanged()
                                self.treeWidget.update()
                            }),
                        ]
                    } else
                    if stage.stageType == .ShapeStage {
                        infoItems = [
                            SceneInfoItem(mmView, "Add Empty Object", { () in
                                
                                self.treeWidget.update()
                            })
                        ]
                    }
                }
                
                if infoItems.count == 0 {
                    infoItems = [SceneInfoItem(mmView, "Render-Z")]
                    //treeWidget.infoAreaStage = nil
                    treeWidget.infoAreaItem = nil
                    self.treeWidget.update()
                }
            }
        }
        mouseIsDown = true
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        let oldHoverItem = hoverInfoItem
        hoverInfoItem = nil
        if infoRect.contains(event.x, event.y) {
            for item in infoItems {
                if item.cb != nil && item.rect.contains(event.x, event.y) {
                    hoverInfoItem = item
                    break
                }
            }
        }
        if hoverInfoItem !== oldHoverItem {
            mmView.update()
        }
        /*
        if mouseIsDown && dragSource == nil {
            dragSource = createDragSource(event.x - rect.x, event.y - rect.y)
            if dragSource != nil {
                dragSource?.sourceWidget = self
                mmView.dragStarted(source: dragSource!)
            }
        }*/
    }
    
    override func mouseLeave(_ event: MMMouseEvent) {
        if hoverInfoItem != nil {
            hoverInfoItem = nil
            mmView.update()
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
    
    var selectionColor  : SIMD4<Float> = SIMD4<Float>(0.2, 0.2, 0.2, 1)
    
    var infoAreaStage   : Stage? = nil
    var infoAreaItem    : StageItem? = nil

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
        rect.width = width
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
                getChildHeight(stage.getChildren())
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
                if infoAreaStage === item {
                    mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 1, fillColor: SIMD4<Float>(0, 0, 0, 0), borderColor: SIMD4<Float>(1, 1, 1, 1), fragment: fragment!)
                } else {
                    if textOnly == false {
                        mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: color, fragment: fragment!)
                    }
                }

                //fontRect = mmView.openSans.getTextRect(text: text, scale: fontScale, rectToUse: fontRect)
                
                let text : String = item.folderIsOpen == false ? "+" : "-"
                mmView.drawText.drawText(mmView.openSans, text: text, x: left + indent, y: top + 8, scale: fontScale, fragment: fragment)
                mmView.drawText.drawText(mmView.openSans, text: item.name, x: left + indent + 15, y: top + 8, scale: fontScale, fragment: fragment)
                
                if item.stageType == .PreStage {
                    let text = globalApp!.currentSceneMode == .TwoD ? "2D" : "3D"
                    mmView.drawText.drawText(mmView.openSans, text: text, x: rect.width - 30, y: top + 8, scale: fontScale, fragment: fragment)
                }
                
                top += unitSize
            }
            
            func drawItem(_ item: StageItem) {
                
                let color = SIMD4<Float>(0.5, 0.5, 0.5, 1)
                if scene?.getSelectedUUID() == item.uuid {
                    mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: selectionColor, fragment: fragment!)
                } else {
                    if textOnly == false {
                        mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: color, fragment: fragment!)
                    }
                }
                
                if infoAreaItem === item {
                    mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 1, fillColor: SIMD4<Float>(0, 0, 0, 0), borderColor: SIMD4<Float>(1, 1, 1, 1), fragment: fragment!)
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
                        drawChildren(stage.getChildren())
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
                
                if infoAreaStage === stage {
                    stage.folderIsOpen = !stage.folderIsOpen
                }
                infoAreaStage = stage
                infoAreaItem = nil
            }
            if let stageItem = item as? StageItem {
                stageItem.folderIsOpen = !stageItem.folderIsOpen
                //selectedItems = [stageItem.uuid]
                
                infoAreaStage = nil
                infoAreaItem = stageItem
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
                    getChildHeight(stage.getChildren())
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
