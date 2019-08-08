//
//  Header.h
//  Shape-Z
//
//  Created by Markus Moenig on 21.02.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

#ifndef Data_h
#define Data_h

#include <simd/simd.h>

typedef vector_float2 float2;
typedef vector_float4 float4;

typedef struct
{
    float2   size;
    float    selected;
    float    hoverIndex;
    float    scale;
    float    borderRound;
    
    float4   hasIcons1;
    
    float    leftTerminalCount;
    float    topTerminalCount;
    float    rightTerminalCount;
    float    bottomTerminalCount;
    
    float4   brandColor;

    float4   rightTerminals[10];
    
    float4   leftTerminal;
    float4   topTerminal;
    float4   bottomTerminal;
    
} NODE_DATA;

#endif /* Data_h */
