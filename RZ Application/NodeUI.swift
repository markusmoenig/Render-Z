//
//  NodeUI.swift
//  Shape-Z
//
//  Created by Markus Moenig on 31/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

class NodeUI
{
    enum Brand {
        case Separator, Selector, KeyDown, Number, Text, DropTarget
    }
    
    enum Role {
        case None, MasterPicker, AnimationPicker, FloatVariablePicker, DirectionVariablePicker, LayerAreaPicker, FloatVariableTarget, DirectionVariableTarget, ObjectInstanceTarget, SceneAreaTarget, AnimationTarget, Float2VariableTarget, BehaviorTreeTarget, SceneTarget
    }
    
    var mmView              : MMView!
    
    var brand               : Brand
    var role                : Role = .None
    
    var node                : Node
    var variable            : String
    var title               : String
    
    var rect                : MMRect = MMRect()
    var titleLabel          : MMTextLabel? = nil
    var titleShadowLabel    : MMTextLabel? = nil

    var supportsTitleHover  : Bool = false
    var titleHover          : Bool = false
    
    var supportsRandom      : Bool = false
    var randomIsOn          : Bool = false
    var randomLabel         : MMTextLabel? = nil
    var randomShadowLabel   : MMTextLabel? = nil
    var randomHover         : Bool = false

    var isDisabled          : Bool = false
    
    var linkedTo            : NodeUI? = nil
    
    var dropTarget          : String? = nil
    
    // Start of the content area
    var contentY            : Float = 0
    
    var titleShadows        : Bool = false
    
    var additionalSpacing   : Float = 0

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

    static let titleTextColor       : SIMD4<Float> = SIMD4<Float>(0.6, 0.6, 0.6, 1.0)
    static let titleShadowTextColor : SIMD4<Float> = SIMD4<Float>(0.0, 0.0, 0.0, 1.0)
    static let contentColor         : SIMD4<Float> = SIMD4<Float>(0.404, 0.408, 0.412, 1.000)
    static let contentColor2        : SIMD4<Float> = SIMD4<Float>(0.243, 0.247, 0.251, 1.000)
    static let contentTextColor     : SIMD4<Float> = SIMD4<Float>(0.749, 0.753, 0.757, 1.000)

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
    
    func randomClicked()
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
    
    func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        if titleShadows && titleShadowLabel == nil {
            titleShadowLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale * scale, color: NodeUI.titleShadowTextColor)
        }
        
        if titleLabel!.scale != NodeUI.titleFontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.titleFontScale * scale)
            if titleShadowLabel != nil {
                titleShadowLabel!.setText(title, scale: NodeUI.titleFontScale * scale)
            }
        }
        
        if titleShadowLabel != nil {
            titleShadowLabel!.isDisabled = isDisabled
            titleShadowLabel!.rect.x = rect.x + NodeUI.titleXOffset * scale + 0.5
            titleShadowLabel!.rect.y = rect.y + 0.5
            titleShadowLabel!.draw()
        }
        
        titleLabel!.isDisabled = isDisabled
        titleLabel!.rect.x = rect.x + NodeUI.titleXOffset * scale
        titleLabel!.rect.y = rect.y
        titleLabel!.color = (titleHover && isDisabled == false) ? SIMD4<Float>(1,1,1,1) : NodeUI.contentTextColor
        titleLabel!.draw()
        
        contentY = rect.y + titleLabel!.rect.height + NodeUI.titleSpacing * scale
        
        if supportsRandom {
            if randomLabel == nil {
                randomLabel = MMTextLabel(mmView, font: mmView.openSans, text: "R", scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
            }
            if titleShadows && randomShadowLabel == nil {
                randomShadowLabel = MMTextLabel(mmView, font: mmView.openSans, text: "R", scale: NodeUI.titleFontScale * scale, color: NodeUI.titleShadowTextColor)
            }
            if randomShadowLabel != nil {
                randomShadowLabel!.isDisabled = isDisabled
                randomShadowLabel!.rect.x = rect.x + rect.width - randomLabel!.rect.width - 5 + 0.5
                randomShadowLabel!.rect.y = rect.y + 0.5
                randomShadowLabel!.draw()
            }
            randomLabel!.rect.x = rect.x + rect.width - randomLabel!.rect.width - 5
            randomLabel!.rect.y = rect.y
            randomLabel!.color = (randomHover && isDisabled == false) ? SIMD4<Float>(1,1,1,1) : NodeUI.contentTextColor
            randomLabel!.draw()
        }
    }
    
    /// Adjust color to disabled if necessary
    func adjustColor(_ color: SIMD4<Float>) -> SIMD4<Float> {
        return isDisabled ? SIMD4<Float>(color.x, color.y, color.z, mmView.skin.disabledAlpha) : color
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
        
        if titleLabel == nil {
            let scale : Float = 1
            titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: "", scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
        }
        
        rect.width = 0
        rect.height = defaultValue
    }
}

class NodeUISelectorItem
{
    var label       : MMTextLabel?
    var shadowLabel : MMTextLabel?
    
    init( _ view: MMView, text: String, shadow: Bool = false)
    {
        label = MMTextLabel(view, font: view.openSans, text: text, scale: NodeUI.fontScale, color: NodeUI.contentTextColor )
        if shadow == true {
            shadowLabel = MMTextLabel(view, font: view.openSans, text: text, scale: NodeUI.fontScale, color: SIMD4<Float>(0,0,0,1))
        }
    }
}

/// Drop down NodeUI class
class NodeUISelector        : NodeUI
{
    enum HoverMode {
        case None, LeftArrow, RightArrow
    }
    
    enum Animating {
        case No, Left, Right
    }
    
    var items               : [String]
    var scrollItems         : [NodeUISelectorItem]
    var index               : Float
    var defaultValue        : Float
    
    let itemHeight          : Float = 26
    let spacer              : Float = 60
    
    var contentWidth        : Float = 0
    var maxItemWidth        : Float = 0
    
    var hoverMode           : HoverMode = .None
    var animating           : Animating = .No
    
    var animatingTo         : Int = 0
    var animOffset          : Float = 0
    
    var scale               : Float = 0

    var contentLabel        : MMTextLabel!
    
    init(_ node: Node, variable: String, title: String, items: [String], index: Float = 0, shadows: Bool = false)
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
        
        super.init(node, brand: .Selector, variable: variable, title: title)
        titleShadows = shadows
    }
    
    func setItems(_ items: [String], fixedWidth: Float? = nil)
    {
        contentWidth = 0
        maxItemWidth = 0
        
        self.scrollItems = []
        for text in items {
            let item = NodeUISelectorItem(mmView, text: text, shadow: titleShadows)
            
            contentWidth += item.label!.rect.width
            maxItemWidth = max(maxItemWidth, item.label!.rect.width)
            
            self.scrollItems.append(item)
        }
        
        contentWidth += Float((items.count - 1 ) * 10) // Add margin
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        
        if titleLabel == nil {
            let scale : Float = 1
            titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
            contentLabel = MMTextLabel(mmView, font: mmView.openSans, text: "", scale: NodeUI.fontScale * scale, color: NodeUI.contentTextColor)
        }
        
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
        if let value = node.properties[variable] {
            index = value
        }
    }
    
    func getValue() -> Float
    {
        return node.properties[variable]!
    }
    
    func setValue(_ value: Float)
    {
        self.index = value
        node.properties[variable] = value
    }
    
    func startScrolling()
    {
        let index : Int = Int(self.index)
        if hoverMode == .RightArrow {
            animatingTo = index == items.count - 1 ? 0 : index + 1
            animating = .Right
            animOffset = 0
            
            let animTolabel = scrollItems[animatingTo].label!
            if  animTolabel.scale != NodeUI.fontScale * scale {
                animTolabel.setText(animTolabel.text, scale: NodeUI.fontScale * scale)
            }
            
            mmView.startAnimate( startValue: 0, endValue: maxItemWidth + spacer / 2 * scale - (maxItemWidth * scale - animTolabel.rect.width) / 2, duration: 300, cb: { (value,finished) in
                if finished {
                    self.animating = .No
                    #if os(iOS)
                    self.hoverMode = .None
                    #endif
                    self.index = Float(self.animatingTo)
                    self.internal_changed()

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
            
            let animTolabel = scrollItems[animatingTo].label!
            if  animTolabel.scale != NodeUI.fontScale * scale {
                animTolabel.setText(animTolabel.text, scale: NodeUI.fontScale * scale)
            }
            
            mmView.startAnimate( startValue: 0, endValue: maxItemWidth + spacer / 2 * scale + (maxItemWidth * scale - animTolabel.rect.width) / 2, duration: 300, cb: { (value,finished) in
                if finished {
                    self.animating = .No
                    #if os(iOS)
                    self.hoverMode = .None
                    #endif
                    self.index = Float(self.animatingTo)
                    self.internal_changed()

                    let oldValue = self.node.properties[self.variable]!
                    self.node.properties[self.variable] = self.index
                    self.node.variableChanged(variable: self.variable, oldValue: oldValue, newValue: self.index)
                }
                self.animOffset = value
                self.mmView.update()
            } )
        }
    }
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        self.scale = scale
        
        let fillColor = titleShadows ? SIMD4<Float>(NodeUI.contentColor2.x, NodeUI.contentColor2.y, NodeUI.contentColor2.z, 0.4) : SIMD4<Float>(0,0,0,0)
        mmView.drawBox.draw( x: rect.x, y: contentY, width: (maxItemWidth + spacer) * scale, height: itemHeight * scale, round: (NodeUI.contentRound + 4) * scale, borderSize: 1, fillColor : SIMD4<Float>(fillColor), borderColor: adjustColor(NodeUI.contentColor) )
        
        let middleY : Float = contentY + itemHeight / 2 * scale
        let arrowUp : Float = 7 * scale
        var left    : Float = rect.x + 10 * scale
        let oneScaled : Float = 1 * scale
        
        var color : SIMD4<Float> = hoverMode == .LeftArrow ? SIMD4<Float>(1,1,1,1) : mmView.skin.ScrollButton.activeColor
        if isDisabled { color.w = 0.2 }
        mmView.drawLine.draw(sx: left, sy: middleY - oneScaled, ex: left + arrowUp, ey: middleY + arrowUp - oneScaled, radius: oneScaled, fillColor: color)
        mmView.drawLine.draw(sx: left, sy: middleY - oneScaled, ex: left + arrowUp, ey: middleY - arrowUp - oneScaled, radius: oneScaled, fillColor: color)

        left = rect.x + (maxItemWidth + spacer - 19) * scale
        color = hoverMode == .RightArrow ? SIMD4<Float>(1,1,1,1) : mmView.skin.ScrollButton.activeColor
        if isDisabled { color.w = 0.2 }
        mmView.drawLine.draw(sx: left + arrowUp, sy: middleY - oneScaled, ex: left, ey: middleY + arrowUp - oneScaled, radius: oneScaled, fillColor: color)
        mmView.drawLine.draw(sx: left + arrowUp, sy: middleY - oneScaled, ex: left, ey: middleY - arrowUp - oneScaled, radius: oneScaled, fillColor: color)
        
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
        
        if titleShadows && isDisabled == false {
            if let shadowLabel = scrollItems[Int(index)].shadowLabel {
                shadowLabel.rect.x = label.rect.x + 0.5
                shadowLabel.rect.y = label.rect.y + 0.5
                shadowLabel.draw()
            }
        }
        label.draw()
        
        if animating == .Right {
            let animTolabel = scrollItems[animatingTo].label!
            animTolabel.rect.x = rect.x + spacer / 2 * scale + maxItemWidth + spacer / 2 * scale - animOffset
            animTolabel.rect.y = label.rect.y
            if titleShadows && isDisabled == false {
                if let shadowLabel = scrollItems[animatingTo].shadowLabel {
                    shadowLabel.rect.x = animTolabel.rect.x + 0.5
                    shadowLabel.rect.y = animTolabel.rect.y + 0.5
                    shadowLabel.draw()
                }
            }
            animTolabel.draw()
        } else
        if animating == .Left {
            let animTolabel = scrollItems[animatingTo].label!
            animTolabel.rect.x = rect.x + spacer / 2 * scale - (maxItemWidth + spacer / 2 * scale) + animOffset
            animTolabel.rect.y = label.rect.y
            if titleShadows && isDisabled == false {
                if let shadowLabel = scrollItems[animatingTo].shadowLabel {
                    shadowLabel.rect.x = animTolabel.rect.x + 0.5
                    shadowLabel.rect.y = animTolabel.rect.y + 0.5
                    shadowLabel.draw()
                }
            }
            animTolabel.draw()
        }
        mmView.renderer.setClipRect()
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
        
        if titleLabel == nil {
            let scale : Float = 1
            titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
            contentLabel = MMTextLabel(mmView, font: mmView.openSans, text: "", scale: NodeUI.fontScale * scale)
        }

        rect.width = 120
        rect.height = titleLabel!.rect.height + NodeUI.titleSpacing + 14 + NodeUI.contentMargin + NodeUI.itemSpacing
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
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        
        let x = rect.x
        let width = 120 * scale
        let itemHeight = (14 + NodeUI.contentMargin) * scale
        
        mmView.drawBox.draw( x: x, y: contentY, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor: adjustColor(NodeUI.contentColor) )
        
        // Draw Text
        if contentLabel.text != keyText || contentLabel.scale != NodeUI.fontScale * scale {
            contentLabel.setText(keyText, scale: NodeUI.fontScale * scale)
        }
        contentLabel.color = adjustColor(NodeUI.contentTextColor)
        contentLabel.drawCentered(x: x, y: contentY, width: width, height: itemHeight)
    }
}

/// Number class
class NodeUINumber : NodeUI
{
    var value       : Float
    var valueRandom : Float? = nil

    var range       : SIMD2<Float>?
    var defaultValue: Float
    var mouseIsDown : Bool = false
    var x           : Float = 0
    var width       : Float = 0
    var int         : Bool = false
    var undoValue   : Float = 0
    
    var contentLabel: MMTextLabel!
    var contentText : String = ""
    var contentValue: Float? = nil
        
    var precision   : Int = 3
    var autoAdjustMargin : Bool = false
    
    var stepSize    : Float = 0
    
    var halfWidth   : Float? = nil
    
    init(_ node: Node, variable: String, title: String, range: SIMD2<Float>? = SIMD2<Float>(0,1), int: Bool = false, value: Float = 0, precision: Int = 3, halfWidthValue : Float? = nil, valueRandom: Float? = nil)
    {
        self.value = value
        self.defaultValue = value
        self.range = range
        self.int = int
        self.precision = precision
        self.halfWidth = halfWidthValue
        self.valueRandom = valueRandom

        if node.properties[variable] == nil {
            node.properties[variable] = value
        } else {
            self.value = node.properties[variable]!
        }
        
        super.init(node, brand: .Number, variable: variable, title: title)
        
        if valueRandom != nil {
            supportsRandom = true
        }
        supportsTitleHover = true
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        
        if titleLabel == nil {
            let scale : Float = 1
            titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
            contentLabel = MMTextLabel(mmView, font: mmView.openSans, text: "", scale: NodeUI.fontScale * scale, color: NodeUI.contentTextColor)
        }

        rect.width = 160
        rect.height = titleLabel!.rect.height + NodeUI.titleSpacing + 14 + NodeUI.contentMargin + NodeUI.itemSpacing
    }
    
    override func titleClicked()
    {
        if isDisabled {
            return
        }
        getNumberDialog(view: mmView, title: title, message: "Enter new value", defaultValue: value, int: int, precision: precision, cb: { (value) -> Void in
            if self.range != nil && self.autoAdjustMargin == false {
                let oldValue = self.value
                self.value = max( value, self.range!.x)
                self.value = min( self.value, self.range!.y)
                self.node.variableChanged(variable: self.variable, oldValue: oldValue, newValue: self.value, continuous: false)
            } else {
                self.node.variableChanged(variable: self.variable, oldValue: self.value, newValue: value, continuous: false)
                self.value = value
                
                if self.range != nil && self.autoAdjustMargin == true {
                    if value > self.range!.y {
                        self.range!.y = value
                    }
                    if value < self.range!.x {
                        self.range!.x = value
                    }
                }
            }
            self.node.properties[self.variable] = self.value
            self.titleHover = false
            self.updateLinked()
            self.mmView.update()
        } )
    }
    
    override func randomClicked()
    {
        if isDisabled {
            return
        }
        getNumberDialog(view: mmView, title: title, message: "Enter new random modifier used on instantiation", defaultValue: valueRandom!, int: int, precision: precision, cb: { (value) -> Void in
            let oldValue = self.valueRandom!
            self.valueRandom = value
            self.node.variableChanged(variable: self.variable + "Random", oldValue: oldValue, newValue: self.valueRandom!, continuous: false)

            self.node.properties[self.variable + "Random"] = self.valueRandom!
            self.randomHover = false
            self.mmView.update()
        } )
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if isDisabled {
            return
        }

        let oldValue = value
        
        if mouseIsDown == false {
            undoValue = value
            
            if range == nil {
                stepSize = 1
            }
            
            if int {
                stepSize = Float(Int(stepSize))
            }
        }
        
        mouseIsDown = true
        
        if range != nil {
            if let halfWidthValue = halfWidth {
                var offset : Float = max((event.x - x), 0)
                
                if offset <= width / 2 {
                    let distance = halfWidthValue - range!.x
                    let perPixel = distance / width * 2

                    value = range!.x + perPixel * offset
                } else {
                    offset -= width / 2
                    
                    let distance = range!.y - halfWidthValue
                    let perPixel = distance / width * 2

                    value = halfWidthValue + perPixel * offset
                }
            } else {
                let perPixel = (range!.y - range!.x) / width
                value = range!.x + perPixel * max((event.x - x), 0)
            }
            
            value = max( value, range!.x)
            value = min( value, range!.y)
            
            if int {
                value = Float(Int(value))
            }
            
            if oldValue != value {
                node.variableChanged(variable: variable, oldValue: oldValue, newValue: value, continuous: true)
                updateLinked()
                mmView.update()
            }
        } else {
            func step()
            {
                if mouseIsDown {
                    
                    if (event.x - x) < width / 2 {
                        // Left
                        value -= stepSize
                    } else {
                        // Right
                        value += stepSize
                    }
                    
                    if int {
                        value = Float(Int(value))
                    }
                    
                    if oldValue != value {
                        node.variableChanged(variable: variable, oldValue: oldValue, newValue: value, continuous: true)
                        updateLinked()
                        mmView.update()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        step()
                    }
                }
            }
            step()
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
        if mouseIsDown && range != nil {
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
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        
        x = rect.x
        width = 160 * scale
        let itemHeight = round((14 + NodeUI.contentMargin) * scale)
        
        mmView.drawBox.draw( x: x, y: contentY, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor : adjustColor(NodeUI.contentColor) )
        
        if range != nil {
            
            var offset : Float = 0
            
            if let halfWidthValue = halfWidth {
                
                if value <= halfWidthValue {
                    let distance : Float = halfWidthValue - range!.x
                    let perPixel : Float = width / 2.0 / distance
                    let valueOffset : Float = value - range!.x;

                    offset = valueOffset * perPixel;
                } else {
                    let distance : Float = range!.y - halfWidthValue
                    let perPixel : Float = width / 2.0 / distance;
                    let valueOffset : Float = value - halfWidthValue;

                    offset = width / 2.0 + valueOffset * perPixel;
                }
                
            } else {
                offset = (width / (range!.y - range!.x)) * (value - range!.x)
            }
            
            if offset > 0 && offset != Float.nan && offset != Float.infinity {
                mmView.renderer.setClipRect(MMRect(x, contentY, offset, itemHeight))
                mmView.drawBox.draw( x: x, y: contentY, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor : adjustColor(NodeUI.contentColor2))
                mmView.renderer.setClipRect()
            }
        }
        
        // --- Draw Text
        if contentValue != value {
            contentText = int ? String(Int(value)) : String(format: "%.0\(precision)f", value)
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

/// Number2 class
class NodeUINumber2 : NodeUI
{
    var value       = SIMD2<Float>(0,0)
    var range       : SIMD2<Float>?
    var defaultValue: SIMD2<Float>? = nil
    var mouseIsDown : Bool = false
    var x           : Float = 0
    var width       : Float = 0
    var undoValue   = SIMD2<Float>(0,0)

    var contentLabel: [MMTextLabel?]
    var contentText : [String]
    var contentValue = SIMD2<Float>(0,0)
    
    var subY        : [Float] = [0,0,0]
    
    var labelTexture: [MTLTexture?]
    
    var precision   : Int = 3
    var autoAdjustMargin : Bool = false
    
    var stepSize    : Float = 0
    var sub         : Int = 0
    
    init(_ node: Node, variable: String, title: String, range: SIMD2<Float>? = nil, value: SIMD2<Float> = SIMD2<Float>(0,0), precision: Int = 3)
    {
        self.value = value
        self.defaultValue = value
        self.range = range
        self.precision = precision
        
        contentText = ["", "", ""]
        contentLabel = [nil, nil, nil]
        labelTexture = [nil, nil, nil]

        /*
        if node.properties[variable + "_x"] == nil {
            node.properties[variable + "_x"] = value.x
            node.properties[variable + "_y"] = value.y
            node.properties[variable + "_z"] = value.z
        } else {
            self.value.x = node.properties[variable + "_x"]!
            self.value.y = node.properties[variable + "_y"]!
            self.value.z = node.properties[variable + "_z"]!
        }*/
        
        super.init(node, brand: .Number, variable: variable, title: title)
        supportsTitleHover = true
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
                
        labelTexture[0] = mmView.icons["X_blue"]!
        labelTexture[1] = mmView.icons["Y_red"]!
        
        if titleLabel == nil {
            let scale : Float = 1
            titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
            
            contentValue[0] = 0
            contentValue[1] = 0

            contentText[0] = String(format: "%.0\(precision)f", 0)
            contentText[1] = contentText[0]

            contentLabel[0] = MMTextLabel(mmView, font: mmView.openSans, text: contentText[0], scale: NodeUI.fontScale * scale, color: NodeUI.contentTextColor)
            contentLabel[1] = MMTextLabel(mmView, font: mmView.openSans, text: contentText[1], scale: NodeUI.fontScale * scale, color: NodeUI.contentTextColor)
        }

        rect.width = 160
        rect.height = titleLabel!.rect.height + NodeUI.titleSpacing + (14 + NodeUI.contentMargin + NodeUI.itemSpacing) * 2
    }
    
    override func titleClicked()
    {
        if isDisabled {
            return
        }
        
        getNumber2Dialog(view: mmView, title: title, message: "Enter new value", defaultValue: value, precision: precision, cb: { (value) -> Void in

            self.node.variableChanged(variable: self.variable, oldValue: self.value, newValue: value, continuous: false)
            self.value = value
        
            //self.node.properties[self.variable] = self.value
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
            
            sub = 0
            if event.y > subY[1] {
                sub = 1
            } else
            if event.y > subY[0] {
                sub = 0
            }
            
            if range == nil {
                stepSize = 1
            }
        }
        
        let oldValue : SIMD2<Float> = value
        mouseIsDown = true
        
        if range != nil {
            let perPixel = (range!.y - range!.x) / width

            value[sub] = range!.x + perPixel * max((event.x - x), 0)
            value[sub] = max( value[sub], range!.x)
            value[sub] = min( value[sub], range!.y)
            
            if oldValue != value {
                node.variableChanged(variable: variable, oldValue: oldValue, newValue: value, continuous: true)
                updateLinked()
                mmView.update()
            }
        } else {
            func step()
            {
                if mouseIsDown {
                    
                    if (event.x - x) < width / 2 {
                        // Left
                        value[sub] -= 1
                    } else {
                        // Right
                        value[sub] += 1
                    }
                    
                    if oldValue != value {
                        node.variableChanged(variable: variable, oldValue: oldValue, newValue: value, continuous: true)
                        updateLinked()
                        mmView.update()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if self.mouseIsDown {
                            step()
                        }
                    }
                }
            }
            step()
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false

        if isDisabled {
            return
        }
        //let oldValue = node.properties[variable]!
        //node.properties[variable] = value
        
        // Disabled the check to allow an continuous event to come through for undo / redo
        //if oldValue != value {
            node.variableChanged(variable: variable, oldValue: undoValue, newValue: value)
            updateLinked()
            mmView.update()
        //}
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if mouseIsDown && range != nil {
            mouseDown(event)
        }
    }
    
    override func mouseLeave() {
    }
    
    func updateLinked()
    {
        //if let linked = linkedTo as? NodeUIAngle {
        //    linked.setValue(value)
        //}
    }
    
    override func update() {
        //value = node.properties[variable]!
    }
    
    func getValue() -> SIMD2<Float>
    {
        return SIMD2<Float>(node.properties[variable + "_x"]!, node.properties[variable + "_y"]!)
    }
    
    func setValue(_ value: SIMD2<Float>)
    {
        self.value = value
        node.properties[variable + "_x"] = value.x
        node.properties[variable + "_y"] = value.y
    }
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        
        x = rect.x + 15
        width = 160 * scale - 15
        let itemHeight = round((14 + NodeUI.contentMargin) * scale)
        
        func drawSub(sub: Int)
        {
            let y : Float = contentY + Float(sub) * itemHeight + Float(sub) * NodeUI.itemSpacing
            subY[sub] = y
            
            mmView.drawBox.draw( x: x, y: y, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor : adjustColor(NodeUI.contentColor) )
            
            if range != nil {
                let offset = (width / (range!.y - range!.x)) * (value[sub] - range!.x)
                if offset > 0 {
                    mmView.renderer.setClipRect(MMRect(x, y, offset, itemHeight))
                    mmView.drawBox.draw( x: x, y: y, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor : adjustColor(NodeUI.contentColor2))
                    mmView.renderer.setClipRect()
                }
            }
            
            // --- Draw Text
            if contentValue[sub] != value[sub] {
                contentText[sub] = String(format: "%.0\(precision)f", value[sub])
                contentValue[sub] = value[sub]
            }
            if contentLabel[sub]!.text != contentText[sub] || contentLabel[sub]!.scale != NodeUI.fontScale * scale {
                contentLabel[sub]!.setText(contentText[sub], scale: NodeUI.fontScale * scale)
            }

            contentLabel[sub]!.isDisabled = isDisabled
            contentLabel[sub]!.color = NodeUI.contentTextColor
            contentLabel[sub]!.drawCentered(x: x, y: y, width: width, height: itemHeight)
            
            mmView.drawTexture.draw(labelTexture[sub]!, x: rect.x, y: y + 3, zoom: 3)
        }
        
        drawSub(sub: 0)
        drawSub(sub: 1)
    }
}


/// Number3 class
class NodeUINumber3 : NodeUI
{
    var value       = SIMD3<Float>(0,0,0)
    var valueRandom : SIMD3<Float>? = nil

    var range       : SIMD2<Float>?
    var defaultValue: SIMD3<Float>? = nil
    var mouseIsDown : Bool = false
    var x           : Float = 0
    var width       : Float = 0
    var undoValue   = SIMD3<Float>(0,0,0)

    var contentLabel: [MMTextLabel?]
    var contentText : [String]
    var contentValue = SIMD3<Float>(0,0,0)
    
    var subY        : [Float] = [0,0,0]
    
    var labelTexture: [MTLTexture?]
    
    var precision   : Int = 3
    var autoAdjustMargin : Bool = false
    
    var stepSize    : Float = 0
    var sub         : Int = 0
    
    init(_ node: Node, variable: String, title: String, range: SIMD2<Float>? = nil, value: SIMD3<Float> = SIMD3<Float>(0,0,0), precision: Int = 3, valueRandom: SIMD3<Float>? = nil)
    {
        self.value = value
        self.defaultValue = value
        self.range = range
        self.precision = precision
        self.valueRandom = valueRandom

        contentText = ["", "", ""]
        contentLabel = [nil, nil, nil]
        labelTexture = [nil, nil, nil]

        /*
        if node.properties[variable + "_x"] == nil {
            node.properties[variable + "_x"] = value.x
            node.properties[variable + "_y"] = value.y
            node.properties[variable + "_z"] = value.z
        } else {
            self.value.x = node.properties[variable + "_x"]!
            self.value.y = node.properties[variable + "_y"]!
            self.value.z = node.properties[variable + "_z"]!
        }*/
        
        super.init(node, brand: .Number, variable: variable, title: title)
        if valueRandom != nil {
            supportsRandom = true
        }
        supportsTitleHover = true
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
                
        labelTexture[0] = mmView.icons["X_blue"]!
        labelTexture[1] = mmView.icons["Y_red"]!
        labelTexture[2] = mmView.icons["Z_green"]!
        
        if titleLabel == nil {
            let scale : Float = 1
            titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
            
            contentValue[0] = 0
            contentValue[1] = 0
            contentValue[2] = 0

            contentText[0] = String(format: "%.0\(precision)f", 0)
            contentText[1] = contentText[0]
            contentText[2] = contentText[0]

            contentLabel[0] = MMTextLabel(mmView, font: mmView.openSans, text: contentText[0], scale: NodeUI.fontScale * scale, color: NodeUI.contentTextColor)
            contentLabel[1] = MMTextLabel(mmView, font: mmView.openSans, text: contentText[1], scale: NodeUI.fontScale * scale, color: NodeUI.contentTextColor)
            contentLabel[2] = MMTextLabel(mmView, font: mmView.openSans, text: contentText[2], scale: NodeUI.fontScale * scale, color: NodeUI.contentTextColor)
        }

        rect.width = 160
        rect.height = titleLabel!.rect.height + NodeUI.titleSpacing + (14 + NodeUI.contentMargin + NodeUI.itemSpacing) * 3
    }
    
    override func titleClicked()
    {
        if isDisabled {
            return
        }
        
        getNumber3Dialog(view: mmView, title: title, message: "Enter new value", defaultValue: value, precision: precision, cb: { (value) -> Void in

            self.node.variableChanged(variable: self.variable, oldValue: self.value, newValue: value, continuous: false)
            self.value = value
        
            //self.node.properties[self.variable] = self.value
            self.titleHover = false
            self.updateLinked()
            self.mmView.update()
        } )
    }
    
    override func randomClicked()
    {
        if isDisabled {
            return
        }
        
        getNumber3Dialog(view: mmView, title: title, message: "Enter new random modifier used on instantiation", defaultValue: valueRandom!, precision: precision, cb: { (value) -> Void in

            self.node.variableChanged(variable: self.variable + "Random", oldValue: self.valueRandom!, newValue: value, continuous: false)
            self.valueRandom = value
        
            self.randomHover = false
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
            
            sub = 0
            if event.y > subY[2] {
                sub = 2
            } else
            if event.y > subY[1] {
                sub = 1
            } else
            if event.y > subY[0] {
                sub = 0
            }
            
            if range == nil {
                stepSize = 1
            }
        }
        
        let oldValue : SIMD3<Float> = value
        mouseIsDown = true
        
        if range != nil {
            let perPixel = (range!.y - range!.x) / width

            value[sub] = range!.x + perPixel * max((event.x - x), 0)
            value[sub] = max( value[sub], range!.x)
            value[sub] = min( value[sub], range!.y)
            
            if oldValue != value {
                node.variableChanged(variable: variable, oldValue: oldValue, newValue: value, continuous: true)
                updateLinked()
                mmView.update()
            }
        } else {
            func step()
            {
                if mouseIsDown {
                    
                    if (event.x - x) < width / 2 {
                        // Left
                        value[sub] -= 1
                    } else {
                        // Right
                        value[sub] += 1
                    }
                    
                    if oldValue != value {
                        node.variableChanged(variable: variable, oldValue: oldValue, newValue: value, continuous: true)
                        updateLinked()
                        mmView.update()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if self.mouseIsDown {
                            step()
                        }
                    }
                }
            }
            step()
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false

        if isDisabled {
            return
        }
        //let oldValue = node.properties[variable]!
        //node.properties[variable] = value
        
        // Disabled the check to allow an continuous event to come through for undo / redo
        //if oldValue != value {
            node.variableChanged(variable: variable, oldValue: undoValue, newValue: value)
            updateLinked()
            mmView.update()
        //}
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if mouseIsDown && range != nil {
            mouseDown(event)
        }
    }
    
    override func mouseLeave() {
    }
    
    func updateLinked()
    {
        //if let linked = linkedTo as? NodeUIAngle {
        //    linked.setValue(value)
        //}
    }
    
    override func update() {
        //value = node.properties[variable]!
    }
    
    func getValue() -> SIMD3<Float>
    {
        return SIMD3<Float>(node.properties[variable + "_x"]!, node.properties[variable + "_y"]!, node.properties[variable + "_z"]!)
    }
    
    func setValue(_ value: SIMD3<Float>)
    {
        self.value = value
        node.properties[variable + "_x"] = value.x
        node.properties[variable + "_y"] = value.y
        node.properties[variable + "_z"] = value.z
    }
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        
        x = rect.x + 15
        width = 160 * scale - 15
        let itemHeight = round((14 + NodeUI.contentMargin) * scale)
        
        func drawSub(sub: Int)
        {
            let y : Float = contentY + Float(sub) * itemHeight + Float(sub) * NodeUI.itemSpacing
            subY[sub] = y
            
            mmView.drawBox.draw( x: x, y: y, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor : adjustColor(NodeUI.contentColor) )
            
            if range != nil {
                let offset = (width / (range!.y - range!.x)) * (value[sub] - range!.x)
                if offset > 0 {
                    mmView.renderer.setClipRect(MMRect(x, y, offset, itemHeight))
                    mmView.drawBox.draw( x: x, y: y, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor : adjustColor(NodeUI.contentColor2))
                    mmView.renderer.setClipRect()
                }
            }
            
            // --- Draw Text
            if contentValue[sub] != value[sub] {
                contentText[sub] = String(format: "%.0\(precision)f", value[sub])
                contentValue[sub] = value[sub]
            }
            if contentLabel[sub]!.text != contentText[sub] || contentLabel[sub]!.scale != NodeUI.fontScale * scale {
                contentLabel[sub]!.setText(contentText[sub], scale: NodeUI.fontScale * scale)
            }

            contentLabel[sub]!.isDisabled = isDisabled
            contentLabel[sub]!.color = NodeUI.contentTextColor
            contentLabel[sub]!.drawCentered(x: x, y: y, width: width, height: itemHeight)
            
            mmView.drawTexture.draw(labelTexture[sub]!, x: rect.x, y: y + 3, zoom: 3)
        }
        
        drawSub(sub: 0)
        drawSub(sub: 1)
        drawSub(sub: 2)
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
        
        if titleLabel == nil {
            let scale : Float = 1
            titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
        }
        
        rect.width = 40
        rect.height = titleLabel!.rect.height + NodeUI.titleSpacing + 42 + NodeUI.itemSpacing
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
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)

        x = rect.x
        width = 40 * scale
        
        let itemHeight =  rect.height * scale
        
        let length : Float = 17
        
        let x0: Float = x + length * scale
        let y0: Float = rect.y + itemHeight / 2 + 2
        
        for i:Float in stride(from: 0, to: 360, by: 20) {
            
            let cosValue : Float = cos(i * Float.pi / 180)
            let sinValue : Float = sin(i * Float.pi / 180)
            
            let x1: Float = x0 + cosValue * (length-5) * scale
            let y1: Float = y0 + sinValue * (length-5) * scale
            let x2: Float = x0 + cosValue * length * scale
            let y2: Float = y0 + sinValue * length * scale
            
            mmView.drawLine.draw(sx: x1, sy: y1, ex: x2, ey: y2, radius: 1, fillColor: NodeUI.contentColor)
        }
        
        let x1: Float = x0 + cos(value * Float.pi / 180) * length * scale
        let y1: Float = y0 + sin(value * Float.pi / 180) * length * scale
        
        mmView.drawLine.draw(sx: x0, sy: y0, ex: x1, ey: y1, radius: 1, fillColor: SIMD4<Float>(repeating: 1))
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
    
    var contentLabel: MMTextLabel!

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
        
        if titleLabel == nil {
            let scale : Float = 1
            titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
            contentLabel = MMTextLabel(mmView, font: mmView.openSans, text: "", scale: NodeUI.fontScale * scale, color: NodeUI.contentTextColor)
        }
        
        rect.width = 160
        rect.height = titleLabel!.rect.height + NodeUI.titleSpacing + 14 + NodeUI.contentMargin + NodeUI.itemSpacing
    }
    
    override func titleClicked()
    {
        if isDisabled {
            return
        }
        let old = value
        getStringDialog(view: mmView, title: title, message: "Enter new value", defaultValue: value, cb: { (value) -> Void in
            self.value = value
            self.oldValue = old
            self.titleHover = false
            self.updateLinked()
            self.mmView.update()
            self.node.variableChanged(variable: self.variable, oldValue: old, newValue: value, continuous: false)
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
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        
        x = rect.x
        width = 160 * scale
        
        let itemHeight = (14 + NodeUI.contentMargin) * scale

        mmView.drawBox.draw( x: x, y: contentY, width: width, height: itemHeight, round: NodeUI.contentRound * scale, borderSize: 0, fillColor : NodeUI.contentColor)
        
        //mmView.drawText.drawTextCentered(mmView.openSans, text: value, x: x, y: contentY, width: width, height: itemHeight - 6, scale: NodeUI.fontScale * scale, color: NodeUI.contentTextColor)
        
        if contentLabel.text != value || contentLabel.scale != NodeUI.fontScale * scale {
            contentLabel.setText(value, scale: NodeUI.fontScale * scale)
        }

        contentLabel!.isDisabled = isDisabled
        contentLabel.color = NodeUI.contentTextColor
        if contentLabel.rect.width < width {
            contentLabel.drawCentered(x: x, y: contentY, width: width, height: itemHeight)
        } else {
            mmView.renderer.setClipRect(MMRect(x + 10, contentY, width - 20, itemHeight))
            contentLabel.drawCenteredY(x: x + 10, y: contentY, width: width - 20, height: itemHeight)
            mmView.renderer.setClipRect()
        }
    }
}

/// Color class
class NodeUIColor : NodeUI
{
    var value       : SIMD3<Float>
    var defaultValue: SIMD3<Float>
    var mouseIsDown : Bool = false
    var x           : Float = 0
    var width       : Float = 0
    
    var prevSize    : SIMD2<Float> = SIMD2<Float>(120,120)
    
    var colorWidget : MMColorWidget? = nil
    var undoValue   : SIMD3<Float> = SIMD3<Float>()
    
    init(_ node: Node, variable: String, title: String, value: SIMD3<Float> = SIMD3<Float>(0,0,0))
    {
        self.value = value
        self.defaultValue = value
    
        super.init(node, brand: .Number, variable: variable, title: title)

        if node.properties[variable + "_x"] == nil {
            setValue(value)
        } else {
            self.value = getValue()
        }
        supportsTitleHover = true
    }
    
    override func calcSize(mmView: MMView) {
        self.mmView = mmView
        
        if titleLabel == nil {
            let scale : Float = 1
            titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.titleFontScale * scale, color: NodeUI.titleTextColor)
        }
        
        rect.width = prevSize.x
        rect.height = prevSize.y + 15 + NodeUI.itemSpacing
        
        if colorWidget == nil {
            colorWidget = MMColorWidget(mmView, value: value)
            colorWidget?.changed = { (val, cont) in
                if self.undoValue != val {
                    self.setValue(val)
                    self.node.variableChanged(variable: self.variable, oldValue: self.undoValue, newValue: self.getValue(), continuous: cont)
                    mmView.update()
                }
            }
        }
    }
    
    override func titleClicked()
    {
        if isDisabled {
            return
        }
        let old = value
        getStringDialog(view: mmView, title: title, message: "Enter new value", defaultValue: toHex(value), cb: { (string) -> Void in
            self.setValue(fromHex(hexString: string))
            self.titleHover = false
            self.mmView.update()
            self.node.variableChanged(variable: self.variable, oldValue: old, newValue: self.value, continuous: false)
        } )
        return
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if isDisabled { return }
        undoValue = getValue()
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
    
    func getValue() -> SIMD3<Float>
    {
        return SIMD3<Float>(node.properties[variable + "_x"]!, node.properties[variable + "_y"]!, node.properties[variable + "_z"]!)
    }
    
    func setValue(_ value: SIMD3<Float>)
    {
        self.value = value
        node.properties[variable + "_x"] = value.x
        node.properties[variable + "_y"] = value.y
        node.properties[variable + "_z"] = value.z
        if let widget = colorWidget {
            if widget.value != value {
                widget.setValue(color: value)
            }
        }
    }
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        x = rect.x
        
        if let widget = colorWidget {
            widget.rect.x = x
            widget.rect.y = contentY
            widget.rect.width = prevSize.x * scale
            widget.rect.height = widget.rect.width
            widget.isDisabled = isDisabled
            
            widget.draw()
        }
    }
}

class NodeUIImage : NodeUISelector
{
    var previewTexture      : MTLTexture? = nil
    var previewIndex        : Float = -1
    
    var menuNode            : Node!
    var menuNode2           : Node!
    var menu                : NodeUIMenu!
    
    var oRect               = MMRect()
    var fragment            : CodeFragment
    
    init(_ node: Node, variable: String, title: String, items: [String], index: Float = 0, shadows: Bool = false, fragment: CodeFragment)
    {
        self.fragment = fragment
        super.init(node, variable: variable, title: title, items: items, index: index, shadows: shadows)
    }
    
    override func calcSize(mmView: MMView) {
        
        super.calcSize(mmView: mmView)
        
        oRect.copy(rect)
        
        rect.width = 190
        rect.height += 90
        
        menuNode = Node()
        menuNode2 = Node()

        let imageScale = NodeUINumber(menuNode, variable: "imageScale", title: "Scale", range: SIMD2<Float>(0, 10), value: fragment.values["imageScale"]!, precision: 4, halfWidthValue: 1)
        menuNode.uiItems.append(imageScale)

        menuNode.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
            if let cb = self.node.floatChangedCB {
                cb(variable, oldValue, newValue, continous, noUndo)
            }
            self.generatePreview()
        }
                
        menu = NodeUIMenu(mmView, node: menuNode)
        menu.shadows = titleShadows
        menu.menuType = .BoxedMenu
        menu.rect.width /= 1.2
        menu.rect.height /= 1.2
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if menu.rect.contains(event.x, event.y) {
            menu.mouseDown(event)
        } else
        if oRect.contains(event.x - rect.x, event.y - rect.y) {
            super.mouseDown(event)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if menu.rect.contains(event.x, event.y) {
            menu.mouseUp(event)
        } else
        if oRect.contains(event.x - rect.x, event.y - rect.y) {
            super.mouseUp(event)
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if menu.rect.contains(event.x, event.y) {
            menu.mouseMoved(event)
        } else
        if oRect.contains(event.x - rect.x, event.y - rect.y) {
            super.mouseMoved(event)
        }
    }
    
    func generatePreview()
    {
        previewTexture = generateImagePreview(domain: "image", imageIndex: index, width: rect.width, height: 85, fragment: fragment)
        previewIndex = index
    }
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        
        if previewIndex != index {
            generatePreview()
        }
        
        if let texture = previewTexture {
            mmView.drawTexture.draw(texture, x: rect.x, y: rect.y + 50, round: 12, roundingRect: SIMD4<Float>(0, 0, Float(texture.width), Float(texture.height)))
        }
        
        menu.rect.x = rect.right() - menu.rect.width
        menu.rect.y = rect.y + 13
        
        if menu.states.contains(.Opened) {
            mmView.delayedDraws.append(menu)
        } else {
            menu.draw()
        }
    }
}

class NodeUINoise2D : NodeUISelector
{
    var previewTexture      : MTLTexture? = nil
    var previewIndex        : Float = -1
    
    var menuNode            : Node!
    var menuNode2           : Node!
    var menu                : NodeUIMenu!
    
    var oRect               = MMRect()
    var fragment            : CodeFragment
    
    init(_ node: Node, variable: String, title: String, items: [String], index: Float = 0, shadows: Bool = false, fragment: CodeFragment)
    {
        self.fragment = fragment
        super.init(node, variable: variable, title: title, items: items, index: index, shadows: shadows)
    }
    
    override func calcSize(mmView: MMView) {
        
        super.calcSize(mmView: mmView)
        
        oRect.copy(rect)
        
        rect.width = 170
        rect.height += 90
        
        menuNode = Node()
        menuNode2 = Node()

        let baseOctaves = NodeUINumber(menuNode, variable: "noiseBaseOctaves", title: "Base Octaves", range: SIMD2<Float>(1, 10), int: true, value: fragment.values["noiseBaseOctaves"]!)
        menuNode.uiItems.append(baseOctaves)
        
        let basePersistance = NodeUINumber(menuNode, variable: "noiseBasePersistance", title: "Base Persistance", range: SIMD2<Float>(0, 2), value: fragment.values["noiseBasePersistance"]!)
        menuNode.uiItems.append(basePersistance)
        
        let baseScale = NodeUINumber(menuNode, variable: "noiseBaseScale", title: "Base Scale", range: SIMD2<Float>(0, 10), value: fragment.values["noiseBaseScale"]!, halfWidthValue: 1)
        menuNode.uiItems.append(baseScale)
        
        let noiseIndex = fragment.values["noiseMix2D"] == nil ? 0 : fragment.values["noiseMix2D"]!
        let mixNoise = NodeUISelector(menuNode2, variable: "noiseMix2D", title: "Mix Noise", items: ["None"] + getAvailable2DNoises().0, index: noiseIndex)
        menuNode2.uiItems.append(mixNoise)
        
        let mixOctaves = NodeUINumber(menuNode2, variable: "noiseMixOctaves", title: "Mix Octaves", range: SIMD2<Float>(1, 10), int: true, value: fragment.values["noiseMixOctaves"]!)
        menuNode2.uiItems.append(mixOctaves)
        
        let mixPersistance = NodeUINumber(menuNode2, variable: "noiseMixPersistance", title: "Mix Persistance", range: SIMD2<Float>(0, 2), value: fragment.values["noiseMixPersistance"]!)
        menuNode2.uiItems.append(mixPersistance)
        
        let mixScale = NodeUINumber(menuNode2, variable: "noiseMixScale", title: "Mix Scale", range: SIMD2<Float>(0, 10), value: fragment.values["noiseMixScale"]!, halfWidthValue: 1)
        menuNode2.uiItems.append(mixScale)
        
        let mixDisturbance = NodeUINumber(menuNode2, variable: "noiseMixDisturbance", title: "Disturbance", range: SIMD2<Float>(0, 2), value: fragment.values["noiseMixDisturbance"]!)
        menuNode2.uiItems.append(mixDisturbance)
        
        let mixValue = NodeUINumber(menuNode, variable: "noiseMixValue", title: "Mix", range: SIMD2<Float>(0, 1), value: fragment.values["noiseMixValue"]!)
        menuNode.uiItems.append(mixValue)
        
        let noiseResultScale = NodeUINumber(menuNode, variable: "noiseResultScale", title: "Result Scale", range: SIMD2<Float>(0, 2), value: fragment.values["noiseResultScale"]!)
        menuNode.uiItems.append(noiseResultScale)
        
        func disableItems() {
            var disableMix = false
            if mixNoise.items[Int(mixNoise.index)] == "None" {
                disableMix = true
            }
            mixOctaves.isDisabled = disableMix
            mixPersistance.isDisabled = disableMix
            mixScale.isDisabled = disableMix
            mixDisturbance.isDisabled = disableMix
            mixValue.isDisabled = disableMix
        }
        
        disableItems()

        menuNode.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
            disableItems()
            if let cb = self.node.floatChangedCB {
                cb(variable, oldValue, newValue, continous, noUndo)
            }
            self.generatePreview()
        }
        
        menuNode2.floatChangedCB = menuNode.floatChangedCB
        
        menu = NodeUIMenu(mmView, node: menuNode, node2: menuNode2, offset: 49)
        menu.shadows = titleShadows
        menu.menuType = .BoxedMenu
        menu.rect.width /= 1.2
        menu.rect.height /= 1.2
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if menu.rect.contains(event.x, event.y) {
            menu.mouseDown(event)
        } else
        if oRect.contains(event.x - rect.x, event.y - rect.y) {
            super.mouseDown(event)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if menu.rect.contains(event.x, event.y) {
            menu.mouseUp(event)
        } else
        if oRect.contains(event.x - rect.x, event.y - rect.y) {
            super.mouseUp(event)
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if menu.rect.contains(event.x, event.y) {
            menu.mouseMoved(event)
        } else
        if oRect.contains(event.x - rect.x, event.y - rect.y) {
            super.mouseMoved(event)
        }
    }
    
    func generatePreview()
    {
        previewTexture = generateNoisePreview2D(domain: "noise2D", noiseIndex: index, width: rect.width, height: 85, fragment: fragment)
        previewIndex = index
    }
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        
        if previewIndex != index {
            generatePreview()
        }
        
        if let texture = previewTexture {
            mmView.drawTexture.draw(texture, x: rect.x, y: rect.y + 50, round: 12, roundingRect: SIMD4<Float>(0, 0, Float(texture.width), Float(texture.height)))
        }
        
        menu.rect.x = rect.right() - menu.rect.width
        menu.rect.y = rect.y + 13
        
        if menu.states.contains(.Opened) {
            mmView.delayedDraws.append(menu)
        } else {
            menu.draw()
        }
    }
}

class NodeUINoise3D : NodeUISelector
{
    var previewTexture      : MTLTexture? = nil
    var previewIndex        : Float = -1
    
    var menuNode            : Node!
    var menuNode2           : Node!
    var menu                : NodeUIMenu!
    
    var oRect               = MMRect()
    var fragment            : CodeFragment
    
    init(_ node: Node, variable: String, title: String, items: [String], index: Float = 0, shadows: Bool = false, fragment: CodeFragment)
    {
        self.fragment = fragment
        super.init(node, variable: variable, title: title, items: items, index: index, shadows: shadows)
    }
    
    override func calcSize(mmView: MMView) {
        
        super.calcSize(mmView: mmView)
        
        oRect.copy(rect)
        
        rect.width = 170
        rect.height += 90
        
        menuNode = Node()
        menuNode2 = Node()

        let baseOctaves = NodeUINumber(menuNode, variable: "noiseBaseOctaves", title: "Base Octaves", range: SIMD2<Float>(1, 10), int: true, value: fragment.values["noiseBaseOctaves"]!)
        menuNode.uiItems.append(baseOctaves)
        
        let basePersistance = NodeUINumber(menuNode, variable: "noiseBasePersistance", title: "Base Persistance", range: SIMD2<Float>(0, 2), value: fragment.values["noiseBasePersistance"]!)
        menuNode.uiItems.append(basePersistance)
        
        let baseScale = NodeUINumber(menuNode, variable: "noiseBaseScale", title: "Base Scale", range: SIMD2<Float>(0, 10), value: fragment.values["noiseBaseScale"]!, halfWidthValue: 1)
        menuNode.uiItems.append(baseScale)
        
        let noiseIndex = fragment.values["noiseMix3D"] == nil ? 0 : fragment.values["noiseMix3D"]!
        let mixNoise = NodeUISelector(menuNode2, variable: "noiseMix3D", title: "Mix Noise", items: ["None"] + getAvailable3DNoises().0, index: noiseIndex)
        menuNode2.uiItems.append(mixNoise)
        
        let mixOctaves = NodeUINumber(menuNode2, variable: "noiseMixOctaves", title: "Mix Octaves", range: SIMD2<Float>(1, 10), int: true, value: fragment.values["noiseMixOctaves"]!)
        menuNode2.uiItems.append(mixOctaves)
        
        let mixPersistance = NodeUINumber(menuNode2, variable: "noiseMixPersistance", title: "Mix Persistance", range: SIMD2<Float>(0, 2), value: fragment.values["noiseMixPersistance"]!)
        menuNode2.uiItems.append(mixPersistance)
        
        let mixScale = NodeUINumber(menuNode2, variable: "noiseMixScale", title: "Mix Scale", range: SIMD2<Float>(0, 10), value: fragment.values["noiseMixScale"]!, halfWidthValue: 1)
        menuNode2.uiItems.append(mixScale)
        
        let mixDisturbance = NodeUINumber(menuNode2, variable: "noiseMixDisturbance", title: "Disturbance", range: SIMD2<Float>(0, 2), value: fragment.values["noiseMixDisturbance"]!)
        menuNode2.uiItems.append(mixDisturbance)
        
        let mixValue = NodeUINumber(menuNode, variable: "noiseMixValue", title: "Mix", range: SIMD2<Float>(0, 1), value: fragment.values["noiseMixValue"]!)
        menuNode.uiItems.append(mixValue)
        
        let noiseResultScale = NodeUINumber(menuNode, variable: "noiseResultScale", title: "Result Scale", range: SIMD2<Float>(0, 2), value: fragment.values["noiseResultScale"]!)
        menuNode.uiItems.append(noiseResultScale)
        
        func disableItems() {
            var disableMix = false
            if mixNoise.items[Int(mixNoise.index)] == "None" {
                disableMix = true
            }
            mixOctaves.isDisabled = disableMix
            mixPersistance.isDisabled = disableMix
            mixScale.isDisabled = disableMix
            mixDisturbance.isDisabled = disableMix
            mixValue.isDisabled = disableMix
        }
        
        disableItems()

        menuNode.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
            disableItems()
            if let cb = self.node.floatChangedCB {
                cb(variable, oldValue, newValue, continous, noUndo)
            }
            self.generatePreview()
        }
        
        menuNode2.floatChangedCB = menuNode.floatChangedCB
        
        menu = NodeUIMenu(mmView, node: menuNode, node2: menuNode2, offset: 49)
        menu.shadows = titleShadows
        menu.menuType = .BoxedMenu
        menu.rect.width /= 1.2
        menu.rect.height /= 1.2
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if menu.rect.contains(event.x, event.y) {
            menu.mouseDown(event)
        } else
        if oRect.contains(event.x - rect.x, event.y - rect.y) {
            super.mouseDown(event)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if menu.rect.contains(event.x, event.y) {
            menu.mouseUp(event)
        } else
        if oRect.contains(event.x - rect.x, event.y - rect.y) {
            super.mouseUp(event)
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if menu.rect.contains(event.x, event.y) {
            menu.mouseMoved(event)
        } else
        if oRect.contains(event.x - rect.x, event.y - rect.y) {
            super.mouseMoved(event)
        }
    }
    
    func generatePreview()
    {
        previewTexture = generateNoisePreview3D(domain: "noise3D", noiseIndex: index, width: rect.width, height: 85, fragment: fragment)
        previewIndex = index
    }
    
    override func draw(mmView: MMView, maxTitleSize: SIMD2<Float>, maxWidth: Float, scale: Float)
    {
        super.draw(mmView: mmView, maxTitleSize: maxTitleSize, maxWidth: maxWidth, scale: scale)
        
        if previewIndex != index {
            generatePreview()
        }
        
        if let texture = previewTexture {
            mmView.drawTexture.draw(texture, x: rect.x, y: rect.y + 50, round: 12, roundingRect: SIMD4<Float>(0, 0, Float(texture.width), Float(texture.height)))
        }
        
        menu.rect.x = rect.right() - menu.rect.width
        menu.rect.y = rect.y + 13
        
        if menu.states.contains(.Opened) {
            mmView.delayedDraws.append(menu)
        } else {
            menu.draw()
        }
    }
}

/// NodeUI Menu
class NodeUIMenu : MMWidget
{
    enum MenuType {
        case BoxedMenu, LabelMenu, Hidden
    }
    
    var menuType    : MenuType = .BoxedMenu
    
    var skin        : MMSkinMenuWidget
    var menuRect    : MMRect
 
    var items       : [MMMenuItem] = []
    
    var selIndex    : Int = -1
    var itemHeight  : Int = 0
    
    var firstClick  : Bool = false
    
    var textLabel   : MMTextLabel? = nil
    
    var node        : Node
    var node2       : Node? = nil
    var pWidget     : PropertiesWidget!
    
    var offset      : Float = 0
    
    var shadows     : Bool = false
    
    init( _ view: MMView, skinToUse: MMSkinMenuWidget? = nil, type: MenuType = .BoxedMenu, node: Node, node2: Node? = nil, offset: Float = 0)
    {
        self.node = node
        self.node2 = node2
        self.offset = offset

        skin = skinToUse != nil ? skinToUse! : view.skin.MenuWidget
        menuRect = MMRect( 0, 0, 0, 0)
        
        self.menuType = type
        
        super.init(view)
        
        name = "NodeUIMenu"
        
        if menuType != .Hidden {
            rect.width = skin.button.width
            rect.height = skin.button.height
        } else {
            rect.width = 0
            rect.height = 0
        }
        
        validStates = [.Checked]
                
        pWidget = PropertiesWidget(view)
        
        node.setupUI(mmView: view)
        pWidget.c1Node = node
        
        menuRect = MMRect()
        menuRect.width = node.uiArea.width
        menuRect.height = node.uiArea.height + offset
        //menuRect.width += skin.margin.width()
        menuRect.height += skin.margin.height()
        
        if let node2 = node2 {
            node2.setupUI(mmView: view)
            pWidget.c2Node = node2
            
            menuRect.width += node2.uiArea.width
            //menuRect.width += skin.margin.width()
            menuRect.height = max(menuRect.height, node2.uiArea.height + skin.margin.height())
        } else {
            menuRect.width += skin.margin.width()
        }
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
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        #endif
        
        if !states.contains(.Opened) {
            
            addState( .Checked )
            addState( .Opened )
            firstClick = true
        
            mmView.widgets.insert(pWidget, at: 0)
            mmView.openPopups.append(pWidget)
        } else {
            #if os(OSX)

            if states.contains(.Opened) && selIndex > -1 {
                removeState( .Opened )
            }
            removeState( .Checked )
            removeState( .Opened )
            if !rect.contains(event.x, event.y) {
                removeState( .Hover )
            }
            mmView.deregisterWidget(pWidget)
            #endif
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        #if os(iOS)

        if states.contains(.Opened) && (firstClick == false || (selIndex > -1 && selIndex < items.count)) {

            if states.contains(.Opened) && selIndex > -1 && selIndex < items.count {
                removeState( .Opened )
            }
            removeState( .Checked )
            removeState( .Opened )
            mmView.deregisterWidget(pWidget)
        }
        
        removeState( .Clicked )
        
        firstClick = false
        #endif
    }
    
    /// If the menu is of type hidden, activates the menu
    func activateHidden()
    {
        addState( .Checked )
        addState( .Opened )
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
            if shadows {
                var color = SIMD4<Float>(NodeUI.contentColor2)
                color.w = 0.4
                mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 4, borderSize: 0, fillColor : color)
            }
            mmView.drawBoxedMenu.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: skin.button.round, borderSize: skin.button.borderSize, fillColor : fColor, borderColor: skin.button.borderColor)
        } else
        if menuType == .LabelMenu {
            if let label = textLabel {
                mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 4, borderSize: 0, fillColor : fColor)
                label.drawCentered(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
            }
        }
        
        if states.contains(.Opened) {
            
            if mmView.openPopups.contains(pWidget) == false {
                removeState(.Opened)
                removeState(.Hover)
                removeState(.Checked)
                removeState(.Clicked)
                return
            }
            
            var x = rect.x + menuRect.width + 4
            var y = rect.y - rect.height
            
            if menuType != .Hidden {
                x += rect.width - menuRect.width
                y += rect.height
            }

            pWidget.rect.x = x
            pWidget.rect.y = y
            pWidget.rect.width = menuRect.width
            pWidget.rect.height = menuRect.height
            
            if pWidget.rect.bottom() > mmView.renderer.cHeight {
                y -= pWidget.rect.bottom() - mmView.renderer.cHeight! + 5
                pWidget.rect.y = y
            }
            
            if node2 != nil {
                pWidget.rect.width -= skin.margin.width() * 2
            }
            
            mmView.drawBox.draw( x: x, y: y, width: pWidget.rect.width, height: menuRect.height, round: skin.round, borderSize: skin.borderSize, fillColor : skin.color, borderColor: skin.borderColor )

            x += skin.margin.left//rect.width - menuRect.width
            y += skin.margin.top
            
            if states.contains(.Opened) {
                node.rect.x = x - pWidget.rect.x
                node.rect.y = y - pWidget.rect.y + offset
                
                if let node2 = node2 {
                    node.rect.x += skin.margin.left
                    node2.rect.x = node.rect.x + node.uiArea.width - skin.margin.width() * 2
                    node2.rect.y = y - pWidget.rect.y
                }
             
                pWidget.draw(xOffset: xOffset, yOffset: yOffset)
            }
        }
    }
}
