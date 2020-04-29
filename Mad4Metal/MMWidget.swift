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
    var pWidgetOffset   : SIMD2<Float>? {get set}
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
class MMWidget : Equatable
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
    
    func pinchGesture(_ scale: Float,_ firstTouch: Bool)
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

/// Generic Dialog class, derive from this

class MMDialog : MMWidget
{
    var title           : String = ""
    var titleLabel      : MMTextLabel!

    var cancelButton    : MMButtonWidget? = nil
    var okButton        : MMButtonWidget
    
    var widgets         : [MMWidget] = []
    var instantClose    : Bool = true

    init(_ view: MMView, title: String, cancelText: String, okText: String) {
        
        var smallButtonSkin = MMSkinButton()
        smallButtonSkin.height = view.skin.Button.height
        smallButtonSkin.round = view.skin.Button.round
        smallButtonSkin.fontScale = view.skin.Button.fontScale
        
        if !cancelText.isEmpty {
            cancelButton = MMButtonWidget( view, skinToUse: smallButtonSkin, text: cancelText )
            widgets.append(cancelButton!)
        }
        okButton = MMButtonWidget( view, skinToUse: smallButtonSkin, text: okText )

        widgets.append(okButton)

        super.init(view)
        name = "MMDialog"
        
        titleLabel = MMTextLabel(view, font: view.openSans, text: title, scale: 0.4)
        titleLabel.textYOffset = 1
        
        okButton.clicked = { (event) -> Void in
            if self.instantClose == true {
                self._ok()
            } else {
                self.ok()
            }
        }
        
        if cancelButton != nil {
            cancelButton!.clicked = { (event) -> Void in
                if self.instantClose {
                    self._cancel()
                } else {
                    self.cancel()
                }
            }
        }
    }
    
    func scrolledIn()
    {
    }
    
    func cleanup(finished:@escaping ()->())
    {
        finished()
    }
    
    func _cancel()
    {
        cleanup(finished: {
            DispatchQueue.main.async {
                self.mmView.widgets = self.mmView.widgetsBackup
                self.mmView.startAnimate( startValue: self.rect.y, endValue: self.rect.y - self.rect.height, duration: 500, cb: { (value,finished) in
                    self.mmView.dialogYPos = value
                    if finished {
                        if self.instantClose == true {
                            self.cancel()
                        }
                    }
                } )
            }
        } )
    }
    
    func _ok()
    {
        cleanup(finished: {
            DispatchQueue.main.async {
                self.mmView.widgets = self.mmView.widgetsBackup
                self.mmView.startAnimate( startValue: self.rect.y, endValue: self.rect.y - self.rect.height, duration: 500, cb: { (value,finished) in
                    self.mmView.dialogYPos = value
                    if finished {
                        if self.instantClose == true {
                            self.ok()
                        }
                    }
                } )
            }
        } )
    }
    
    func ok()
    {
    }
    
    func cancel()
    {
    }
    
    func doCancel()
    {
        
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
//        mmView.drawBox.draw( x: rect.x, y: rect.y - yOffset, width: rect.width, height: 200, round: 0, borderSize: 1, fillColor: float4(0.165, 0.169, 0.173, 1.000), borderColor: float4(0.267, 0.271, 0.275, 1.000) )
        
//        mmView.renderer.setClipRect(MMRect(rect.x, (rect.y + 19) - yOffset, rect.width, rect.height))
        mmView.drawBox.draw( x: rect.x, y: rect.y - yOffset, width: rect.width, height: rect.height, round: 40, borderSize: 2, fillColor: mmView.skin.Dialog.color, borderColor: mmView.skin.Dialog.borderColor )
//        mmView.renderer.setClipRect()

        titleLabel.drawCentered(x: rect.x, y: rect.y - yOffset, width: rect.width, height: 35)
        
        okButton.rect.x = rect.x + rect.width - okButton.rect.width - 20
        okButton.rect.y = rect.y + rect.height - 40 - yOffset
        okButton.draw()
        
        if let cancel = cancelButton {
            cancel.rect.x = okButton.rect.x - cancel.rect.width - 10
            cancel.rect.y = okButton.rect.y
            cancel.draw()
        }
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
    var iconZoom    : Float = 1
    var fixedWidth  : Float? = nil
    
    init( _ view: MMView, skinToUse: MMSkinButton? = nil, text: String? = nil, iconName: String? = nil, customState: MTLRenderPipelineState? = nil, fixedWidth: Float? = nil)
    {
        skin = skinToUse != nil ? skinToUse! : view.skin.ToolBarButton
        self.fixedWidth = fixedWidth
        super.init(view)
        
        name = "MMButtonWidget"
        rect.width = skin.width
        rect.height = skin.height
        
        validStates = [.Checked]
        
        if text != nil {
            label = MMTextLabel(view, font: view.openSans, text: text!, scale: skin.fontScale )
            rect.width = label!.rect.width + skin.margin.width()
            if let fWidth = fixedWidth {
                rect.width = fWidth
            }
        }

        if iconName != nil {
            texture = view.icons[iconName!]
            if let texture = texture {
                rect.width = Float(texture.width)
                rect.height = Float(texture.height)
            }
        }
        
        self.customState = customState
    }
    
    func setText(_ text: String)
    {
        if let label = self.label as? MMTextLabel {
            label.setText(text)
            rect.width = self.label!.rect.width + skin.margin.width()
        }
        
        if let fWidth = fixedWidth {
            rect.width = fWidth
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
        let fColor : SIMD4<Float>
        if !isDisabled {
            if states.contains(.Hover) {
                fColor = skin.hoverColor
            } else if states.contains(.Checked) || states.contains(.Clicked) {
                fColor = skin.activeColor
            } else {
                fColor = skin.color
            }
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fColor, borderColor: skin.borderColor )
        } else {
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : SIMD4<Float>(0,0,0,0), borderColor: SIMD4<Float>(skin.borderColor.x, skin.borderColor.y, skin.borderColor.z, 0.2))
        }
        
        if let textLabel = label as? MMTextLabel {
            label!.rect.x = rect.x + (rect.width - label!.rect.width) / 2// skin.margin.left
            //label!.rect.y = rect.y + textYOffset + (rect.height - label!.rect.height) / 2
            
            label!.rect.y = rect.y + textYOffset + (rect.height - (textLabel.lineHeight - (textLabel.lineHeight - label!.rect.height - 2))) / 2
            
            if label!.isDisabled != isDisabled {
                label!.isDisabled = isDisabled
            }
            label!.draw()
        }
        
        if texture != nil {
            let x = rect.x + (rect.width - Float(texture!.width) / iconZoom) / 2
            let y = rect.y + textYOffset + (rect.height - Float(texture!.height) / iconZoom) / 2
            mmView.drawTexture.draw(texture!, x: x, y: y, zoom: iconZoom, globalAlpha: isDisabled ? 0.3 : 1)
        }
        
        if customState != nil {
            mmView.drawCustomState.draw(customState!, x: rect.x + skin.margin.left / 1.5, y: rect.y + skin.margin.left / 1.5, width: rect.width - skin.margin.width()/1.5, height: rect.width - skin.margin.width()/1.5)
        }
    }
}

/// Opens / Closes views
class MMSideSliderWidget : MMWidget
{
    enum Mode {
        case Left, Right, Animating
    }
    
    var mode        : Mode
    var opacity     : Float = 1
    
    override init( _ view: MMView)
    {
        mode = .Left
        
        super.init(view)
        name = "MMSideSliderWidget"
        
        validStates = [.Checked]
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
    
    func setMode(_ mode : Mode )
    {
        if self.mode == .Animating && mode != .Animating {
            mmView.startAnimate( startValue: 0, endValue: 1, duration: 200, cb: { (value,finished) in
                self.opacity = value
                self.mmView.update()
            } )
        }
        self.mode = mode
        if mode == .Animating {
            opacity = 0
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawSphere.draw( x: rect.x, y: rect.y, radius: rect.width / 2, borderSize: 0, fillColor : mmView.skin.Widget.color)
        
        if mode == .Animating {
            return
        }
        
        let middleY : Float = rect.y + rect.height / 2
        let arrowUp : Float = 10
        
        var color = states.contains(.Hover) ? mmView.skin.ScrollButton.hoverColor : mmView.skin.ScrollButton.activeColor
        color.w = opacity
        
        var left = rect.x + rect.width / 2 + 10
        
        if mode == .Left {
            mmView.drawLine.draw(sx: left, sy: middleY, ex: left + arrowUp, ey: middleY + arrowUp, radius: 1.5, fillColor: color)
            mmView.drawLine.draw(sx: left, sy: middleY, ex: left + arrowUp, ey: middleY - arrowUp, radius: 1.5, fillColor: color)
        } else {
            left += 2
            mmView.drawLine.draw(sx: left + arrowUp, sy: middleY, ex: left, ey: middleY + arrowUp, radius: 1.5, fillColor: color)
            mmView.drawLine.draw(sx: left + arrowUp, sy: middleY, ex: left, ey: middleY - arrowUp, radius: 1.5, fillColor: color)
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
        case BoxedMenu, LabelMenu, Hidden
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
        
        if menuType != .Hidden {
            rect.width = skin.button.width
            rect.height = skin.button.height
        } else {
            rect.width = 0
            rect.height = 0
        }
        
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
        menuRect.height = Float(items.count * itemHeight) + Float(items.count-1) * skin.spacing
        
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
            if !rect.contains(event.x, event.y) {
                removeState( .Hover )
            }
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
        
        removeState( .Clicked )
        
        firstClick = false
        #endif
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if states.contains(.Opened) {
            let oldSelIndex = selIndex
            selIndex = -1
            
            var x = event.x - rect.x
            var y : Int = Int(event.y - rect.y - skin.margin.top)
            
            if menuType != .Hidden {
                x += -rect.width + menuRect.width
                y += Int(-rect.height)
            }
            
            if  y >= 0 && Float(y) <= menuRect.height - skin.margin.height() && x >= 0 && x <= menuRect.width {
                 selIndex = y / (Int(itemHeight) + Int(skin.spacing))
                if oldSelIndex != selIndex {
                    mmView.update()
                }
            }
        }
    }
    
    /// If the menu is of type hidden, activates the menu
    func activateHidden()
    {
        addState( .Checked )
        addState( .Opened )
        selIndex = -1
        mmView.mouseTrackWidget = self
        firstClick = false
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
            
            var x = rect.x
            var y = rect.y
            
            if menuType != .Hidden {
                x += rect.width - menuRect.width
                y += rect.height
            }

            mmView.drawBox.draw( x: x, y: y, width: menuRect.width, height: menuRect.height, round: skin.round, borderSize: skin.borderSize, fillColor : skin.color, borderColor: skin.borderColor )

            x += skin.margin.left//rect.width - menuRect.width
            y += skin.margin.top
            for (index,var item) in self.items.enumerated() {

                if index == selIndex {
                    item.textBuffer = mmView.drawText.drawTextCenteredY(mmView.openSans, text: item.text, x: x, y: y, width: menuRect.width, height: Float(itemHeight), scale: skin.fontScale, color: SIMD4<Float>(repeating: 1), textBuffer: item.textBuffer)
                } else {
                    item.textBuffer = mmView.drawText.drawTextCenteredY(mmView.openSans, text: item.text, x: x, y: y, width: menuRect.width, height: Float(itemHeight), scale: skin.fontScale, color: skin.textColor, textBuffer: item.textBuffer)
                }
                
                y += Float(itemHeight) + skin.spacing
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
        mmView.drawTexture.draw(texture!, x: rect.x, y: rect.y, zoom: zoom)
    }
}

/// Switch Button widget class which handles all buttons
class MMSwitchButtonWidget : MMWidget
{
    enum State {
        case Several, One
    }
    
    enum DotSize {
        case Small, Large
    }
    
    enum DotLocation {
        case All, Middle, UpperLeft
    }
    
    enum HoverMode {
        case Outside, Several, One
    }
    
    var state       : State = .Several
    var dotSize     : DotSize
    
    var hoverMode   : HoverMode = .Outside
    
    var skin        : MMSkinButton
    var label       : MMTextLabel!
    var text        : String!
    var textYOffset : Float = 0
    
    var space       : Float = 40
    
    var fingerIsDown: Bool = false
    
    init( _ view: MMView, skinToUse: MMSkinButton? = nil, text: String, dotSize : DotSize = .Small )
    {
        self.text = text
        self.dotSize = dotSize
        skin = skinToUse != nil ? skinToUse! : view.skin.ToolBarButton
        super.init(view)
        
        name = "MMSwitchButtonWidget"
        rect.height = skin.height
        
        validStates = [.Checked]
        
        label = MMTextLabel(view, font: view.openSans, text: text, scale: skin.fontScale )
        //label.color = float4(0.933, 0.937, 0.941, 1.000)
        rect.width = label.rect.width + space * 2 + skin.margin.width()
        adjustToState()
    }
    
    func setState(_ state: State)
    {
        self.state = state
        adjustToState()
        if super.clicked != nil {
            super.clicked!(MMMouseEvent(0,0))
        }
    }
    
    func adjustToState()
    {
        if state == .Several {
            label.setText(text + "s")
        } else {
            label.setText(text)
        }
    }
    
    func distanceToRRect(_ x: Float,_ y: Float,_ width: Float,_ height: Float, round: Float,_ mouseX: Float,_ mouseY: Float) -> Float
    {
        var uv : SIMD2<Float> = SIMD2<Float>(mouseX - x, mouseY - y)
        uv = uv - SIMD2<Float>(rect.width / 2, rect.height / 2)
        
        let d : SIMD2<Float> = simd_abs(uv) - SIMD2<Float>(width/2, height/2) + round / 2
        let dist : Float = simd_length(max(d,SIMD2<Float>(repeating: 0))) + min(max(d.x,d.y),0.0) - round / 2
        
        return dist
    }
    
    override func _clicked(_ event:MMMouseEvent)
    {
        if !isDisabled {
            
            if hoverMode == .Several {
                state = .Several
            } else
            if hoverMode == .One {
                state = .One
            }
            //state = state == .Several ? .One : .Several
            adjustToState()

            addState( .Checked )
            if super.clicked != nil {
                super.clicked!(event)
            }
        }
    }
    
    override func mouseUp(_ event:MMMouseEvent)
    {
        #if os(iOS)
        fingerIsDown = false
        #endif
    }
    
    override func mouseDown(_ event:MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        fingerIsDown = true
        #endif
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        func opIntersection( d1: Float, d2: Float ) -> Float { return max(d1,d2) }

        let oldHoverMode = hoverMode
        hoverMode = .Outside
        let dist = distanceToRRect(rect.x, rect.y, rect.width, rect.height, round: skin.round, event.x, event.y)
        if dist < 0 {
            if state == .Several {
                hoverMode = .Several
                let oneDist = distanceToRRect(rect.x - space / 2, rect.y, rect.width - space, rect.height, round: skin.round, event.x, event.y)
                let d = opIntersection(d1: oneDist, d2: dist)
                
                if d > 0 {
                    hoverMode = .One
                }
            } else {
                hoverMode = .One
                let severalDist = distanceToRRect(rect.x + space - space / 2, rect.y, rect.width - space, rect.height, round: skin.round, event.x, event.y)
                let d = opIntersection(d1: severalDist, d2: dist)

                if d > 0 {
                    hoverMode = .Several
                }
            }
        }

        if oldHoverMode != hoverMode {
            mmView.update()
        }
    }
    
    override func mouseLeave(_ event: MMMouseEvent) {
        let oldHoverMode = hoverMode
        hoverMode = .Outside
        
        if oldHoverMode != hoverMode {
            mmView.update()
        }
    }
    
    func drawDots(_ x: Float,_ y: Float, amount: Int, offset: Float, size: Float, dotLocation: DotLocation = .All)
    {
        if dotLocation == .All {
            for h in 0...amount-1 {
                for w in 0...amount-1 {
                    
                    let xOff : Float = x + Float(w) * offset
                    let yOff : Float = y + Float(h) * offset

                    mmView.drawSphere.draw( x: xOff, y: yOff, radius: size, borderSize: 0, fillColor : label.color)
                }
            }
        } else
        if dotLocation == .Middle {
            let middle : Int = Int((amount - 1) / 2)
            for h in 0...amount-1 {
                for w in 0...amount-1 {
                    
                    let xOff : Float = x + Float(w) * offset
                    let yOff : Float = y + Float(h) * offset
                    
                    if h == middle && w == middle {
                        mmView.drawSphere.draw( x: xOff, y: yOff, radius: size, borderSize: 0, fillColor : label.color)
                    } else {
                        mmView.drawSphere.draw( x: xOff, y: yOff, radius: size, borderSize: 0, fillColor : SIMD4<Float>(0.278, 0.282, 0.286, 1.000))
                    }
                }
            }
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        let checkedState : Bool = states.contains(.Checked)
        #if os(iOS)
        if checkedState == false && fingerIsDown == false {
            hoverMode = .Outside
        }
        #endif
        
        if state == .Several {
        
            var fillColor    : SIMD4<Float> = hoverMode == .One ? skin.hoverColor : SIMD4<Float>(0,0,0,0)
            var borderColor  : SIMD4<Float> = skin.borderColor
            
            if isDisabled {
                fillColor.w = mmView.skin.disabledAlpha
                borderColor.w = mmView.skin.disabledAlpha
            }
            
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fillColor, borderColor: borderColor)
            
            fillColor = checkedState ? (hoverMode == .Several ? skin.hoverColor : skin.activeColor) : (hoverMode == .Several ? skin.hoverColor : mmView.skin.ToolBar.color)
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width - space, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fillColor, borderColor: borderColor)
            
            label.rect.x = rect.x + space + 6
            label.rect.y = rect.y + textYOffset + (rect.height - label.rect.height) / 2
            
            if label.isDisabled != isDisabled {
                label.isDisabled = isDisabled
            }
            label.draw()
        } else {
            
            var fillColor    : SIMD4<Float> = hoverMode == .Several ? skin.hoverColor : SIMD4<Float>(0,0,0,0)
            var borderColor  : SIMD4<Float> = skin.borderColor
            
            if isDisabled {
                fillColor.w = mmView.skin.disabledAlpha
                borderColor.w = mmView.skin.disabledAlpha
            }
            
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fillColor, borderColor: borderColor)
            
            fillColor = checkedState ? (hoverMode == .One ? skin.hoverColor : skin.activeColor) : (hoverMode == .One ? skin.hoverColor : mmView.skin.ToolBar.color)
            mmView.drawBox.draw( x: rect.x + space, y: rect.y, width: rect.width - space, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fillColor, borderColor: borderColor)
            
            label.rect.x = rect.x + space + 26
            label.rect.y = rect.y + textYOffset + (rect.height - label.rect.height) / 2
            
            if label.isDisabled != isDisabled {
                label.isDisabled = isDisabled
            }
            label.draw()
        }
        
        if dotSize == .Small {
            drawDots(rect.x + 15, rect.y + 10, amount: 3, offset: 7, size: 2.5)
            drawDots(rect.x + rect.width - space + 8, rect.y + 10, amount: 3, offset: 7, size: 2.5, dotLocation: .Middle)
        } else {
            drawDots(rect.x + 15, rect.y + 11, amount: 2, offset: 11, size: 3.5)
            drawDots(rect.x + rect.width - space + 8, rect.y + 11, amount: 2, offset: 11, size: 3.5, dotLocation: .Middle)
        }
    }
}


/// Switch icon widget class
class MMSwitchIconWidget : MMWidget
{
    enum State {
        case Left, Right
    }
    
    enum DotSize {
        case Small, Large
    }
    
    enum DotLocation {
        case All, Middle, UpperLeft
    }
    
    enum HoverMode {
        case Outside, Left, Right
    }
    
    var state       : State = .Left
    var dotSize     : DotSize = .Small
    
    var hoverMode   : HoverMode = .Outside
    
    var skin        : MMSkinButton
    var text        : String!
    var textYOffset : Float = 0
    
    var space       : Float = 70
    
    var fingerIsDown: Bool = false
    
    var leftIconOnTexture   : MTLTexture?
    var leftIconOffTexture  : MTLTexture?

    var rightIconOnTexture  : MTLTexture?
    var rightIconOffTexture : MTLTexture?
    
    var onColor             = SIMD4<Float>(1,1,1,1)
    var offColor            = SIMD4<Float>(0,0,0,1)
    
    var iconZoom            : Float = 2

    init( _ view: MMView, skinToUse: MMSkinButton? = nil, leftIconName: String, rightIconName: String )
    {
        skin = skinToUse != nil ? skinToUse! : view.skin.ToolBarButton
        super.init(view)
        
        name = "MMSwitchIconWidget"
        rect.height = skin.height
        
        leftIconOnTexture = view.icons[leftIconName + "_on"]
        leftIconOffTexture = view.icons[leftIconName + "_off"]
        rightIconOnTexture = view.icons[rightIconName + "_on"]
        rightIconOffTexture = view.icons[rightIconName + "_off"]
        
        validStates = [.Checked]
        
        //label.color = float4(0.933, 0.937, 0.941, 1.000)
        rect.width = 130
        adjustToState()
    }
    
    func setState(_ state: State)
    {
        self.state = state
        adjustToState()
        if super.clicked != nil {
            super.clicked!(MMMouseEvent(0,0))
        }
    }
    
    func adjustToState()
    {
    }
    
    func distanceToRRect(_ x: Float,_ y: Float,_ width: Float,_ height: Float, round: Float,_ mouseX: Float,_ mouseY: Float) -> Float
    {
        var uv : SIMD2<Float> = SIMD2<Float>(mouseX - x, mouseY - y)
        uv = uv - SIMD2<Float>(rect.width / 2, rect.height / 2)
        
        let d : SIMD2<Float> = simd_abs(uv) - SIMD2<Float>(width/2, height/2) + round / 2
        let dist : Float = simd_length(max(d,SIMD2<Float>(repeating: 0))) + min(max(d.x,d.y),0.0) - round / 2
        
        return dist
    }
    
    override func _clicked(_ event:MMMouseEvent)
    {
        if !isDisabled {
            
            if hoverMode == .Left {
                state = .Left
            } else
            if hoverMode == .Right {
                state = .Right
            }
            //state = state == .Several ? .One : .Several
            adjustToState()

            addState( .Checked )
            if super.clicked != nil {
                super.clicked!(event)
            }
        }
    }
    
    override func mouseUp(_ event:MMMouseEvent)
    {
        #if os(iOS)
        fingerIsDown = false
        #endif
    }
    
    override func mouseDown(_ event:MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        fingerIsDown = true
        #endif
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        func opIntersection( d1: Float, d2: Float ) -> Float { return max(d1,d2) }

        let oldHoverMode = hoverMode
        hoverMode = .Outside
        let dist = distanceToRRect(rect.x, rect.y, rect.width, rect.height, round: skin.round, event.x, event.y)
        if dist < 0 {
            if state == .Left {
                hoverMode = .Left
                let oneDist = distanceToRRect(rect.x - space / 2, rect.y, rect.width - space, rect.height, round: skin.round, event.x, event.y)
                let d = opIntersection(d1: oneDist, d2: dist)
                
                if d > 0 {
                    hoverMode = .Right
                }
            } else {
                hoverMode = .Right
                let severalDist = distanceToRRect(rect.x + space - space / 2, rect.y, rect.width - space, rect.height, round: skin.round, event.x, event.y)
                let d = opIntersection(d1: severalDist, d2: dist)

                if d > 0 {
                    hoverMode = .Left
                }
            }
        }

        if oldHoverMode != hoverMode {
            mmView.update()
        }
    }
    
    override func mouseLeave(_ event: MMMouseEvent) {
        let oldHoverMode = hoverMode
        hoverMode = .Outside
        
        if oldHoverMode != hoverMode {
            mmView.update()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        let checkedState : Bool = states.contains(.Checked)
        #if os(iOS)
        if checkedState == false && fingerIsDown == false {
            hoverMode = .Outside
        }
        #endif
        
        if state == .Left {
        
            var fillColor    : SIMD4<Float> = offColor
            var borderColor  : SIMD4<Float> = fillColor//hoverMode == .Right ? skin.hoverColor : fillColor
            
            if isDisabled {
                fillColor.w = mmView.skin.disabledAlpha
                borderColor.w = mmView.skin.disabledAlpha
            }
            
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fillColor, borderColor: borderColor)
            
            fillColor = onColor//checkedState ? (hoverMode == .Left ? skin.hoverColor : onColor) : (hoverMode == .Left ? skin.hoverColor : offColor)
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width - space + 10, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fillColor, borderColor: borderColor)
            
            mmView.drawTexture.draw(leftIconOnTexture!, x: rect.x + 23, y: rect.y + 8, zoom: iconZoom)
            mmView.drawTexture.draw(rightIconOffTexture!, x: rect.x + space + 16, y: rect.y + 8, zoom: iconZoom)
        } else {
            
            var fillColor    : SIMD4<Float> = offColor
            var borderColor  : SIMD4<Float> = fillColor//hoverMode == .Left ? skin.hoverColor : offColor
            
            if isDisabled {
                fillColor.w = mmView.skin.disabledAlpha
                borderColor.w = mmView.skin.disabledAlpha
            }
            
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fillColor, borderColor: borderColor)
            
            fillColor = onColor//checkedState ? (hoverMode == .Right ? skin.hoverColor : skin.activeColor) : (hoverMode == .Right ? skin.hoverColor : mmView.skin.ToolBar.color)
            mmView.drawBox.draw( x: rect.x + space - 10, y: rect.y, width: rect.width - space + 10, height: rect.height, round: skin.round, borderSize: skin.borderSize, fillColor : fillColor, borderColor: borderColor)
            
            mmView.drawTexture.draw(leftIconOffTexture!, x: rect.x + 23, y: rect.y + 8, zoom: iconZoom)
            mmView.drawTexture.draw(rightIconOnTexture!, x: rect.x + space + 16, y: rect.y + 8, zoom: iconZoom)
        }
    }
}
