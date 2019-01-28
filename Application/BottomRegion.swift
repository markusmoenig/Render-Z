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
    
    let timeline        : MMTimeline
    
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    var mode            : BottomRegionMode
    
    init( _ view: MMView, app: App )
    {
        self.app = app
        mode = .Open
        timeline = MMTimeline(view)
        
        super.init( view, type: .Bottom )
        
        rect.height = 100
        self.app.topRegion!.timelineButton.addState( .Checked )
        
        mmView.registerWidget(timeline, region: self)
    }
    
    override func build()
    {
        rect.y = mmView.renderer.cHeight - rect.height

        if rect.height > 0 {
            
            // Timeline area
            
            timeline.rect.copy( rect )
            timeline.rect.width -= app.rightRegion!.rect.width
            timeline.draw(app.layerManager.getCurrentLayer().sequence)
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
        } else if rect.height != 100 {
            
            mmView.startAnimate( startValue: rect.height, endValue: 100, duration: 500, cb: { (value,finished) in
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
