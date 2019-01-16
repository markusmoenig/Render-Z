//
//  Layer.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ShapeSelector
{
    var shapes          : [Shape]
    var shapeFactory    : ShapeFactory
    
    var shapeRects      : [MMRect]

    var compute         : MMCompute?
    var state           : MTLComputePipelineState?
    
    var width, height   : Float
    var spacing         : Float
    var unitSize        : Float
    
    var selectedIndex   : Int
    var selectedShape   : Shape!
    
    init( width: Float )
    {
        shapes = []
        shapeFactory = ShapeFactory()
        
        shapeRects = []
        compute = MMCompute()
        
        spacing = 10
        unitSize = (width - spacing * 3) / 2
        
        selectedIndex = 0
        
        // --- Shapes

        for shapeDef in shapeFactory.shapes {
            let shape = shapeFactory.createShape(shapeDef.name, size: unitSize / 2 - 8)
            if shape.name == "Box" {
                selectedShape = shape
            }
            shapes.append( shape )
        }
        
        // ---
        
        self.width = width
        height = spacing * 2
        let length : Int = shapes.count
        height += Float((length / 2 + length % 2 ) * Int(unitSize))
//        print( unitSize, height, length.truncatingRemainder(dividingBy: 2.0), length )
        
        build()
    }
    
    /// Build the source
    func build()
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
        
        for shape in shapes {
            source += shape.globalCode;
        }
        
        source +=
        """

            // Grayscale compute kernel
            kernel void
            layerBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
                         texture2d<half, access::read>   inTexture   [[texture(1)]],
                         uint2                           gid         [[thread_position_in_grid]])
            {
                float2 uvOrigin = float2( gid.x - outTexture.get_width() / 2.,
                                          gid.y - outTexture.get_height() / 2. );
                float2 uv;

                float dist = 10000;
        """

        var counter : Int = 0
        var left : Float = spacing + unitSize / 2
        var top : Float = spacing + unitSize / 2
        var selLeft : Float = 0
        var selTop : Float = 0
        
        shapeRects = []
        for (index, shape) in shapes.enumerated() {

            source += "uv = uvOrigin; uv.x += outTexture.get_width() / 2 - \(left); uv.y += outTexture.get_height() / 2 - \(top);\n"
            source += "dist = merge( dist, " + shape.createDistanceCode(uvName: "uv") + ");"
            
            if index == selectedIndex {
                selLeft = left
                selTop = top
            }
                
            shapeRects.append( MMRect(left - unitSize / 2, top - unitSize / 2, unitSize, unitSize ) )
            
            counter += 1
            if counter % 2 == 0 {
                top += unitSize + spacing
                left = spacing + unitSize / 2
            } else {
                left += unitSize + spacing
            }
        }
        
        source +=
        """
                float4 fillColor = float4( 0.5, 0.5, 0.5, 1);
                float4 borderColor = float4( 1 );
        
                float4 col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );
                col = mix( col, borderColor, borderMask( dist, 2 ) );
        
                uv = uvOrigin; uv.x += outTexture.get_width() / 2 - \(selLeft); uv.y += outTexture.get_height() / 2 - \(selTop);
        
                float2 d = abs( uv ) - \(unitSize) / 2 + 4;
                dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - 4;

                col = mix( col, borderColor, borderMask( dist, 2 ) );
        
                outTexture.write(half4(col.x, col.y, col.z, col.w), gid);
            }
        """
        
//        print( source )
        let library = compute!.createLibraryFromSource(source: source)
        state = compute!.createState(library: library, name: "layerBuilder")
        
        if compute!.width != width || compute!.height != height {
            compute!.allocateTexture(width: width, height: height)
        }
        
        compute!.run( state )
    }
    
    /// Selected the shape at the given relative mouse position
    func selectAt(_ x: Float,_ y: Float)
    {
        for (index, rect) in shapeRects.enumerated() {
            if rect.contains( x, y ) {
                selectedIndex = index
                selectedShape = shapes[index]
                build()
                break
            }
        }
    }
    
    /// Create an instance of the currently selected shape
    func createSelected() -> Shape
    {
        return shapeFactory.createShape(selectedShape.name)
    }
}
