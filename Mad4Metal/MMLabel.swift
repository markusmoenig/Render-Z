//
//  MMLabel.swift
//  Framework
//
//  Created by Markus Moenig on 09.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

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
    var textBuffer  : MMTextBuffer?
    
    init( _ view: MMView, font: MMFont, text: String, scale: Float = 0.5 )
    {
        rect = MMRect()
        
        mmView = view;
        self.font = font
        self.text = text
        self.scale = scale
        
        rect = font.getTextRect(text: text, scale: scale, rectToUse: rect)
    }
    
    func draw()
    {
        textBuffer = mmView.drawText.drawText(font, text: text, x: rect.x, y: rect.y, scale: scale, textBuffer: textBuffer)
    }
}
