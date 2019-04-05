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
class MMTlSequence : Codable, MMListWidgetItem
{
    var uuid            : UUID = UUID()
    var name            : String = "Idle"

    var items           : [UUID: [Int:MMTlKey]] = [:]
}

/// Draws the timeline for the given sequence
class MMTimeline : MMWidget
{
    enum MMTimelineMode {
        case Unused, Scrubbing
    }
    
    var mode                    : MMTimelineMode
    
    var recordButton            : MMButtonWidget
    var playButton              : MMButtonWidget

    var isRecording             : Bool = false
    var isPlaying               : Bool = false

    var changedCB               : ((Int)->())?
    
    // --- Timeline attributes
    
    var tlRect                  : MMRect
    var currentFrame            : Int

    var totalFrames             : Int = 100
    var pixelsPerFrame          : Float = 0
    var visibleFrames           : Float = 0
    
    var visibleStartFrame       : Float = 0
    var barStartX               : Float = 0
    
    override init(_ view: MMView )
    {
        mode = .Unused
        changedCB = nil
        
        currentFrame = 0
        tlRect = MMRect()
        pixelsPerFrame = 40
        
        view.registerIcon("timeline_recording")
        view.registerIcon("timeline_play")

        recordButton = MMButtonWidget(view, iconName: "timeline_recording")
        playButton = MMButtonWidget(view, iconName: "timeline_play")

        super.init(view)

        playButton.clicked = { (event) in
            
            if !self.isPlaying {
                
                self.isPlaying = true
                self.mmView.lockFramerate()

            } else {

                self.isPlaying = false
                self.mmView.unlockFramerate()
                self.playButton.removeState(.Checked)

            }
        }
        
        recordButton.clicked = { (event) in
            if self.isRecording {
                self.recordButton.removeState(.Checked)
                self.isRecording = false
            } else {
                self.isRecording = true
            }
        }
    }
    
    func activate()
    {
        mmView.registerWidgets(widgets: recordButton, playButton)
    }
    
    func deactivate()
    {
        mmView.deregisterWidgets(widgets: recordButton, playButton)
    }
    
    func draw(_ sequence: MMTlSequence, uuid: UUID)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y - 1, width: rect.width, height: rect.height, round: 4, borderSize: 0,  fillColor : float4(0.110, 0.110, 0.110, 1.000), borderColor: float4(repeating: 0) )// mmView.skin.Widget.borderColor )
        
        let skin = mmView.skin.TimelineWidget
        
        if isPlaying {
            currentFrame += 1
            if currentFrame >= totalFrames {
                currentFrame = 0
            }
            changedCB?(currentFrame)
        }
        
        // --- Initialization
        
        var x = rect.x + skin.margin.left
        let y = rect.y + skin.margin.top
        
        tlRect.x = x
        tlRect.y = y
        tlRect.width = rect.width - skin.margin.right - 8
        tlRect.height = 40
        
        mmView.drawBox.draw( x: x - 4, y: y - 4, width: tlRect.width + 8, height: tlRect.height, round: 4, borderSize: 2, fillColor: float4(0.110, 0.110, 0.110, 1.000), borderColor : float4(0.133, 0.133, 0.133, 1.000) )
        
        pixelsPerFrame =  tlRect.width / Float(totalFrames)
        visibleFrames = (tlRect.width - 7 - 2) / pixelsPerFrame
        
        let ratio = Float(totalFrames) / visibleFrames;
        let startFrame = barStartX / pixelsPerFrame * ratio
        visibleStartFrame = startFrame
        
        var frames : Int = Int(visibleStartFrame)
        
        var textEveryXFrames : Int = 10;
        if pixelsPerFrame < 2.4  { textEveryXFrames = 50 }
        if pixelsPerFrame < 1.0 { textEveryXFrames = 100 }
        if pixelsPerFrame < 0.4 { textEveryXFrames = 500 }
        if pixelsPerFrame < 0.1 { textEveryXFrames = 1000 }
        if pixelsPerFrame < 0.04 { textEveryXFrames = 10000 }
        
        //
        
        let right = rect.right() - skin.margin.right - 2
        
        let item = sequence.items[uuid]
//        print( "draw", uuid)
//        print( item )
        
        mmView.renderer.setClipRect( MMRect(tlRect.x, rect.y, tlRect.width, rect.height ) )
        
        while x < right {
            
            if ( frames % textEveryXFrames ) == 0 {
                // --- Long line with text
                
                mmView.drawBox.draw( x: x, y: y + 20, width: 2, height: 11, round: 0, fillColor : mmView.skin.Widget.borderColor )
                
                mmView.drawText.drawText(mmView.openSans, text: String(frames), x: x, y: y + 3, scale: 0.32)
            } else
            {
                if (frames % (textEveryXFrames/10*2)) == 0 {
                    // --- Short line with no text
                    
                    mmView.drawBox.draw( x: x, y: y + 25, width: 2, height: 6, round: 0, fillColor : mmView.skin.Widget.borderColor )
                }
            }
            
            x += pixelsPerFrame
            frames += 1
        }
        
        func drawMarker(x: Float, color: float4, frame: String? = nil)
        {
            let height : Float = 31
            mmView.drawBox.draw( x: x, y: y + 1, width: 5, height: height, fillColor : color)
            
            if frame != nil {
                mmView.drawBox.draw( x: x + 4.5, y: y + 0.5, width: Float(frame!.count * 10) + 5, height: 18, borderSize: 1.5, fillColor: float4(0.110, 0.110, 0.110, 1.000), borderColor : color)
                mmView.drawText.drawText(mmView.openSans, text: frame!, x: x + 7, y: y + 3, scale: 0.32)

            } else {
                mmView.drawBox.draw( x: x + 3, y: y + 1, width: 10, height: 18, fillColor : color)
            }
        }
        
        // --- Keys
        for(_,dict) in sequence.items {
            for(frame,_) in dict {
                let keyX = tlRect.x + Float(frame) * pixelsPerFrame
                drawMarker( x: keyX, color : float4(0.137, 0.620, 0.784, 1.000) )
            }
        }
        
        // --- Marker
        let markerX = tlRect.x + Float(currentFrame) * pixelsPerFrame
        drawMarker( x: markerX, color : float4(0.675, 0.788, 0.184, 1.000), frame: String(currentFrame) )
        
        mmView.renderer.setClipRect()
        
        // Buttons
        
        recordButton.rect.x = tlRect.x
        recordButton.rect.y = tlRect.y + 40
        recordButton.draw()
        
        playButton.rect.x = tlRect.x + 60
        playButton.rect.y = tlRect.y + 40
        playButton.draw()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if tlRect.contains(event.x, event.y) {
            let frame = frameAt(event.x,event.y)
            if frame != currentFrame && frame >= 0 && frame < totalFrames {
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
        if mode == .Scrubbing {
            let frame = frameAt(event.x,event.y)
            if frame != currentFrame && frame >= 0 && frame < totalFrames {
                currentFrame = frame
                changedCB?(currentFrame)
            }
        }
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
    func transformProperties(sequence: MMTlSequence, uuid: UUID, properties: [String:Float], frame: Int? = nil) -> [String:Float]
    {
        let item = sequence.items[uuid]
        if item == nil { return properties }

        let currentFrame = frame == nil ? self.currentFrame : frame!
        
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
