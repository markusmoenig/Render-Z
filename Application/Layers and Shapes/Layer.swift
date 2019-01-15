//
//  Layer.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Layer : Codable
{
    var shapes          : [MM2DShape]
    var shapeIdCounter  : Int
    
    var compute         : MMCompute?
    var state           : MTLComputePipelineState?
    
    private enum CodingKeys: String, CodingKey {
        case shapes
        case shapeIdCounter
    }
    
    init()
    {
        shapes = []
        shapeIdCounter = 0
        
        compute = MMCompute()
        build()
    }
    
    func addShape(_ shape: MM2DShape)
    {
        shapes.append( shape )
    }
    
    /// Build the source for the layer
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

            float2 translate(float2 p, float2 t)
            {
                return p - t;
            }

            """
            
            source += getGlobalCode()
        
            source +=
            """

            kernel void
            layerBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
                         texture2d<half, access::read>   inTexture   [[texture(1)]],
                         uint2                           gid         [[thread_position_in_grid]])
            {
                float2 fragCoord = float2( gid.x, gid.y );
                float2 uv = 700. * (fragCoord.xy + float(0.5)) / outTexture.get_width();

                float2 center = float2( 350., 350. * outTexture.get_height() / outTexture.get_width() );
                uv = translate(uv, center );//- vec2( uOrigin.x * 40., uOrigin.y * 40. ) );
                float2 tuv = uv;

                float dist = 1000;
        """

        for shape in shapes {
            let posX = shape.properties["posX"]
            let posY = shape.properties["posY"]
            source += "uv = translate( tuv, float2( \(posX ?? 0), \(posY ?? 0) ) );"
            source += "dist = merge( dist, " + shape.create(uvName: "uv") + ");"
        }
        
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
        
        let library = compute!.createLibraryFromSource(source: source)
        state = compute!.createState(library: library, name: "layerBuilder")
    }
    
    @discardableResult func run(width:Float, height:Float) -> MTLTexture
    {
        if compute!.width != width || compute!.height != height {
            compute!.allocateTexture(width: width, height: height)
        }
        
        compute!.run( state )
        return compute!.texture
    }
    
    func getGlobalCode() -> String
    {
        var coll : [String] = []
        var result = ""
        
        for shape in shapes {
            
            if !coll.contains(shape.name) {
                result += shape.globalCode()
                coll.append( shape.name )
            }
        }
        
        return result
    }
}
