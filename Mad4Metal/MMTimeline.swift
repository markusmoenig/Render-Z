//
//  MMTimeline.swift
//  Shape-Z
//
//  Created by Markus Moenig on 28/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

/// A timeline key consisting of property values at the given frame
class MMTlKey : Codable
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
    var color           : float4? = nil

    var items           : [UUID: [Int:MMTlKey]] = [:]
}

/// Draws the timeline for the given sequence
class MMTimeline : MMWidget
{
    enum MMTimelineMode {
        case Unused, Scrubbing, ScrubbingKey, MovingBar, MoveLeftHandle, MoveRightHandle
    }
    
    var mode                    : MMTimelineMode
    
    var recordButton            : MMButtonWidget
    var playButton              : MMButtonWidget
    var deleteButton            : MMButtonWidget

    var isRecording             : Bool = false
    var isPlaying               : Bool = false

    var changedCB               : ((Int)->())?
    
    var currentSequence         : MMTlSequence? = nil
    var currentKey              : MMTlKey? = nil
    var keyScrubPos             : Int = 0
    var keyScrubUUID            : UUID = UUID()
    
    // --- Timeline attributes
    
    var tlRect                  : MMRect
    var barRect                 : MMRect
    var currentFrame            : Int

    var totalFrames             : Int = 100
    var pixelsPerFrame          : Float = 0
    var visibleFrames           : Float = 0
    
    var visibleStartFrame       : Float = 0
    var barStartX               : Float = 0
    
    var percentVisible          : Float = 0.8
    let barHandleWidth          : Float = 18
    
    var dragStart               : float2 = float2()
    var dragStartFrame          : Float = 0
    var dragStartValue          : Float = 0

    override init(_ view: MMView )
    {
        mode = .Unused
        changedCB = nil
        
        currentFrame = 0
        tlRect = MMRect()
        barRect = MMRect()
        pixelsPerFrame = 40
        
        view.registerIcon("timeline_recording")
        view.registerIcon("timeline_play")
        view.registerIcon("timeline_delete")

        var smallButtonSkin = MMSkinButton()
        smallButtonSkin.height = 30
        smallButtonSkin.fontScale = 0.4
        smallButtonSkin.margin.left = 8
        
        recordButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Rec")//iconName: "timeline_recording")
        playButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Play")//iconName: "timeline_play")
        deleteButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Del")//iconName: "timeline_delete")
        
        recordButton.textYOffset = -1
        playButton.textYOffset = -1
        deleteButton.textYOffset = -1

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
        
        deleteButton.clicked = { (event) in
            var dict = self.currentSequence!.items[self.keyScrubUUID]
            if let _ = dict!.removeValue(forKey: self.keyScrubPos) {
                self.currentKey = nil
                self.currentSequence!.items[self.keyScrubUUID] = dict
                self.changedCB?(self.currentFrame)
                self.mmView.update()
            }
        }
    }
    
    func activate()
    {
        mmView.registerWidgets(widgets: recordButton, playButton, deleteButton)
    }
    
    func deactivate()
    {
        mmView.deregisterWidgets(widgets: recordButton, playButton, deleteButton)
    }
    
    /// Returns the frame number for the given mouse position
    func frameAt(_ x: Float,_ y: Float) -> Int
    {
        var frame : Float = 0
        
        let frameX = max(x - tlRect.x, 0)
        frame = visibleStartFrame + frameX / pixelsPerFrame
        
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
    
    /// Returns the max frame for the given sequence
    func getMaxFrame(sequence: MMTlSequence) -> Int
    {
        var maxFrame : Int = 0
        
        for item in sequence.items
        {
            for(frame,_) in item.value {
                if frame > maxFrame {
                    maxFrame = frame
                }
            }
        }
        
        return maxFrame
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
                value = delta != 0 ? prevValue! + delta * simd_smoothstep( prevValue!, nextValue!, prevValue! + ( delta / frameDur ) * frameOffset ) : prevValue!;
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
            return
        }
        
        for(frame,key) in sequence.items[uuid]! {
            print( "Key at \(frame): \(key)" )
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if tlRect.contains(event.x, event.y) {
            
            currentKey = nil
            
            // --- Check if user clicked on a keyframe
            if let sequence = currentSequence {
                for(uuid,dict) in sequence.items {
                    for(frame,key) in dict {
                        let keyX = tlRect.x + (Float(frame)-visibleStartFrame) * pixelsPerFrame
                        if event.x >= keyX && event.x <= keyX + 12 {
                            currentKey = key
                            mode = .ScrubbingKey
                            keyScrubPos = frame
                            keyScrubUUID = uuid
                            mmView.mouseTrackWidget = self
                            return
                        }
                    }
                }
            }
            
            let frame = frameAt(event.x,event.y)
            if frame != currentFrame && frame >= 0 && frame < totalFrames {
                currentFrame = frame
                changedCB?(currentFrame)
                mmView.update()
            }
            mode = .Scrubbing
            mmView.mouseTrackWidget = self
        } else
        if barRect.contains(event.x, event.y)
        {
            if event.x - barRect.x < barHandleWidth {
                dragStartFrame = percentVisible
                dragStartValue = barStartX
                mode = .MoveLeftHandle
            } else
            if barRect.right() - barHandleWidth < event.x {
                dragStartFrame = Float(frameAt(event.x, event.y))
                dragStartValue = percentVisible
                mode = .MoveRightHandle
            } else {
                dragStartFrame = barStartX / pixelsPerFrame
                mode = .MovingBar
            }
            dragStart = float2(event.x, event.y)
            mmView.mouseTrackWidget = self
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mode = .Unused
        mmView.mouseTrackWidget = nil
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if mode == .Scrubbing {
            let frame = frameAt(event.x,event.y)
            if frame != currentFrame && frame >= 0 && frame < totalFrames {
                currentFrame = frame
                changedCB?(currentFrame)
                mmView.update()
            }
        } else
        if mode == .ScrubbingKey {
            let frame = frameAt(event.x,event.y)
            
            if frame != keyScrubPos {
                var dict = currentSequence!.items[keyScrubUUID]
                if let entry = dict!.removeValue(forKey: keyScrubPos) {
                    dict![frame] = entry
                    keyScrubPos = frame
                    changedCB?(currentFrame)
                    mmView.update()
                }
                currentSequence!.items[keyScrubUUID] = dict
            }
        } else
        if mode == .MovingBar {
            let diff : float2 = float2(event.x, event.y) - dragStart
            
            var frame : Float = (dragStartFrame + diff.x / pixelsPerFrame)
            
            frame = max(0, frame)
            barStartX = min(frame * pixelsPerFrame, tlRect.width - barRect.width)
            mmView.update()
        } else
        if mode == .MoveRightHandle {
            let diffPixels : float2 = float2(event.x, event.y) - dragStart
            let diff : Float = (diffPixels.x / pixelsPerFrame) / percentVisible
            let newPercent : Float = dragStartValue + diff / Float(totalFrames)

            percentVisible = max(0.1, min(1 - visibleStartFrame / Float(totalFrames), newPercent))
            mmView.update()
        } else
        if mode == .MoveLeftHandle {
            let diffPixels : float2 = dragStart - float2(event.x, event.y)
            let diff : Float = (diffPixels.x / pixelsPerFrame) / percentVisible
            let newPercent : Float = dragStartFrame + diff / Float(totalFrames)
            
            let newBarStartX : Float = dragStartValue - diffPixels.x
            
            if newBarStartX >= 0 {
                if newPercent > 0.1 {
                    barStartX = newBarStartX
                    percentVisible = newPercent//max(0.1, min(1 - visibleStartFrame / Float(totalFrames), newPercent))
                }
            } else {
                percentVisible = max(0.1, min(1 - visibleStartFrame / Float(totalFrames), newPercent))
                barStartX = 0
            }
            mmView.update()
        }
    }
    
    func draw(_ sequence: MMTlSequence, uuid: UUID)
    {
        currentSequence = sequence
        
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
        
        pixelsPerFrame = tlRect.width / (Float(totalFrames)*percentVisible)
        visibleFrames = (tlRect.width - 7 - 2) / pixelsPerFrame
        
        //m_totalBarLengthInPixel=((availableWidth * percent) / 100.0);

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
                mmView.drawBox.draw( x: x + 4.5, y: y + 1, width: Float(frame!.count * 10) + 5, height: 18, borderSize: 1.5, fillColor: float4(0.110, 0.110, 0.110, 1.000), borderColor : color)
                mmView.drawText.drawText(mmView.openSans, text: frame!, x: x + 7, y: y + 3, scale: 0.32)
                
            } else {
                mmView.drawBox.draw( x: x + 3, y: y + 1, width: 10, height: 18, fillColor : color)
            }
        }
        
        // --- Keys
        for(_,dict) in sequence.items {
            for(frame,key) in dict {
                let keyX = tlRect.x + (Float(frame) - visibleStartFrame) * pixelsPerFrame
                drawMarker( x: keyX, color : float4(0.137, 0.620, 0.784, 1.000), frame: key === currentKey ? String(frame) : nil )
            }
        }
        
        // --- Marker
        let markerX = tlRect.x + (Float(currentFrame) - visibleStartFrame) * pixelsPerFrame
        drawMarker( x: markerX, color : float4(0.675, 0.788, 0.184, 1.000), frame: currentKey === nil ? String(currentFrame) : nil )
        
        mmView.renderer.setClipRect()
        
        // --- Bar
        //let totalBarWidth : Float = tlRect.width
        
        barRect.x = tlRect.x + barStartX
        barRect.y = tlRect.y + 40
        barRect.width = ((Float(totalFrames) * percentVisible) * pixelsPerFrame) * percentVisible
        barRect.height = 15

        mmView.drawBox.draw( x: barRect.x, y: barRect.y - 1, width: barHandleWidth, height: 17, fillColor : float4(0.471, 0.471, 0.471, 1.000))

        mmView.drawBox.draw( x: barRect.x + barHandleWidth, y: barRect.y, width: barRect.width - 2 * barHandleWidth, height: 15, fillColor : float4(0.376, 0.376, 0.376, 1.000))
        
        mmView.drawBox.draw( x: barRect.x + barRect.width - barHandleWidth, y: barRect.y - 1, width: 18, height: 17, fillColor : float4(0.471, 0.471, 0.471, 1.000))

        // Buttons
        
        let buttonsY = tlRect.y + 65
        
        recordButton.rect.x = tlRect.x
        recordButton.rect.y = buttonsY
        recordButton.draw()
        
        playButton.rect.x = tlRect.x + 50
        playButton.rect.y = buttonsY
        playButton.draw()
        
        deleteButton.isDisabled = currentKey == nil
        deleteButton.rect.x = tlRect.x + 105
        deleteButton.rect.y = buttonsY
        deleteButton.draw()
    }
}
