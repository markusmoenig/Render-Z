//
//  NodeUI.swift
//  Shape-Z
//
//  Created by Markus Moenig on 27.02.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class NodeUI
{
    enum Brand {
        case Separator, DropDown, KeyDown, Number, Text
    }
    
    enum Role {
        case None, MasterPicker, AnimationPicker, ValueVariablePicker, DirectionVariablePicker, LayerAreaPicker
    }
    
    var mmView      : MMView!
    
    var brand       : Brand
    var role        : Role = .None
    
    var node        : Node
    var variable    : String
    var title       : String
    
    var rect        : MMRect = MMRect()
    var titleLabel  : MMTextLabel? = nil
    
    var supportsTitleHover: Bool = false
    var titleHover  : Bool = false
    
    var isDisabled  : Bool = false
    var disabledAlpha: Float = 0.2
    
    var linkedTo    : NodeUI? = nil

    // --- Statics
    
    static let fontName = "Open Sans"
    static let fontScale : Float = 0.4
    static let titleMargin : MMMargin = MMMargin(0, 5, 5, 5)
    static let titleSpacing : Float = 5

    init(_ node : Node, brand: Brand, variable: String, title: String)
    {
        self.node = node
        self.brand = brand
        self.variable = variable
        self.title = title
    }
    
    func titleClicked()
    {
    }
    
    func internal_changed()
    {
    }
    
    func keyDown(_ event: MMKeyEvent)
    {
    }
    
    func keyUp(_ event: MMKeyEvent)
    {
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
    
    func mouseLeave()
    {
    }
    
    func calcSize(mmView: MMView)
    {
        self.mmView = mmView
        rect.width = 100
        rect.height = 20
    }
    
    // Update from properties
    func update()
    {
    }
    
    func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
    }
    
    /// Adjust color to disabled if necessary
    func adjustColor(_ color: float4) -> float4 {
        return isDisabled ? float4(color.x, color.y, color.z, disabledAlpha) : color
    }
}

/// Separator Class
class NodeUISeparator : NodeUI
{
    var defaultValue: Float
    
    init(_ node: Node, variable: String, title: String, value: Float = 5)
    {
        self.defaultValue = value
        super.init(node, brand: .Separator, variable: variable, title: title)
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: "", scale: NodeUI.fontScale)
        
        rect.width = 0
        rect.height = defaultValue
    }
}

/// Drop down NodeUI class
class NodeUIDropDown : NodeUI
{
    var items       : [String]
    var index       : Float
    var open        : Bool = false
    var defaultValue: Float
    
    var itemHeight  : Float = 0
    var minItemWidth: Float = 85
    
    init(_ node: Node, variable: String, title: String, items: [String], index: Float = 0)
    {
        self.items = items
        self.index = index
        self.defaultValue = index
        
        if node.properties[variable] == nil {
            node.properties[variable] = index
        } else {
            self.index = node.properties[variable]!
        }
        
        super.init(node, brand: .DropDown, variable: variable, title: title)
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.fontScale)
        
        minItemWidth = 85
        let itemRect = MMRect()
        for item in items {
            mmView.openSans.getTextRect(text: item, scale: NodeUI.fontScale, rectToUse: itemRect)
            if itemRect.width + 10 > minItemWidth {
                minItemWidth = itemRect.width + 10
            }
        }
        
        rect.width = titleLabel!.rect.width + NodeUI.titleMargin.width() + NodeUI.titleSpacing + minItemWidth
        rect.height = titleLabel!.rect.height + NodeUI.titleMargin.height()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if isDisabled == false {
            open = true
            mouseMoved(event)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if open {
            let oldValue = node.properties[variable]!
            node.properties[variable] = index
            node.variableChanged(variable: variable, oldValue: oldValue, newValue: index)
            mmView.update()
        }
        open = false
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if open {
            let y = event.y - rect.y
            let index = Float(Int(y / itemHeight))
            if index >= 0 && index < Float(items.count) {
                self.index = index
                internal_changed()
                mmView.update()
            }
        }
    }
    
    override func update() {
        index = node.properties[variable]!
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
//        mmView.drawBox.draw( x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale, round: 0, borderSize: 1 * scale, fillColor : float4(0), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
        
        if titleLabel!.scale != NodeUI.fontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.fontScale * scale)
        }
        titleLabel!.isDisabled = isDisabled
        titleLabel!.drawRightCenteredY(x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale)
        
        let x = rect.x + maxTitleSize.x * scale + NodeUI.titleSpacing * scale
        let width = minItemWidth * scale//rect.width * scale - maxTitleSize.x * scale - NodeUI.titleSpacing * scale
        itemHeight =  rect.height * scale
        
        let skin = mmView.skin.MenuWidget
        
        if !open || items.count == 0 {
            mmView.drawBox.draw( x: x, y: rect.y, width: width, height: itemHeight, round: 0, borderSize: 1, fillColor : adjustColor(skin.color), borderColor: adjustColor(skin.borderColor))
            
            if items.count > 0 {
                mmView.drawText.drawTextCentered(mmView.openSans, text: items[Int(index)], x: x, y: rect.y, width: width, height: itemHeight, scale: NodeUI.fontScale * scale, color: adjustColor(skin.textColor))
            }
        } else {
            mmView.drawBox.draw( x: x, y: rect.y, width: width, height: itemHeight * Float(items.count), round: 0, borderSize: 1, fillColor : skin.color, borderColor: skin.borderColor )
            
            var itemY : Float = rect.y
            for (ind,item) in items.enumerated() {
                
                let textColor = Float(ind) == index ? float4(repeating: 1) : skin.textColor
                mmView.drawText.drawTextCentered(mmView.openSans, text: item, x: x, y: itemY, width: width, height: itemHeight, scale: NodeUI.fontScale * scale, color: textColor)
                itemY += itemHeight
            }
        }
    }
}

/// Animation picker derived from NodeUIDropDown and with .AnimationPicker role
class NodeUIMasterPicker : NodeUIDropDown
{
    var uiConnection        : UINodeConnection
    var uuids               : [UUID] = []
    
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        uiConnection = connection
        super.init(node, variable: variable, title: title, items: [])
        uiConnection.uiMasterPicker = self
        role = .MasterPicker
    }
    
    override func internal_changed()
    {
        uiConnection.connectedMaster = uuids[Int(index)]
        uiConnection.masterNode = uiConnection.nodeGraph?.getNodeForUUID(uiConnection.connectedMaster!)
        if let nodeGraph = uiConnection.nodeGraph {
            nodeGraph.updateNode(node)
        }
    }
}

/// Animation picker derived from NodeUIDropDown and with .AnimationPicker role
class NodeUIAnimationPicker : NodeUIDropDown
{
    var uiConnection        : UINodeConnection
    var uuids               : [UUID] = []
    
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        uiConnection = connection
        super.init(node, variable: variable, title: title, items: [])
        uiConnection.uiPicker = self
        role = .AnimationPicker
    }
    
    override func internal_changed()
    {
        uiConnection.connectedTo = uuids[Int(index)]
        uiConnection.target = nil
        if let object = uiConnection.masterNode as? Object {
            for seq in object.sequences {
                if seq.uuid == uiConnection.connectedTo {
                    uiConnection.target = seq
                    break;
                }
            }
        }
    }
}

/// Value Variable picker derived from NodeUIDropDown and with .ValueVariablePicker role
class NodeUIValueVariablePicker : NodeUIDropDown
{
    var uiConnection        : UINodeConnection
    var uuids               : [UUID] = []
    
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        uiConnection = connection
        super.init(node, variable: variable, title: title, items: [])
        uiConnection.uiPicker = self
        role = .ValueVariablePicker
    }
    
    override func internal_changed()
    {
        uiConnection.connectedTo = uuids[Int(index)]
        uiConnection.target = uiConnection.nodeGraph?.getNodeForUUID(uiConnection.connectedTo!)
    }
}

/// Direction Variable picker derived from NodeUIDropDown and with .DirectionVariablePicker role
class NodeUIDirectionVariablePicker : NodeUIDropDown
{
    var uiConnection        : UINodeConnection
    var uuids               : [UUID] = []
    
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        uiConnection = connection
        super.init(node, variable: variable, title: title, items: [])
        uiConnection.uiPicker = self
        role = .DirectionVariablePicker
    }
    
    override func internal_changed()
    {
        uiConnection.connectedTo = uuids[Int(index)]
        uiConnection.target = uiConnection.nodeGraph?.getNodeForUUID(uiConnection.connectedTo!)
    }
}

/// Layer area picker derived from NodeUIDropDown and with .LayerAreaPicker role
class NodeUILayerAreaPicker : NodeUIDropDown
{
    var uiConnection        : UINodeConnection
    var uuids               : [UUID] = []
    
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        uiConnection = connection
        super.init(node, variable: variable, title: title, items: [])
        uiConnection.uiPicker = self
        role = .LayerAreaPicker
    }
    
    override func internal_changed()
    {
        uiConnection.connectedTo = uuids[Int(index)]
        uiConnection.target = uiConnection.nodeGraph?.getNodeForUUID(uiConnection.connectedTo!)
    }
}

/// Key down NodeUI class
class NodeUIKeyDown : NodeUI
{
    var keyCode     : Float = -1
    var keyText     : String = ""
    var keyCodes    : [UInt16:String] = [
        53: "Escape",

        50: "Back Quote",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        23: "5",
        22: "6",
        26: "7",
        28: "8",
        25: "9",
        29: "0",
        27: "-",
        24: "=",
        51: "Delete",

        48: "Tab",
        12: "Q",
        13: "W",
        14: "E",
        15: "R",
        17: "T",
        16: "Y",
        32: "U",
        34: "I",
        31: "O",
        35: "P",
        33: "[",
        30: "]",
        42: "\\",
        
//        57: "Caps Lock",
        0: "A",
        1: "S",
        2: "D",
        3: "F",
        5: "G",
        4: "H",
        38: "J",
        40: "K",
        37: "L",
        41: ";",
        39: ",",
        36: "Return",
        
        57: "Shift",
        6: "Z",
        7: "X",
        8: "C",
        9: "V",
        11: "B",
        45: "N",
        46: "M",
        43: "Comma",
        47: "Period",
        44: "/",
        60: "Shift",
        
        63: "fn",
        59: "Control",
        58: "Option",
        55: "Command",
        49: "Space",
//        55: "R. Command",
        61: "R. Option",
        
        123: "Arrow Left",
        126: "Arrow Up",
        124: "Arrow Right",
        125: "Arrow Down",
    ]
    
    init(_ node: Node, variable: String, title: String)
    {
        if node.properties[variable] == nil {
            node.properties[variable] = keyCode
        } else {
            keyCode = node.properties[variable]!
            let code = UInt16(exactly:keyCode)
            if code != nil {
                let desc = keyCodes[code!]
                if desc != nil {
                    keyText = desc!
                }
            }
        }
        
        super.init(node, brand: .KeyDown, variable: variable, title: title)
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.fontScale)
        
        rect.width = titleLabel!.rect.width + NodeUI.titleMargin.width() + NodeUI.titleSpacing + 120
        rect.height = titleLabel!.rect.height + NodeUI.titleMargin.height()
    }
    
    override func keyDown(_ event: MMKeyEvent)
    {
//        if event.characters != nil {
//            keyText = event.characters!.uppercased()
//        }
        keyCode = Float(event.keyCode)
        
        let desc = keyCodes[event.keyCode]
        if desc != nil {
            keyText = desc!
        }
        
        let oldValue = node.properties[variable]!
        node.properties[variable] = keyCode
        
        if oldValue != keyCode {
            node.variableChanged(variable: variable, oldValue: oldValue, newValue: keyCode)
            mmView.update()
        }
    }
    
    override func update() {
        keyCode = node.properties[variable]!
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
        if titleLabel!.scale != NodeUI.fontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.fontScale * scale)
        }
        titleLabel!.isDisabled = isDisabled
        titleLabel!.drawRightCenteredY(x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale)
        
        let x = rect.x + maxTitleSize.x * scale + NodeUI.titleSpacing * scale
        let width = 120 * scale
        let height = rect.height * scale
        
        let skin = mmView.skin.MenuWidget
        
        mmView.drawBox.draw( x: x, y: rect.y, width: width, height: height, round: 0, borderSize: 1, fillColor : adjustColor(skin.color), borderColor: adjustColor(skin.borderColor) )
        
        mmView.drawText.drawTextCentered(mmView.openSans, text: keyText, x: x, y: rect.y, width: width, height: height, scale: NodeUI.fontScale * scale, color: adjustColor(skin.textColor))
    }
}

/// Number class
class NodeUINumber : NodeUI
{
    var value       : Float
    var range       : float2?
    var defaultValue: Float
    var mouseIsDown : Bool = false
    var x           : Float = 0
    var width       : Float = 0
    var int         : Bool = false
    var undoValue   : Float = 0
    
    init(_ node: Node, variable: String, title: String, range: float2? = float2(0,1), int: Bool = false, value: Float = 0)
    {
        self.value = value
        self.defaultValue = value
        self.range = range
        self.int = int

        if node.properties[variable] == nil {
            node.properties[variable] = value
        } else {
            self.value = node.properties[variable]!
        }
        
        super.init(node, brand: .Number, variable: variable, title: title)
        supportsTitleHover = true
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.fontScale)
        
        rect.width = titleLabel!.rect.width + NodeUI.titleMargin.width() + NodeUI.titleSpacing + 120
        rect.height = titleLabel!.rect.height + NodeUI.titleMargin.height()
    }
    
    override func titleClicked()
    {
        if isDisabled {
            return
        }
        getNumberDialog(view: mmView, title: title, message: "Enter new value", defaultValue: value, cb: { (value) -> Void in
            if self.range != nil {
                let oldValue = self.value
                self.value = max( value, self.range!.x)
                self.value = min( self.value, self.range!.y)
                self.node.variableChanged(variable: self.variable, oldValue: oldValue, newValue: self.value, continuous: false)
            } else {
                self.node.variableChanged(variable: self.variable, oldValue: self.value, newValue: value, continuous: false)
                self.value = value
            }
            self.node.properties[self.variable] = self.value
            self.titleHover = false
            self.updateLinked()
            self.mmView.update()
        } )
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if isDisabled {
            return
        }

        if mouseIsDown == false {
            undoValue = value
        }
        mouseIsDown = true

        if range != nil {
            let oldValue = value
            let perPixel = (range!.y - range!.x) / width

            value = range!.x + perPixel * (event.x - x)
            value = max( value, range!.x)
            value = min( value, range!.y)
            
            if int {
                value = floor(value)
            }
            
            if oldValue != value {
                node.variableChanged(variable: variable, oldValue: oldValue, newValue: value, continuous: true)
                updateLinked()
                mmView.update()
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if isDisabled {
            return
        }
        //let oldValue = node.properties[variable]!
        node.properties[variable] = value
        
        // Disabled the check to allow an continuous event to come through for undo / redo
        //if oldValue != value {
            node.variableChanged(variable: variable, oldValue: undoValue, newValue: value)
            updateLinked()
            mmView.update()
        //}
        mouseIsDown = false
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if mouseIsDown {
            mouseDown(event)
        }
    }
    
    override func mouseLeave() {
    }
    
    func updateLinked()
    {
        if let linked = linkedTo as? NodeUIAngle {
            linked.value = value
            node.properties[linked.variable] = value
        }
    }
    
    override func update() {
        value = node.properties[variable]!
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
        if titleLabel!.scale != NodeUI.fontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.fontScale * scale)
        }
        
        let skin = mmView.skin.MenuWidget
        
        if titleHover && isDisabled == false {
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: maxTitleSize.x * scale + NodeUI.titleSpacing * scale, height: maxTitleSize.y * scale, round: 4, borderSize: 1, fillColor : float4(0.5, 0.5, 0.5, 1), borderColor: float4(repeating:0) )
        }
        
        titleLabel!.isDisabled = isDisabled
        titleLabel!.drawRightCenteredY(x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale)
        
        x = rect.x + maxTitleSize.x * scale + NodeUI.titleSpacing * scale
        width = 120 * scale//rect.width * scale - maxTitleSize.x * scale - NodeUI.titleSpacing * scale
        
        let itemHeight =  rect.height * scale
        
        mmView.drawBox.draw( x: x, y: rect.y, width: width, height: itemHeight, round: 0, borderSize: 1, fillColor : adjustColor(skin.color), borderColor: adjustColor(skin.borderColor) )
        
        if range != nil {
            let offset = (width / (range!.y - range!.x)) * (value - range!.x)
            
            mmView.drawBox.draw( x: x, y: rect.y, width: offset, height: itemHeight, round: 0, borderSize: 1, fillColor : float4( 0.4, 0.4, 0.4, 1), borderColor: adjustColor(skin.borderColor) )
        }
        
        mmView.drawText.drawTextCentered(mmView.openSans, text: int ? String(Int(value)) : String(format: "%.02f", value), x: x, y: rect.y, width: width, height: itemHeight, scale: NodeUI.fontScale * scale, color: adjustColor(skin.textColor))
    }
}

/// Angle class
class NodeUIAngle : NodeUI
{
    var value       : Float
    var defaultValue: Float
    var mouseIsDown : Bool = false
    var x           : Float = 0
    var width       : Float = 0
    
    init(_ node: Node, variable: String, title: String, value: Float = 0)
    {
        self.value = value
        self.defaultValue = value
        
        if node.properties[variable] == nil {
            node.properties[variable] = value
        } else {
            self.value = node.properties[variable]!
        }
        
        super.init(node, brand: .Number, variable: variable, title: title)
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.fontScale)
        
        rect.width = titleLabel!.rect.width + NodeUI.titleMargin.width() + NodeUI.titleSpacing + 40
        rect.height = 40
    }

    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        
        /*
        if oldValue != value {
            node.variableChanged(variable: variable, oldValue: oldValue, newValue: value, continuous: true)
            mmView.update()*/
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        /*
        let oldValue = node.properties[variable]!
        node.properties[variable] = value
        
        if oldValue != value {
            node.variableChanged(variable: variable, oldValue: oldValue, newValue: value)
            mmView.update()
        }
        */
        mouseIsDown = false
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
    }
    
    override func mouseLeave() {
    }
    
    override func update() {
        value = node.properties[variable]!
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
        if titleLabel!.scale != NodeUI.fontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.fontScale * scale)
        }
        
        let skin = mmView.skin.MenuWidget
        
        titleLabel!.isDisabled = isDisabled
        titleLabel!.drawRightCenteredY(x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale)
        
        x = rect.x + maxTitleSize.x * scale + NodeUI.titleSpacing * scale + (maxWidth - 40) * scale / 2
        width = 40 * scale//rect.width * scale - maxTitleSize.x * scale - NodeUI.titleSpacing * scale
        
        let itemHeight =  rect.height * scale
        
        //mmView.drawBox.draw( x: x, y: rect.y, width: width, height: itemHeight, round: 0, borderSize: 1, fillColor : skin.color, borderColor: skin.borderColor )
        
        let length : Float = 17
        
        let x0: Float = x + length * scale
        let y0: Float = rect.y + itemHeight / 2
        
        for i:Float in stride(from: 0, to: 360, by: 20) {
            
            let cosValue : Float = cos(i * Float.pi / 180)
            let sinValue : Float = sin(i * Float.pi / 180)
            
            let x1: Float = x0 + cosValue * (length-5) * scale
            let y1: Float = y0 + sinValue * (length-5) * scale
            let x2: Float = x0 + cosValue * length * scale
            let y2: Float = y0 + sinValue * length * scale
            
            mmView.drawLine.draw(sx: x1, sy: y1, ex: x2, ey: y2, radius: 1, fillColor: skin.color)
        }
        
        let x1: Float = x0 + cos(value * Float.pi / 180) * length * scale
        let y1: Float = y0 + sin(value * Float.pi / 180) * length * scale
        
        mmView.drawLine.draw(sx: x0, sy: y0, ex: x1, ey: y1, radius: 1, fillColor: float4(repeating: 1))
    }
}

/// Text class
class NodeUIText : NodeUI
{
    var value       : String
    var oldValue    : String
    var defaultValue: String
    var mouseIsDown : Bool = false
    var x           : Float = 0
    var width       : Float = 0
    
    init(_ node: Node, variable: String, title: String, value: String = "")
    {
        self.value = value
        self.defaultValue = value
        self.oldValue = value
        
        super.init(node, brand: .Text, variable: variable, title: title)
        supportsTitleHover = true
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.fontScale)
        
        rect.width = titleLabel!.rect.width + NodeUI.titleMargin.width() + NodeUI.titleSpacing + 120
        rect.height = titleLabel!.rect.height + NodeUI.titleMargin.height()
    }
    
    override func titleClicked()
    {
        let old = value
        getStringDialog(view: mmView, title: title, message: "Enter new value", defaultValue: value, cb: { (value) -> Void in
            self.value = value
            self.oldValue = old
            self.titleHover = false
            self.updateLinked()
            self.mmView.update()
            self.node.variableChanged(variable: self.variable, oldValue: 0, newValue: 1, continuous: false)
        } )
        return
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
    }
    
    override func mouseLeave() {
    }
    
    func updateLinked()
    {
    }
    
    override func update() {
        value = oldValue
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
        if titleLabel!.scale != NodeUI.fontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.fontScale * scale)
        }
        
        let skin = mmView.skin.MenuWidget
        
        if titleHover {
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: maxTitleSize.x * scale + NodeUI.titleSpacing * scale, height: maxTitleSize.y * scale, round: 4, borderSize: 1, fillColor : float4(0.5, 0.5, 0.5, 1), borderColor: float4(repeating:0) )
        }
        
        titleLabel!.isDisabled = isDisabled
        titleLabel!.drawRightCenteredY(x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale)
        
        x = rect.x + maxTitleSize.x * scale + NodeUI.titleSpacing * scale
        width = 120 * scale//rect.width * scale - maxTitleSize.x * scale - NodeUI.titleSpacing * scale
        
        let itemHeight =  rect.height * scale
        
        mmView.drawBox.draw( x: x, y: rect.y, width: width, height: itemHeight, round: 0, borderSize: 1, fillColor : skin.color, borderColor: skin.borderColor )
        
        mmView.drawText.drawTextCentered(mmView.openSans, text: value, x: x, y: rect.y, width: width, height: itemHeight, scale: NodeUI.fontScale * scale, color: skin.textColor)
    }
}
