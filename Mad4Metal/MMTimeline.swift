//
//  MMTimeline.swift
//  Shape-Z
//
//  Created by Markus Moenig on 28/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

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
    
    var recordButton            : MMButtonWidget
    
    var isRecording             : Bool = false
    
    var changedCB               : ((Int)->())?

    override init(_ view: MMView )
    {
        mode = .Unused
        changedCB = nil
        
        currentFrame = 0
        tlRect = MMRect()
        pixelsPerFrame = 40
        
        recordButton = MMButtonWidget(view, text: "Rec")

        view.registerWidget(recordButton)
        
        super.init(view)
        
        recordButton.clicked = { (event) in
            if self.isRecording {
                self.recordButton.removeState(.Checked)
                self.isRecording = false
            } else {
                self.isRecording = true
            }
        }
    }
    
    func draw(_ sequence: MMTlSequence, uuid: UUID)
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
        
        let item = sequence.items[uuid]
//        print( "draw", uuid)
//        print( item )
        
        while x < right {
            mmView.drawBox.draw( x: x, y: y, width: 1.5, height: 20, round: 0, fillColor : mmView.skin.Widget.borderColor )
            
            if item != nil {
                let frame = frameAt(x, y)
                let key = item![frame]
                
                if key != nil {
//                    print( "here" )
                    mmView.drawBox.draw( x: x, y: y, width: 5.5, height: 20, round: 0, fillColor : float4(0.137, 0.620, 0.784, 1.000) )
                }
            }
        
            
            x += pixelsPerFrame
        }
        
        let cFrameX = tlRect.x + Float(currentFrame) * pixelsPerFrame
        if tlRect.contains(cFrameX, tlRect.y) {
            
            mmView.drawBox.draw( x: cFrameX, y: y, width: pixelsPerFrame, height: 20, round: 0, fillColor : float4(0.675, 0.788, 0.184, 1.000) )

        }
        
        // Buttons
        
        recordButton.rect.x = tlRect.x
        recordButton.rect.y = tlRect.y + 26

//        recordButton.rect.width = 30
//        recordButton.rect.height = 30
        recordButton.draw()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if tlRect.contains(event.x, event.y) {
            let frame = frameAt(event.x,event.y)
            if frame != currentFrame {
                currentFrame = frame
                changedCB?(currentFrame)
            }
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
    
    /// Returns the frame number for the given mouse position
    func frameAt(_ x: Float,_ y: Float) -> Int
    {
        var frame : Float = 0
        
        let frameX = x - tlRect.x
        frame = frameX / pixelsPerFrame
        
//        print( Int(frame) )
        
        return Int(frame)
    }
    
    /// At the given properties to a key located at the currentframe for the object / shape identified by the uuid
    func addKeyProperties(sequence: MMTlSequence, uuid: UUID, properties: [String:Float])
    {
        var itemDict = sequence.items[uuid]
        
        if itemDict == nil {
            // If no entry yet for the given uuid create one
            itemDict = [:]
            sequence.items[uuid] = itemDict
        }
        
        // Test if there is a key already at the current frame position
        var key : MMTlKey? = itemDict![currentFrame]
        if key == nil {
            key = MMTlKey()
            sequence.items[uuid]![currentFrame] = key
        }
        
        for(name, value) in properties {
            sequence.items[uuid]![currentFrame]!.values[name] = value
        }
        
//        printSequence(sequence: sequence, uuid: uuid)
    }
    
    /// Transform the properties of the given object based on the keys in the sequence (using the current frame position of the timeline)
    func transformProperties(sequence: MMTlSequence, uuid: UUID, properties: [String:Float]) -> [String:Float]
    {
        let item = sequence.items[uuid]
        if item == nil { return properties }

        var props : [String:Float] = [:]

        func calcValueFor(_ name:String) -> Float
        {
            var value : Float = 0
            
            var prevFrame : Int = -1
            var prevValue : Float? = nil
            var nextFrame : Int = 1000000
            var nextValue : Float? = nil
            
            for(frame,key) in item! {
                if frame < currentFrame && frame > prevFrame {
                    if let value = key.values[name] {
                        prevFrame = frame
                        prevValue = value
                    }
                } else
                if frame == currentFrame {
                    if let value = key.values[name] {
                        prevFrame = frame
                        prevValue = value
                        nextFrame = frame
                        nextValue = value
                    }
                    break
                } else
                if frame > currentFrame && frame < nextFrame {
                    if let value = key.values[name] {
                        nextFrame = frame
                        nextValue = value
                    }
                }
            }
            
//            print( name, prevFrame, prevValue, nextFrame, nextValue)
            
            if prevValue != nil && nextValue == nil {
                value = prevValue!
            } else
            if prevValue == nil && nextValue == nil {
                value = properties[name]!
            } else
            if prevValue != nil && nextValue != nil && prevValue! == nextValue! {
                value = prevValue!
            } else {
                prevFrame = prevValue == nil ? 0 : prevFrame
                prevValue = prevValue == nil ? properties[name]! : prevValue
                
                let frameDur : Float = Float(nextFrame - prevFrame)
                let frameOffset : Float = Float(currentFrame - prevFrame)
                
                let delta = nextValue! - prevValue!
                
//                value = prevValue! + ( delta / frameDur ) * frameOffset
                value = delta != 0 ? prevValue! + delta * simd_smoothstep( prevValue!, nextValue!, prevValue! + ( delta / frameDur ) * frameOffset ) : 0;
            }
            
            return value
        }
        
        for(name,_) in properties {
            props[name] = calcValueFor(name)
        }
        
        return props
    }
    
    /// Print the given squence to the console
    func printSequence(sequence: MMTlSequence, uuid: UUID)
    {
        if sequence.items[uuid] == nil {
            print( "No entry for \(uuid) in sequence" )
        }
        
        for(frame,key) in sequence.items[uuid]! {
            print( "Key at \(frame): \(key)" )
        }
    }
}
