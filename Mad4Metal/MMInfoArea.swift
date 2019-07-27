//
//  MMInfoArea.swift
//  Shape-Z
//
//  Created by Markus Moenig on 27/7/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class MMInfoAreaItem {
    
    var mmView      : MMView
    var title       : String
    var variable    : String
    var value       : Float
    var rect        : MMRect
    var scale       : Float
    var range       : float2
    var int         : Bool
    
    var titleLabel  : MMTextLabel
    var valueLabel  : MMTextLabel
    
    var cb          : ((Float, Float) -> ())?
    
    init(_ mmView: MMView,_ title: String,_ variable: String,_ value: Float, scale: Float = 0.3, int: Bool = false, range: float2 = float2(-100000, 100000), cb: ((Float, Float) -> ())? = nil)
    {
        self.mmView = mmView
        self.title = title
        self.variable = variable
        self.value = value
        self.scale = scale
        self.cb = cb
        self.range = range
        self.int = int
        
        rect = MMRect()
        
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: scale )
        valueLabel = MMTextLabel(mmView, font: mmView.openSans, text: int ? String(Int(value)) : String(format: "%.02f", value), scale: scale )
    }
    
    func setValue(_ value: Float)
    {
        self.value = value
        if !int {
            valueLabel.setText(String(format: "%.02f", value))
        } else {
            valueLabel.setText(String(Int(value)))
        }
    }
}

class MMInfoArea : MMWidget {
    
    var items           : [MMInfoAreaItem] = []
    var hoverItem       : MMInfoAreaItem? = nil
    var scale           : Float
    
    init(_ mmView: MMView, scale: Float = 0.3)
    {
        self.scale = scale
        super.init(mmView)
    }
    
    func reset()
    {
        items = []
        hoverItem = nil
    }
    
    func addItem(_ title: String,_ variable: String,_ value: Float, int: Bool = false, range: float2 = float2(-100000, 100000), cb: ((Float, Float) -> ())? = nil) -> MMInfoAreaItem
    {
        let item = MMInfoAreaItem(mmView, title, variable, value, scale: scale, int: int, range: range, cb: cb)
        items.append(item)
        computeSize()
        return item
    }
    
    func updateItem(_ variable: String,_ value: Float)
    {
        for item in items {
            if item.variable == variable {
                item.setValue(value)
            }
        }
        computeSize()
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        let oldHoverItem : MMInfoAreaItem? = hoverItem
        hoverItem = nil
        
        for item in items {
            if item.rect.contains(event.x, event.y) {
                hoverItem = item
                break
            }
        }
        
        if oldHoverItem !== hoverItem {
            mmView.update()
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        _ = mouseMoved(event)
        if let item = hoverItem {
            
            getNumberDialog(view: mmView, title: item.title, message: "Enter new value", defaultValue: item.value, cb: { (value) -> Void in
                if let cb = item.cb {
                    if value >= item.range.x && value <= item.range.y {
                        cb(item.value, value)
                        item.setValue(value)
                        self.computeSize()
                        self.mmView.update()
                    }
                }
            } )
        }
    }
    
    override func mouseLeave(_ event: MMMouseEvent) {
        hoverItem = nil
    }
    
    func computeSize()
    {
        var width   : Float = 0
        var height  : Float = 0
        
        for item in items {
            width += item.titleLabel.rect.width + 5
            width += item.valueLabel.rect.width + 10
            
            height = max(item.valueLabel.rect.height, height)
        }
        rect.width = width + 5
        rect.height = height + 5
    }
    
    func draw()
    {
        if items.isEmpty { return }
        
        var x : Float = rect.x + 5
        
        for item in items {
            
            if item === hoverItem {
                mmView.drawBox.draw( x: item.rect.x, y: item.rect.y, width: item.rect.width, height: item.rect.height, round: 4, borderSize: 0, fillColor : mmView.skin.ToolBarButton.hoverColor )
            }
            
            item.titleLabel.rect.x = x
            item.titleLabel.rect.y = rect.y
            item.titleLabel.draw()
            
            item.rect.x = x - 4
            item.rect.y = item.titleLabel.rect.y - 0.5
            item.rect.height = rect.height
            
            x += item.titleLabel.rect.width + 5
            
            item.valueLabel.rect.x = x
            item.valueLabel.rect.y = item.titleLabel.rect.y
            item.valueLabel.draw()
            
            x += item.valueLabel.rect.width + 10
            
            item.rect.width = x - item.rect.x - 6
        }
    }
}
