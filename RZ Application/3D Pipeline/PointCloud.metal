//
//  PointCloud.metal
//  Shape-Z
//
//  Created by Markus Moenig on 11/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut{
    float4 position[[position]];
    float pointsize[[point_size]];
};

vertex VertexOut basic_vertex(const device packed_float3 *points [[ buffer(0) ]], const device float4x4 *m [[ buffer(1) ]],
                           unsigned int vid [[ vertex_id ]] )
{
    VertexOut out;

    out.position = *m * float4(points[vid], 1.0);
    out.pointsize = 80;
    
    return out;
}

fragment half4 basic_fragment() {

    return half4(1.0);
}
