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
    var font        : MMFont {get set}

    func draw()
}

class MMShadowTextLabel : MMWidget
{
    var white       : MMTextLabel
    var black       : MMTextLabel
    
    init( _ view: MMView, font: MMFont, text: String, scale: Float = 0.5, color: SIMD4<Float> = SIMD4<Float>(0.957, 0.957, 0.957, 1) )
    {
        white = MMTextLabel(view, font: font, text: text, scale: scale, color: color)
        black = MMTextLabel(view, font: font, text: text, scale: scale, color: SIMD4<Float>(0, 0, 0, 1))
        
        super.init(view)
        
        rect.width = white.rect.width
        rect.height = white.rect.height
    }
    
    func setText(_ text: String, scale: Float? = nil)
    {
        white.setText(text, scale: scale)
        black.setText(text, scale: scale)
    }
    
    func draw()
    {
        black.rect.x = rect.x + 0.5
        black.rect.y = rect.y + 0.5
        black.draw()
        
        white.rect.x = rect.x
        white.rect.y = rect.y
        white.draw()
    }
}

class MMTextLabel: MMLabel
{
    var mmView      : MMView
    var rect        : MMRect
    var font        : MMFont
    var text        : String
    var scale       : Float
    var textBuffer  : MMTextBuffer?
    var textYOffset : Float = -1
    var lineHeight  : Float = 0
    
    var color  : SIMD4<Float> {
        
        willSet(newValue) {
            if newValue != color {
                textBuffer = nil
            }
        }
    }
    
    var isDisabled  : Bool {
        
        willSet(newValue) {
            if newValue != isDisabled {
                textBuffer = nil
            }
        }
    }
    
    init( _ view: MMView, font: MMFont, text: String, scale: Float = 0.5, color: SIMD4<Float> = SIMD4<Float>(0.957, 0.957, 0.957, 1) )
    {
        rect = MMRect()
        
        mmView = view;
        self.font = font
        self.text = text
        self.scale = scale
        self.color = color
        self.isDisabled = false
        
        rect = font.getTextRect(text: text, scale: scale, rectToUse: rect)
        lineHeight = font.getLineHeight(scale)
    }
    
    func draw()
    {
        textBuffer = mmView.drawText.drawText(font, text: text, x: rect.x, y: rect.y, scale: scale, color: SIMD4<Float>( color.x, color.y, color.z, isDisabled ? 0.2 : color.w), textBuffer: textBuffer)
    }
    
    func drawCentered(x:Float, y:Float, width:Float, height:Float)
    {
        let drawX = x + (width - rect.width) / 2
        let drawY = y + (height - rect.height)/2 + textYOffset
        textBuffer = mmView.drawText.drawText(font, text: text, x: drawX, y: drawY, scale: scale, color: SIMD4<Float>( color.x, color.y, color.z, isDisabled ? 0.2 : color.w), textBuffer: textBuffer)
    }
    
    func drawCenteredY(x:Float, y:Float, width:Float, height:Float)
    {
        let drawX = x
        let drawY = y + (height - rect.height)/2 + textYOffset
        textBuffer = mmView.drawText.drawText(font, text: text, x: drawX, y: drawY, scale: scale, color: SIMD4<Float>( color.x, color.y, color.z, isDisabled ? 0.2 : color.w), textBuffer: textBuffer)
    }
    
    func drawRightCenteredY(x:Float, y:Float, width:Float, height:Float)
    {
        let drawX = x + width - rect.width
        let drawY = y + (height - rect.height)/2 + textYOffset
        textBuffer = mmView.drawText.drawText(font, text: text, x: drawX, y: drawY, scale: scale, color: SIMD4<Float>( color.x, color.y, color.z, isDisabled ? 0.2 : color.w), textBuffer: textBuffer)
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
