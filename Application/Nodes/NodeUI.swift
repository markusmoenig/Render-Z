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
        case DropDown, KeyDown
    }
    
    var brand       : Brand
    var node        : Node
    var variable    : String
    var title       : String
    
    var rect        : MMRect = MMRect()
    var titleLabel  : MMTextLabel? = nil
    
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
    
    func calcSize(mmView: MMView)
    {
        rect.width = 100
        rect.height = 20
    }
    
    func draw(mmView: MMView, maxTitleSize: float2, scale: Float)
    {
    }
}

/// Drop down NodeUI class
class NodeUIDropDown : NodeUI
{
    var items       : [String]
    var index       : Float
    var open        : Bool = false
    
    var itemHeight  : Float = 0
    
    init(_ node: Node, variable: String, title: String, items: [String], index: Float = 0)
    {
        self.items = items
        self.index = index
        
        if node.properties[variable] == nil {
            node.properties[variable] = index
        } else {
            self.index = node.properties[variable]!
        }
        
        super.init(node, brand: .DropDown, variable: variable, title: title)
    }
    
    override func calcSize(mmView: MMView) {
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: NodeUI.fontScale)

        rect.width = titleLabel!.rect.width + NodeUI.titleMargin.width() + NodeUI.titleSpacing + 80
        rect.height = titleLabel!.rect.height + NodeUI.titleMargin.height()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        open = true
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if open {
            node.properties[variable] = index
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
            }
        }
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, scale: Float)
    {
//        mmView.drawBox.draw( x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale, round: 0, borderSize: 1 * scale, fillColor : float4(0), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
        
        if titleLabel!.scale != NodeUI.fontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.fontScale * scale)
        }
        titleLabel!.drawRightCenteredY(x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale)
        
        let x = rect.x + maxTitleSize.x * scale + NodeUI.titleSpacing * scale
        let width = 80 * scale//rect.width * scale - maxTitleSize.x * scale - NodeUI.titleSpacing * scale
        itemHeight =  rect.height * scale
        
        let skin = mmView.skin.MenuWidget
        
        if !open {
            mmView.drawBox.draw( x: x, y: rect.y, width: width, height: itemHeight, round: 0, borderSize: 1, fillColor : skin.color, borderColor: skin.borderColor )
            
            mmView.drawText.drawTextCentered(mmView.openSans, text: items[Int(index)], x: x, y: rect.y, width: width, height: itemHeight, scale: NodeUI.fontScale * scale, color: skin.textColor)
        } else {
            mmView.drawBox.draw( x: x, y: rect.y, width: width, height: itemHeight * Float(items.count), round: 0, borderSize: 1, fillColor : skin.color, borderColor: skin.borderColor )
            
            var itemY : Float = rect.y
            for (ind,item) in items.enumerated() {
                
                let textColor = Float(ind) == index ? float4(1) : skin.textColor
                mmView.drawText.drawTextCentered(mmView.openSans, text: item, x: x, y: itemY, width: width, height: itemHeight, scale: NodeUI.fontScale * scale, color: textColor)
                itemY += itemHeight
            }
        }
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
            let desc = keyCodes[UInt16(keyCode)]
            if desc != nil {
                keyText = desc!
            }
        }
        
        super.init(node, brand: .KeyDown, variable: variable, title: title)
    }
    
    override func calcSize(mmView: MMView) {
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
        node.properties[variable] = keyCode
    }
    
    override func draw(mmView: MMView, maxTitleSize: float2, scale: Float)
    {
        if titleLabel!.scale != NodeUI.fontScale * scale {
            titleLabel!.setText(title, scale: NodeUI.fontScale * scale)
        }
        titleLabel!.drawRightCenteredY(x: rect.x, y: rect.y, width: maxTitleSize.x * scale, height: maxTitleSize.y * scale)
        
        let x = rect.x + maxTitleSize.x * scale + NodeUI.titleSpacing * scale
        let width = 120 * scale
        let height = rect.height * scale
        
        let skin = mmView.skin.MenuWidget
        
        mmView.drawBox.draw( x: x, y: rect.y, width: width, height: height, round: 0, borderSize: 1, fillColor : skin.color, borderColor: skin.borderColor )
        
        mmView.drawText.drawTextCentered(mmView.openSans, text: keyText, x: x, y: rect.y, width: width, height: height, scale: NodeUI.fontScale * scale, color: skin.textColor)
    }
}
