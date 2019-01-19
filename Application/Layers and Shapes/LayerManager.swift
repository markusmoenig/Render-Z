//
//  LayerManager.swift
//  Shape-Z
//
//  Created by Markus Moenig on 15/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class LayerManager : Codable
{
    var layers          : [Layer]
    var layerIdCounter : Int

    var currentIndex    : Int
    
    var compute         : MMCompute?
    var state           : MTLComputePipelineState?
    
    var width           : Float!
    var height          : Float!

    private enum CodingKeys: String, CodingKey {
        case layers
        case currentIndex
        case layerIdCounter
    }
    
    init()
    {
        layers = []
        layerIdCounter = 0
        
        currentIndex = 0
        
        width = 0
        height = 0
        
        let layer = Layer()
        addLayer( layer )
    }
    
    func addLayer(_ layer: Layer)
    {
        layers.append( layer )
        layer.id = layerIdCounter
        layerIdCounter += 1
    }
    
    @discardableResult func run(width:Float, height:Float) -> MTLTexture
    {
        let layer = layers[currentIndex]
        
        self.width = width; self.height = height
        let texture = layer.run(width:width, height:height)
        return texture
    }
    
    func getCurrentLayer() -> Layer
    {
        return layers[currentIndex]
    }
    
    /// Get the object and shape id at the specific location
    func getShapeAt( x: Float, y: Float )
    {
        var source =
        """
            #include <metal_stdlib>
            #include <simd/simd.h>
            using namespace metal;

            float4 merge(float4 d1, float4 d2)
            {
                if ( d1.x < d2.x ) return d1;
                else return d2;
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
            selectedAt(device float4  *out [[ buffer(0) ]],
            uint id [[ thread_position_in_grid ]])
            {
                float2 fragCoord = float2( \(x), \(y) );
                float2 uv = 700. * (fragCoord.xy + float(0.5)) / \(width!);
        
                //float2 center = float2( 350., 350. * \(height!) / \(width!) );
                //uv = translate(uv, center );//- vec2( uOrigin.x * 40., uOrigin.y * 40. ) );
                float2 tuv = uv;
        
                float4 dist = float4(1000, -1, -1, -1);
        """
        
        for layer in layers {
            for object in layer.objects {
                for shape in object.shapes {
                    let posX = shape.properties["posX"]
                    let posY = shape.properties["posY"]
                    source += "uv = translate( tuv, float2( \(posX ?? 0), \(posY ?? 0) ) );"
                    source += "dist = merge( dist, float4(" + shape.createDistanceCode(uvName: "uv") + ", \(layer.id), \(object.id), \(shape.id) ) );"
                }
            }
        }
    
        source +=
        """
        
                out[id] = dist;
            }
        """
        
        if compute == nil {
            compute = MMCompute()
        }
        
        //        print( source )
    
        let library = compute!.createLibraryFromSource(source: source)
        state = compute!.createState(library: library, name: "selectedAt")

        let outBuffer = compute!.device.makeBuffer(length: MemoryLayout<float4>.stride, options: [])!
        compute!.runBuffer(state, outBuffer: outBuffer)
        
        let result = outBuffer.contents().load(as: float4.self)
        print( result )
        
        if result.x < 0 {
        
        }
    }
    
    /// Gets the global code of all shapes in the project
    func getGlobalCode() -> String
    {
        var coll : [String] = []
        var result = ""
        
        for layer in layers {
            for object in layer.objects {
                for shape in object.shapes {
                
                    if !coll.contains(shape.name) {
                        result += shape.globalCode
                        coll.append( shape.name )
                    }
                }
            }
        }
        
        return result
    }
}
