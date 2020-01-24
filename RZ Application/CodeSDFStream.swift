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
    var componentCounter    : Int = 0
    
    var monitor             : CodeFragment? = nil
    
    init()
    {
        
    }
    
    func openStream(_ type: CodeComponent.ComponentType,_ instance : CodeBuilderInstance,_ codeBuilder: CodeBuilder)
    {
        self.type = type
        self.instance = instance
        self.codeBuilder = codeBuilder
        
        monitor = nil
        componentCounter = 0        
        instance.properties = []
        
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
                float4 __monitorOut = float4(0,0,0,0);
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );
                float2 __origin = float2(__gid.x, __gid.y);
                float2 __center = __size / 2;
                __origin = __translate(__origin, __center);

                float GlobalTime = __data[0].x;
                float outDistance = 10;
                float4 outShape = float4(100000, 0,0,0);
            
            """
        }
    }

    func closeStream()
    {
        if let monitorFragment = monitor {
            if monitorFragment.name != "outDistance" {
                instance.code +=
                """
                
                outShape = __monitorOut;
                
                """
            } else {
                instance.code +=
                """
                
                outShape = float4(float3(outShape.x), 1);
                
                """
            }
        }
        
        if type == .SDF2D {
            instance.code +=
            """
            
                __outTexture.write(half4(outShape), __gid);
             }
            """
        }
        
        //print(instance.code)
        codeBuilder.buildInstance(instance)
    }
    
    func pushComponent(_ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        dryRunComponent(component, instance.data.count, monitor)
        instance.collectProperties(component)
        self.monitor = monitor
        
        if type == .SDF2D
        {
            let posX = instance.getTransformPropertyIndex(component, "_posX")
            let posY = instance.getTransformPropertyIndex(component, "_posY")

            instance.code +=
            """
                {
                    float2 pos = __translate(__origin, float2(__data[\(posX)].x, -__data[\(posY)].x));
            
            """
        }
        
        instance.code += component.code!

        if componentCounter > 0 {
            instance.code +=
            """
            
                float4 shapeA = outShape;
                float4 shapeB = float4(outDistance,0,0,0);
            
            """
            
            if let subComponent = component.subComponent {
                dryRunComponent(subComponent, instance.data.count)
                instance.collectProperties(subComponent)
                instance.code += subComponent.code!
            }
        } else {
            instance.code +=
            """
            
                outShape = float4(outDistance,0,0,0);
            
            """
        }
    
        instance.code += "\n    }\n"
        componentCounter += 1
    }
}
