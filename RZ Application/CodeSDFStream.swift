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

    var ids                 : [Int:(StageItem?, CodeComponent?)] = [:]
    var idCounter           : Int = 0

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
        
        ids = [:]
        idCounter = 0
                
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
                float4 outShape = float4(100000, -1, -1, -1);
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
            texture2d<half, access::write>          __normalTexture [[texture(4)]],
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
            
                float4 outShape = float4(100000, -1, -1, -1);
                float4 outNormal = float4(0);
            
                float t = 0.001;
                for( int i=0; i < 70; i++ )
                {
                    float4 h = map( __ro + __rd * t, &__funcData );
                    if( h.x <(0.001 * t) )
                    {
                        outShape = h;
                        outShape.y = t;
            
                        float3 pos = __ro + t * __rd;
            
                        float2 e = float2(1.0,-1.0)*0.5773*0.0005;
                        outNormal.xyz = normalize( e.xyy*map( pos + e.xyy, &__funcData ).x +
                              e.yyx*map( pos + e.yyx, &__funcData ).x +
                              e.yxy*map( pos + e.yxy, &__funcData ).x +
                              e.xxx*map( pos + e.xxx, &__funcData ).x );
                        
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
    
        if type == .SDF2D {
            instance.code +=
            """
            
                __outTexture.write(half4(outShape), __gid);
            }
            """
            instance.code = headerCode + instance.code
        } else
        if type == .SDF3D {
            instance.code +=
            """
            
                __normalTexture.write(half4(outNormal), __gid);
                __outTexture.write(half4(outShape), __gid);
            }
            """
            mapCode +=
            """
            
                return outShape;
            }
            
            """
            instance.code = headerCode + mapCode + instance.code
        }
        
        //print(instance.code)
        codeBuilder.buildInstance(instance)
    }
    
    func pushComponent(_ component: CodeComponent,_ monitor: CodeFragment? = nil, stageItem: StageItem? = nil)
    {
        dryRunComponent(component, instance.data.count, monitor)
        instance.collectProperties(component, stageItem)
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
                float4 shapeB = float4(outDistance,0,0,\(idCounter));
            
            """
            
            if let subComponent = component.subComponent {
                dryRunComponent(subComponent, instance.data.count, monitor)
                instance.collectProperties(subComponent)
                code += subComponent.code!
            }
        } else {
            code +=
            """
            
                outShape = float4(outDistance,0,0,\(idCounter));
            
            """
        }
    
        code += "\n    }\n"
        if type == .SDF2D {
            instance.code += code
        } else
        if type == .SDF3D {
            mapCode += code
        }
        
        // If we have a stageItem, store the id
        if let stageItem = stageItem {
            ids[idCounter] = (stageItem, component)
        }
        idCounter += 1
        componentCounter += 1
    }
}
