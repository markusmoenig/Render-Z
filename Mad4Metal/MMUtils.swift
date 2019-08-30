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
    
    init(_ rect : MMRect)
    {
        x = rect.x; y = rect.y
        width = rect.width; height = rect.height
    }
    
    func set( _ x : Float, _ y : Float, _ width: Float, _ height : Float, scale: Float = 1 )
    {
        self.x = x * scale; self.y = y * scale; self.width = width * scale; self.height = height * scale
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
    
    /// Returns true if the given point is inside the scaled rect
    func contains( _ x : Float, _ y : Float, _ scale : Float ) -> Bool
    {
        if self.x <= x && self.y <= y && self.x + self.width * scale >= x && self.y + self.height * scale >= y {
            return true;
        }
        return false;
    }
    
    /// Intersect the rects
    func intersect(_ rect: MMRect)
    {
        let left = max(x, rect.x)
        let top = max(y, rect.y)
        let right = min(x + width, rect.x + rect.width )
        let bottom = min(y + height, rect.y + rect.height )
        let width = right - left
        let height = bottom - top
        
        if width > 0 && height > 0 {
            x = left
            y = top
            self.width = width
            self.height = height
        } else {
            copy(rect)
        }
    }
    
    /// Merge the rects
    func merge(_ rect: MMRect)
    {
        width = width > rect.width ? width : rect.width + (rect.x - x)
        height = height > rect.height ? height : rect.height + (rect.y - y)
        x = min(x, rect.x)
        y = min(y, rect.y)
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
    
    /// Shrinks the rectangle by the given x and y amounts
    func shrink(_ x : Float,_ y : Float)
    {
        self.x += x
        self.y += y
        self.width -= x * 2
        self.height -= y * 2
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

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + self.lowercased().dropFirst()
    }
    
    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

/// RGB to HSL
func toHSL(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float)
{
    let _max : Float = max(r, g, b)
    let _min : Float = min(r, g, b)
    
    let v : Float = (_max + _min) / 2
    var h : Float = v
    var s : Float = v
    let l : Float = v
    
    if (_max == _min)
    {
        h = 0.0
        s = 0.0
    }
    else
    {
        let d = _max - _min
        
        s = l > 0.5 ? d / (2 - _max - _min) : d / (_max + _min)
        
        if (_max == r)
        {
            h = (g - b) / d + (g < b ? 6 : 0)
        }
        else
        if (_max == g) {
            h = (b - r) / d + 2
        }
        else
        if (_max == b) {
            h = (r - g) / d + 4
        }
        
        h /= 6
    }

    return (h,s,l)
}

/// HSL to RGB
func toRGB(_ h: Float, _ s: Float, _ l: Float) -> (Float, Float, Float)
{
    func hueAngle(_ hueIn: Float, _ x: Float, _ y: Float) -> Float
    {
        var hue: Float = hueIn
        
        if hue < 0.0 {
            hue += 1
        } else
        if hue > 1.0 {
            hue -= 1
        }
        
        if hue < 1 / 6 { return x + (y - x) * 6 * hue }
        if hue < 1 / 2 { return y }
        if hue < 2 / 3 { return x + (y - x) * ((2 / 3) - hue) * 6 }
        
        return x
    }
    
    var r : Float
    var g : Float
    var b : Float

    if (s == 0.0) {
        r = l
        g = l
        b = l
    } else
    {
        let y : Float = l < 0.5 ? l * (1 + s) : l + s - l * s
        let x : Float = 2 * l - y
        
        let hue = h / 360
        
        r = hueAngle(hue + 1 / 3, x, y);
        g = hueAngle(hue        , x, y);
        b = hueAngle(hue - 1 / 3, x, y);
    }
    
    return (r,g,b)
}

func createNodeCamera(_ node: Node) -> Camera
{
    let prevOffX = node.properties["prevOffX"]
    let prevOffY = node.properties["prevOffY"]
    let prevScale = node.properties["prevScale"]
    let camera = Camera(x: prevOffX != nil ? prevOffX! : 0, y: prevOffY != nil ? prevOffY! : 0, zoom: prevScale != nil ? prevScale! : 1)
    
    return camera
}

func createStaticTextSource(_ font: MMFont, _ text: String, varCounter: Int = 0) -> String
{
    var source = "FontChar chars\(varCounter)[\(text.count)];\n"
    
    var totalWidth : Float = 0
    var totalHeight : Float = 0
    
    for c in text {
        let bmFont = font.getItemForChar(c)!
        
        totalWidth += bmFont.width + bmFont.xadvance
        totalHeight = max(totalHeight,bmFont.height)
    }
    
    for (index,c) in text.enumerated() {
        let bmFont = font.getItemForChar(c)!
        let varName = "chars\(varCounter)[\(index)]"
        
        source += "\(varName).charPos.x = \(bmFont.x);\n"
        source += "\(varName).charPos.y = \(bmFont.y);\n"
        source += "\(varName).charSize.x = \(bmFont.width);\n"
        source += "\(varName).charSize.y = \(bmFont.height);\n"
        source += "\(varName).charOffset.x = \(bmFont.xoffset);\n"
        source += "\(varName).charOffset.y = \(bmFont.yoffset);\n"
        source += "\(varName).charAdvance.x = \(bmFont.xadvance);\n"
        source += "\(varName).stringInfo.x = \(totalWidth);\n"
        source += "\(varName).stringInfo.y = \(totalHeight);\n"
        source += "\(varName).stringInfo.w = \(index == text.count-1 ? 1 : 0);\n"
    }
    
    return source
}

func getStaticTextSize(_ font: MMFont, _ text: String,_ scale: Float = 1) -> float2
{
    var totalWidth : Float = 0
    var totalHeight : Float = 0
    
    for c in text {
        let bmFont = font.getItemForChar(c)!
        
        totalWidth += bmFont.width + bmFont.xadvance
        totalHeight = max(totalHeight,bmFont.height)
    }
    
    return float2(totalWidth,totalHeight)
}

func toDegrees(_ rad: Float) -> Float
{
    return rad * 180 / Float.pi
}

func toRadians(_ degree: Float) -> Float
{
    return degree * Float.pi / 180
}

func shadeColor(_ color: float4,_ factor: Float) -> float4
{
    let t: Float = factor < 0 ? 0 : 1
    let p: Float = factor < 0 ? -factor : factor
    
    let rc = float4((t - color.x) * p + color.x,(t - color.y) * p + color.y,(t - color.z) * p + color.z,color.w)
    return rc
}
