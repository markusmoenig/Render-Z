//
//  ShapeSelector.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

struct ShapeSelectorDrag : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : float2? = float2()
    var shape           : Shape? = nil
    var name            : String = ""
}

class ShapeSelector
{
    var mmView          : MMView
    var shapes          : [Shape]
    var shapeFactory    : ShapeFactory
    
    var shapeRects      : [MMRect]

    var fragment        : MMFragment?
    
    var width, height   : Float
    var spacing         : Float
    var unitSize        : Float
    
    var selectedIndex   : Int
    var selectedShape   : Shape!
    
    var zoom            : Float = 2
    
    init(_ view: MMView, width: Float )
    {
        mmView = view
        
        shapes = []
        shapeFactory = ShapeFactory()
        
        shapeRects = []
        fragment = MMFragment(view)

        spacing = 10
        unitSize = (width - spacing * 3) / 2
        
        selectedIndex = 0
        
        // --- Shapes

        for shapeDef in shapeFactory.shapes {
            let shape = shapeFactory.createShape(shapeDef.name, size: unitSize / 2 - 2)
            if shape.name == "Box" {
                selectedShape = shape
            }
            shapes.append( shape )
        }
        
        // ---
        
        self.width = width * zoom
        height = spacing * 4
        let length : Int = shapes.count
        let lines : Float = Float((length / 2 + length % 2))
        height += Float(lines * Float(unitSize) + lines * Float(20))
//        print( unitSize, height, length.truncatingRemainder(dividingBy: 2.0), length )
        
        height = height * zoom
        build()
    }
    
    /// Build the source
    func build()
    {
        var source =
        """
            
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
        
        for shape in shapes {
            source += shape.globalCode;
        }
        
        source +=
        """
        
            fragment float4 shapeBuilder(RasterizerData in [[stage_in]])
            {
                float2 size = float2( \(width), \(height) );
                float2 uvOrigin = in.textureCoordinate * size - size / 2;
                uvOrigin.y = 1 - uvOrigin.y;
                float2 uv;
        
                float dist = 10000;
        
        """

        var counter : Int = 0
        var left : Float = (spacing + unitSize / 2) * zoom
        var top : Float = (spacing + unitSize / 2) * zoom
        
        shapeRects = []
        for (_, shape) in shapes.enumerated() {

            source += "uv = uvOrigin; uv.x += size.x / 2 - \(left); uv.y += size.y / 2 - \(top);\n"
            
            source += "uv /= \(zoom);\n"
            source += "dist = merge( dist, " + shape.createDistanceCode(uvName: "uv") + ");"
            
            shapeRects.append( MMRect(left/zoom - unitSize / 2, top / zoom - unitSize / 2, unitSize, unitSize ) )
            
            counter += 1
            if counter % 2 == 0 {
                top += (unitSize + spacing + 20) * zoom
                left = (spacing + unitSize / 2) * zoom
            } else {
                left += (unitSize + spacing) * zoom
            }
        }
        
        source +=
        """
                float4 fillColor = float4( 0.5, 0.5, 0.5, 1);
                float4 borderColor = float4( 1 );
        
                float4 col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );
                col = mix( col, borderColor, borderMask( dist, 2 ) );
                return col;
            }
        """
        
        let library = fragment!.createLibraryFromSource(source: source)
        let fragmentState = fragment!.createState(library: library, name: "shapeBuilder")
        
        if fragment!.width != width || fragment!.height != height {
            fragment!.allocateTexture(width: width, height: height)
        }
        
        if fragment!.encoderStart() {

            fragment!.encodeRun(fragmentState, inTexture: mmView.openSans.atlas)
            
            left = spacing
            top = spacing + unitSize - 4
            counter = 0
            let fontScale : Float = 0.26
            
            var fontRect = MMRect()
            
            for shape in shapes {
                
                fontRect = mmView.openSans.getTextRect(text: shape.name, scale: fontScale * zoom, rectToUse: fontRect)
                mmView.drawText.drawText(mmView.openSans, text: shape.name, x: left + (unitSize - fontRect.width) / 2, y: top + 4, scale: fontScale * zoom, fragment: fragment)
                
                counter += 1
                if counter % 2 == 0 {
                    top += (unitSize + spacing + 20)
                    left = spacing
                } else {
                    left += unitSize + spacing
                }
            }
            
            fragment!.encodeEnd()
        }
    }
    
    /// Creates a thumbnail for the given shape name
    func createShapeThumbnail(_ shape: Shape) -> MTLTexture?
    {
        let comp = MMCompute()
        comp.allocateTexture(width: unitSize, height: unitSize)
        
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
        
        source += shape.globalCode
        
        source +=
        """
        
        kernel void
        iconBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
        texture2d<half, access::read>   inTexture   [[texture(1)]],
        uint2                           gid         [[thread_position_in_grid]])
        {
            float2 uv = float2( gid.x - outTexture.get_width() / 2., gid.y - outTexture.get_height() / 2. );
            float dist = 10000;
        """
        
        source += "dist = merge( dist, " + shape.createDistanceCode(uvName: "uv") + ");"
        source +=
        """
            float4 fillColor = float4( 0.5, 0.5, 0.5, 1);
            float4 borderColor = float4( 1 );
        
            float4 col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );
            col = mix( col, borderColor, borderMask( dist, 2 ) );
        
            outTexture.write(half4(col.x, col.y, col.z, col.w), gid);
        }
        """
        
        //        print( source )
        let library = comp.createLibraryFromSource(source: source)
        let state = comp.createState(library: library, name: "iconBuilder")
        
        comp.run( state )
        
        return comp.texture
    }
    
    /// Selected the shape at the given relative mouse position
    func selectAt(_ x: Float,_ y: Float) -> Shape?
    {
        for (index, rect) in shapeRects.enumerated() {
            if rect.contains( x, y ) {
                selectedIndex = index
                selectedShape = shapes[index]
                return selectedShape
            }
        }
        return nil
    }
    
    /// Create a drag item for the given position
    func createDragSource(_ x: Float,_ y: Float) -> ShapeSelectorDrag
    {
        var drag = ShapeSelectorDrag()
        for (index, rect) in shapeRects.enumerated() {
            if rect.contains( x, y ) {
                drag.id = "ShapeSelectorItem"
                drag.name = shapes[index].name
                drag.pWidgetOffset!.x = x - rect.x
                drag.pWidgetOffset!.y = y - rect.y
                drag.shape = shapeFactory.createShape(drag.name, size: unitSize / 2 - 2)

                let texture = createShapeThumbnail(drag.shape!)
                drag.previewWidget = MMTextureWidget(mmView, texture: texture)
                break
            }
        }
        return drag
    }
    
    /// Create an instance of the currently selected shape
    func createSelected() -> Shape
    {
        return shapeFactory.createShape(selectedShape.name)
    }
}
