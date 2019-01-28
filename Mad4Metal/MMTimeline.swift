//
//  MMTimeline.swift
//  Shape-Z
//
//  Created by Markus Moenig on 28/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

/// A timeline key consisting property values at the given frame
struct MMTlKey : Codable
{
    /// The animated value of the given object, i.e. it's properties
    var values          : [String: Float] = [:]
    
    /// Sequences which get started by this item
    var sequences       : [UUID] = []
    
    /// Optional properties which define the behavior of this key
    var properties      : [String: Float] = [:]
}

/// A sequence defines a set of keys for objects
class MMTlSequence : Codable
{
    var uuid            : UUID = UUID()
    
    var items           : [UUID: [Int:MMTlKey]] = [:]
}

/// Draws the timeline for the given sequence
class MMTimeline : MMWidget
{
    enum MMTimelineMode {
        case Unused, Scrubbing
    }
    
    var mode                    : MMTimelineMode
    var currentFrame            : Int
    
    var tlRect                  : MMRect
    var pixelsPerFrame          : Float

    override init(_ view: MMView )
    {
        mode = .Unused
        currentFrame = 0
        tlRect = MMRect()
        pixelsPerFrame = 40
        
        super.init(view)
    }
    
    func draw(_ sequence: MMTlSequence)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y - 1, width: rect.width, height: rect.height, round: 4, borderSize: 0,  fillColor : mmView.skin.Widget.color, borderColor: float4(0) )// mmView.skin.Widget.borderColor )
        
        let skin = mmView.skin.TimelineWidget
        
        var x = rect.x + skin.margin.left
        let y = rect.y + skin.margin.top + 20
        
        tlRect.x = x
        tlRect.y = y
        tlRect.width = rect.width - skin.margin.right
        tlRect.height = 20

        let right = rect.right() - skin.margin.right
        
        while x < right {
            mmView.drawBox.draw( x: x, y: y, width: 1.5, height: 20, round: 0, fillColor : mmView.skin.Widget.borderColor )
            x += pixelsPerFrame
        }
        
        let cFrameX = tlRect.x + Float(currentFrame) * pixelsPerFrame
        if tlRect.contains(cFrameX, tlRect.y) {
            
            mmView.drawBox.draw( x: cFrameX, y: y, width: pixelsPerFrame, height: 20, round: 0, fillColor : float4(0.675, 0.788, 0.184, 1.000) )

        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if tlRect.contains(event.x, event.y) {
            currentFrame = frameAt(event.x,event.y)
            mode = .Scrubbing
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mode = .Unused
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
    }
    
    func frameAt(_ x: Float,_ y: Float) -> Int
    {
        var frame : Float = 0
        
        let frameX = x - tlRect.x
        frame = frameX / pixelsPerFrame
        
        print( Int(frame) )
        
        return Int(frame)
    }
}
