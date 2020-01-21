//
//  CodeSDFStream.swift
//  Shape-Z
//
//  Created by Markus Moenig on 21/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation

class CodeSDFStream
{
    var type                : CodeComponent.ComponentType = .SDF2D
    var instance            : CodeBuilderInstance!
    var codeBuilder         : CodeBuilder!
    
    init()
    {
        
    }
    
    func openStream(_ type: CodeComponent.ComponentType,_ instance : CodeBuilderInstance,_ codeBuilder: CodeBuilder)
    {
        self.type = type
        self.instance = instance
        self.codeBuilder = codeBuilder
        
        if type == .SDF2D {
            instance.code +=
            """
            
            #include <metal_stdlib>
            #include <simd/simd.h>
            using namespace metal;
                        
            float2 __translate(float2 p, float2 t)
            {
                return p - t;
            }
            
            """
            
            instance.code +=
                
            """
            kernel void componentBuilder(
            texture2d<half, access::write>          __outTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            //texture2d<half, access::sample>       fontTexture [[texture(2)]],
            uint2 __gid                               [[thread_position_in_grid]])
            {
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );
                float2 __origin = float2(__gid.x, __gid.y);
                float2 __center = __size / 2;
                __origin = __translate(__origin, __center);

                float GlobalTime = __data[0].x;
                float outDistance = 10;
                float4 __output = float4(100000,0,0,0);

            """
        }
    }

    func closeStream()
    {
        if type == .SDF2D {
            instance.code +=
            """
            
                __outTexture.write(half4(__output), __gid);
             }
            """
        }
        
        print(instance.code)
        codeBuilder.buildInstance(instance)
    }
    
    func pushComponent(_ component: CodeComponent)
    {
        dryRunComponent(component, instance.data.count)
        
        instance.collectProperties(component)
        
        if type == .SDF2D
        {
            let posX = instance.getTransformPropertyIndex(component, "_posX")
            let posY = instance.getTransformPropertyIndex(component, "_posY")
            print( "posX", posX)
            print( "posY", posY)
            instance.code +=
            """
                {
                    float2 pos = __translate(__origin, float2(__data[\(posX)].x, -__data[\(posY)].x));
            """
        }

        instance.code += component.code!
        instance.code += "\n __output.x = min( __output.x, outDistance);\n"
        instance.code += "\n    }\n"
    }
}
