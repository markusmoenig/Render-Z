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
    
    init(_ component: CodeComponent? = nil)
    {
        self.component = component
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
    var openWidth           : Float = 200

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
        
        spacing = 10
        //unitSize = 35
        itemSize = 80

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
                        
            let left        : Float = 50
            var top         : Float = 0
            let fontScale   : Float = 0.4
            
            let color = SIMD4<Float>(1, 1, 1, 0.4)
            let borderColor = SIMD4<Float>(0.5, 0.5, 0.5, 1)

            let tempRect = MMRect()
            
            let textHeight : Float = 18
            
            for item in currentList {
                
                item.rect.set(left, top, itemSize, itemSize)
                
                if let comp = item.component {
                    let fColor = item === currentItem ? SIMD4<Float>(0.4,0.4,0.4,1) : SIMD4<Float>(0,0,0,0)
                    
                    mmView.drawBox.draw( x: left, y: top, width: itemSize, height: itemSize, round: 4, borderSize: 1, fillColor: fColor, borderColor: borderColor, fragment: fragment!)
                    
                    mmView.drawBox.draw( x: left, y: top + itemSize - textHeight, width: itemSize, height: textHeight, round: 4, borderSize: 0, fillColor: color, fragment: fragment!)
                    
                    font.getTextRect(text: comp.libraryName, scale: fontScale, rectToUse: tempRect)
                    mmView.drawText.drawText(mmView.openSans, text: comp.libraryName, x: left + (itemSize - tempRect.width)/2, y: top + itemSize - textHeight, scale: fontScale, fragment: fragment)
                    
                    if let thumb = globalApp!.thumbnail.request(comp.libraryName + " - " + libraryId, comp) {
                        mmView.drawTexture.draw(thumb, x: left + (itemSize - 200 / 3.5)/2, y: top, zoom: 3.5, fragment: fragment)
                    }
                } else {
                    mmView.drawBox.draw( x: left, y: top, width: itemSize, height: itemSize, round: 4, borderSize: 1, fillColor: SIMD4<Float>(0,0,0,0), borderColor: borderColor, fragment: fragment!)
                }

                top += itemSize + spacing
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
            scrollArea.rect.height -= 60
            scrollArea.build(widget:textureWidget, area: scrollArea.rect, xOffset: xOffset)
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y

        #if os(iOS)
        mouseMoved(event)
        #endif
        
        currentItem = nil
        if let current = hoverItem {
            currentItem = current
            
            if libraryId.starts(with: "Render") {
                globalApp!.libraryDialog.setType(libraryId, current)
                mmView.showDialog(globalApp!.libraryDialog)
            } else {
                if current.component == nil {
                    globalApp!.libraryDialog.setType(libraryId, current)
                    mmView.showDialog(globalApp!.libraryDialog)
                } else {
                    globalApp!.currentEditor.setComponent(current.component!)
                }
            }
            update()
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false

    }
    
    //override func mouseLeave(_ event: MMMouseEvent) {
    //    hoverItem = nil
    //}
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        hoverItem = nil
        for item in currentList {
            if item.rect.contains(event.x - rect.x, event.y - 50 - rect.y - scrollArea.offsetY) {
                hoverItem = item
                break
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
            if item.stageItemType == .ShapeStage {
                nextState = .Open
                scrollButton.setItems(["Shapes", "Materials", "Domain"], fixedWidth: 190)
                
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
    }
    
    /// Replace the json of the component with the given uuid, called from the LibraryDialog
    func replaceJSONForItem(_ contextItem: ContextItem,_ json: String)
    {
        if let comp = decodeComponentFromJSON(json) {
            
            // Insert default values for the component, position etc
            setDefaultComponentValues(comp)
            
            comp.selected = nil
            globalApp!.currentEditor.setComponent(comp)
            globalApp!.currentEditor.updateOnNextDraw(compile: true)
            
            if contextItem.component != nil {
                // Replace the old component
                comp.uuid = contextItem.component!.uuid
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
            build()
        }
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
