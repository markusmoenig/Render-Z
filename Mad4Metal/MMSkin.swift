//
//  MMSkin.swift
//  Framework
//
//  Created by Markus Moenig on 9/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

struct MMSkinWidget
{
    var color           : float4 = float4(0.145, 0.145, 0.145, 1.0)
    var selectionColor  : float4 = float4(0.224, 0.275, 0.361, 1.000)
    var textColor       : float4 = float4(0.957, 0.957, 0.957, 1.0)
    var borderColor     : float4 = float4(0.4, 0.4, 0.4, 1.0)
}

struct MMSkinButton
{
    var margin :    MMMargin = MMMargin( 8, 8, 8, 8 )
    var width :     Float = 40
    var height :    Float = 40
    var fontScale : Float = 0.5
    var borderSize: Float = 1.5
    var round:      Float = 6
    var color :     float4 = float4(0.392, 0.392, 0.392, 0.0 )
    var hoverColor: float4 = float4(0.502, 0.502, 0.502, 1.0 )
    var activeColor:float4 = float4(0.392, 0.392, 0.392, 1.0)
    var borderColor:float4 = float4(0.4, 0.4, 0.4, 1.0 )
}

struct MMSkinMenuButton
{
    var margin          : MMMargin = MMMargin( 8, 8, 8, 8 )
    var width           : Float = 40
    var height          : Float = 40
    var fontScale       : Float = 0.5
    var borderSize      : Float = 0
    var round           : Float = 6
    var color           : float4 = float4(0.392, 0.392, 0.392, 0.0 )
    var hoverColor      : float4 = float4(0.502, 0.502, 0.502, 1.0 )
    var activeColor     : float4 = float4(0.392, 0.392, 0.392, 1.0)
    var borderColor     : float4 = float4(0.4, 0.4, 0.4, 1.0 )
}

struct MMSkinMenuWidget
{
    var button          : MMSkinMenuButton = MMSkinMenuButton()
    
    var margin          : MMMargin = MMMargin( 8, 8, 8, 8 )

    var fontScale       : Float = 0.35
    var borderSize      : Float = 1.5
    var spacing         : Float = 4
    var color           : float4 = float4(0.569, 0.569, 0.569, 1.000)
    var hoverColor      : float4 = float4(0.502, 0.502, 0.502, 1.0 )
    var borderColor     : float4 = float4(0.0, 0.0, 0.0, 1.0 )
    var textColor       : float4 = float4(0.0, 0.0, 0.0, 1.0 )
    var selTextColor    : float4 = float4(0.404, 0.494, 0.686, 1.000)
    var selectionColor  : float4 = float4(0.224, 0.275, 0.361, 1.000)
}

struct MMSkin
{
    var Widget : MMSkinWidget = MMSkinWidget()
    var ToolBarButton : MMSkinButton = MMSkinButton()
    var MenuWidget : MMSkinMenuWidget = MMSkinMenuWidget()
}
