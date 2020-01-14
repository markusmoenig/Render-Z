//
//  SourceList.swift
//  Shape-Z
//
//  Created by Markus Moenig on 26/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import CloudKit

class LibraryItem    : MMTreeWidgetItem
{
    var name         : String = ""
    var uuid         : UUID = UUID()
    var color        : SIMD4<Float>? = SIMD4<Float>(0.5, 0.5, 0.5, 1)
    var children     : [MMTreeWidgetItem]? = nil
    var folderOpen   : Bool = false
        
    let json         : String
        
    init(_ name: String,_ json: String)
    {
        self.name = name
        self.json = json
    }
}

struct LibraryDrag      : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : SIMD2<Float>? = SIMD2<Float>()
    var name            : String = ""
    
    var codeFragment    : CodeFragment? = nil
}

class LibraryWidget         : MMWidget
{
    var treeWidget          : MMTreeWidget
    var scrollButton        : MMScrollButton!
    
    var privateItems        : [LibraryItem] = []
    var publicItems         : [LibraryItem] = []

    var currentItems        : [LibraryItem] = []
    
    var mouseIsDown         : Bool = false
    var mouseDownPos        : SIMD2<Float> = SIMD2<Float>()
    
    var font                : MMFont
    var fontScale           : Float = 0.40
    
    var hoverItem           : FragItem? = nil
    var selectedItem        : FragItem? = nil
    
    var dragSource          : LibraryDrag?
    
    var currentWidth        : Float = 0
    var openWidth           : Float = 200

    override init(_ view: MMView)
    {
        font = view.openSans

        treeWidget = MMTreeWidget(view)
        treeWidget.skin.selectionColor = SIMD4<Float>(0.5,0.5,0.5,1)
        treeWidget.itemRound = 0
        treeWidget.textOnly = true
        treeWidget.unitSize -= 5
        treeWidget.itemSize -= 5
        
        scrollButton = MMScrollButton(view, items: ["Public", "Private"], index: 0)
        scrollButton.setItems(["Public", "Private"], fixedWidth: 190)
        scrollButton.changed = { (index)->() in
            view.update()
        }

        treeWidget.selectionColor = SIMD4<Float>(0.2, 0.2, 0.2, 1)
        
        super.init(view)

        let query = CKQuery(recordType: "components", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.renderz").publicCloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            
            let primitives = LibraryItem("Primitives", "")
            primitives.children = []
            self.publicItems.append(primitives)

            records?.forEach({ (record) in
                
                
                //currentItems.append(item)
                
                // System Field from property
                //let recordName_fromProperty = record.recordID.recordName
                //print("System Field, recordName: \(recordName_fromProperty)")
                //let deeplink = record.value(forKey: "deeplink")
                //print("Custom Field, deeplink: \(deeplink ?? "")")
                
                let name = record.recordID.recordName
                
                primitives.children!.append(LibraryItem(name,""))
                
                self.currentItems = self.publicItems
                self.treeWidget.build(items: self.currentItems, fixedWidth: self.openWidth)
            })
        }
    }
    
    func activate()
    {
        mmView.registerWidgets(widgets: scrollButton, self)
    }
    
    func deactivate()
    {
        mmView.deregisterWidgets(widgets: scrollButton, self)
    }
    
    // The 2D or 3D mode changed
    func modeChanged()
    {
        
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
        
        treeWidget.rect.copy(rect)
        treeWidget.rect.y += 45
        treeWidget.rect.height -= 45
        treeWidget.draw()
        
        rect.copy(treeWidget.rect)
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        if treeWidget.rect.contains(event.x, event.y) {
            let changed = treeWidget.selectAt(event.x - rect.x, (event.y - rect.y), items: currentItems)
            if changed {
                treeWidget.build(items: currentItems, fixedWidth: openWidth)
                mmView.update()
            }
            return
        }
        mouseMoved(event)
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
        if treeWidget.rect.contains(event.x, event.y) {
            treeWidget.mouseUp(event)
            return
        }
    }
    
    //override func mouseLeave(_ event: MMMouseEvent) {
    //    hoverItem = nil
    //}
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if treeWidget.rect.contains(event.x, event.y) {
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
    }
    
    func selectItem(_ item: FragItem)
    {
        selectedItem = item
        treeWidget.selectedItems = []
                    
        for item in item.items{
            item.color = item.codeFragment!.fragmentType == .Primitive ? mmView.skin.Code.name : mmView.skin.Code.reserved
        }
        
        treeWidget.build(items: item.items, fixedWidth: 200)
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        treeWidget.mouseScrolled(event)
    }
    
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
    }
}
