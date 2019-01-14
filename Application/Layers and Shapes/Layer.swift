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
             
            // Rec. 709 luma values for grayscale image conversion
            //constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);

            // Grayscale compute kernel
            kernel void
            layerBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
                         texture2d<half, access::read>   inTexture   [[texture(1)]],
                         uint2                           gid         [[thread_position_in_grid]])
            {
                float2 uv = float2( gid.x - outTexture.get_width() / 2.,
                                   gid.y - outTexture.get_height() / 2. );

                float dist = 1;
        """

        for shape in shapes {
            source += "dist = " + shape.create(uvName: "uv") + ";"
        }
        
        source +=
        """
                if ( dist <= 0 ) outTexture.write( half4(1, 1, 1, 1.0), gid );
                else outTexture.write(half4(1, 0, 0, 1.0), gid);
            }
        """
        
        let library = compute!.createLibraryFromSource(source: source)
        state = compute!.createState(library: library, name: "layerBuilder")
    }
    
    func run(width:Float, height:Float)
    {
        if compute!.width != width || compute!.height != height {
            compute!.allocateTexture(width: width, height: height)
        }
        
        compute!.run( state )
    }
}
