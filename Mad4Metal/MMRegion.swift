//
//  MMRegion.swift
//  Framework
//
//  Created by Markus Moenig on 04.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class MMRegion
{
    enum MMRegionType
    {
        case Left, Top, Right, Bottom, Editor
    }
    
    var rect        : MMRect
    let mmView      : MMView
    
    let type        : MMRegionType
    
    // --- Animation
    
    var animActive      : Bool
    var animTarget      : Float
    var animStartValue  : Float
    var animStepValue   : Float
    var animFinishedCB  : ()->()

    init( _ view: MMView, type: MMRegionType )
    {
        mmView = view
        rect = MMRect()
        
        self.type = type
        animActive = false
        animTarget = 0
        animStartValue = 0
        animStepValue = 0
        animFinishedCB = {}
    }
    
    func startAnimation(_ target: Float, startValue: Float = 0, stepValue: Float = 10, finishedCB: @escaping ()->() = {} )
    {
        animActive = true
        animTarget = target
        animStartValue = startValue
        animStepValue = stepValue
        animFinishedCB = finishedCB
        rect.width = animStartValue
        mmView.preferredFramesPerSecond = mmView.maxFramerate
    }
    
    func endAnimation()
    {
        mmView.preferredFramesPerSecond = mmView.defaultFramerate
        animActive = false
        animFinishedCB()
    }
    
    func build()
    {
        if animActive {
            switch type
            {
                case .Left:
                
                    if animTarget > rect.width {
                        rect.width += animStepValue
                        if rect.width >= animTarget {
                            rect.width = animTarget
                            endAnimation()
                        }
                    } else if animTarget < rect.width {
                        rect.width -= animStepValue
                        if rect.width <= animTarget {
                            rect.width = animTarget
                            endAnimation()
                        }
                    } else {
                        endAnimation()
                    }
                
                case .Right, .Top, .Bottom, .Editor:
                    animActive = false
            }
        }
    }
    
    func layoutH( startX: Float, startY: Float, spacing: Float, widgets: MMWidget... )
    {
        var x : Float = startX
        for widget in widgets {
            widget.rect.x = x
            widget.rect.y = startY
            x += widget.rect.width + spacing
        }        
    }
    
    func registerWidgets( widgets: MMWidget... )
    {
        for widget in widgets {
            mmView.registerWidget( widget, region: self )
        }
    }
    
    func resize(width: Float, height: Float)
    {
    }
}
