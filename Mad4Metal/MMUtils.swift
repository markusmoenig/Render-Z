//
//  MMUtils.swift
//  Framework
//
//  Created by Markus Moenig on 05.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

/// MMRect class
class MMRect
{
    var x : Float
    var y: Float
    var width: Float
    var height: Float
    
    init( _ x : Float, _ y : Float, _ width: Float, _ height : Float, scale: Float = 1 )
    {
        self.x = x * scale; self.y = y * scale; self.width = width * scale; self.height = height * scale
    }
    
    init()
    {
        x = 0; y = 0; width = 0; height = 0
    }
    
    /// Copy the content of the given rect
    func copy(_ rect : MMRect)
    {
        x = rect.x; y = rect.y
        width = rect.width; height = rect.height
    }
    
    /// Returns true if the given point is inside the rect
    func contains( _ x : Float, _ y : Float ) -> Bool
    {
        if self.x <= x && self.y <= y && self.x + self.width >= x && self.y + self.height >= y {
            return true;
        }
        return false;
    }
    
    /// Returns the cordinate of the right edge of the rectangle
    func right() -> Float
    {
        return x + width
    }
    
    /// Returns the cordinate of the bottom of the rectangle
    func bottom() -> Float
    {
        return y + height
    }
}

/// MMMargin class
class MMMargin
{
    var left :  Float
    var top :   Float
    var right : Float
    var bottom: Float
    
    init( _ left : Float, _ top : Float, _ right: Float, _ bottom : Float)
    {
        self.left = left; self.top = top; self.right = right; self.bottom = bottom
    }
    
    init()
    {
        left = 0; top = 0; right = 0; bottom = 0
    }
    
    func width() -> Float
    {
        return left + right
    }
    
    func height() -> Float
    {
        return top + bottom
    }
}
