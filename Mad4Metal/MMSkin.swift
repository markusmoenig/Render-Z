//
//  MMSkin.swift
//  Framework
//
//  Created by Markus Moenig on 9/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

struct MMSkinButton
{
    var margin :    MMMargin
    var width :     Float
    var height :    Float
    var fontScale : Float
    var borderSize: Float
    var round:      Float
    var color :     float4
    var hoverColor: float4
    var activeColor:float4
    var borderColor:float4
}

struct MMSkin
{
    var toolBarButton : MMSkinButton = MMSkinButton( margin: MMMargin( 8, 8, 8, 8 ), width: 40, height: 40, fontScale: 0.5, borderSize : 1.5, round: 6, color: float4(0.392, 0.392, 0.392, 0.0 ), hoverColor: float4(0.502, 0.502, 0.502, 1.0 ), activeColor: float4(0.392, 0.392, 0.392, 1.0), borderColor: float4(0.4, 0.4, 0.4, 1.0 ) )
}
