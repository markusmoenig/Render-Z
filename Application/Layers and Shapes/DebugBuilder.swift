//
//  DebugBuilder.swift
//  Shape-Z
//
//  Created by Markus Moenig on 7/3/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class DebugDisk {
    var pos         : SIMD2<Float>
    var radius      : Float
    var border      : Float
    var color       : SIMD4<Float>
    
    init(_ pos : SIMD2<Float>,_ radius: Float,_ border: Float,_ color: SIMD4<Float>)
    {
        self.pos = pos
        self.radius = radius
        self.border = border
        self.color = color
    }
}

class DebugLine {
    var pos1        : SIMD2<Float>
    var pos2        : SIMD2<Float>
    var radius      : Float
    var border      : Float
    var color       : SIMD4<Float>
    
    init(_ pos1 : SIMD2<Float>, _ pos2 : SIMD2<Float>,_ radius: Float,_ border: Float,_ color: SIMD4<Float>)
    {
        self.pos1 = pos1
        self.pos2 = pos2
        self.radius = radius
        self.border = border
        self.color = color
    }
}

class DebugBox {
    var pos         : SIMD2<Float>
    var size        : SIMD2<Float>
    var rotation    : Float
    var border      : Float
    var color       : SIMD4<Float>
    
    init(_ pos : SIMD2<Float>,_ size: SIMD2<Float>,_ rotation: Float,_ border: Float,_ color: SIMD4<Float>)
    {
        self.pos = pos
        self.size = size
        self.rotation = rotation
        self.border = border
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

    // Offset of the line data
    var lineOffset      : Int = 0
    
    // Offset of the box data
    var boxOffset       : Int = 0
    
    var texture         : MTLTexture? = nil
    
    var disks           : [DebugDisk] = []
    var lines           : [DebugLine] = []
    var boxes           : [DebugBox] = []
    
    var disksBackup     : [DebugDisk] = []
    var linesBackup     : [DebugLine] = []
    var boxesBackup     : [DebugBox] = []
    
    func clear()
    {
        disks = []
        lines = []
        boxes = []
    }
    
    func save() {
        disksBackup = disks
        linesBackup = lines
        boxesBackup = boxes
    }
    
    func restore() {
        let t1 = disks
        let t2 = lines
        let t3 = boxes

        disks = disksBackup
        lines = linesBackup
        boxes = boxesBackup
        
        disksBackup = t1
        linesBackup = t2
        boxesBackup = t3
    }
    
    func addDisk(_ pos : SIMD2<Float>,_ radius: Float,_ border: Float, _ color: SIMD4<Float>)
    {
        disks.append(DebugDisk(pos, radius, border, color))
    }
    
    func addLine(_ pos1 : SIMD2<Float>, _ pos2 : SIMD2<Float>,_ radius: Float,_ border: Float, _ color: SIMD4<Float>)
    {
        lines.append(DebugLine(pos1, pos2, radius, border, color))
    }
    
    func addBox(_ pos : SIMD2<Float>, _ size : SIMD2<Float>,_ rotation: Float,_ border: Float, _ color: SIMD4<Float>)
    {
        boxes.append(DebugBox(pos, size, rotation, border, color))
    }
}

class DebugBuilder
{
    var compute         : MMCompute?
    var nodeGraph       : NodeGraph
    var maxDiskSize     : Int = 80
    var maxLineSize     : Int = 20
    var maxBoxSize      : Int = 20

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
            float4      lines[\(maxLineSize*3)];
            float4      boxes[\(maxBoxSize*3)];
        } DEBUG_DATA;
        
        """

        instance.data!.append( camera.xPos )
        instance.data!.append( camera.yPos )
        instance.data!.append( 1/camera.zoom )
        instance.data!.append( 0 )
        
        instance.headerOffset = instance.data!.count
        
        // Fill up the disk space
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
        
        instance.lineOffset = instance.data!.count

        // Fill up the lines
        for _ in 0..<maxLineSize {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.boxOffset = instance.data!.count
        
        // Fill up the boxes
        for _ in 0..<maxBoxSize {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            
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
        
        float sdLine( float2 uv, float2 pa, float2 pb, float r) {
            float2 o = uv-pa;
            float2 l = pb-pa;
            float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
            return -(r-distance(o,l*h));
        }
        
        float sdBox(float2 p, float2 b )
        {
            float2 d = abs(p)-b;
            return length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
        }
        
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
                float border = debugData->disks[i*2].w;

                if ( radius > 0.0 ) {
                    float dist = length(uv - pos) - radius;
                    if ( border == 0.0 )
                        col = mix( col, debugData->disks[i*2+1], fillMask(dist) * debugData->disks[i*2+1].w );
                    else
                        col = mix( col, debugData->disks[i*2+1], borderMask(dist, border) * debugData->disks[i*2+1].w );
                } else break;
            }
        
            for(int i = 0; i < \(maxLineSize); ++i)
            {
                float2 pos1 = float2(debugData->lines[i*3].x, debugData->lines[i*3].y);
                float2 pos2 = float2(debugData->lines[i*3].z, debugData->lines[i*3].w);
                float radius = debugData->lines[i*3+1].x;
                float border = debugData->lines[i*3+1].y;
        
                if ( radius > 0.0 ) {
                    float dist = sdLine(uv, pos1, pos2, radius);
                    if ( border == 0.0 )
                        col = mix( col, debugData->lines[i*3+2], fillMask(dist) * debugData->lines[i*3+2].w );
                    else
                        col = mix( col, debugData->lines[i*3+2], borderMask(dist, border) * debugData->lines[i*3+2].w );
                } else break;
            }
        
            for(int i = 0; i < \(maxBoxSize); ++i)
            {
                float2 pos = float2(debugData->boxes[i*3].x, debugData->boxes[i*3].y);
                float2 size = float2(debugData->boxes[i*3].z, debugData->boxes[i*3].w);
                float rotation = debugData->boxes[i*3+1].x;
                float border = debugData->boxes[i*3+1].y;
        
                if ( rotation >= 0.0 ) {
                    float dist = sdBox(uv - pos, size);
                    if ( border == 0.0 )
                        col = mix( col, debugData->boxes[i*3+2], fillMask(dist) * debugData->boxes[i*3+2].w );
                    else
                        col = mix( col, debugData->boxes[i*3+2], borderMask(dist, border) * debugData->boxes[i*3+2].w );
                } else break;
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
        var offset : Int = instance.headerOffset
        
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
            instance.data![offset + index * 8 + 3] = disk.border

            instance.data![offset + index * 8 + 4] = disk.color.x
            instance.data![offset + index * 8 + 5] = disk.color.y
            instance.data![offset + index * 8 + 6] = disk.color.z
            instance.data![offset + index * 8 + 7] = disk.color.w
        }
        
        // Fill Lines
        offset = instance.lineOffset
        
        for index in 0..<maxLineSize {
            instance.data![offset + index * 12 + 4] = -1
        }
        
        for (index,line) in instance.lines.enumerated() {
            if index >= maxLineSize {
                break;
            }
            instance.data![offset + index * 12] = line.pos1.x
            instance.data![offset + index * 12 + 1] = line.pos1.y
            instance.data![offset + index * 12 + 2] = line.pos2.x
            instance.data![offset + index * 12 + 3] = line.pos2.y
            
            instance.data![offset + index * 12 + 4] = line.radius
            instance.data![offset + index * 12 + 5] = line.border
            
            instance.data![offset + index * 12 + 8] = line.color.x
            instance.data![offset + index * 12 + 9] = line.color.y
            instance.data![offset + index * 12 + 10] = line.color.z
            instance.data![offset + index * 12 + 11] = line.color.w
        }
        
        // Fill Boxes
        offset = instance.boxOffset
        
        for index in 0..<maxBoxSize {
            instance.data![offset + index * 12 + 4] = -1
        }
        
        for (index,box) in instance.boxes.enumerated() {
            if index >= maxBoxSize {
                break;
            }
            instance.data![offset + index * 12] = box.pos.x
            instance.data![offset + index * 12 + 1] = box.pos.y
            instance.data![offset + index * 12 + 2] = box.size.x
            instance.data![offset + index * 12 + 3] = box.size.y
            
            instance.data![offset + index * 12 + 4] = box.rotation
            instance.data![offset + index * 12 + 5] = box.border
            
            instance.data![offset + index * 12 + 8] = box.color.x
            instance.data![offset + index * 12 + 9] = box.color.y
            instance.data![offset + index * 12 + 10] = box.color.z
            instance.data![offset + index * 12 + 11] = box.color.w
        }
        
        // ---
        
        memcpy(instance.buffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
        
        compute!.run( instance.state, inBuffer: instance.buffer, inTexture: nodeGraph.mmView.openSans.atlas )
        return compute!.texture
    }
}
