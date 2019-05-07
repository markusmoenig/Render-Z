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
    var isDisabled  : Bool {get set}

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
    var isDisabled  : Bool {
        didSet{
            textBuffer = nil
        }
    }
    
    init( _ view: MMView, font: MMFont, text: String, scale: Float = 0.5, color: float4 = float4(0.957, 0.957, 0.957, 1) )
    {
        rect = MMRect()
        
        mmView = view;
        self.font = font
        self.text = text
        self.scale = scale
        self.color = color
        self.isDisabled = false
        
        rect = font.getTextRect(text: text, scale: scale, rectToUse: rect)
    }
    
    func draw()
    {
        textBuffer = mmView.drawText.drawText(font, text: text, x: rect.x, y: rect.y, scale: scale, color: float4( color.x, color.y, color.z, isDisabled ? 0.1 : 1.0), textBuffer: textBuffer)
    }
    
    func drawCentered(x:Float, y:Float, width:Float, height:Float)
    {
        let drawX = x + (width - rect.width) / 2
        let drawY = y + (height - rect.height)/2 - 1
        textBuffer = mmView.drawText.drawText(font, text: text, x: drawX, y: drawY, scale: scale, color: color, textBuffer: textBuffer)
    }
    
    func drawCenteredY(x:Float, y:Float, width:Float, height:Float)
    {
        let drawX = x
        let drawY = y + (height - rect.height)/2 - 1
        textBuffer = mmView.drawText.drawText(font, text: text, x: drawX, y: drawY, scale: scale, color: color, textBuffer: textBuffer)
    }
    
    func drawRightCenteredY(x:Float, y:Float, width:Float, height:Float)
    {
        let drawX = x + width - rect.width
        let drawY = y + (height - rect.height)/2 - 1
        textBuffer = mmView.drawText.drawText(font, text: text, x: drawX, y: drawY, scale: scale, color: color, textBuffer: textBuffer)
    }
    
    func setText(_ text: String, scale: Float? = nil)
    {
        if text != self.text || (scale != nil && self.scale != scale) {
            self.text = text
            textBuffer = nil
            if scale != nil {
                self.scale = scale!
            }
            rect = font.getTextRect(text: text, scale: self.scale, rectToUse: rect)
        }
    }
}
