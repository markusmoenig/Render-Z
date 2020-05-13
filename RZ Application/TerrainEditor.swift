//
//  TerrainEditor.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/5/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class LayerListItem : MMTreeWidgetItem
{
    enum LayerType : Int {
        case PaintLayer, GlobalNoiseLayer, RegionLayer
    }
    
    var name         : String
    var uuid         : UUID
    var color        : SIMD4<Float>? = SIMD4<Float>(0.5, 0.5, 0.5, 1)
    var children     : [MMTreeWidgetItem]? = nil
    var folderOpen   : Bool = false
    
    var layerType    : LayerType
            
    init(_ name: String, _ uuid: UUID,_ type: LayerType)
    {
        self.name = name
        self.uuid = uuid
        layerType = type
    }
}

class TerrainEditor         : MMWidget
{
    var terrain             : Terrain!
    
    var mouseIsDown         : Bool = false
    var mouseDownPos        : SIMD2<Float> = SIMD2<Float>()
    
    var layerListWidget     : MMTreeWidget
    var layerItems          : [LayerListItem] = []
    var currentLayerItem    : LayerListItem!
    
    override required init(_ view: MMView)
    {
        layerListWidget = MMTreeWidget(view)
        
        layerListWidget.skin.selectionColor = SIMD4<Float>(0.5,0.5,0.5,1)
        layerListWidget.itemRound = 0
        layerListWidget.textOnly = true
        layerListWidget.unitSize -= 5
        layerListWidget.itemSize -= 5
        
        layerListWidget.selectionColor = SIMD4<Float>(0.2, 0.2, 0.2, 1)
        
        super.init(view)
    }
    
    func activate()
    {
        mmView.registerPriorityWidgets(widgets: self)
    }
    
    func deactivate()
    {
        mmView.deregisterWidgets(widgets: self)
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        
        if layerListWidget.rect.contains(event.x, event.y) {
            let changed = layerListWidget.selectAt(event.x - layerListWidget.rect.x, (event.y - layerListWidget.rect.y), items: layerItems)
            if changed {
                
                layerListWidget.build(items: layerItems, fixedWidth: 150)
                if let item = layerListWidget.getCurrentItem() as? LayerListItem {
                    setLayerItem(item)
                }
            }
            return
        }
        mouseMoved(event)
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
        if layerListWidget.rect.contains(event.x, event.y) {
            layerListWidget.mouseUp(event)
            return
        }
    }
    
    //override func mouseLeave(_ event: MMMouseEvent) {
    //    hoverItem = nil
    //}
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
    }
    
    func setLayerItem(_ item: LayerListItem)
    {
        currentLayerItem = item
    }
    
    func setTerrain(_ terrain: Terrain)
    {
        self.terrain = terrain
        
        // Build Layer List
        
        layerItems = []
        
        var item = LayerListItem("Test", UUID(), .GlobalNoiseLayer)
        layerItems.append(item)

        item = LayerListItem("Paint Layer", UUID(), .PaintLayer)
        layerItems.append(item)
        
        layerListWidget.selectedItems = [item.uuid]
        layerListWidget.build(items: layerItems, fixedWidth: 150)
        setLayerItem(item)
    }

    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        drawPreview(mmView: mmView, rect)
        
        mmView.drawBox.draw( x: rect.x, y: rect.bottom() - 160 + 0.5, width: rect.width + 0.5, height: 160, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 0.8) )
        
        layerListWidget.rect.x = rect.x + 5
        layerListWidget.rect.y = rect.bottom() - 160 + 5
        layerListWidget.rect.width = 160
        layerListWidget.rect.height = 150
        layerListWidget.draw()

    }
}
