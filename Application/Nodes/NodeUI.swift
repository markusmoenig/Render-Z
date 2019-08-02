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
        case Separator, DropDown, KeyDown, Number, Text, DropTarget
    }
    
    enum Role {
        case None, MasterPicker, AnimationPicker, FloatVariablePicker, DirectionVariablePicker, LayerAreaPicker, FloatVariableTarget, DirectionVariableTarget, ObjectInstanceTarget, LayerAreaTarget, AnimationTarget, Float2VariableTarget, BehaviorTreeTarget
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
    
    var dropTarget  : String? = nil
    
    // Start of the content area
    var contentY    : Float = 0

    // --- Statics
    
    static let fontName             : String = "Open Sans"
    static let titleFontScale       : Float = 0.34
    static let fontScale            : Float = 0.4
    static let titleMargin          : MMMargin = MMMargin(0, 5, 5, 5)
    static let titleSpacing         : Float = 5
    static let titleXOffset         : Float = 6
    static let itemSpacing          : Float = 6
    static let contentMargin        : Float = 8
    static let contentRound         : Float = 22

    static let titleTextColor       : float4 = float4(0.6, 0.6, 0.6, 1.0)
    static let contentColor         : float4 = float4(0.404, 0.408, 0.412, 1.000)
    static let contentColor2        : float4 = float4(0.243, 0.247, 0.251, 1.000)
    static let contentTextColor     : float4 = float4(0.749, 0.753, 0.757, 1.000)

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
        if titleLabel!.scale != NodeUI.titleFontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.titleFontScale * scale)
        }
        
        titleLabel!.isDisabled = isDisabled
        titleLabel!.rect.x = rect.x + NodeUI.titleXOffset * scale
        titleLabel!.rect.y = rect.y
        titleLabel!.color = (titleHover && isDisabled == false) ? float4(1,1,1,1) : NodeUI.contentTextColor
        titleLabel!.draw()
        
        contentY = rect.y + titleLabel!.rect.height + NodeUI.titleSpacing * scale
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

class NodeUISelectorItem
{
    var label       : MMTextLabel?
    
    init( _ view: MMView, text: String)
    {
        label = MMTextLabel(view, font: view.openSans, text: text, scale: NodeUI.fontScale, color: NodeUI.contentTextColor )
    }
}

/// Drop down NodeUI class
class NodeUIDropDown : NodeUI
{
    enum HoverMode {
        case None, LeftArrow, RightArrow
    }
    
    enum Animating {
        case No, Left, Right
    }
    
    var items       : [String]
    var scrollItems : [NodeUISelectorItem]
    var index       : Float
    var defaultValue: Float
    
    let itemHeight  : Float = 26
    let spacer      : Float = 60
    
    var contentWidth: Float = 0
    var maxItemWidth: Float = 0
    
    var hoverMode   : HoverMode = .None
    var animating   : Animating = .No
    
    var animatingTo : Int = 0
    var animOffset  : Float = 0
    
    var scale       : Float = 0

    var contentLabel: MMTextLabel!
    
    init(_ node: Node, variable: String, title: String, items: [String], index: Float = 0)
    {
        self.items = items
        self.scrollItems = []
        self.index = index
        self.defaultValue = index
        
        if node.properties[variable] == nil {
            node.properties[variable] = index
        } else {
            self.index = node.properties[variable]!
        }
        
        super.init(node, brand: .DropDown, variable: variable, title: title)
    }
    
    func setItems(_ items: [String], fixedWidth: Float? = nil)
    {
        contentWidth = 0
        maxItemWidth = 0
        
        self.scrollItems = []
        for text in items {
            let item = NodeUISelectorItem(mmView, text: text)
            
            contentWidth += item.label!.rect.width
            maxItemWidth = max(maxItemWidth, item.label!.rect.width)
            
            self.scrollItems.append(item)
        }
        
        contentWidth += Float((items.count - 1 ) * 10) // Add margin
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale, color: NodeUI.titleTextColor)
        contentLabel = MMTextLabel(mmView, font: mmView.openSans, text: "", scale: NodeUI.fontScale, color: NodeUI.contentTextColor)
        
        self.setItems(items)

        rect.width = maxItemWidth + spacer
        rect.height = titleLabel!.rect.height + NodeUI.titleSpacing + itemHeight + NodeUI.itemSpacing
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if isDisabled {
            return
        }
        startScrolling()
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if isDisabled {
            return
        }
        let oldHoverMode = hoverMode
        hoverMode = .None
        
        if items.count > 1 {
            if rect.contains(event.x, event.y, scale) && event.x <= rect.x + 25 * scale && event.y > contentY {
                hoverMode = .LeftArrow
            }
            if rect.contains(event.x, event.y, scale) && event.x >= rect.x + (maxItemWidth + spacer - 19) * scale && event.y > contentY {
                hoverMode = .RightArrow
            }
        }
        if oldHoverMode != hoverMode {
            update()
        }
    }
    
    override func mouseLeave() {
        hoverMode = .None
        update()
    }
    
    override func update() {
        index = node.properties[variable]!
    }
    
    func startScrolling()
    {
        let index : Int = Int(self.index)
        if hoverMode == .RightArrow {
            animatingTo = index == items.count - 1 ? 0 : index + 1
            animating = .Right
            animOffset = 0
            mmView.startAnimate( startValue: 0, endValue: maxItemWidth + spacer / 2 * scale - (maxItemWidth * scale - scrollItems[animatingTo].label!.rect.width) / 2, duration: 300, cb: { (value,finished) in
                if finished {
                    self.animating = .No
                    self.index = Float(self.animatingTo)

                    let oldValue = self.node.properties[self.variable]!
                    self.node.properties[self.variable] = self.index
                    self.node.variableChanged(variable: self.variable, oldValue: oldValue, newValue: self.index)
                }
                self.animOffset = value
                self.mmView.update()
            } )
        } else
        if hoverMode == .LeftArrow {
            animatingTo = index == 0 ? items.count - 1 : index - 1
            animating = .Left
            animOffset = 0
            mmView.startAnimate( startValue: 0, endValue: maxItemWidth + spacer / 2 * scale + (maxItemWidth * scale - scrollItems[animatingTo].label!.rect.width) / 2, duration: 300, cb: { (value,finished) in
                if finished {
                    self.animating = .No
                    self.index = Float(self.animatingTo)

                    let oldValue = self.node.properties[self.variable]!
                    self.node.properties[self.variable] = self.index
                    self.node.variableChanged(variable: self.variable, oldValue: oldValue, newValue: self.index)
                }
                self.animOffset = value
                self.mmView.update()
            } )
        }
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        self.scale = scale
        
        mmView.drawBox.draw( x: rect.x, y: contentY, width: (maxItemWidth + spacer) * scale, height: itemHeight * scale, round: (NodeUI.contentRound + 4) * scale, borderSize: 1, fillColor : float4(0,0,0,0), borderColor: adjustColor(NodeUI.contentColor) )
        
        let middleY : Float = contentY + itemHeight / 2 * scale
        let arrowUp : Float = 7 * scale
        var left    : Float = rect.x + 10 * scale
        
        var color : float4 = hoverMode == .LeftArrow ? float4(1,1,1,1) : mmView.skin.ScrollButton.activeColor
        if isDisabled { color.w = 0.2 }
        mmView.drawLine.draw(sx: left, sy: middleY, ex: left + arrowUp, ey: middleY + arrowUp, radius: 1 * scale, fillColor: color)
        mmView.drawLine.draw(sx: left, sy: middleY, ex: left + arrowUp, ey: middleY - arrowUp, radius: 1 * scale, fillColor: color)

        left = rect.x + (maxItemWidth + spacer - 19) * scale
        color = hoverMode == .RightArrow ? float4(1,1,1,1) : mmView.skin.ScrollButton.activeColor
        if isDisabled { color.w = 0.2 }
        mmView.drawLine.draw(sx: left + arrowUp, sy: middleY, ex: left, ey: middleY + arrowUp, radius: 1 * scale, fillColor: color)
        mmView.drawLine.draw(sx: left + arrowUp, sy: middleY, ex: left, ey: middleY - arrowUp, radius: 1 * scale, fillColor: color)
        
        if items.count == 0 { return }
        
        let label = scrollItems[Int(index)].label!
        
        if  label.scale != NodeUI.fontScale * scale {
            label.setText(label.text, scale: NodeUI.fontScale * scale)
        }
        
        mmView.renderer.setClipRect(MMRect(rect.x + 20 * scale, rect.y, (maxItemWidth + 20) * scale, rect.height * scale))

        label.isDisabled = isDisabled
        label.rect.x = rect.x + spacer / 2 * scale + (maxItemWidth * scale - label.rect.width) / 2
        label.rect.y = contentY + 5 * scale

        if animating == .Right {
            label.rect.x -= animOffset
        } else
        if animating == .Left {
            label.rect.x += animOffset
        }
        label.draw()
        
        if animating == .Right {
            let animTolabel = scrollItems[animatingTo].label!
            if  animTolabel.scale != NodeUI.fontScale * scale {
                animTolabel.setText(animTolabel.text, scale: NodeUI.fontScale * scale)
            }
            
            animTolabel.rect.x = rect.x + spacer / 2 * scale + maxItemWidth + spacer / 2 * scale - animOffset
            animTolabel.rect.y = label.rect.y
            animTolabel.draw()
        } else
        if animating == .Left {
            let animTolabel = scrollItems[animatingTo].label!
            if  animTolabel.scale != NodeUI.fontScale * scale {
                animTolabel.setText(animTolabel.text, scale: NodeUI.fontScale * scale)
            }
            
            animTolabel.rect.x = rect.x + spacer / 2 * scale - (maxItemWidth + spacer / 2 * scale) + animOffset
            animTolabel.rect.y = label.rect.y
            animTolabel.draw()
        }
        mmView.renderer.setClipRect()
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
class NodeUIFloatVariablePicker : NodeUIDropDown
{
    var uiConnection        : UINodeConnection
    var uuids               : [UUID] = []
    
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        uiConnection = connection
        super.init(node, variable: variable, title: title, items: [])
        uiConnection.uiPicker = self
        role = .FloatVariablePicker
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

/// NodeUI Drop Target
class NodeUIDropTarget : NodeUI
{
    enum HoverState {
        case None, Valid, Invalid
    }
    
    var hoverState  : HoverState = .None
    var uiConnection: UINodeConnection!

    var itemHeight  : Float = 48
    var minItemWidth: Float = 85

    var targetID    : String
    
    var contentLabel: MMTextLabel!
    
    init(_ node: Node, variable: String, title: String, targetID: String)
    {
        self.targetID = targetID
        super.init(node, brand: .DropTarget, variable: variable, title: title)
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.fontScale)
        
        var text = ""
        if let name = uiConnection.targetName {
            text = name
        }
        
        contentLabel = MMTextLabel(mmView, font: mmView.openSans, text: text, scale: NodeUI.fontScale)
        minItemWidth = max( contentLabel.rect.width + 15, 85 )
        
        rect.width = titleLabel!.rect.width + NodeUI.titleMargin.width() + NodeUI.titleSpacing + minItemWidth
        rect.height = titleLabel!.rect.height + NodeUI.titleMargin.height()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        uiConnection.nodeGraph!.refList.switchTo(id: targetID, selected: uiConnection.connectedTo)
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
    }
    
    override func update() {
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
        if titleLabel!.scale != NodeUI.fontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.fontScale * scale)
        }
        
        itemHeight = (rect.height-2) * scale
        let y : Float = rect.y - 1

        titleLabel!.isDisabled = isDisabled
        titleLabel!.drawRightCenteredY(x: rect.x, y: y, width: maxTitleSize.x * scale, height: itemHeight)
        
        let x = rect.x + maxTitleSize.x * scale + NodeUI.titleSpacing * scale
        let width = node.uiMaxWidth * scale// minItemWidth * scale
        
        let skin = mmView.skin.MenuWidget
        
        if hoverState == .Valid && isDisabled == false {
            mmView.drawBox.draw( x: x, y: y, width: width, height: itemHeight, round: 16 * scale, borderSize: 1, fillColor : float4(repeating: 0), borderColor: mmView.skin.Node.successColor)
        } else
        if (hoverState == .Invalid || contentLabel!.text == "") && isDisabled == false {
            mmView.drawBox.draw( x: x, y: y, width: width, height: itemHeight, round: 16 * scale, borderSize: 1, fillColor : float4(repeating: 0), borderColor: mmView.skin.Node.failureColor)
        } else {
            mmView.drawBox.draw( x: x, y: y, width: width, height: itemHeight, round: 16 * scale, borderSize: 1, fillColor : float4(repeating: 0), borderColor: float4(skin.color.x, skin.color.y, skin.color.z, 0.3))
        }
        
        if contentLabel.scale != NodeUI.fontScale * scale {
            contentLabel.setText(contentLabel.text, scale: NodeUI.fontScale * scale)
        }
        
        contentLabel.isDisabled = isDisabled
        contentLabel.drawCentered(x: x, y: y, width: width, height: itemHeight)
    }
}

/// Float Variable Target derived from NodeUIDropTarget and with "Float Variable" drop ID
class NodeUIFloatVariableTarget : NodeUIDropTarget
{
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        super.init(node, variable: variable, title: title, targetID: "Float Variable")
        uiConnection = connection
        uiConnection.uiTarget = self
        role = .FloatVariableTarget
    }
}

/// Direction Variable Target derived from NodeUIDropTarget and with "Value Variable" drop ID
class NodeUIDirectionVariableTarget : NodeUIDropTarget
{
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        super.init(node, variable: variable, title: title, targetID: "Direction Variable")
        uiConnection = connection
        uiConnection.uiTarget = self
        role = .DirectionVariableTarget
    }
}

/// Float2 Variable Target derived from NodeUIDropTarget and with "Float2 Variable" drop ID
class NodeUIFloat2VariableTarget : NodeUIDropTarget
{
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        super.init(node, variable: variable, title: title, targetID: "Float2 Variable")
        uiConnection = connection
        uiConnection.uiTarget = self
        role = .Float2VariableTarget
    }
}

/// Object Instance Target derived from NodeUIDropTarget and with "Object Instance" drop ID
class NodeUIObjectInstanceTarget : NodeUIDropTarget
{
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        super.init(node, variable: variable, title: title, targetID: "Object Instance")
        uiConnection = connection
        uiConnection.uiTarget = self
        role = .ObjectInstanceTarget
    }
}

/// Layer Area Target derived from NodeUIDropTarget and with "Layer Area" drop ID
class NodeUILayerAreaTarget : NodeUIDropTarget
{
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        super.init(node, variable: variable, title: title, targetID: "Layer Area")
        uiConnection = connection
        uiConnection.uiTarget = self
        role = .LayerAreaTarget
    }
}

/// Animation Target derived from NodeUIDropTarget and with "Animation" drop ID
class NodeUIAnimationTarget : NodeUIDropTarget
{
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        super.init(node, variable: variable, title: title, targetID: "Animation")
        uiConnection = connection
        uiConnection.uiTarget = self
        role = .AnimationTarget
    }
}

/// Behavior Tree Target derived from NodeUIDropTarget and with "Behavior Tree" drop ID
class NodeUIBehaviorTreeTarget : NodeUIDropTarget
{
    init(_ node: Node, variable: String, title: String, connection: UINodeConnection)
    {
        super.init(node, variable: variable, title: title, targetID: "Behavior Tree")
        uiConnection = connection
        uiConnection.uiTarget = self
        role = .BehaviorTreeTarget
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
    
    var contentLabel: MMTextLabel!

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
        contentLabel = MMTextLabel(mmView, font: mmView.openSans, text: "", scale: NodeUI.fontScale)

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
        
        // Draw Text
        if contentLabel.text != keyText || contentLabel.scale != NodeUI.fontScale * scale {
            contentLabel.setText(keyText, scale: NodeUI.fontScale * scale)
        }
        contentLabel.color = adjustColor(skin.textColor)
        contentLabel.drawCentered(x: x, y: rect.y, width: width, height: height)
        //mmView.drawText.drawTextCentered(mmView.openSans, text: keyText, x: x, y: rect.y, width: width, height: height, scale: NodeUI.fontScale * scale, color: adjustColor(skin.textColor))
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
    
    var contentLabel: MMTextLabel!
    var contentText : String = ""
    var contentValue: Float? = nil
    
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
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale, color: NodeUI.titleTextColor)
        contentLabel = MMTextLabel(mmView, font: mmView.openSans, text: String(value), scale: NodeUI.fontScale, color: NodeUI.contentTextColor)

        rect.width = 160
        rect.height = titleLabel!.rect.height + NodeUI.titleSpacing + contentLabel!.rect.height + NodeUI.contentMargin + NodeUI.itemSpacing
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
            linked.setValue(value)
        }
    }
    
    override func update() {
        value = node.properties[variable]!
    }
    
    func getValue() -> Float
    {
        return node.properties[variable]!
    }
    
    func setValue(_ value: Float)
    {
        self.value = value
        node.properties[variable] = value
        updateLinked()
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        
        x = rect.x
        width = 160 * scale
        let itemHeight = contentLabel!.rect.height + NodeUI.contentMargin * scale
        
        mmView.drawBox.draw( x: x, y: contentY, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor : adjustColor(NodeUI.contentColor) )
        
        if range != nil {
            let offset = (width / (range!.y - range!.x)) * (value - range!.x)
            if offset > 0 {
                mmView.renderer.setClipRect(MMRect(x, contentY, offset, itemHeight))
                mmView.drawBox.draw( x: x, y: contentY, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor : adjustColor(NodeUI.contentColor2))
                mmView.renderer.setClipRect()
            }
        }
        
        // --- Draw Text
        if contentValue != value {
            contentText = int ? String(Int(value)) : String(format: "%.02f", value)
            contentValue = value
        }
        if contentLabel.text != contentText || contentLabel.scale != NodeUI.fontScale * scale {
            contentLabel.setText(contentText, scale: NodeUI.fontScale * scale)
        }

        contentLabel!.isDisabled = isDisabled
        contentLabel.color = NodeUI.contentTextColor
        contentLabel.drawCentered(x: x, y: contentY, width: width, height: itemHeight)
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
    
    func getValue() -> Float
    {
        return node.properties[variable]!
    }
    
    func setValue(_ value: Float)
    {
        self.value = value
        node.properties[variable] = value
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

/// Color class
class NodeUIColor : NodeUI
{
    var value       : float3
    var defaultValue: float3
    var mouseIsDown : Bool = false
    var x           : Float = 0
    var width       : Float = 0
    
    var prevSize    : float2 = float2(80,90)
    
    var colorWidget : MMColorWidget? = nil
    
    init(_ node: Node, variable: String, title: String, value: float3 = float3(0,0,0))
    {
        self.value = value
        self.defaultValue = value
    
        super.init(node, brand: .Number, variable: variable, title: title)

        if node.properties[variable + "_r"] == nil {
            setValue(value)
        } else {
            self.value = getValue()
        }
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.fontScale)
        
        rect.width = titleLabel!.rect.width + NodeUI.titleMargin.width() + NodeUI.titleSpacing + prevSize.x
        rect.height = prevSize.y
        
        if colorWidget == nil {
            colorWidget = MMColorWidget(mmView, value: value)
            colorWidget?.changed = { (val, cont) in
                self.setValue(val)
                
                if !cont {
                    self.node.variableChanged(variable: self.variable, oldValue: 0, newValue: 1)
                    mmView.update()
                }
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if isDisabled { return }
        mouseIsDown = true
        if let widget = colorWidget {
            widget.mouseDown(event)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if isDisabled { return }
        if let widget = colorWidget {
            widget.mouseUp(event)
        }
        mouseIsDown = false
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if isDisabled { return }
        if let widget = colorWidget {
            widget.mouseMoved(event)
        }
    }
    
    override func mouseLeave() {
    }
    
    override func update() {
        value = getValue()
    }
    
    func getValue() -> float3
    {
        return float3(node.properties[variable + "_r"]!, node.properties[variable + "_g"]!, node.properties[variable + "_b"]!)
    }
    
    func setValue(_ value: float3)
    {
        self.value = value
        node.properties[variable + "_r"] = value.x
        node.properties[variable + "_g"] = value.y
        node.properties[variable + "_b"] = value.z
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, maxWidth: Float, scale: Float)
    {
        if titleLabel!.scale != NodeUI.fontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.fontScale * scale)
        }
        
        titleLabel!.isDisabled = isDisabled
        titleLabel!.drawRightCenteredY(x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale)
        
        x = rect.x + maxTitleSize.x * scale + NodeUI.titleSpacing * scale// + (maxWidth - prevSize.x) * scale / 2
        
        if let widget = colorWidget {
            widget.rect.x = x
            widget.rect.y = rect.y + 5 * scale
            widget.rect.width = prevSize.x * scale
            widget.rect.height = widget.rect.width
            widget.isDisabled = isDisabled
            
            widget.draw()
        }
    }
}
