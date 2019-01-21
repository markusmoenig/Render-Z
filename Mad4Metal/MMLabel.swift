//
//  MMLabel.swift
//  Framework
//
//  Created by Markus Moenig on 09.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

protocol MMLabel
{
    var rect : MMRect {get set}

    func draw()
}

class MMTextLabel: MMLabel
{
    var mmView      : MMView
    var rect        : MMRect
    var font        : MMFont
    var text        : String
    var scale       : Float
    var color       : float4
    var textBuffer  : MMTextBuffer?
    
    init( _ view: MMView, font: MMFont, text: String, scale: Float = 0.5, color: float4 = float4(0.957, 0.957, 0.957, 1) )
    {
        rect = MMRect()
        
        mmView = view;
        self.font = font
        self.text = text
        self.scale = scale
        self.color = color
        
        rect = font.getTextRect(text: text, scale: scale, rectToUse: rect)
    }
    
    func draw()
    {
        textBuffer = mmView.drawText.drawText(font, text: text, x: rect.x, y: rect.y, scale: scale, color: color, textBuffer: textBuffer)
    }
    
    func drawCentered(x:Float, y:Float, width:Float, height:Float)
    {
        let drawX = x + (width - rect.width) / 2
        let drawY = y + (height - rect.height)/2
        textBuffer = mmView.drawText.drawText(font, text: text, x: drawX, y: drawY, scale: scale, color: color, textBuffer: textBuffer)
    }
    
    func drawYCentered(x:Float, y:Float, width:Float, height:Float)
    {
        let drawX = x
        let drawY = y + (height - rect.height)/2
        textBuffer = mmView.drawText.drawText(font, text: text, x: drawX, y: drawY, scale: scale, color: color, textBuffer: textBuffer)
    }
    
    func setText(_ text: String)
    {
        if text != self.text {
            self.text = text
            textBuffer = nil
            rect = font.getTextRect(text: text, scale: scale, rectToUse: rect)
        }
    }
}
