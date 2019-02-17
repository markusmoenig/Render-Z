//
//  MMListWidget.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

protocol MMListWidgetItem
{
    var name        : String {get set}
    var uuid        : UUID {get set}
}

class MMListWidget : MMWidget
{
    var fragment        : MMFragment?
    var state           : MTLRenderPipelineState?
    
    var width, height   : Float
    var spacing         : Float
    var unitSize        : Float
    
    var hoverData       : [Float]
    var hoverBuffer     : MTLBuffer?
    var hoverIndex      : Int = -1
    var hoverUp         : Bool = false
    
    var textureWidget   : MMTextureWidget
    var scrollArea      : MMScrollArea
    
    var selectedItems   : [UUID] = []
    var selectionChanged: ((_ item: [MMListWidgetItem])->())? = nil
    
    override init(_ view: MMView)
    {
        scrollArea = MMScrollArea(view, orientation: .Vertical)
        
        width = 0
        height = 0
        
        fragment = MMFragment(view)
        fragment!.allocateTexture(width: 10, height: 10)
        
        spacing = 0
        unitSize = 35
        
        textureWidget = MMTextureWidget( view, texture: fragment!.texture )

        hoverData = [-1,0]
        hoverBuffer = fragment!.device.makeBuffer(bytes: hoverData, length: hoverData.count * MemoryLayout<Float>.stride, options: [])!
        
        super.init(view)
        zoom = 2
//        unitSize *= zoom
        textureWidget.zoom = zoom
    }
    
    /// Build the source
    func build(items: [MMListWidgetItem], fixedWidth: Float? = nil)
    {
        let count : Float = Float(items.count)
        width = fixedWidth != nil ? fixedWidth! * zoom : rect.width * zoom
        height = (count * unitSize + (count > 0 ? (count-1) * spacing : Float(0))) * zoom
        if width == 0 {
            width = 1
        }
        if height == 0 {
            height = 1
        }
        
        var source =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;

        float merge(float d1, float d2)
        {
            return min(d1, d2);
        }

        float fillMask(float dist)
        {
            return clamp(-dist, 0.0, 1.0);
        }

        float borderMask(float dist, float width)
        {
            //dist += 1.0;
            return clamp(dist + width, 0.0, 1.0) - clamp(dist, 0.0, 1.0);
        }

        float sdLineListWidget( float2 uv, float2 pa, float2 pb, float r) {
            float2 o = uv-pa;
            float2 l = pb-pa;
            float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
            return -(r-distance(o,l*h));
        }

        typedef struct
        {
            float      hoverOffset;
            float      fill;
        } MMLISTWIDGET_HOVER_DATA;

        """
        
        source +=
        """
        
        fragment float4 listWidgetBuilder(RasterizerData in [[stage_in]],
                                          constant MMLISTWIDGET_HOVER_DATA  *hoverData   [[ buffer(2) ]])
        {
            float2 size = float2( \(width*zoom), \(height) );

            float2 uvOrigin = float2( in.textureCoordinate.x * size.x - size.x / 2., size.y - in.textureCoordinate.y * size.y - size.y / 2. );
            float2 uv;
        
            float dist = 10000;
            float2 d;
        
            float borderSize = 2.0;
            float round = 4;
        
            float4 fillColor = float4(0.275, 0.275, 0.275, 1.000);
            float4 borderColor = float4( 0.5, 0.5, 0.5, 1 );
            float4 primitiveColor = float4(1, 1, 1, 1.000);
        
            float4 modeInactiveColor = float4(0.5, 0.5, 0.5, 1.000);
            float4 modeActiveColor = float4(1);
        
            float4 scrollInactiveColor = float4(0.5, 0.5, 0.5, 0.2);
            float4 scrollHoverColor = float4(1);
            float4 scrollActiveColor = float4(0.5, 0.5, 0.5, 1);
        
            float4 finalCol = float4( 0 ), col = float4( 0 );
        
        """
        
        let left : Float = (width/2) * zoom
        var top : Float = (unitSize / 2) * zoom
        
        for (_, item) in items.enumerated() {

            source += "uv = uvOrigin; uv.x += size.x / 2.0 - \(left) + borderSize/2; uv.y += size.y / 2.0 - \(top) + borderSize/2;\n"
            source += "uv /= \(zoom);\n"
            
            source += "d = abs( uv ) - float2( \((width)/2) - borderSize - 2, \(unitSize/2) - borderSize ) + float2( round );\n"
            source += "dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - round;\n"
            
            if selectedItems.contains( item.uuid ) {
                source += "col = float4( \(mmView.skin.Widget.selectionColor.x), \(mmView.skin.Widget.selectionColor.y), \(mmView.skin.Widget.selectionColor.z), fillMask( dist ) * \(mmView.skin.Widget.selectionColor.w) );\n"
            } else {
                source += "col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );\n"
            }
            source += "col = mix( col, borderColor, borderMask( dist, borderSize) );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
            /*
            // --- Up / Down Arrows
            
            // --- Up
            source += "uv -= float2( 105., 0. );\n"
            source += "dist = sdLineListWidget( uv, float2( 0, 6 ), float2( 10, -4), 2);\n"
            source += "dist = min( dist, sdLineListWidget( uv, float2( 10, -4), float2( 20, 6), 2) );\n"
            if index == 0 || items.count < 2 {
                source += "col = float4( scrollInactiveColor.xyz, fillMask( dist ) * scrollInactiveColor.w );\n"
            } else {
                source += "if (\(index*2) == hoverData->hoverOffset ) col = float4( scrollHoverColor.xyz, fillMask( dist ) * scrollHoverColor.w ); else col = float4( scrollActiveColor.xyz, fillMask( dist ) * scrollActiveColor.w );\n"
            }
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Down
            source += "uv -= float2( 35., 0. );\n"
            source += "dist = sdLineListWidget( uv, float2( 0, -4 ), float2( 10, 6), 2);\n"
            source += "dist = min( dist, sdLineListWidget( uv, float2( 10, 6 ), float2( 20, -4), 2) );\n"
            if index == items.count - 1 || items.count < 2 {
                source += "col = float4( scrollInactiveColor.xyz, fillMask( dist ) * scrollInactiveColor.w );\n"
            } else {
                source += "if (\(index*2+1) == hoverData->hoverOffset ) col = float4( scrollHoverColor.xyz, fillMask( dist ) * scrollHoverColor.w ); else col = float4( scrollActiveColor.xyz, fillMask( dist ) * scrollActiveColor.w );\n"            }
            source += "finalCol = mix( finalCol, col, col.a );\n"
            */
            // ---
            
            //            source += "col = float4( primitiveColor.x, primitiveColor.y, primitiveColor.z, fillMask( dist ) * primitiveColor.w );\n"
            //            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            top += (unitSize + spacing) * zoom
        }
        
        source +=
        """

            return finalCol;
        }
        """
        
        let library = fragment!.createLibraryFromSource(source: source)
        state = fragment!.createState(library: library, name: "listWidgetBuilder")
        
        if fragment!.width != width || fragment!.height != height {
            fragment!.allocateTexture(width: width, height: height)
            textureWidget.setTexture(fragment!.texture)
        }
        
//        update()
        
        if fragment!.encoderStart() {
            
            fragment!.encodeRun(state )//, inBuffer: hoverBuffer)
            
            let left : Float = 6 * zoom
            var top : Float = 4 * zoom
            let fontScale : Float = 0.22
            
            var fontRect = MMRect()
            
//            let item = items[0]
            
            for item in items {
            
                fontRect = mmView.openSans.getTextRect(text: item.name, scale: fontScale, rectToUse: fontRect)
                mmView.drawText.drawText(mmView.openSans, text: item.name, x: left, y: top, scale: fontScale * zoom, fragment: fragment)
                
                top += (unitSize / 2) * zoom
            }
            
            fragment!.encodeEnd()
        }
    }
    
    override func draw()
    {
        scrollArea.rect.copy(rect)
        scrollArea.build(widget:textureWidget, area: rect)
    }
    
    func drawWithXOffset(xOffset: Float)
    {
        scrollArea.rect.copy(rect)
        scrollArea.build(widget:textureWidget, area: rect, xOffset: xOffset)
    }
    
    func update()
    {
//        memcpy(hoverBuffer?.contents(), hoverData, hoverData.count * MemoryLayout<Float>.stride)
//        fragment!.run(state, inBuffer: hoverBuffer)
    }
    
    /// Selected the shape at the given relative mouse position
    @discardableResult func selectAt(_ x: Float,_ y: Float, items: [MMListWidgetItem], multiSelect: Bool = false) -> Bool
    {
        let item = itemAt(x, y, items: items)
        var changed : Bool = false
        
        if item != nil {
            if !multiSelect {
                
                selectedItems = [item!.uuid]
                
                if selectionChanged != nil {
                    selectionChanged!( [item!] )
                }
                
            } //else if !currentObject!.selectedShapes.contains( currentObject!.shapes[selectedIndex].uuid ) {
                //currentObject!.selectedShapes.append( currentObject!.shapes[selectedIndex].uuid )
            //}
            changed = true
        }
        
        return changed
    }
    
    /// Returns the item at the given location
    @discardableResult func itemAt(_ x: Float,_ y: Float, items: [MMListWidgetItem]) -> MMListWidgetItem?
    {
        let index : Float = (y - scrollArea.offsetY) / (unitSize+spacing)
        let selectedIndex = Int(index)
        
        if selectedIndex >= 0 && selectedIndex < items.count {
            return items[selectedIndex]
        }
        
        return nil
    }
    
    /*
    /// Sets the hover index for the given mouse position
    @discardableResult func hoverAt(_ x: Float,_ y: Float) -> Bool
    {
        let index : Float = y / (unitSize+spacing)
        hoverIndex = Int(index)
        let oldIndex = hoverData[0]
        hoverData[0] = -1
        
        if currentObject != nil {
            if hoverIndex >= 0 && hoverIndex < currentObject!.shapes.count {
                
                //            print( x )
                
                if x >= 227 && x <= 255 {
                    hoverData[0] = Float(hoverIndex*2)
                    hoverUp = true
                } else
                    if x >= 262 && x <= 289 {
                        hoverData[0] = Float(hoverIndex*2+1)
                        hoverUp = false
                }
            }
        }
        
        return hoverData[0] != oldIndex
    }*/
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        scrollArea.mouseScrolled(event)
    }
    
    /// Creates a thumbnail for the given shape name
    func createShapeThumbnail(item: MMListWidgetItem) -> MTLTexture?
    {
        var source =
        """
            #include <metal_stdlib>
            #include <simd/simd.h>
            using namespace metal;

            float merge(float d1, float d2)
            {
                return min(d1, d2);
            }

            float fillMask(float dist)
            {
                return clamp(-dist, 0.0, 1.0);
            }

            float borderMask(float dist, float width)
            {
                //dist += 1.0;
                return clamp(dist + width, 0.0, 1.0) - clamp(dist, 0.0, 1.0);
            }
        """
        
        let width : Float = 200 * zoom
        let height : Float = unitSize * zoom
        
        let texture = fragment!.allocateTexture(width: width, height: height, output: true)
        
        let left : Float = (width/2) * zoom
        let top : Float = (unitSize / 2) * zoom
        
        source +=
        """
        
        fragment float4 listWidgetThumbnail(RasterizerData in [[stage_in]])
        {
            float2 size = float2( \(width*zoom), \(height) );
        
            float2 uvOrigin = float2( in.textureCoordinate.x * size.x - size.x / 2., size.y - in.textureCoordinate.y * size.y - size.y / 2. );
            float2 uv;
        
            float dist = 10000;
            float2 d;
        
            float borderSize = 2.0;
            float round = 4;
        
            float4 fillColor = float4(0.275, 0.275, 0.275, 1.000);
            float4 borderColor = float4( 0.5, 0.5, 0.5, 1 );
            float4 primitiveColor = float4(1, 1, 1, 1.000);
        
            float4 modeInactiveColor = float4(0.5, 0.5, 0.5, 1.000);
            float4 modeActiveColor = float4(1);
        
            float4 scrollInactiveColor = float4(0.5, 0.5, 0.5, 0.2);
            float4 scrollHoverColor = float4(1);
            float4 scrollActiveColor = float4(0.5, 0.5, 0.5, 1);
        
            float4 finalCol = float4( 0 ), col = float4( 0 );
        """
        
        source += "uv = uvOrigin; uv.x += size.x / 2.0 - \(left) + borderSize/2; uv.y += size.y / 2.0 - \(top) + borderSize/2;\n"
        source += "uv /= \(zoom);\n"
        
        source += "d = abs( uv ) - float2( \((width)/2) - borderSize - 2, \(unitSize/2) - borderSize ) + float2( round );\n"
        source += "dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - round;\n"
        
        source += "col = float4( \(mmView.skin.Widget.selectionColor.x), \(mmView.skin.Widget.selectionColor.y), \(mmView.skin.Widget.selectionColor.z), fillMask( dist ) * \(mmView.skin.Widget.selectionColor.w) );\n"
        
        source += "col = mix( col, borderColor, borderMask( dist, borderSize) );\n"
        source += "finalCol = mix( finalCol, col, col.a );\n"
        
        source +=
        """
            return finalCol;
        }
        """
        
        //        print( source )
        let library = fragment!.createLibraryFromSource(source: source)
        let state = fragment!.createState(library: library, name: "listWidgetThumbnail")
        
        if fragment!.encoderStart(outTexture: texture) {
            
            fragment!.encodeRun(state)
            
            let left : Float = 6 * zoom
            let top : Float = 4 * zoom
            let fontScale : Float = 0.22
            
            var fontRect = MMRect()
            
            fontRect = mmView.openSans.getTextRect(text: item.name, scale: fontScale, rectToUse: fontRect)
            mmView.drawText.drawText(mmView.openSans, text: item.name, x: left, y: top, scale: fontScale * zoom, fragment: fragment)
 
            fragment!.encodeEnd()
        }
        
        return texture
    }
}
