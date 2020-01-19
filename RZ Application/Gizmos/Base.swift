//
//  Base.swift
//  Render-Z
//
//  Created by Markus Moenig on 19/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation

class GizmoBase              : MMWidget
{
    enum GizmoState         : Float {
        case Inactive, CenterMove, xAxisMove, yAxisMove, Rotate, xAxisScale, yAxisScale, xyAxisScale
    }
    
    var hoverState          : GizmoState = .Inactive
    var dragState           : GizmoState = .Inactive
    
    var component            : CodeComponent!

    func setComponent(_ comp: CodeComponent)
    {
        component = comp
    }
}
