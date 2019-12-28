//
//  CodeSemantics.swift
//  Render-Z
//
//  Created by Markus Moenig on 27/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

/// The smallest possible fragment of code which has a type, name and arguments like step()
class CodeFragment          : Codable
{
    enum FragmentType       : Int, Codable {
        case Undefined, FragmentType, VariableDefinition
    }
    
    var fragmentType        : FragmentType = .Undefined
    var typeName            : String = ""
    var name                : String = ""
        
    var arguments           : [CodeStatement] = []

    var rect                : MMRect = MMRect()
    
    private enum CodingKeys: String, CodingKey {
        case fragmentType
        case typeName
        case name
        case arguments
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fragmentType = try container.decode(FragmentType.self, forKey: .fragmentType)
        typeName = try container.decode(String.self, forKey: .typeName)
        name = try container.decode(String.self, forKey: .name)
        arguments = try container.decode([CodeStatement].self, forKey: .arguments)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fragmentType, forKey: .fragmentType)
        try container.encode(typeName, forKey: .name)
        try container.encode(name, forKey: .name)
        try container.encode(arguments, forKey: .arguments)
    }

    init(_ type: FragmentType,_ typeName: String = "",_ name: String = "")
    {
        fragmentType = type
        self.typeName = typeName
        self.name = name
    }
}

/// A flat list of fragments which are either combined arithmetically or listed (function header)
class CodeStatement         : Codable
{
    enum StatementType      : Int, Codable {
        case Arithmetic, List
    }
    
    var statementType       : StatementType
    var fragments           : [CodeFragment] = []

    private enum CodingKeys: String, CodingKey {
        case statementType
        case fragments
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statementType = try container.decode(StatementType.self, forKey: .statementType)
        fragments = try container.decode([CodeFragment].self, forKey: .fragments)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fragments, forKey: .fragments)
    }
    
    init(_ type: StatementType)
    {
        self.statementType = type
    }
}

/// A single block (line) of code. Has an individual fragment on the left and a list (CodeStatement) on the right. Represents any kind of supported code.
class CodeBlock
{
    enum BlockType {
        case FunctionHeader
    }
    
    let blockType           : BlockType

    var fragment            : CodeFragment = CodeFragment(.Undefined)
    var statement           : CodeStatement

    init(_ type: BlockType)
    {
        self.blockType = type
        statement = CodeStatement(.Arithmetic)

        if type == .FunctionHeader {
            statement.statementType = .List
        }
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        switch( blockType )
        {
        case .FunctionHeader:
        
            ctx.font.getTextRect(text: fragment.typeName, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: fragment.typeName, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.reserved, fragment: frag)
            }
        }
    }
}

/// A single function which has a block of code for the header and a list of blocks for the body.
class CodeFunction
{
    enum FunctionType {
        case FreeFlow
    }
    
    enum HoverArea {
        case None, Body
    }
    
    let functionType        : FunctionType
    var name                : String
    
    var header              : CodeBlock = CodeBlock( .FunctionHeader )
    var body                : [CodeBlock] = []
    
    var rects               : [String: MMRect] = [:]
    var hoverArea           : HoverArea = .None

    init(_ type: FunctionType, _ name: String)
    {
        functionType = type
        self.name = name
        
        header.fragment = CodeFragment(.FragmentType, "void", "main")
        
        rects["body"] = MMRect()
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        header.draw(mmView, ctx)
    }
}

/// A code component which is a list of functions.
class CodeComponent
{
    var functions           : [CodeFunction] = []
    
    init()
    {
    }
    
    func createFunction(_ type: CodeFunction.FunctionType, _ name: String)
    {
        let f = CodeFunction(type, name)
        functions.append(f)
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        for f in functions {
            
            f.draw(mmView, ctx)
        }
    }
}

/// The editor context to draw the code in
class CodeContext
{
    let mmView              : MMView
    let font                : MMFont
    var fontScale           : Float = 0.6
    
    var fragment            : MMFragment? = nil
    
    var cX                  : Float = 0
    var cY                  : Float = 0
    var cIndent             : Float = 0

    var indent              : Float = 0
    var lineHeight          : Float = 0
    var gapX                : Float = 0
    var gapY                : Float = 0

    var tempRect            : MMRect = MMRect()
    
    init(_ view: MMView,_ fragment: MMFragment,_ font: MMFont,_ fontScale: Float)
    {
        mmView = view
        self.fragment = fragment
        self.font = font
        self.fontScale = fontScale
        
        calcLineHeight()
    }
    
    /// Calculates the line height for the current font and fontScale
    func calcLineHeight()
    {
        tempRect = font.getTextRect(text: "()", scale: fontScale, rectToUse: tempRect)
        lineHeight = tempRect.height
    }
}
