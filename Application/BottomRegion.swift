//
//  BottomRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class BottomRegion: MMRegion
{
    var app             : App
    var animating       : Bool = false
    
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    var mode            : BottomRegionMode
    
    init( _ view: MMView, app: App )
    {
        self.app = app
        mode = .Closed
        
        super.init( view, type: .Bottom )
        
        rect.height = 0
    }
    
    override func build()
    {
        rect.y = mmView.renderer.cHeight - rect.height

        if rect.height > 0 {
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 2,  fillColor : float4( 0.192, 0.573, 0.478, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
        }
    }
    
    func switchMode()
    {
        if animating { return }
        
        if mode == .Open {
            mmView.startAnimate( startValue: rect.height, endValue: 0, duration: 500, cb: { (value,finished) in
                self.rect.height = value
                if finished {
                    self.animating = false
                    self.mode = .Closed
                    self.app.topRegion!.timelineButton.removeState( .Checked )
                }
            } )
            animating = true
        } else if rect.height != 150 {
            
            mmView.startAnimate( startValue: rect.height, endValue: 150, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.mode = .Open
                }
                self.rect.height = value
            } )
            animating = true
        }
    }
}
