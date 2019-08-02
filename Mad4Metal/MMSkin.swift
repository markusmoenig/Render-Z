//
//  MMSkin.swift
//  Framework
//
//  Created by Markus Moenig on 9/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

struct MMSkinToolBar
{
    var height          : Float = 44
    var borderSize      : Float = 1
    var round           : Float = 0
    var color           : float4 = float4(0.145, 0.145, 0.149, 1.000)
    var borderColor     : float4 = float4(0.094, 0.098, 0.102, 1.000)
}

struct MMSkinWidget
{
    var color           : float4 = float4(0.145, 0.145, 0.145, 1.0)
    var selectionColor  : float4 = float4(0.224, 0.275, 0.361, 1.000)
    var textColor       : float4 = float4(0.957, 0.957, 0.957, 1.0)
    var borderColor     : float4 = float4(0.4, 0.4, 0.4, 1.0)
}

struct MMSkinButton
{
    var margin :    MMMargin = MMMargin( 16, 8, 16, 8 )
    var width :     Float = 40
    var height :    Float = 40
    var fontScale : Float = 0.5
    var borderSize: Float = 1.5
    var round:      Float = 34
    var color :     float4 = float4(0.392, 0.392, 0.392, 0.0 )
    var hoverColor: float4 = float4(0.502, 0.502, 0.502, 1.0 )
    var activeColor:float4 = float4(0.392, 0.392, 0.392, 1.0)
    var borderColor:float4 = float4(0.4, 0.4, 0.4, 1.0 )
}

struct MMSkinSmallButton
{
    var margin :    MMMargin = MMMargin( 8, 8, 8, 12 )
    var width :     Float = 40
    var height :    Float = 30
    var fontScale : Float = 0.4
    var borderSize: Float = 1.5
    var round:      Float = 26
    var color :     float4 = float4(0.392, 0.392, 0.392, 0.0 )
    var hoverColor: float4 = float4(0.502, 0.502, 0.502, 1.0 )
    var activeColor:float4 = float4(0.392, 0.392, 0.392, 1.0)
    var borderColor:float4 = float4(0.4, 0.4, 0.4, 1.0 )
}

struct MMSkinScrollButton
{
    var margin :    MMMargin = MMMargin( 8, 8, 8, 8 )
    var width :     Float = 40
    var height :    Float = 40
    var fontScale : Float = 0.5
    var borderSize: Float = 1.5
    var round:      Float = 34
    var color :     float4 = float4(0.392, 0.392, 0.392, 0.0 )
    var hoverColor: float4 = float4(1, 1, 1, 1.0 )
    var activeColor:float4 = float4(0.5, 0.5, 0.5, 1.0)
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
    var color           : float4 = float4(1, 1, 1, 0.0 )
    var hoverColor      : float4 = float4(1, 1, 1, 0.2 )
    var activeColor     : float4 = float4(1, 1, 1, 0.2 )
    var borderColor     : float4 = float4(0.0, 0.0, 0.0, 0.0 )
}

struct MMSkinMenuWidget
{
    var button          : MMSkinMenuButton = MMSkinMenuButton()
    
    var margin          : MMMargin = MMMargin( 12, 8, 12, 8 )

    var fontScale       : Float = 0.35
    var borderSize      : Float = 1
    var spacing         : Float = 4
    var round           : Float = 12
    var color           : float4 = float4(0.533, 0.537, 0.541, 1.000)
    var hoverColor      : float4 = float4(0.502, 0.502, 0.502, 1.0 )
    var borderColor     : float4 = float4(0.0, 0.0, 0.0, 1.0 )
    var textColor       : float4 = float4(0.165, 0.169, 0.173, 1.000)
    var selTextColor    : float4 = float4(0.878, 0.882, 0.886, 1.000)
    var selectionColor  : float4 = float4(0.224, 0.275, 0.361, 1.000)
}

struct MMSkinTimeline
{
    var margin          : MMMargin = MMMargin( 8, 8, 8, 8 )
}

struct MMSkinNode
{
    var titleColor      : float4 = float4(0.878, 0.886, 0.890, 1.000)

    var propertyColor   : float4 = float4(0.757, 0.471, 0.255, 1.000)
    var behaviorColor   : float4 = float4(0.196, 0.400, 0.369, 1.000)
    var functionColor   : float4 = float4(0.173, 0.310, 0.518, 1.000)
    var arithmeticColor : float4 = float4(0.035, 0.039, 0.043, 1.000)
    var selectionColor  : float4 = float4(0.224, 0.275, 0.361, 1.000)
    
    var successColor    : float4 = float4(0.278, 0.545, 0.220, 1.000)
    var failureColor    : float4 = float4(0.729, 0.263, 0.235, 1.000)
    var runningColor    : float4 = float4(0.678, 0.682, 0.686, 1.000)
}

struct MMSkin
{
    var Widget : MMSkinWidget = MMSkinWidget()
    var ToolBar : MMSkinToolBar = MMSkinToolBar()
    var ToolBarButton : MMSkinButton = MMSkinButton()
    var Button : MMSkinSmallButton = MMSkinSmallButton()
    var IconButton : MMSkinButton = MMSkinButton()
    var MenuWidget : MMSkinMenuWidget = MMSkinMenuWidget()
    var TimelineWidget : MMSkinTimeline = MMSkinTimeline()
    var ScrollButton : MMSkinScrollButton = MMSkinScrollButton()
    var Node : MMSkinNode = MMSkinNode()
}
