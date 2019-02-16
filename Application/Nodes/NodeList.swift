//
//  NodeList.swift
//  Shape-Z
//
//  Created by Markus Moenig on 16/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class NodeListItem : MMListWidgetItem
{
    var         name : String = ""
    var         uuid : UUID = UUID()
    
    init(_ name: String)
    {
        self.name = name
    }
}

class NodeList : MMWidget
{
    var app                 : App
    
    var listWidget          : MMListWidget
    var items               : [NodeListItem] = []
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        
        listWidget = MMListWidget(view)
        
        var item = NodeListItem("Object")
        
        items.append(item)
        
        listWidget.build(items: items, fixedWidth: 200)

        super.init(view)
    }
    
    func getCurrentItem() -> MMListWidgetItem?
    {
        for item in items {
            if listWidget.selectedItems.contains( item.uuid ) {
                return item
            }
        }
        return nil
    }
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: float4( 0, 0, 0, 1 ) )

        listWidget.rect.x = rect.x
        listWidget.rect.y = rect.y
        listWidget.rect.width = rect.width
        listWidget.rect.height = rect.height
        
        listWidget.drawWithXOffset(xOffset: app.leftRegion!.rect.width - 200)
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        let changed = listWidget.selectAt(event.x - rect.x, (event.y - rect.y) - 30, items: items)
        if changed {
            listWidget.build(items: items, fixedWidth: 200)
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        listWidget.mouseScrolled(event)
    }
}
