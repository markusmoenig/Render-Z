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
    
    var headerCode          : String = ""
    var mapCode             : String = ""

    var monitor             : CodeFragment? = nil
    
    init()
    {
        
    }
    
    func openStream(_ type: CodeComponent.ComponentType,_ instance : CodeBuilderInstance,_ codeBuilder: CodeBuilder, camera: CodeComponent? = nil)
    {
        self.type = type
        self.instance = instance
        self.codeBuilder = codeBuilder
        
        monitor = nil
        componentCounter = 0        
        instance.properties = []
                
        if type == .SDF2D {
            headerCode = codeBuilder.getHeaderCode()
            headerCode +=
            """
                        
            float2 __translate(float2 p, float2 t)
            {
                return p - t;
            }
            
            """
            
            // Generate the camera code and add the global camera code
            if let camera = camera {
                dryRunComponent(camera, instance.data.count, monitor)
                instance.collectProperties(camera)
                if let globalCode = camera.globalCode {
                    headerCode += globalCode
                }
            }
            
            instance.code =
                
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
            
                struct FuncData __funcData;
                __funcData.GlobalTime = GlobalTime;
                __funcData.__monitorOut = &__monitorOut;
                __funcData.__data = __data;
            
            """
            
            if let camera = camera {
                instance.code +=
                """
                
                    {
                        float2 position = __origin;
                        float2 outPosition = float2(0);
                
                """
                instance.code += camera.code!
                instance.code +=
                """
                
                        __origin = float2(outPosition.x, outPosition.y);
                    }
                
                """
            }
        } else
        if type == .SDF3D {
            headerCode = codeBuilder.getHeaderCode()
            headerCode +=
            """
            
            """
            
            mapCode =
            """
            
            float4 map( float3 pos, thread struct FuncData *__funcData )
            {
                float4 outShape = float4(100000, -1, -1, 1);
                float outDistance = 10;
            
                constant float4 *__data = __funcData->__data;
                float4 __monitorOut = *__funcData->__monitorOut;
                float GlobalTime = __funcData->GlobalTime;

            
            """
            
            instance.code =
                
            """
            kernel void componentBuilder(
            texture2d<half, access::write>          __outTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::sample>         __rayOriginTexture [[texture(2)]],
            texture2d<half, access::sample>         __rayDirectionTexture [[texture(3)]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

                float4 __monitorOut = float4(0,0,0,0);
            
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );

                float GlobalTime = __data[0].x;
            
                float2 __uv = float2(__gid.x, __gid.y);
                float3 __ro = float4(__rayOriginTexture.sample(__textureSampler, __uv / __size )).xyz;
                float3 __rd = float4(__rayDirectionTexture.sample(__textureSampler, __uv / __size )).xyz;

                struct FuncData __funcData;
                __funcData.GlobalTime = GlobalTime;
                __funcData.__monitorOut = &__monitorOut;
                __funcData.__data = __data;
            
                //float4 outShape = map( float3(0,0,0), &__funcData );
                float4 outShape = float4(0);
            
                float t = 0.001;
                for( int i=0; i < 70; i++ )
                {
                    float4 h = map( __ro + __rd * t, &__funcData );
                    if( abs(h.x)<(0.001 /**t*/) )
                    {
                        outShape = h;
                        break;
                    }
                    t += h.x;
                }
            
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
        
        instance.code +=
        """
        
            __outTexture.write(half4(outShape), __gid);
        }
        """
    
        if type == .SDF2D {
            instance.code = headerCode + instance.code
        } else
        if type == .SDF3D {
            mapCode +=
            """
            
                return outShape;
            }
            
            """
            instance.code = headerCode + mapCode + instance.code
        }
        
        print(instance.code)
        codeBuilder.buildInstance(instance)
    }
    
    func pushComponent(_ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        dryRunComponent(component, instance.data.count, monitor)
        instance.collectProperties(component)
        self.monitor = monitor
        
        if let globalCode = component.globalCode {
            headerCode += globalCode
        }
        
        var code = ""
        
        if type == .SDF2D
        {
            let posX = instance.getTransformPropertyIndex(component, "_posX")
            let posY = instance.getTransformPropertyIndex(component, "_posY")

            code +=
            """
                {
                    float2 pos = __translate(__origin, float2(__data[\(posX)].x, -__data[\(posY)].x));
            
            """
        }
        
        if type == .SDF3D
        {
            code +=
            """
                {
            
            """
        }

        
        code += component.code!

        if componentCounter > 0 {
            code +=
            """
            
                float4 shapeA = outShape;
                float4 shapeB = float4(outDistance,0,0,1);
            
            """
            
            if let subComponent = component.subComponent {
                dryRunComponent(subComponent, instance.data.count, monitor)
                instance.collectProperties(subComponent)
                instance.code += subComponent.code!
            }
        } else {
            code +=
            """
            
                outShape = float4(outDistance,0,0,1);
            
            """
        }
    
        code += "\n    }\n"
        if type == .SDF2D {
            instance.code += code
        } else
        if type == .SDF3D {
            mapCode += code
        }
        componentCounter += 1
    }
}
