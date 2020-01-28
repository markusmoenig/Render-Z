//
//  SourceList.swift
//  Shape-Z
//
//  Created by Markus Moenig on 26/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import CloudKit

class ContextItem
{
    var component       : CodeComponent? = nil
    var rect            : MMRect = MMRect()
    
    var subComponent    : CodeComponent? = nil
    var subRect         : MMRect? = nil

    init(_ component: CodeComponent? = nil)
    {
        self.component = component
    }
}

class ContextInfoItem
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

struct ContextDrag      : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : SIMD2<Float>? = SIMD2<Float>()
    var name            : String = ""
    
    var codeFragment    : CodeFragment? = nil
}

class ContextWidget         : MMWidget
{
    enum ContextState {
        case Closed, Open
    }
    
    var scrollButton        : MMScrollButton!
    var textureWidget       : MMTextureWidget
    var scrollArea          : MMScrollArea

    var contextState        : ContextState = .Closed
    var animating           : Bool = false

    var item                : StageItem? = nil
    var currentList         : [ContextItem] = []
    var currentItem         : ContextItem? = nil
    var hoverItem           : ContextItem? = nil
    var hoverOnSub          : Bool = false
    var currentOnSub        : Bool = false

    var currentId           : String = ""
    var libraryId           : String = ""

    var fragment            : MMFragment?
    var width, height       : Float
    
    var spacing             : Float
    var itemSize            : Float
    
    var mouseIsDown         : Bool = false
    var mouseDownPos        : SIMD2<Float> = SIMD2<Float>()
    
    var font                : MMFont
    var fontScale           : Float = 0.40
    
    var selectedItem        : StageItem? = nil
    
    //var dragSource          : LibraryDrag?
    
    var currentWidth        : Float = 0
    var openWidth           : Float = 160
    
    // Info Area
    var infoItems           : [ContextInfoItem] = []
    var hoverInfoItem       : ContextInfoItem? = nil
    var pressedInfoItem     : ContextInfoItem? = nil
    var infoRect            : MMRect = MMRect()

    static var InfoHeight   : Float = 30

    override init(_ view: MMView)
    {
        font = view.openSans
        
        scrollButton = MMScrollButton(view, items: [], index: 0)
        scrollButton.changed = { (index)->() in
            view.update()
        }
        
        width = 0
        height = 0
        
        fragment = MMFragment(view)
        fragment!.allocateTexture(width: 1, height: 1)
        
        spacing = 22
        //unitSize = 35
        itemSize = 70

        textureWidget = MMTextureWidget(view, texture: fragment!.texture)
        scrollArea = MMScrollArea(view, orientation: .Vertical)

        super.init(view)
        zoom = mmView.scaleFactor
        textureWidget.zoom = zoom
    }
    
    func activate()
    {
        mmView.registerWidgets(widgets: scrollButton, self)
    }
    
    func deactivate()
    {
        mmView.deregisterWidgets(widgets: scrollButton, self)
    }
    
    /// Build the texture widget
    func build()
    {
        width = openWidth
        rect.width = openWidth
        height = max(Float(currentList.count) * itemSize + (Float(currentList.count) - 1) * spacing, 1)
        
        // ---
        
        if self.fragment!.width != self.width * zoom || self.fragment!.height != self.height * zoom {
            self.fragment!.allocateTexture(width: self.width * zoom, height: self.height * zoom)
        }
        self.textureWidget.setTexture(self.fragment!.texture)
        self.update()
    }
    
    override func update()
    {
        if fragment!.encoderStart() {
                        
            var top         : Float = 0
            let fontScale   : Float = 0.4
            //let lineHeight  : Float = font.getLineHeight(fontScale)
            
            //let color = SIMD4<Float>(1, 1, 1, 0.4)
            let borderColor = SIMD4<Float>(0.5, 0.5, 0.5, 1)

            let tempRect = MMRect()
                                    
            if libraryId.starts(with: "SDF") {
                for (index, item) in currentList.enumerated() {
                                        
                    if let comp = item.component {
                        
                        item.rect.set(0, top, width, itemSize)

                        if item === currentItem && currentOnSub == false {
                            mmView.drawBox.draw( x: 0, y: top, width: width, height: itemSize, round: 0, borderSize: 0, fillColor: SIMD4<Float>(0.4,0.4,0.4,1), borderColor: borderColor, fragment: fragment!)
                        }
                        
                        //mmView.drawBox.draw( x: localLeft, y: top + itemSize - lineHeight, width: itemSize, height: lineHeight, round: 4, borderSize: 0, fillColor: color, fragment: fragment!)
                        
                        //font.getTextRect(text: comp.libraryName, scale: fontScale, rectToUse: tempRect)
                        //mmView.drawText.drawText(mmView.openSans, text: comp.libraryName, x: (width - tempRect.width)/2, y: top + itemSize - lineHeight - 2, scale: fontScale, fragment: fragment)
                        
                        if let thumb = globalApp!.thumbnail.request(comp.libraryName + " :: " + libraryId, comp) {
                            mmView.drawTexture.draw(thumb, x: (width - 200 / 3) / 2, y: top, zoom: 3, fragment: fragment)
                        }
                        
                        if let subComp = comp.subComponent, index > 0 {
                            // Boolean Items
                            
                            item.subRect = MMRect(0, top - spacing, width, spacing)
                            
                            mmView.drawBox.draw( x: 0, y: top - spacing, width: width, height: spacing, round: 0, borderSize: 0, fillColor: item === currentItem && currentOnSub == true ? SIMD4<Float>(0.4,0.4,0.4,1) : SIMD4<Float>(1,1,1,0.5), borderColor: borderColor, fragment: fragment!)
                            
                            let name = subComp.libraryName
                            font.getTextRect(text: name, scale: fontScale, rectToUse: tempRect)
                            mmView.drawText.drawText(mmView.openSans, text: name, x: (width - tempRect.width ) / 2, y: top - spacing + 1, scale: fontScale, fragment: fragment)
                        }
                    } else {
                        if index > 0 {
                            top -= spacing / 2
                        }
                        item.rect.set((width - itemSize) / 2, top, itemSize, itemSize)
                        mmView.drawBox.draw( x: item.rect.x, y: item.rect.y, width: itemSize, height: itemSize, round: 4, borderSize: 1, fillColor: SIMD4<Float>(0,0,0,0), borderColor: borderColor, fragment: fragment!)
                    }

                    top += itemSize + spacing
                }
            }
            
            fragment!.encodeEnd()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
        scrollButton.rect.copy(rect)
        scrollButton.rect.x += 5
        scrollButton.rect.y += 5
        scrollButton.rect.width = openWidth - 10
        scrollButton.rect.height = 35
        scrollButton.draw(xOffset: xOffset, yOffset: yOffset)
        
        if currentList.count > 0 {
            scrollArea.rect.copy(rect)
            scrollArea.rect.y += 50
            scrollArea.rect.height -= 60 - ContextWidget.InfoHeight
            scrollArea.build(widget:textureWidget, area: scrollArea.rect, xOffset: xOffset)
            
            infoRect.x = rect.x
            infoRect.y = rect.y + rect.height - ContextWidget.InfoHeight
            infoRect.width = rect.width
            infoRect.height = ContextWidget.InfoHeight
            
            let infoItemWidth : Float = infoRect.width / Float(infoItems.count)
            
            var xOff : Float = infoRect.x
            for item in infoItems {
                item.rect.x = xOff
                item.rect.y = infoRect.y
                item.rect.width = infoItemWidth
                item.rect.height = ContextWidget.InfoHeight
                if item === pressedInfoItem {
                    mmView.drawBox.draw( x: item.rect.x, y: item.rect.y, width: item.rect.width, height: item.rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.4, 0.4, 0.4, 1))
                } else
                if item === hoverInfoItem {
                    mmView.drawBox.draw( x: item.rect.x, y: item.rect.y, width: item.rect.width, height: item.rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.2, 0.2, 0.2, 1))
                }
                item.label.drawCentered(x: item.rect.x, y: item.rect.y, width: item.rect.width, height: item.rect.height)
                xOff += infoItemWidth
            }
        }
    }
    
    func createInfoItems()
    {
        infoItems = []

        if let current = currentItem {
            if libraryId.starts(with: "SDF") {
                if currentOnSub == false {
                    // SDF
                    if let _ = current.component {
                        infoItems = [
                            ContextInfoItem(mmView, "Change", { () in
                                globalApp!.libraryDialog.setType(self.libraryId, current)
                                self.mmView.showDialog(globalApp!.libraryDialog)
                            }),
                            ContextInfoItem(mmView, "Delete", { () in
                            }),
                        ]
                    }
                } else {
                    // Boolean
                    if let _ = current.component {
                        infoItems = [
                            ContextInfoItem(mmView, "Change", { () in
                                globalApp!.libraryDialog.setType("Boolean", current)
                                self.mmView.showDialog(globalApp!.libraryDialog)
                            })
                        ]
                    }
                }
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        #endif
        
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        
        if let infoItem = hoverInfoItem {
            pressedInfoItem = infoItem
            #if os(OSX)
            infoItem.cb!()
            #endif
        }
        
        currentItem = nil
        currentOnSub = false
        infoItems = []
        
        if let current = hoverItem {
            currentItem = current
            currentOnSub = hoverOnSub
            
            if libraryId.starts(with: "Render") {
                globalApp!.libraryDialog.setType(libraryId, current)
                mmView.showDialog(globalApp!.libraryDialog)
            } else
            if libraryId.starts(with: "SDF") {
                if currentOnSub == false {
                    // SDF
                    if current.component == nil {
                        globalApp!.libraryDialog.setType(libraryId, current)
                        mmView.showDialog(globalApp!.libraryDialog)
                    } else {
                        globalApp!.currentEditor.setComponent(current.component!)
                    }
                } else {
                    // Boolean
                    if let sub = current.subComponent {
                        globalApp!.currentEditor.setComponent(sub)
                    }
                }
            } else
            {
                if current.component == nil {
                    globalApp!.libraryDialog.setType(libraryId, current)
                    mmView.showDialog(globalApp!.libraryDialog)
                } else {
                    globalApp!.currentEditor.setComponent(current.component!)
                }
            }
            update()
        }
        
        createInfoItems()
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        #if os(iOS)
        if let infoItem = pressedInfoItem {
            infoItem.cb!()
        }
        hoverInfoItem = nil
        #endif
        mouseIsDown = false
        pressedInfoItem = nil
    }
    
    override func mouseLeave(_ event: MMMouseEvent) {
        if hoverInfoItem != nil {
            hoverInfoItem = nil
            mmView.update()
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        hoverItem = nil
        hoverOnSub = false
        for item in currentList {
            if item.rect.contains(event.x - rect.x, event.y - 50 - rect.y - scrollArea.offsetY) {
                hoverItem = item
                break
            }
            if let subRect = item.subRect {
                if subRect.contains(event.x - rect.x, event.y - 50 - rect.y - scrollArea.offsetY) {
                    hoverItem = item
                    hoverOnSub = true
                    break
                }
            }
        }
        
        hoverInfoItem = nil
        if hoverItem == nil && infoRect.contains(event.x, event.y) {
            let oldHoverItem = hoverInfoItem
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
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        scrollArea.mouseScrolled(event)
    }
    
    func setSelected(_ selItem: StageItem? = nil)
    {
        var nextState : ContextState = .Closed
        var listToUse : [CodeComponent] = []
        
        var addEmpty : Bool = false
                
        currentItem = nil
        hoverItem = nil
        currentId = ""
        currentList = []
        
        if let item = selItem {
            if item.stageItemType == .PreStage {
                nextState = .Closed
                if let comp = item.components[item.defaultName] {
                    listToUse = [comp]
                    if comp.componentType == .Camera2D {
                        libraryId = "Camera2D"
                    } else
                    if comp.componentType == .Camera3D {
                        libraryId = "Camera3D"
                    }
                }
            } else
            if item.stageItemType == .ShapeStage {
                nextState = .Open
                scrollButton.setItems(["Shapes", "Material", "Domain"])
                
                if globalApp!.currentSceneMode == .TwoD {
                    currentId = "shapes2D"
                    listToUse = item.componentLists[currentId]!
                    libraryId = "SDF2D"
                } else {
                    currentId = "shapes3D"
                    libraryId = "SDF3D"
                    listToUse = item.componentLists[currentId]!
                }
                addEmpty = true
            } else
            if item.stageItemType == .RenderStage {
                nextState = .Closed
                listToUse = [item.components[item.defaultName]!]
                if globalApp!.currentSceneMode == .TwoD {
                    libraryId = "Render2D"
                } else {
                    libraryId = "Render3D"
                }
            }
        }
            
        if nextState != contextState {
            switchState()
        }
        
        for comp in listToUse {
            currentList.append(ContextItem(comp))
        }
        
        if listToUse.count > 0 {
            currentItem = currentList[0]
            if nextState == .Open {
                globalApp!.currentEditor.setComponent(currentItem!.component!)
            }
        }
                
        if addEmpty {
            currentList.append(ContextItem())
        }
        build()

        selectedItem = selItem
        createInfoItems()
    }
    
    /// Replace the json of the component with the given uuid, called from the LibraryDialog
    func replaceJSONForItem(_ contextItem: ContextItem,_ json: String)
    {
        if let comp = decodeComponentFromJSON(json) {
            
            let undo = globalApp!.currentEditor.undoStageItemStart("Add Component")
            
            comp.selected = nil
            globalApp!.currentEditor.setComponent(comp)
            globalApp!.currentEditor.updateOnNextDraw(compile: true)
            
            if comp.componentType == .Camera2D || comp.componentType == .Camera3D {
                comp.uuid = contextItem.component!.uuid
                globalApp!.project.selected!.updateComponent(comp)
                contextItem.component = comp
            } else
            if comp.componentType == .SDF2D || comp.componentType == .SDF3D {
                // If SDF, add the default boolean operator as subcomponent
                
                // Insert default values for the component, position etc
                setDefaultComponentValues(comp)
                
                if contextItem.component != nil {
                    // Replace the old component
                    comp.uuid = contextItem.component!.uuid
                    if let sub = contextItem.subComponent {
                        comp.subComponent = sub
                    }
                    globalApp!.project.selected!.updateComponent(comp)
                } else {
                    // Add the component
                    comp.uuid = UUID()
                    currentList.append(ContextItem())
                    if let selected = selectedItem {
                        selected.componentLists[currentId]?.append(comp)
                    }
                }
                
                contextItem.component = comp
                currentOnSub = false
                                
                if contextItem.subComponent == nil {
                    if let bComp = decodeComponentFromJSON(defaultBoolean) {
                        //CodeComponent(.Boolean)
                        //bComp.createDefaultFunction(.Boolean)
                        bComp.uuid = UUID()
                        bComp.selected = nil
                        comp.subComponent = bComp
                        contextItem.subComponent = bComp
                    }
                }
            } else
            if comp.componentType == .Boolean {
                // If Boolean, replace the subComponent
                
                comp.uuid = UUID()
                contextItem.subComponent = comp
                contextItem.component!.subComponent = comp
                
                currentItem = contextItem
                currentOnSub = true
            }

            currentItem = contextItem

            build()
            globalApp!.currentEditor.undoStageItemEnd(undo)
        }
        createInfoItems()
    }

    /// Switches between open and close states
    func switchState() {
        if animating { return }
        let rightRegion = globalApp!.rightRegion!
        let openWidth = globalApp!.context.openWidth
        
        if contextState == .Open {
            globalApp!.mmView.startAnimate( startValue: rightRegion.rect.width, endValue: 0, duration: 500, cb: { (value,finished) in
                globalApp!.context.currentWidth = value
                if finished {
                    self.animating = false
                    self.contextState = .Closed
                    
                    self.mmView.deregisterWidget(self)
                    self.deactivate()
                }
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
            } )
            animating = true
        } else if rightRegion.rect.height != openWidth {
            
            globalApp!.mmView.startAnimate( startValue: rightRegion.rect.width, endValue: openWidth, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.contextState = .Open
                    self.activate()
                    self.mmView.registerWidget(self)
                }
                globalApp!.context.currentWidth = value
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
            } )
            animating = true
        }
    }
    /*
    /// Create a drag item
    func createDragSource(_ x: Float,_ y: Float) -> LibraryDrag?
    {
        if let listItem = treeWidget.getCurrentItem(), listItem.children == nil {
            if let item = listItem as? SourceListItem, item.codeFragment != nil {
                var drag = LibraryDrag()
                
                drag.id = "LibraryDragItem"
                drag.name = item.name
                drag.pWidgetOffset!.x = x
                drag.pWidgetOffset!.y = y.truncatingRemainder(dividingBy: treeWidget.unitSize)
                
                drag.codeFragment = item.codeFragment
                                                
                let texture = treeWidget.createShapeThumbnail(item: listItem)
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
    }*/
}
