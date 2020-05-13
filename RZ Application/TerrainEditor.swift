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
        
        if event.y < rect.bottom() - 160 {
            // inside the upper area
            
            if let loc = getHitLocationAt(event) {
                print(loc.x, loc.y)
            }
            return
        }
        
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
    
    /// Returns the XZ location of the mouse location
    func getHitLocationAt(_ event: MMMouseEvent) -> SIMD2<Float>?
    {
        let x : Float = event.x - rect.x
        let y : Float = event.y - rect.y
         
        // Selection
        if let texture = globalApp!.currentPipeline!.getTextureOfId("id") {
             
            if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .rgba32Float) {
             
                globalApp!.currentPipeline!.codeBuilder.renderCopy(convertTo, texture, syncronize: true)
                 
                let region = MTLRegionMake2D(min(Int(x), convertTo.width-1), min(Int(y), convertTo.height-1), 1, 1)

                var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(repeating: 0), count: 1)
                texArray.withUnsafeMutableBytes { texArrayPtr in
                    if let ptr = texArrayPtr.baseAddress {
                        convertTo.getBytes(ptr, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * convertTo.width), from: region, mipmapLevel: 0)
                    }
                }
                let value = texArray[0]
                
                if value.w >= 0 {
                    let camera = getCameraValues(event)
                    let hit = camera.0 + normalize(camera.1) * value.y
                    
                    print(camera.0, camera.1, value.y, value.w)
                    
                    return SIMD2<Float>(hit.x, hit.z)
                }
            }
        }
        return nil
    }
    
    /// Returns the XZ location of the mouse location
    func getTextureValueAt(_ event: MMMouseEvent, texture: MTLTexture) -> SIMD4<Float>
    {
        let x : Float = event.x - rect.x
        let y : Float = event.y - rect.y

        if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .rgba32Float) {
         
            globalApp!.currentPipeline!.codeBuilder.renderCopy(convertTo, texture, syncronize: true)
            let region = MTLRegionMake2D(min(Int(x), convertTo.width-1), min(Int(y), convertTo.height-1), 1, 1)

            var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(repeating: 0), count: 1)
            texArray.withUnsafeMutableBytes { texArrayPtr in
                if let ptr = texArrayPtr.baseAddress {
                    convertTo.getBytes(ptr, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * convertTo.width), from: region, mipmapLevel: 0)
                }
            }
            
            return texArray[0]
        }
        
        return SIMD4<Float>(0,0,0,0)
    }
    
    /// Returns the origin and lookAt values of the camera
    func getCameraValues(_ event: MMMouseEvent) -> (SIMD3<Float>, SIMD3<Float>)
    {
        if let pipeline = globalApp!.currentPipeline as? Pipeline3D {
    
            let originTexture = pipeline.checkTextureSize(rect.width, rect.height, nil, .rgba16Float)
            let directionTexture = pipeline.checkTextureSize(rect.width, rect.height, nil, .rgba16Float)
            
            if let inst = pipeline.instanceMap["camera3D"] {
                pipeline.codeBuilder.render(inst, originTexture!, outTextures: [directionTexture!])
                
                let origin = getTextureValueAt(event, texture: originTexture!)
                let lookAt = getTextureValueAt(event, texture: directionTexture!)
                
                return (SIMD3<Float>(origin.x, origin.y, origin.z), SIMD3<Float>(lookAt.x, lookAt.y, lookAt.z))
            }
        }
    
        
        /*
        if let camera = cameraComponent {
            let origin = getTransformedComponentProperty(camera, "origin")
            let lookAt = getTransformedComponentProperty(camera, "lookAt")
            
            return (SIMD3<Float>(origin.x, origin.y, origin.z), SIMD3<Float>(lookAt.x, lookAt.y, lookAt.z))
        }*/
        return (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 0))
    }
}
