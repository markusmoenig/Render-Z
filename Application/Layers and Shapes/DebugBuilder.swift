//
//  DebugBuilder.swift
//  Shape-Z
//
//  Created by Markus Moenig on 7/3/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class DebugDisk {
    var pos         : float2
    var radius      : Float
    var color       : float4
    
    init(_ pos : float2,_ radius: Float,_ color: float4)
    {
        self.pos = pos
        self.radius = radius
        self.color = color
    }
}

class DebugBuilderInstance
{
    var state           : MTLComputePipelineState? = nil
    
    var data            : [Float]? = []
    var buffer          : MTLBuffer? = nil
    
    // Offset of the header data
    var headerOffset    : Int = 0
    
    var texture         : MTLTexture? = nil
    
    var disks           : [DebugDisk] = []
    
    func clear()
    {
        disks = []
    }
    
    func addDisk(_ pos : float2,_ radius: Float,_ color: float4)
    {
        disks.append(DebugDisk(pos, radius, color))
    }
}

class DebugBuilder
{
    var compute         : MMCompute?
    var nodeGraph       : NodeGraph
    var maxDiskSize     : Int = 20

    init(_ nodeGraph: NodeGraph)
    {
        self.nodeGraph = nodeGraph
        compute = MMCompute()
    }
    
    /// Build the state for the given objects
    func build(camera: Camera ) -> DebugBuilderInstance
    {
        let instance = DebugBuilderInstance()
        
        var source =
        """

        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;

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
        
        typedef struct
        {
            float4      camera;

            float4      disks[\(maxDiskSize*2)];
        } DEBUG_DATA;
        
        """

        instance.data!.append( camera.xPos )
        instance.data!.append( camera.yPos )
        instance.data!.append( 1/camera.zoom )
        instance.data!.append( 0 )
        
        instance.headerOffset = instance.data!.count
        
        // Fill up the objects
        for _ in 0..<maxDiskSize {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        source +=
        """
        
        kernel void
        debugBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
            constant DEBUG_DATA                     *debugData   [[ buffer(1) ]],
            texture2d<half, access::sample>          fontTexture [[texture(2)]],
            uint2                                    gid         [[thread_position_in_grid]])
        {
            float2 size = float2( outTexture.get_width(), outTexture.get_height() );
            float2 fragCoord = float2( gid.x, gid.y );
            float2 uv = fragCoord;
            
            float2 center = size / 2;
            uv = translate(uv, center - float2(debugData->camera.x, debugData->camera.y ) );
            uv.y = -uv.y;
            uv *= debugData->camera.z;
        
            float4 col = float4(0);
        
            for(int i = 0; i < \(maxDiskSize); ++i)
            {
                float2 pos = float2(debugData->disks[i*2].x, debugData->disks[i*2].y);
                float radius = debugData->disks[i*2].z;
        
                if ( radius > 0.0 ) {
                    float dist = length(uv - pos) - radius;
                    col = mix( col, debugData->disks[i*2+1], fillMask(dist) * debugData->disks[i*2+1].w );
                }
            }

        """
            
        source +=
        """
            outTexture.write(half4(col.x, col.y, col.z, col.w), gid);
        }
        
        """
        
        instance.buffer = compute!.device.makeBuffer(bytes: instance.data!, length: instance.data!.count * MemoryLayout<Float>.stride, options: [])!
        
        let library = compute!.createLibraryFromSource(source: source)
        instance.state = compute!.createState(library: library, name: "debugBuilder")
        
        return instance
    }
    
    /// Render the layer
    @discardableResult func render(width:Float, height:Float, instance: DebugBuilderInstance, camera: Camera) -> MTLTexture
    {
        if compute!.texture == nil || compute!.width != width || compute!.height != height {
            compute!.allocateTexture(width: width, height: height)
        }
        
        instance.texture = compute!.texture

        instance.data![0] = camera.xPos
        instance.data![1] = camera.yPos
        instance.data![2] = 1/camera.zoom
        
        // Fill Disks
        let offset : Int = instance.headerOffset
        
        for index in 0..<maxDiskSize {
            instance.data![offset + index * 8 + 2] = -1
        }
        
        for (index,disk) in instance.disks.enumerated() {
            if index >= maxDiskSize {
                break;
            }
            instance.data![offset + index * 8] = disk.pos.x
            instance.data![offset + index * 8 + 1] = disk.pos.y
            instance.data![offset + index * 8 + 2] = disk.radius
            
            instance.data![offset + index * 8 + 4] = disk.color.x
            instance.data![offset + index * 8 + 5] = disk.color.y
            instance.data![offset + index * 8 + 6] = disk.color.z
            instance.data![offset + index * 8 + 7] = disk.color.w
        }
        
        // ---
        
        memcpy(instance.buffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
        
        compute!.run( instance.state, inBuffer: instance.buffer, inTexture: nodeGraph.mmView.openSans.atlas )
        return compute!.texture
    }
}
