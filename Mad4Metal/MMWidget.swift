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

class MMKeyEvent
{
    var characters  : String?
    var keyCode     : UInt16
    
    init(_ characters: String?,_ keyCode: UInt16 )
    {
        self.characters = characters; self.keyCode = keyCode
    }
}

/// Widget Base Class
class MMWidget
{
    enum MMWidgetStates {
        case Hover, Clicked, Focus, Checked, Opened, Closed
    }
    
    var validStates : [MMWidgetStates]
    var states      : [MMWidgetStates]
    
    var name        : String! = "MMWidget"
    
    var mmView      : MMView
    var rect        : MMRect
    var id          : Int
    var clicked     : ((_ event: MMMouseEvent)->())?
    
    var isDisabled  : Bool = false
    var zoom        : Float = 1
    
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
    
    func update()
    {
        mmView.update()
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
    
    func mouseEnter(_ event:MMMouseEvent)
    {
    }
    
    func mouseLeave(_ event:MMMouseEvent)
    {
    }
    
    func keyDown(_ event: MMKeyEvent)
    {
    }
    
    func keyUp(_ event: MMKeyEvent)
    {
    }
    
    func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
    }
    
    func dragEnded(event:MMMouseEvent, dragSource:MMDragSource)
    {
    }
    
    func dragTerminated()
    {
    }
    
    func pinchGesture(_ scale: Float)
    {
    }

    func _clicked(_ event: MMMouseEvent)
    {
        if clicked != nil {
            clicked!(event)
        }
        mmView.update()
    }
    
    func addState(_ state: MMWidgetStates)
    {
        states.append( state )
        mmView.update()
    }
    
    func removeState(_ state: MMWidgetStates)
    {
        states.removeAll(where: { $0 == state })
        mmView.update()
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
    var texture     : MTLTexture?
    var customState : MTLRenderPipelineState?
    var textYOffset : Float = 0
    
    init( _ view: MMView, skinToUse: MMSkinButton? = nil, text: String? = nil, iconName: String? = nil, customState: MTLRenderPipelineState? = nil )
    {
        skin = skinToUse != nil ? skinToUse! : view.skin.ToolBarButton
        super.init(view)
        
        name = "MMButtonWidget"
        rect.width = skin.width
        rect.height = skin.height
        
        validStates = [.Checked]
        
        if text != nil {
            label = MMTextLabel(view, font: view.openSans, text: text!, scale: skin.fontScale )
            rect.width = label!.rect.width + skin.margin.width()
        }

        if iconName != nil {
            texture = view.icons[iconName!]
        }
        
        self.customState = customState
    }
    
    func setText(_ text: String)
    {
        if let label = self.label as? MMTextLabel {
            label.setText(text)
            rect.width = self.label!.rect.width + skin.margin.width()
        }
    }

    override func _clicked(_ event:MMMouseEvent)
    {
        if !isDisabled {
            addState( .Checked )
            if super.clicked != nil {
                super.clicked!(event)
            }
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        let fColor : float4
        if !isDisabled {
            if states.contains(.Hover) {
                fColor = skin.hoverColor
            } else if states.contains(.Checked) || states.contains(.Clicked) {
                fColor = skin.activeColor
            } else {
                fColor = skin.color
            }
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fColor, borderColor: skin.borderColor )
        }
        
        if label != nil {
            label!.rect.x = rect.x + (rect.width - label!.rect.width) / 2// skin.margin.left
            label!.rect.y = rect.y + textYOffset + (rect.height - label!.rect.height) / 2
            
            if label!.isDisabled != isDisabled {
                label!.isDisabled = isDisabled
            }
            label!.draw()
        }
        
        if texture != nil {
            let x = rect.x + (rect.width - Float(texture!.width)) / 2
            let y = rect.y + (rect.height - Float(texture!.height)) / 2
            mmView.drawTexture.draw(texture!, x: x, y: y)
        }
        
        if customState != nil {
            mmView.drawCustomState.draw(customState!, x: rect.x + skin.margin.left, y: rect.y + skin.margin.left, width: rect.width - skin.margin.width(), height: rect.height - skin.margin.height())
        }
    }
}

struct MMMenuItem
{
    var text        : String
    var cb          : ()->()
    
    var textBuffer  : MMTextBuffer?
    
    var custom      : Any? = nil
    
    init(text: String, cb: @escaping ()->() )
    {
        self.text = text
        self.cb = cb
        textBuffer = nil
        custom = nil
    }
}

/// Button widget class which handles all buttons
class MMMenuWidget : MMWidget
{
    enum MenuType {
        case BoxedMenu, LabelMenu
    }
    
    var menuType    : MenuType = .BoxedMenu
    
    var skin        : MMSkinMenuWidget
    var menuRect    : MMRect
 
    var items       : [MMMenuItem]
    
    var selIndex    : Int = -1
    var itemHeight  : Int = 0
    
    var firstClick  : Bool = false
    
    var textLabel   : MMTextLabel? = nil
    
    init( _ view: MMView, skinToUse: MMSkinMenuWidget? = nil, type: MenuType = .BoxedMenu, items: [MMMenuItem] = [])
    {
        skin = skinToUse != nil ? skinToUse! : view.skin.MenuWidget
        menuRect = MMRect( 0, 0, 0, 0)
        
        self.menuType = type
        self.items = items
        
        super.init(view)
        
        name = "MMMenuWidget"
        
        rect.width = skin.button.width
        rect.height = skin.button.height
        
        validStates = [.Checked]
        setItems(items)
    }
    
    /// Only for MenuType == LabelMenu
    func setText(_ text: String,_ scale: Float? = nil)
    {
        if textLabel == nil {
            textLabel = MMTextLabel(mmView, font: mmView.openSans, text: "")
        }
        
        if let label = textLabel {
            label.setText(text, scale: scale)
            
            rect.width = label.rect.width + 10
            rect.height = label.rect.height + 4
        }
    }

    /// Set the items for the menu, can be updated dynamically
    func setItems(_ items: [MMMenuItem])
    {
        self.items = items
        menuRect = MMRect( 0, 0, 0, 0)

        let r = MMRect()
        var maxHeight : Float = 0
        for item in self.items {
            mmView.openSans.getTextRect(text: item.text, scale: skin.fontScale, rectToUse: r)
            menuRect.width = max(menuRect.width, r.width)
            maxHeight = max(maxHeight, r.height)
        }
        
        itemHeight = Int(maxHeight) + 6
        menuRect.height = Float(items.count * itemHeight)// + Float(items.count-1) * skin.spacing
        
        menuRect.width += skin.margin.width()
        menuRect.height += skin.margin.height()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        #endif
        
        if !states.contains(.Opened) {
            
            addState( .Checked )
            addState( .Opened )
            selIndex = -1
            mmView.mouseTrackWidget = self
            firstClick = true
        
        } else {
            #if os(OSX)

            if states.contains(.Opened) && selIndex > -1 {
                removeState( .Opened )
                let item = items[selIndex]
                item.cb()
            }
            removeState( .Checked )
            removeState( .Opened )
            mmView.mouseTrackWidget = nil
            #endif
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        #if os(iOS)

        if states.contains(.Opened) && (firstClick == false || (selIndex > -1 && selIndex < items.count)) {

            if states.contains(.Opened) && selIndex > -1 && selIndex < items.count {
                removeState( .Opened )
                let item = items[selIndex]
                item.cb()
            }
            removeState( .Checked )
            removeState( .Opened )
            
            mmView.mouseTrackWidget = nil
        }
 
        firstClick = false
        #endif
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if states.contains(.Opened) {
            let oldSelIndex = selIndex
            selIndex = -1
            
            let x = event.x - rect.x - rect.width + menuRect.width
            let y : Int = Int(event.y - rect.y - rect.height - skin.margin.top)
            
            if  y >= 0 && Float(y) <= menuRect.height - skin.margin.height() && x >= 0 && x <= menuRect.width {
                 selIndex = y / Int(itemHeight)
                if oldSelIndex != selIndex {
                    mmView.update()
                }
            }
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        let fColor : vector_float4
        if states.contains(.Hover) {
            fColor = skin.button.hoverColor
        } else if states.contains(.Checked) || states.contains(.Clicked) {
            fColor = skin.button.activeColor
        } else {
            fColor = skin.button.color
        }
        
        if menuType == .BoxedMenu {
            mmView.drawBoxedMenu.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.button.round, borderSize: skin.button.borderSize, fillColor : fColor, borderColor: skin.button.borderColor )
        } else
        if menuType == .LabelMenu {
            if let label = textLabel {
                mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 4, borderSize: 0, fillColor : fColor)
                label.drawCentered(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
            }
        }
        
        if states.contains(.Opened) && items.count > 0 {
            
            let x = rect.x + rect.width - menuRect.width
            var y = rect.y + rect.height

            mmView.drawBox.draw( x: x, y: y, width: menuRect.width, height: menuRect.height, round: 0, borderSize: skin.borderSize, fillColor : float4( 0.5, 0.5, 0.5, 1), borderColor: skin.borderColor )

            y += skin.margin.top
            for (index,var item) in self.items.enumerated() {

                if index == selIndex {
                    /*
                    mmView.drawBox.draw( x: x + skin.borderSize, y: y - skin.spacing, width: menuRect.width - 2 * skin.borderSize - 1, height: Float(itemHeight) + 2 * skin.spacing, round: 0, borderSize: 0, fillColor : skin.selectionColor, borderColor: skin.borderColor )*/
                    
                    item.textBuffer = mmView.drawText.drawTextCenteredY(mmView.openSans, text: item.text, x: x + skin.margin.left, y: y, width: menuRect.width, height: Float(itemHeight), scale: skin.fontScale, color: float4(repeating: 1), textBuffer: item.textBuffer)
                } else {
                    item.textBuffer = mmView.drawText.drawTextCenteredY(mmView.openSans, text: item.text, x: x + skin.margin.left, y: y, width: menuRect.width, height: Float(itemHeight), scale: skin.fontScale, color: skin.textColor, textBuffer: item.textBuffer)
                }
                
                y += Float(itemHeight)
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
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawTexture.draw(texture!, x: rect.x, y: rect.y, zoom: zoom);
    }
}
