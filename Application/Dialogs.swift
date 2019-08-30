//
//  Dialogs.swift
//  Shape-Z
//
//  Created by Markus Moenig on 29/8/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class TemplateChooserItem {
    
    var fileName            : String = ""
    var description         : String = ""

    var titleLabel          : MMTextLabel
    var descriptionLabel    : MMTextLabel
    var rect                : MMRect = MMRect()
    
    init(_ mmView: MMView,_ title: String, _ fileName: String = "", _ description: String = "")
    {
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title)
        descriptionLabel = MMTextLabel(mmView, font: mmView.openSans, text: description, scale: 0.36, color: float4(mmView.skin.Item.textColor))
        self.fileName = fileName
    }
}

class MMTemplateChooser : MMDialog {
    
    var items           : [TemplateChooserItem] = []

    var hoverItem       : TemplateChooserItem? = nil
    var selItem         : TemplateChooserItem? = nil

    init(_ view: MMView) {
        super.init(view, title: "Choose Project Template", cancelText: "", okText: "Create Project")
        
        rect.width = 600
        rect.height = 400
        
        items.append( TemplateChooserItem(mmView, "Empty Project" ) )
        items.append( TemplateChooserItem(mmView, "Pinball", "Pinball", "Physics" ) )
        items.append( TemplateChooserItem(mmView, "Pong", "Pong", "Customized Physics (Collision), AI" ) )
        
        widgets.append(self)
        selItem = items[0]
    }
    
    override func ok() {
        super.ok()
        
        if let selected = selItem {
            if !selected.fileName.isEmpty {
                let path = Bundle.main.path(forResource: selected.fileName, ofType: "shape-z")!
                let data = NSData(contentsOfFile: path)! as Data
                let dataString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)

                globalApp!.loadFrom(dataString! as String)
            }
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        super.mouseMoved(event)
        
        hoverItem = nil
        for item in items {
            if item.rect.contains(event.x, event.y) {
                hoverItem = item
                break
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        #if os(iOS)
        mouseMoved(event)
        #endif
        super.mouseDown(event)
        
        if let hover = hoverItem {
            selItem = hover
            mmView.update()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0) {
        super.draw(xOffset: xOffset, yOffset: yOffset)
        
        let itemSize : Float = (rect.width - 2 - 6) / 3
        
        mmView.drawBox.draw( x: rect.x, y: rect.y + 35, width: rect.width, height: rect.height - 90 - 40, round: 26, borderSize: 1, fillColor: float4(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        
        for (index,item) in items.enumerated() {
            
            var x : Float = rect.x + 2
            let y : Float = rect.y + 37
            
            let borderColor = selItem === item ? mmView.skin.Item.selectionColor : mmView.skin.Item.borderColor
            let textColor = selItem === item ? mmView.skin.Item.selectionColor : float4(1,1,1,1)

            x += (Float(index).truncatingRemainder(dividingBy: 3)) * (itemSize + 2)

            mmView.drawBox.draw( x: x, y: y, width: itemSize, height: itemSize, round: 26, borderSize: 2, fillColor: mmView.skin.Item.color, borderColor: borderColor)
            
            item.rect.set(x, y, itemSize, itemSize)
            item.titleLabel.color = textColor
            item.titleLabel.drawCentered(x: x, y: y + itemSize / 3 * 2, width: itemSize, height: 35)
        }
        
        let y : Float = rect.y + 35 + rect.height - 90 - 30
        
        mmView.drawBox.draw( x: rect.x + 10, y: y, width: rect.width - 20, height: 30, round: 26, borderSize: 1, fillColor: float4(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        if let item = selItem {
            item.descriptionLabel.drawCentered(x: rect.x + 10, y: y, width: rect.width - 20, height: 30)
        }
    }
}
