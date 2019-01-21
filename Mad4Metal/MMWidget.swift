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

    init( _ view: MMView, skinToUse: MMSkinButton? = nil, text: String? = nil )
    {
        skin = skinToUse != nil ? skinToUse! : view.skin.ToolBarButton
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
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fColor, borderColor: skin.borderColor )
        
        if label != nil {
            label!.rect.x = rect.x + skin.margin.left
            label!.rect.y = rect.y + (skin.height - label!.rect.height) / 2
            label!.draw()
        }
    }
}

struct MMMenuItem
{
    var text        : String
    var cb          : ()->()
    
    var textBuffer  : MMTextBuffer?
    var rect        : MMRect
    
    init(text: String, cb: @escaping ()->() )
    {
        self.text = text
        self.cb = cb
        textBuffer = nil
        rect = MMRect()
    }
}

/// Button widget class which handles all buttons
class MMMenuWidget : MMWidget
{
    var skin        : MMSkinMenuWidget
    var menuRect    : MMRect
    
    var items       : [MMMenuItem]
    var selIndex    : Int = -1
    
    init( _ view: MMView, skinToUse: MMSkinMenuWidget? = nil, items: [MMMenuItem])
    {
        skin = skinToUse != nil ? skinToUse! : view.skin.MenuWidget
        menuRect = MMRect( 0, 0, 0, 0)
        self.items = items

        super.init(view)
        
        name = "MMMenuWidget"
        rect.width = skin.button.width
        rect.height = skin.button.height
        
        validStates = [.Checked]
        
        var y : Float = 0//skin.margin.top + skin.borderSize
        
        let r = MMRect()
        for item in self.items {
            item.rect.copy( view.openSans!.getTextRect(text: item.text, scale: skin.fontScale, rectToUse: r) )
            
            item.rect.y = y
            
            menuRect.width = max(menuRect.width, r.width)
            menuRect.height += r.height
            
            y += item.rect.height
        }
        
        menuRect.width += skin.margin.width() + skin.borderSize * 2
        menuRect.height += skin.margin.height() + skin.borderSize * 2
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        addState( .Checked )
        addState( .Opened )
        selIndex = -1
        mmView.mouseTrackWidget = self
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        removeState( .Checked )
        removeState( .Opened )
        mmView.mouseTrackWidget = nil
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if states.contains(.Opened) {
            let y = event.y - rect.y - rect.height

            selIndex = -1
            for (index, item) in items.enumerated() {
                if item.rect.y <= y && item.rect.y + item.rect.height >= y {
                    selIndex = index
                }
            }
            print( y, selIndex )
        }
    }
    
    override func draw()
    {
        let fColor : vector_float4
        if states.contains(.Hover) {
            fColor = skin.button.hoverColor
        } else if states.contains(.Checked) || states.contains(.Clicked) {
            fColor = skin.button.activeColor
        } else {
            fColor = skin.button.color
        }
        mmView.drawBoxedMenu.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.button.round, borderSize: skin.button.borderSize, fillColor : fColor, borderColor: skin.button.borderColor )
        
        if states.contains(.Opened) {
            
            let boxX = rect.x + rect.width - menuRect.width
            let boxY = rect.y + rect.height

            mmView.drawBox.draw( x: boxX, y: boxY, width: menuRect.width, height: menuRect.height, round: 0, borderSize: skin.borderSize, fillColor : float4( 0.5, 0.5, 0.5, 1), borderColor: float4( 1, 1, 1, 1 ) )

            for (index,var item) in self.items.enumerated() {

                if index == selIndex {
                    mmView.drawBox.draw( x: boxX + item.rect.x, y: boxY + item.rect.y, width: menuRect.width, height: menuRect.height, round: 0, borderSize: 0, fillColor : mmView.skin.Widget.selectionColor, borderColor: float4( 1, 1, 1, 1 ) )
                }
                item.textBuffer = mmView.drawText.drawText(mmView.openSans!, text: item.text, x: boxX + item.rect.x, y: boxY + item.rect.y, scale: skin.fontScale, color: skin.color, textBuffer: item.textBuffer)
            }
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
    
    func setTexture(_ texture: MTLTexture?)
    {
        self.texture = texture
        rect.width = Float(texture!.width)
        rect.height = Float(texture!.height)
    }
    
    override func draw()
    {
        mmView.drawTexture.draw( texture!, x: rect.x, y: rect.y );
    }
}
