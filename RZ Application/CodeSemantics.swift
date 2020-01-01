//
//  CodeSemantics.swift
//  Render-Z
//
//  Created by Markus Moenig on 27/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

/// The smallest possible fragment of code which has a type, name and arguments like step()
class CodeFragment          : Codable, Equatable
{
    enum FragmentType       : Int, Codable {
        case    Undefined,              // Type is not defined yet
                TypeDefinition,         // Type definition (float4 param)
                ConstTypeDefinition,    // Const type definition (float4 colorize) cannot be editited
                VariableDefinition,     // Definition of a variable (float4 color)
                OutVariable,            // Out variable (outColor), cannot be edited
                ConstantDefinition,     // Definition of a constant (float4)
                ConstantValue           // Value of a constant (1.2), right now only floats
    }
    
    var fragmentType        : FragmentType = .Undefined
    var typeName            : String = ""
    var name                : String = ""
    var uuid                : UUID = UUID()
        
    var arguments           : [CodeStatement] = []

    var rect                : MMRect = MMRect()
    var argRect             : MMRect = MMRect()
    
    var values              : [String:Float] = [:]

    private enum CodingKeys: String, CodingKey {
        case fragmentType
        case typeName
        case name
        case uuid
        case arguments
        case values
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fragmentType = try container.decode(FragmentType.self, forKey: .fragmentType)
        typeName = try container.decode(String.self, forKey: .typeName)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        arguments = try container.decode([CodeStatement].self, forKey: .arguments)
        values = try container.decode([String:Float].self, forKey: .values)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fragmentType, forKey: .fragmentType)
        try container.encode(typeName, forKey: .name)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(arguments, forKey: .arguments)
        try container.encode(values, forKey: .values)
    }
    
    static func ==(lhs:CodeFragment, rhs:CodeFragment) -> Bool { // Implement Equatable
        return lhs.uuid == rhs.uuid
    }

    init(_ type: FragmentType,_ typeName: String = "",_ name: String = "")
    {
        fragmentType = type
        self.typeName = typeName
        self.name = name
        
        if type == .ConstantValue {
            values["value"] = 1
            values["min"] = 0
            values["max"] = 1
            values["precision"] = 3
        }
    }
    
    // ConstantValue only, sets the value
    func setValue(_ value: Float)
    {
        if fragmentType == .ConstantValue {
            values["value"] = value
        }
    }
    
    func canBeSelected() -> Bool
    {
        if fragmentType == .ConstTypeDefinition || fragmentType == .OutVariable {
            return false
        }
        return true
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        if fragmentType == .OutVariable {
            let rStart = ctx.rectStart()
            
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.outVariable, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            ctx.addCode(name)
        } else
        if fragmentType == .ConstantDefinition {
            let rStart = ctx.rectStart()
            
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.reserved, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            ctx.addCode(typeName)
        } else
        if fragmentType == .ConstantValue {
            let rStart = ctx.rectStart()
            let value = String(format: "%.0\(Int(values["precision"]!))f", values["value"]!)
            
            ctx.font.getTextRect(text: value, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: value, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.value, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            ctx.addCode(value)
        }
        
        // Arguments
        
        if !arguments.isEmpty {
            let op = "("
            ctx.font.getTextRect(text: op, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: op, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
            }
            ctx.cX += ctx.tempRect.width + ctx.gapX
            
            ctx.addCode("( ")
        }
        
        for (index, arg) in arguments.enumerated() {
            arg.draw(mmView, ctx)
            
            if index != arguments.endIndex - 1 {
                let op = ","
                ctx.font.getTextRect(text: op, scale: ctx.fontScale, rectToUse: ctx.tempRect)
                if let frag = ctx.fragment {
                    mmView.drawText.drawText(ctx.font, text: op, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
                }
                ctx.cX += ctx.tempRect.width + ctx.gapX
                ctx.addCode( ", " )
            }
        }
        
        if !arguments.isEmpty {
            let op = ")"
            ctx.font.getTextRect(text: op, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: op, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
            }
            ctx.cX += ctx.tempRect.width + ctx.gapX
            ctx.addCode(") ")
        }
    }
}

/// A flat list of fragments which are either combined arithmetically or listed (function header)
class CodeStatement         : Codable, Equatable
{
    enum StatementType      : Int, Codable {
        case Arithmetic, List
    }
    
    var statementType       : StatementType
    var fragments           : [CodeFragment] = []
    var uuid                : UUID = UUID()

    private enum CodingKeys: String, CodingKey {
        case statementType
        case fragments
        case uuid
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statementType = try container.decode(StatementType.self, forKey: .statementType)
        fragments = try container.decode([CodeFragment].self, forKey: .fragments)
        uuid = try container.decode(UUID.self, forKey: .uuid)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(statementType, forKey: .statementType)
        try container.encode(fragments, forKey: .fragments)
        try container.encode(uuid, forKey: .uuid)
    }
    
    static func ==(lhs:CodeStatement, rhs:CodeStatement) -> Bool { // Implement Equatable
        return lhs.uuid == rhs.uuid
    }
    
    init(_ type: StatementType)
    {
        self.statementType = type
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        for f in fragments {
            
            f.draw(mmView, ctx)
            ctx.drawFragmentState(f)
        }
    }
}

/// A single block (line) of code. Has an individual fragment on the left and a list (CodeStatement) on the right. Represents any kind of supported code.
class CodeBlock             : Codable, Equatable
{
    enum BlockType          : Int, Codable {
        case Empty, FunctionHeader, OutVariable
    }
    
    let blockType           : BlockType

    var fragment            : CodeFragment = CodeFragment(.Undefined)
    var statement           : CodeStatement
    var uuid                : UUID = UUID()

    var rect                : MMRect = MMRect()
    var assignmentRect      : MMRect = MMRect()

    private enum CodingKeys: String, CodingKey {
        case blockType
        case fragment
        case statement
        case uuid
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockType = try container.decode(BlockType.self, forKey: .blockType)
        fragment = try container.decode(CodeFragment.self, forKey: .fragment)
        statement = try container.decode(CodeStatement.self, forKey: .fragment)
        uuid = try container.decode(UUID.self, forKey: .uuid)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fragment, forKey: .fragment)
        try container.encode(statement, forKey: .statement)
        try container.encode(uuid, forKey: .uuid)
    }
    
    static func ==(lhs:CodeBlock, rhs:CodeBlock) -> Bool { // Implement Equatable
        return lhs.uuid == rhs.uuid
    }
    
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
        let rStart = ctx.rectStart()

        // Border
        if blockType == .FunctionHeader {
            ctx.font.getTextRect(text: "func", scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: "func", x: ctx.border - ctx.tempRect.width - ctx.gapX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.border, fragment: frag)
                
                if ctx.cFunction === ctx.hoverFunction {
                    mmView.drawBox.draw( x: ctx.gapX / 2, y: ctx.cFunction!.rect.y - ctx.gapY / 2, width: ctx.border - ctx.gapX / 2, height: ctx.lineHeight + ctx.gapY, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, 0.5), fragment: frag )
                }
            }
            
        } else {
            let line : String = String(ctx.blockNumber)
            ctx.font.getTextRect(text: line, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: line, x: ctx.border - ctx.tempRect.width - ctx.gapX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.border, fragment: frag)
                
                if ctx.cBlock === ctx.hoverBlock {
                    mmView.drawBox.draw( x: ctx.gapX / 2, y: ctx.cBlock!.rect.y - ctx.gapY / 2, width: ctx.border - ctx.gapX / 2, height: ctx.lineHeight + ctx.gapY, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, 0.5), fragment: frag )
                }
            }
        }
        
        // Content
        if blockType == .Empty {
            let rStart = ctx.rectStart()
            ctx.cX += 100//ctx.editorWidth - ctx.cX
            ctx.rectEnd(fragment.rect, rStart)
            ctx.cY += ctx.lineHeight + ctx.gapY
            ctx.drawFragmentState(fragment)
        } else if blockType == .FunctionHeader {
            let rStart = ctx.rectStart()
            ctx.font.getTextRect(text: fragment.typeName, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: fragment.typeName, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.reserved, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width + ctx.gapX
            
            ctx.font.getTextRect(text: fragment.name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: fragment.name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.nameHighlighted, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.cY += ctx.lineHeight + ctx.gapY
            ctx.rectEnd(fragment.rect, rStart)
            
            ctx.drawFragmentState(fragment)
            
            ctx.cIndent = ctx.indent
        } else {
            // left side
            fragment.draw(mmView, ctx)
            ctx.drawFragmentState(fragment)

            // assignment
            let arStart = ctx.rectStart()
            let op = "="
            
            ctx.font.getTextRect(text: op, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: op, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(assignmentRect, arStart)
            ctx.cX += ctx.gapX

            ctx.addCode( " " + op + " " )

            // statement
            statement.draw(mmView, ctx)
            
            ctx.cY += ctx.lineHeight + ctx.gapY
            
            ctx.addCode( ";\n" )
        }
        
        ctx.rectEnd(rect, rStart)
        ctx.drawBlockState(self)
    }
}

/// A single function which has a block of code for the header and a list of blocks for the body.
class CodeFunction          : Codable, Equatable
{
    enum FunctionType       : Int, Codable {
        case FreeFlow, ScreenObjectColorize
    }
    
    let functionType        : FunctionType
    var name                : String
    
    var header              : CodeBlock = CodeBlock( .FunctionHeader )
    var body                : [CodeBlock] = []
    var uuid                : UUID = UUID()

    var rect                : MMRect = MMRect()

    private enum CodingKeys: String, CodingKey {
        case functionType
        case name
        case header
        case body
        case uuid
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        functionType = try container.decode(FunctionType.self, forKey: .functionType)
        name = try container.decode(String.self, forKey: .name)
        header = try container.decode(CodeBlock.self, forKey: .header)
        body = try container.decode([CodeBlock].self, forKey: .body)
        uuid = try container.decode(UUID.self, forKey: .uuid)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(functionType, forKey: .functionType)
        try container.encode(name, forKey: .name)
        try container.encode(header, forKey: .header)
        try container.encode(body, forKey: .body)
        try container.encode(uuid, forKey: .uuid)
    }
    
    static func ==(lhs:CodeFunction, rhs:CodeFunction) -> Bool { // Implement Equatable
        return lhs.uuid == rhs.uuid
    }
    
    init(_ type: FunctionType, _ name: String)
    {
        functionType = type
        self.name = name
        
        header.fragment = CodeFragment(type == .FreeFlow ? .TypeDefinition : .ConstTypeDefinition, "void", "colorize")
    }
    
    func createOutVariableBlock(_ typeName: String,_ name: String) -> CodeBlock
    {
        let b = CodeBlock(CodeBlock.BlockType.OutVariable)
        
        b.fragment.fragmentType = .OutVariable
        b.fragment.typeName = typeName
        b.fragment.name = name
        
        let constant = CodeFragment(.ConstantDefinition, "float4", "float4")
        b.statement.fragments.append(constant)
        
        for index in 0...3 {
            let argStatement = CodeStatement(.Arithmetic)
            
            let constValue = CodeFragment(.ConstantValue, "float")
            if name == "outColor" {
                if index == 0 {
                    constValue.setValue(0.161)
                } else
                if index == 1 {
                    constValue.setValue(0.165)
                } else
                if index == 2 {
                    constValue.setValue(0.184)
                }
            }
            argStatement.fragments.append(constValue)
            constant.arguments.append(argStatement)
        }
        return b
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        ctx.blockNumber = 1
        let rStart = ctx.rectStart()

        header.draw(mmView, ctx)
        for b in body {
            ctx.cBlock = b
            
            ctx.cIndent = ctx.indent
            ctx.cX = ctx.border + ctx.startX + ctx.cIndent
            b.draw(mmView, ctx)
            
            ctx.blockNumber += 1
        }
        
        ctx.rectEnd(rect, rStart)
        
        //mmView.drawBox.draw( x: ctx.border, y: rect.y, width: 2, height: rect.height, round: 0, borderSize: 0, fillColor: mmView.skin.Code.border, fragment: ctx.fragment )
        ctx.drawFunctionState(self)
    }
}

/// A code component which is a list of functions.
class CodeComponent         : Codable, Equatable
{
    enum ComponentType      : Int, Codable {
        case Colorize
    }
    
    let componentType       : ComponentType
    
    var functions           : [CodeFunction] = []
    var uuid                : UUID = UUID()
    
    var selected            : UUID? = nil

    var rect                : MMRect = MMRect()
    
    // Code Generation
    var code                : String? = nil

    private enum CodingKeys: String, CodingKey {
        case componentType
        case functions
        case uuid
        case selected
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        componentType = try container.decode(ComponentType.self, forKey: .componentType)
        functions = try container.decode([CodeFunction].self, forKey: .functions)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        selected = try container.decode(UUID?.self, forKey: .uuid)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(functions, forKey: .functions)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(selected, forKey: .selected)
    }
    
    static func ==(lhs:CodeComponent, rhs:CodeComponent) -> Bool { // Implement Equatable
        return lhs.uuid == rhs.uuid
    }
    
    init(_ type: ComponentType = .Colorize)
    {
        componentType = type
    }
    
    func createFunction(_ name: String)
    {
        let f = CodeFunction(.FreeFlow, name)
        f.body.append(CodeBlock(.Empty))
        functions.append(f)
    }
    
    func createDefaultFunction(_ type: CodeFunction.FunctionType)
    {
        let f = CodeFunction(type, "colorize")
        
        f.body.append(CodeBlock(.Empty))
        f.body.append(f.createOutVariableBlock("float4", "outColor"))
        functions.append(f)
    }
    
    func codeAt(_ mmView: MMView,_ x: Float,_ y: Float,_ ctx: CodeContext)
    {
        ctx.hoverFunction = nil
        ctx.hoverBlock = nil
        ctx.hoverFragment = nil
        
        for f in functions {
            
            // Check for func marker
            if y >= f.rect.y && y <= f.rect.y + ctx.lineHeight && x <= ctx.border {
                ctx.hoverFunction = f
                break
            }
            
            // ---
            
            if f.header.fragment.canBeSelected() && f.header.fragment.rect.contains(x, y) {
                ctx.hoverFragment = f.header.fragment
                break
            }
            for b in f.body {
                
                // Check for block marker
                if y >= b.rect.y && y <= b.rect.y + ctx.lineHeight && x <= ctx.border {
                    ctx.hoverBlock = b
                    break
                }
                
                if b.fragment.canBeSelected() && b.fragment.rect.contains(x, y) {
                    ctx.hoverFragment = b.fragment
                    break
                }
                                
                for fragment in b.statement.fragments {
                    for statement in fragment.arguments {
                        for arg in statement.fragments {
                            if arg.rect.contains(x, y) {
                                ctx.hoverFragment = arg
                                break
                            }
                        }
                    }
                    if ctx.hoverFragment == nil {
                        if fragment.rect.contains(x, y) {
                            ctx.hoverFragment = fragment
                            break
                        }
                    }
                }
            }
        }
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        let rStart = ctx.rectStart()
        ctx.cComponent = self
        
        code = ""
        
        for f in functions {
            
            ctx.cFunction = f
            ctx.cX = ctx.border + ctx.startX
            ctx.cIndent = 0
            f.draw(mmView, ctx)
        }
        
        ctx.rectEnd(rect, rStart)
    }
}

/// The editor context to draw the code in
class CodeContext
{
    let mmView              : MMView
    let font                : MMFont
    var fontScale           : Float = 0.6
    
    var fragment            : MMFragment? = nil
    
    // Running vars
    var cX                  : Float = 0
    var cY                  : Float = 0
    var cIndent             : Float = 0

    var cComponent          : CodeComponent? = nil
    var cFunction           : CodeFunction? = nil
    var cBlock              : CodeBlock? = nil

    // Fixed vars
    var indent              : Float = 0
    var lineHeight          : Float = 0
    var gapX                : Float = 0
    var gapY                : Float = 0
    var startX              : Float = 0
    var border              : Float = 0
    var hoverAlpha          : Float = 0
    var selectionAlpha      : Float = 0
    
    // Status
    var blockNumber         : Int = 0
    
    var editorWidth         : Float = 0
    
    var hoverFunction       : CodeFunction? = nil
    var hoverBlock          : CodeBlock? = nil
    var hoverFragment       : CodeFragment? = nil
    
    var selectedFunction    : CodeFunction? = nil
    var selectedBlock       : CodeBlock? = nil
    var selectedFragment    : CodeFragment? = nil
    
    var dropFragment        : CodeFragment? = nil
        
    var tempRect            : MMRect = MMRect()
    
    init(_ view: MMView,_ fragment: MMFragment,_ font: MMFont,_ fontScale: Float)
    {
        mmView = view
        self.fragment = fragment
        self.font = font
        self.fontScale = fontScale
    }
    
    func reset(_ editorWidth: Float)
    {
        fontScale = 0.45
        startX = 10
        cY = 40
        
        gapX = 5
        gapY = 1
        indent = 20
        border = 60
        
        hoverAlpha = 0.5
        selectionAlpha = 0.7
        
        self.editorWidth = editorWidth
        self.lineHeight = font.getLineHeight(fontScale)
    }
    
    func rectStart() -> SIMD2<Float>
    {
        return SIMD2<Float>(cX, cY)
    }
    
    func rectEnd(_ rect: MMRect,_ start: SIMD2<Float>)
    {
        rect.x = start.x - gapX / 2
        rect.y = start.y - gapY / 2
        rect.width = cX - start.x + gapX
        rect.height = max(cY - start.y, lineHeight) + gapY
    }
    
    func addCode(_ source: String)
    {
        if cComponent!.code != nil {
            cComponent!.code! += source
        }
    }
    
    func drawHighlight(_ rect: MMRect,_ alpha: Float = 0.5)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: fragment )
    }
    
    func drawFunctionState(_ function: CodeFunction)
    {
        if function === hoverFunction || function.uuid == cComponent!.selected {
            let alpha : Float = function.uuid == cComponent!.selected ? selectionAlpha : hoverAlpha
            mmView.drawBox.draw( x: function.rect.x, y: function.rect.y, width: function.rect.width, height: function.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: fragment )
        }
    }
    
    func drawBlockState(_ block: CodeBlock)
    {
        if block === hoverBlock || block.uuid == cComponent!.selected {
            let alpha : Float = block.uuid == cComponent!.selected ? selectionAlpha : hoverAlpha
            mmView.drawBox.draw( x: block.rect.x, y: block.rect.y, width: block.rect.width, height: block.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: fragment )
        }
    }
    
    func drawFragmentState(_ fragment: CodeFragment)
    {
        if let drop = dropFragment, fragment == hoverFragment {
            
            if cBlock!.blockType == .Empty && drop.fragmentType == .VariableDefinition {
                drawHighlight(fragment.rect, hoverAlpha)
            }
        } else
        if fragment === hoverFragment || fragment.uuid == cComponent!.selected {
            let alpha : Float = fragment.uuid == cComponent!.selected ? selectionAlpha : hoverAlpha
            drawHighlight(fragment.rect, alpha)
        }
    }
}
