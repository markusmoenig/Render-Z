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
        case DropDown
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
    static let titleMargin : MMMargin = MMMargin(5, 5, 5, 5)
    static let titleSpacing : Float = 5

    init(_ node : Node, brand: Brand, variable: String, title: String)
    {
        self.node = node
        self.brand = .DropDown
        self.variable = variable
        self.title = title
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
class NodeDropDown : NodeUI
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
                
                let textColor = Float(ind) == index ? skin.selTextColor : skin.textColor
                mmView.drawText.drawTextCentered(mmView.openSans, text: item, x: x, y: itemY, width: width, height: itemHeight, scale: NodeUI.fontScale * scale, color: textColor)
                itemY += itemHeight
            }
        }
    }
}
