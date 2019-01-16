//
//  MMWidget.swift
//  Framework
//
//  Created by Markus Moenig on 05.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

protocol MMDragSource
{
    var id              : String {get set}
    var sourceWidget    : MMWidget? {get set}
    var previewWidget   : MMWidget? {get set}
    var pWidgetOffset   : float2? {get set}
}

class MMMouseEvent
{
    // Position
    var x           : Float
    var y           : Float
    
    // Deltas for mouseScrolled
    var deltaX      : Float?
    var deltaY      : Float?
    var deltaZ      : Float?

    init(_ x: Float,_ y: Float )
    {
        self.x = x; self.y = y
    }
}

/// Widget Base Class
class MMWidget
{
    enum MMWidgetStates {
        case Hover, Clicked, Focus, Disabled, Checked, Opened, Closed
    }
    
    var validStates : [MMWidgetStates]
    var states      : [MMWidgetStates]
    
    var name        : String! = "MMWidget"
    
    var mmView      : MMView
    var rect        : MMRect
    var id          : Int
    var clickedCB   : ((_ x: Float,_ y: Float)->())?
    
    var dropTargets : [String]
    
    init(_ view: MMView)
    {
        validStates = [.Hover,.Clicked,.Focus]
        states = []
        
        dropTargets = []
        
        mmView = view
        rect = MMRect()
        id = view.getWidgetId()
    }
    
    func mouseDown(_ event: MMMouseEvent)
    {
    }
    
    func mouseUp(_ event: MMMouseEvent)
    {
    }
    
    func mouseMoved(_ event: MMMouseEvent)
    {
    }
    
    func mouseScrolled(_ event: MMMouseEvent)
    {
    }
    
    func draw()
    {
    }
    
    func dragEnded(event:MMMouseEvent, dragSource:MMDragSource)
    {
    }
    
    func dragTerminated()
    {
    }
    
    func clicked(_ x: Float,_ y: Float)
    {
        if clickedCB != nil {
            clickedCB!(x,y)
        }
    }
    
    func addState(_ state: MMWidgetStates)
    {
        states.append( state )
    }
    
    func removeState(_ state: MMWidgetStates)
    {
        states.removeAll(where: { $0 == state })
    }
    
    static func == (lhs: MMWidget, rhs: MMWidget) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Button widget class which handles all buttons
class MMButtonWidget : MMWidget
{
    var skin        : MMSkinButton
    var label       : MMLabel?

    init( _ view: MMView, skinToUse: MMSkinButton, text: String? = nil )
    {
        skin = skinToUse
        super.init(view)
        
        name = "MMButtonWidget"
        rect.width = skin.width
        rect.height = skin.height
        
        validStates = [.Checked]
        
        if text != nil {
            label = MMTextLabel(view, font: view.openSans!, text: text!, scale: skin.fontScale )
            rect.width = label!.rect.width + skin.margin.width()
        }
    }
    
    override func clicked(_ x: Float,_ y: Float)
    {
        super.clicked(x,y)
        addState( .Checked )
    }
    
    override func draw()
    {
        let fColor : vector_float4
        if states.contains(.Hover) {
            fColor = skin.hoverColor
        } else if states.contains(.Checked) || states.contains(.Clicked) {
            fColor = skin.activeColor
        } else {
            fColor = skin.color
        }
        mmView.drawCube.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fColor, borderColor: skin.borderColor )
        
        if label != nil {
            label!.rect.x = rect.x + skin.margin.left
            label!.rect.y = rect.y + (skin.height - label!.rect.height/2) / 2
            label!.draw()
        }
    }
}

/// Texture widget
class MMTextureWidget : MMWidget
{
    var texture : MTLTexture?

    init( _ view: MMView, name: String )
    {
        super.init(view)
        
        texture = mmView.loadTexture( name )
        self.name = "MMTextureWidget"
    }
    
    init( _ view: MMView, texture: MTLTexture? )
    {
        super.init(view)
        self.texture = texture
        rect.width = Float(texture!.width)
        rect.height = Float(texture!.height)
    }
    
    override func draw()
    {
        mmView.drawTexture.draw( texture!, x: rect.x, y: rect.y );
    }
}
