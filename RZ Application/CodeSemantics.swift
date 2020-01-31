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
                VariableReference,      // Reference to a variable
                OutVariable,            // Out variable (outColor), cannot be edited
                ConstantDefinition,     // Definition of a constant (float4)
                ConstantValue,          // Value of a constant (1.2), right now only floats
                Primitive,              // A primitive function line abs, sin, length etc
                Arithmetic,             // +, -, etc
                OpeningRoundBracket,    // (
                ClosingRoundBracket,    // )
                Assignment,             // =, +=, *= etc
                Comparison,             // ==, <=, >= etc
                If,                     // If
                Else,                   // Else
                For,                    // For
                End
    }
    
    enum FragmentProperties : Int, Codable{
        case Selectable, Dragable, Targetable, NotCodeable, Monitorable
    }
    
    var fragmentType        : FragmentType = .Undefined
    var properties          : [FragmentProperties]
    var typeName            : String = ""
    var name                : String = ""
    var uuid                : UUID = UUID()
        
    var arguments           : [CodeStatement] = []
    var argumentFormat      : [String]? = nil
    
    var evaluatesTo         : String? = nil
    
    /// Variable reference
    var referseTo           : UUID? = nil
    
    // For .VariableReference, "xy"
    var qualifier           : String = ""

    var rect                : MMRect = MMRect()
    var argRect             : MMRect = MMRect()
    
    var values              : [String:Float] = [:]
    
    weak var parentBlock    : CodeBlock? = nil
    weak var parentStatement: CodeStatement? = nil
    
    // Represent a floatx as a float
    var isSimplified        : Bool = false

    // How many times we get referenced
    var references          : Int = 0
    
    private enum CodingKeys: String, CodingKey {
        case fragmentType
        case properties
        case typeName
        case name
        case uuid
        case arguments
        case argumentFormat
        case evaluatesTo
        case referseTo
        case qualifier
        case values
        case isSimplified
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fragmentType = try container.decode(FragmentType.self, forKey: .fragmentType)
        properties = try container.decode([FragmentProperties].self, forKey: .properties)
        typeName = try container.decode(String.self, forKey: .typeName)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        arguments = try container.decode([CodeStatement].self, forKey: .arguments)
        argumentFormat = try container.decode([String]?.self, forKey: .argumentFormat)
        evaluatesTo = try container.decode(String?.self, forKey: .evaluatesTo)
        referseTo = try container.decode(UUID?.self, forKey: .referseTo)
        qualifier = try container.decode(String.self, forKey: .qualifier)
        values = try container.decode([String:Float].self, forKey: .values)
        isSimplified = try container.decode(Bool.self, forKey: .isSimplified)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fragmentType, forKey: .fragmentType)
        try container.encode(properties, forKey: .properties)
        try container.encode(typeName, forKey: .typeName)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(arguments, forKey: .arguments)
        try container.encode(argumentFormat, forKey: .argumentFormat)
        try container.encode(evaluatesTo, forKey: .evaluatesTo)
        try container.encode(referseTo, forKey: .referseTo)
        try container.encode(qualifier, forKey: .qualifier)
        try container.encode(values, forKey: .values)
        try container.encode(isSimplified, forKey: .isSimplified)
    }
    
    static func ==(lhs:CodeFragment, rhs:CodeFragment) -> Bool { // Implement Equatable
        return lhs.uuid == rhs.uuid
    }

    init(_ type: FragmentType,_ typeName: String = "",_ name: String = "",_ properties: [FragmentProperties] = [],_ argumentFormat: [String]? = nil,_ evaluatesTo: String? = nil)
    {
        fragmentType = type
        self.typeName = typeName
        self.name = name
        self.properties = properties
        self.argumentFormat = argumentFormat
        self.evaluatesTo = evaluatesTo
        
        values["value"] = 1

        if typeName.contains("int") {
            values["precision"] = 0
            values["min"] = 0
            values["max"] = 10
        } else {
            values["precision"] = 3
            values["min"] = 0
            values["max"] = 1
        }
    }
    
    /// ConstantValue only, sets the value
    func setValue(_ value: Float)
    {
        if fragmentType == .ConstantValue {
            values["value"] = value
        }
    }
    
    /// Returns true if fragment is negated
    func isNegated() -> Bool
    {
        if let negated = values["negated"] {
            if negated == 1 {
                return true
            }
        }
        return false
    }
    
    /// Sets the negated property of the fragment
    func setNegated(_ negated: Bool)
    {
        values["negated"] = negated == true ? 1 : 0
    }
    
    /// Returns the type this fragment evaluates to, based on the evaluatesTo value and the input values.
    func evaluateType(ignoreQualifiers: Bool = false) -> String
    {
        var type :String = ""
        
        /*
        if let evaluates = evaluatesTo {
            type = evaluates
            // Expand on this, i.e. input0 is type of first argument etc
        } else {
            type = typeName
        }*/
        type = typeName
        
        if isSimplified {
            type = getBaseType(typeName)
        }

        if ignoreQualifiers == false {
            if qualifier.count > 0 {
                type = getBaseType(type)
                if qualifier.count > 1 {
                    type += String(qualifier.count)
                }
            }
        }
        return type
    }
    
    /// Returns the number of components for this fragment
    func evaluateComponents(ignoreQualifiers: Bool = false) -> Int
    {
        var components : Int = 1
        let typeName = evaluateType(ignoreQualifiers: ignoreQualifiers)
        if typeName.hasSuffix("2") {
            components = 2
        } else
        if typeName.hasSuffix("3") {
            components = 3
        } else
        if typeName.hasSuffix("4") {
            components = 4
        }
        
        if ignoreQualifiers == false {
            if qualifier.count > 0 {
                components = qualifier.count
            }
        }
        return components
    }
    
    /// Returns the base type of the type, i.f. float for float2
    func getBaseType(_ typeName: String) -> String
    {
        var compName    : String = typeName
        
        if typeName.hasSuffix("2") {
            compName.remove(at: compName.index(before: compName.endIndex))
        } else
        if typeName.hasSuffix("3") {
            compName.remove(at: compName.index(before: compName.endIndex))
        } else
        if typeName.hasSuffix("4") {
            compName.remove(at: compName.index(before: compName.endIndex))
        }
        
        return compName
    }
    
    /// Returns true if the fragment supports the given type, needs to evaluate the evaluatesTo string which may depend on the argumentFormats
    func supportsType(_ typeName: String) -> Bool
    {
        var rc : Bool = false
        
        if let eval = evaluatesTo {
            if eval == typeName {
                rc = true
            } else
            if eval.starts(with: "input") {
                let typeArray = argumentFormat![0].components(separatedBy: "|")
                if typeArray.contains(typeName) {
                    rc = true
                }
            }
        } else
        if self.typeName == typeName {
            rc = true
        }
        
        //print("supportsType", typeName, rc, evaluatesTo, argumentFormat)
        
        return rc
    }
    
    /// Createa a copy of the given fragment with a new UUID
    func createCopy() -> CodeFragment
    {
        let copy = CodeFragment(fragmentType, typeName, name, properties, argumentFormat, evaluatesTo)
        copy.values = values
        copy.referseTo = referseTo
        copy.qualifier = qualifier
        copy.isSimplified = isSimplified
        
        copyArgumentsTo(copy)

        return copy
    }
    
    /// Createa a copy of the given fragment with a new UUID
    func copyTo(_ dest: CodeFragment)
    {
        dest.fragmentType = fragmentType
        dest.typeName = typeName
        dest.name = name
        dest.properties = properties
        dest.argumentFormat = argumentFormat
        dest.evaluatesTo = evaluatesTo
        dest.values = values
        dest.referseTo = referseTo
        dest.qualifier = qualifier
        dest.isSimplified = isSimplified

        copyArgumentsTo(dest)
    }
    
    /// Recursively copies the arguments to the destination fragment
    func copyArgumentsTo(_ dest: CodeFragment)
    {
        func copyArguments(_ destFragment: CodeFragment,_ sourceStatements: [CodeStatement])
        {
            destFragment.arguments = []
            for sourceStatement in sourceStatements {

                let argStatement = CodeStatement(sourceStatement.statementType)

                for frag in sourceStatement.fragments
                {
                    let copy = frag.createCopy()
                    argStatement.fragments.append(copy)
                    copyArguments(copy, frag.arguments)
                }
                destFragment.arguments.append(argStatement)
            }
        }
        
        copyArguments(dest, arguments)
    }
    
    /// .ConstanValue only: Creates a string for the value
    func getValueString() -> String
    {
        let valueString = (isNegated() == true ? " -" : "") + String(format: "%.0\(Int(values["precision"]!))f", values["value"]!)
        return valueString
    }
    
    /// Creates a string for the qualifier
    func getQualifierString() -> String
    {
        var string : String = ""
        if qualifier.count > 0 {
            string = "." + qualifier
        }
        return string
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        parentBlock = ctx.cBlock
        references = 0
        
        if fragmentType == .OutVariable {
            let rStart = ctx.rectStart()
            var name = self.name
            
            name += getQualifierString()
            
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.outVariable, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            ctx.addCode(name)
        } else
        if fragmentType == .End {
            let rStart = ctx.rectStart()
            let name = "end"
                        
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.reserved, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
        } else
        if fragmentType == .ConstantDefinition {
            let rStart = ctx.rectStart()
            let name = (isNegated() && isSimplified == false ? " -" : "") + (isSimplified ? getValueString() : self.name)
            
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: isSimplified ? mmView.skin.Code.value : mmView.skin.Code.reserved, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            ctx.addCode(name)
        } else
        if fragmentType == .Primitive {
            let rStart = ctx.rectStart()
            var name = (isNegated() ? " -" : "")
            
            if let referalUUID = referseTo {
                // This is a function reference!
                if let referencedFunction = ctx.functionMap[referalUUID] {
                    referencedFunction.references += 1
                    if !ctx.cFunction!.dependsOn.contains(referencedFunction) {
                        ctx.cFunction!.dependsOn.append(referencedFunction)
                    }
                    name += referencedFunction.name
                    self.name = referencedFunction.name
                }
            } else {
                name += self.name
            }
            
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.name, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            // Replace mod with fmod
            if name == "mod" {
                name = "fmod"
            }
            ctx.addCode(name)
        } else
        if fragmentType == .If || fragmentType == .Else || fragmentType == .For {
            let rStart = ctx.rectStart()
            
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.reserved, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            ctx.addCode(name)
        } else
        if fragmentType == .VariableDefinition {
            //ctx.cVariables[self.uuid] = self
            ctx.registerVariableForSyntaxBlock(self)

            let rStart = ctx.rectStart()
            
            ctx.font.getTextRect(text: typeName, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: typeName, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.reserved, fragment: frag)
            }
            ctx.cX += ctx.tempRect.width + ctx.gapX
            
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.name, fragment: frag)
            }
            ctx.cX += ctx.tempRect.width
            
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            if !properties.contains(.NotCodeable) {
                ctx.addCode(typeName + " " + name)
            }
        } else
        if fragmentType == .ConstantValue {
            let rStart = ctx.rectStart()
            let value = getValueString()
            
            ctx.font.getTextRect(text: value, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: value, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.value, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            ctx.addCode(value)
        } else
        if fragmentType == .VariableReference {
            let rStart = ctx.rectStart()
            var invalid : Bool = false
            
            // Get the name of the variable
            var name : String
            if let ref = referseTo {
                if let v = ctx.cVariables[ref] {
                    name = (isNegated() ? " -" : "") + v.name
                    v.references += 1
                } else {
                    name = "NOT FOUND"
                    invalid = true
                }
            } else {
                name = "NIL"
                invalid = true
            }

            if invalid {
                // If reference is invalid, replace this with a constant
                let constant = defaultConstantForType(typeName)
                constant.copyTo(self)
            }
            
            name += getQualifierString()
            
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.name, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX
            
            ctx.addCode(name)
        } else
        if fragmentType == .Arithmetic || fragmentType == .Assignment || fragmentType == .Comparison {
            let rStart = ctx.rectStart()
           
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
               mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
            }

            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX

            ctx.addCode(name)
        } else
        if fragmentType == .OpeningRoundBracket || fragmentType == .ClosingRoundBracket {
            let rStart = ctx.rectStart()
           
            ctx.font.getTextRect(text: name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
               mmView.drawText.drawText(ctx.font, text: name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
            }

            ctx.cX += ctx.tempRect.width
            ctx.rectEnd(rect, rStart)
            ctx.cX += ctx.gapX

            ctx.addCode(name)
        }
        
        // Arguments
        
        var processArguments = true
        
        if fragmentType == .ConstantDefinition && isSimplified {
            // If fragment is simplified, skip arguments
            processArguments = false
        }
        
        if processArguments {
            if !arguments.isEmpty {
                let op = "("
                ctx.font.getTextRect(text: op, scale: ctx.fontScale, rectToUse: ctx.tempRect)
                if let frag = ctx.fragment {
                    mmView.drawText.drawText(ctx.font, text: op, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
                    if self === ctx.hoverFragment || uuid == ctx.cComponent!.selected {
                        let alpha : Float = uuid == ctx.cComponent!.selected ? ctx.selectionAlpha : ctx.hoverAlpha
                        mmView.drawBox.draw( x: ctx.cX - ctx.gapX / 2 - 1, y: ctx.cY - ctx.gapY / 2, width: ctx.tempRect.width + ctx.gapX, height: ctx.lineHeight + ctx.gapY, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: frag )
                    }
                }
                ctx.cX += ctx.tempRect.width + ctx.gapX
                
                ctx.addCode("( ")
            }
            
            for (index, arg) in arguments.enumerated() {
                arg.isArgumentIndexOf = index
                arg.draw(mmView, ctx)
                
                if index != arguments.endIndex - 1 {
                    let op = fragmentType == .For ? ";" : ","
                    ctx.font.getTextRect(text: op, scale: ctx.fontScale, rectToUse: ctx.tempRect)
                    if let frag = ctx.fragment {
                        mmView.drawText.drawText(ctx.font, text: op, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
                    }
                    ctx.cX += ctx.tempRect.width + ctx.gapX
                    ctx.addCode( op + " " )
                }
            }
            
            // FuncData as last argument for FreeFlow functions
            if fragmentType == .Primitive && referseTo != nil {
                if ctx.cFunction!.functionType == .FreeFlow {
                    ctx.addCode( ", __funcData" )
                } else {
                    ctx.addCode( ", &__funcData" )
                }
            }
            
            if !arguments.isEmpty {
                let op = ")"
                ctx.font.getTextRect(text: op, scale: ctx.fontScale, rectToUse: ctx.tempRect)
                if let frag = ctx.fragment {
                    mmView.drawText.drawText(ctx.font, text: op, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
                    if self === ctx.hoverFragment || uuid == ctx.cComponent!.selected {
                        let alpha : Float = uuid == ctx.cComponent!.selected ? ctx.selectionAlpha : ctx.hoverAlpha
                        mmView.drawBox.draw( x: ctx.cX - ctx.gapX / 2, y: ctx.cY - ctx.gapY / 2, width: ctx.tempRect.width + ctx.gapX, height: ctx.lineHeight + ctx.gapY, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: frag )
                    }
                }
                ctx.cX += ctx.tempRect.width + ctx.gapX
                ctx.addCode(") ")
            
                // Expand rect, experimental
                //rect.width = ctx.cX - rect.x
            }
            
            if arguments.isEmpty && fragmentType == .Primitive && referseTo != nil {
                // For function references which dont have arguments we need to add the brackets manually
                
                let op = "()"
                ctx.font.getTextRect(text: op, scale: ctx.fontScale, rectToUse: ctx.tempRect)
                if let frag = ctx.fragment {
                    mmView.drawText.drawText(ctx.font, text: op, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
                }
                ctx.cX += ctx.tempRect.width + ctx.gapX
                ctx.addCode( "(__funcData)" )
            }
        }
    }
    
    func addProperty(_ property: FragmentProperties)
    {
        properties.append( property )
    }
    
    func removeState(_ property: FragmentProperties)
    {
        properties.removeAll(where: { $0 == property })
    }
    
    /// Returns true if the fragment supports the given property
    func supports(_ property: FragmentProperties) -> Bool
    {
        return properties.contains(property)
    }
}

/// A flat list of fragments which are either combined arithmetically or listed (function header)
class CodeStatement         : Codable, Equatable
{
    enum StatementType      : Int, Codable {
        case Arithmetic, List, Boolean
    }
    
    var statementType       : StatementType
    var fragments           : [CodeFragment] = []
    var uuid                : UUID = UUID()

    var isArgumentIndexOf   : Int = 0

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
            f.parentStatement = self
            f.draw(mmView, ctx)
            ctx.drawFragmentState(f)
        }
    }
}

/// A single block (line) of code. Has an individual fragment on the left and a list (CodeStatement) on the right. Represents any kind of supported code.
class CodeBlock             : Codable, Equatable
{
    enum BlockType          : Int, Codable {
        case Empty, FunctionHeader, OutVariable, VariableDefinition, VariableReference, IfHeader, ElseHeader, ForHeader, End
    }
    
    var blockType           : BlockType

    var fragment            : CodeFragment = CodeFragment(.Undefined)
    var assignment          : CodeFragment = CodeFragment(.Assignment, "", "=", [.Selectable])
    var statement           : CodeStatement
    
    var uuid                : UUID = UUID()
    var comment             : String = ""
    
    var children            : [CodeBlock] = []

    var rect                : MMRect = MMRect()
    
    weak var parentFunction : CodeFunction? = nil
    weak var parentBlock    : CodeBlock? = nil

    private enum CodingKeys: String, CodingKey {
        case blockType
        case fragment
        case assignment
        case statement
        case uuid
        case comment
        case children
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockType = try container.decode(BlockType.self, forKey: .blockType)
        fragment = try container.decode(CodeFragment.self, forKey: .fragment)
        assignment = try container.decode(CodeFragment.self, forKey: .assignment)
        statement = try container.decode(CodeStatement.self, forKey: .statement)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        comment = try container.decode(String.self, forKey: .comment)
        if let children = try container.decodeIfPresent([CodeBlock].self, forKey: .children) {
            self.children = children
        }
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blockType, forKey: .blockType)
        try container.encode(fragment, forKey: .fragment)
        try container.encode(assignment, forKey: .assignment)
        try container.encode(statement, forKey: .statement)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(comment, forKey: .comment)
        try container.encode(children, forKey: .children)
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
        } else
        if type == .End {
            fragment.fragmentType = .End
        }
    }
    
    /// Returns the type of the block, i.e. the type of the fragment on the left
    func evaluateType() -> String
    {
        return fragment.evaluateType()
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        fragment.parentBlock = self

        if comment.isEmpty == false {
            ctx.drawText("// " + comment, mmView.skin.Code.border)
            ctx.cY += ctx.lineHeight + ctx.gapY
        }
        
        let rStart = ctx.rectStart()
        var maxRight : Float = 0

        // Border
        if blockType == .FunctionHeader {
            ctx.font.getTextRect(text: "func", scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: "func", x: ctx.border - ctx.tempRect.width - ctx.gapX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.border, fragment: frag)
                
                if ctx.cFunction === ctx.hoverFunction {
                    let fY : Float = ctx.cFunction!.comment.isEmpty ? 0 : ctx.lineHeight + ctx.gapY
                    mmView.drawBox.draw( x: ctx.gapX / 2, y: ctx.cFunction!.rect.y - ctx.gapY / 2 + fY, width: ctx.border - ctx.gapX / 2, height: ctx.lineHeight + ctx.gapY, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, 0.5), fragment: frag )
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
            ctx.cX += 160//ctx.editorWidth - ctx.cX
            ctx.rectEnd(fragment.rect, rStart)
            ctx.cY += ctx.lineHeight + ctx.gapY
            ctx.drawFragmentState(fragment)
        } else
        if blockType == .End {
            fragment.draw(mmView, ctx)
            ctx.cY += ctx.lineHeight + ctx.gapY
        } else
        if blockType == .FunctionHeader {
            let rStart = ctx.rectStart()

            // Return type
            ctx.font.getTextRect(text: fragment.typeName, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: fragment.typeName, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.reserved, fragment: frag)
            }
            ctx.cX += ctx.tempRect.width + ctx.gapX
            
            // Function name
            ctx.font.getTextRect(text: fragment.name, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            if let frag = ctx.fragment {
                mmView.drawText.drawText(ctx.font, text: fragment.name, x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.nameHighlighted, fragment: frag)
            }
            
            ctx.cX += ctx.tempRect.width
            
            ctx.rectEnd(fragment.rect, rStart)
            if fragment.fragmentType == .TypeDefinition {
                ctx.addCode(fragment.typeName + " " + fragment.name + "( ")
            }
            ctx.cX += ctx.gapX

            ctx.font.getTextRect(text: "(", scale: ctx.fontScale, rectToUse: ctx.tempRect)
            ctx.drawText("(", mmView.skin.Code.constant)
            ctx.cX += ctx.tempRect.width + ctx.gapX
            
            let firstCX = ctx.cX
            
            for (index,arg) in statement.fragments.enumerated() {
                arg.draw(mmView, ctx)

                if index != statement.fragments.endIndex - 1 {
                    ctx.font.getTextRect(text: ",", scale: ctx.fontScale, rectToUse: ctx.tempRect)
                    if let frag = ctx.fragment {
                        mmView.drawText.drawText(ctx.font, text: ",", x: ctx.cX, y: ctx.cY, scale: ctx.fontScale, color: mmView.skin.Code.constant, fragment: frag)
                    }
                    //ctx.cX += ctx.tempRect.width + ctx.gapX
                    ctx.cX = firstCX
                    ctx.cY += ctx.lineHeight + ctx.gapY
                    if arg.properties.contains(.NotCodeable) == false {
                        ctx.addCode(",")
                    }
                }
                ctx.drawFragmentState(arg)
            }

            ctx.font.getTextRect(text: ")", scale: ctx.fontScale, rectToUse: ctx.tempRect)
            ctx.drawText(")", mmView.skin.Code.constant)
            ctx.cX += ctx.tempRect.width + ctx.gapX
            
            // FreeFlow Function Definition
            if fragment.fragmentType == .TypeDefinition {
                ctx.addCode(", thread FuncData *__funcData)\n")
                ctx.addCode("{\n")
                ctx.addCode("float GlobalTime = __funcData->GlobalTime;")
                if ctx.monitorFragment != nil {
                    ctx.addCode("float4 __monitorOut = *__funcData->__monitorOut;")
                }
                ctx.addCode(fragment.typeName + " out" + " = " + fragment.typeName + "(0);\n")
            }
 
            ctx.cY += ctx.lineHeight + ctx.gapY
            //ctx.rectEnd(fragment.rect, rStart)
            
            ctx.drawFragmentState(fragment)
            
            ctx.cIndent = ctx.indent
        } else
        if blockType == .IfHeader || blockType == .ElseHeader || blockType == .ForHeader {

            fragment.draw(mmView, ctx)
            ctx.drawFragmentState(fragment)
            ctx.cY += ctx.lineHeight + ctx.gapY
            ctx.blockNumber += 1
            
            if fragment.rect.right() > maxRight {
                maxRight = fragment.rect.right()
            }
            
            for args in fragment.arguments {
                for frags in args.fragments {
                    if frags.rect.right() > maxRight {
                        maxRight = frags.rect.right() + 16
                    }
                }
            }
                        
            ctx.addCode("{\n")
            ctx.openSyntaxBlock(uuid)
            
            for b in children {
                b.parentFunction = nil
                b.parentBlock = self
                
                ctx.cBlock = b
                ctx.cX = ctx.border + ctx.startX + ctx.cIndent
                b.draw(mmView, ctx)
                ctx.blockNumber += 1
                
                if b.rect.right() > maxRight {
                    maxRight = b.rect.right()
                }
            }
            ctx.closeSyntaxBlock(uuid)
            ctx.addCode("}\n")
        } else {
            let propIndex = ctx.cComponent!.properties.firstIndex(of: fragment.uuid)
            
            // left side
            fragment.draw(mmView, ctx)
            ctx.drawFragmentState(fragment)

            // assignment
            assignment.draw(mmView, ctx)
            ctx.drawFragmentState(assignment)

            // statement
            if let _ = propIndex {
                // PROPERTY!!!!
                let code = ctx.cComponent!.code!
                let globalCode = ctx.cComponent!.globalCode!
                statement.draw(mmView, ctx)
                ctx.cComponent!.code = code
                ctx.cComponent!.globalCode = globalCode
                let dataIndex = ctx.propertyDataOffset
                let components = fragment.evaluateComponents()
                
                if ctx.cFunction!.functionType == .FreeFlow {
                    ctx.addCode( "__funcData->__data[\(dataIndex)]" )
                } else {
                    ctx.addCode( "__data[\(dataIndex)]" )
                }
                
                if components == 1 {
                    ctx.addCode( ".x" )
                } else
                if components == 2 {
                    ctx.addCode( ".xy" )
                } else
                if components == 3 {
                    ctx.addCode( ".xyz" )
                }
                ctx.propertyDataOffset += 1
            } else {
                statement.draw(mmView, ctx)
            }
            
            ctx.cY += ctx.lineHeight + ctx.gapY
            ctx.addCode( ";\n" )
        }
        
        ctx.rectEnd(rect, rStart)
        if rect.right() < maxRight {
            rect.width = maxRight - rect.x
        }
        ctx.drawBlockState(self)
    }
}

/// A single function which has a block of code for the header and a list of blocks for the body.
class CodeFunction          : Codable, Equatable
{
    enum FunctionType       : Int, Codable {
        case FreeFlow, Colorize, SkyDome, SDF2D, SDF3D, Render2D, Render3D, Boolean, Camera2D, Camera3D
    }
    
    let functionType        : FunctionType
    var name                : String
    
    var header              : CodeBlock = CodeBlock( .FunctionHeader )
    var body                : [CodeBlock] = []
    var uuid                : UUID = UUID()
    
    var comment             : String = ""

    var rect                : MMRect = MMRect()
    
    // CloudKit
    var libraryName         : String = ""
    var libraryCategory     : String = "Noise"
    var libraryComment      : String = ""
    
    // Referenced this many times in the component
    var references          : Int = 0
    
    // Depends on these other functions
    var dependsOn           : [CodeFunction] = []

    private enum CodingKeys: String, CodingKey {
        case functionType
        case name
        case header
        case body
        case uuid
        case comment
        case libraryName
        case libraryCategory
        case libraryComment
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        functionType = try container.decode(FunctionType.self, forKey: .functionType)
        name = try container.decode(String.self, forKey: .name)
        header = try container.decode(CodeBlock.self, forKey: .header)
        body = try container.decode([CodeBlock].self, forKey: .body)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        comment = try container.decode(String.self, forKey: .comment)
        if let lName = try container.decodeIfPresent(String.self, forKey: .libraryName) {
            libraryName = lName
        }
        if let lCategory = try container.decodeIfPresent(String.self, forKey: .libraryCategory) {
            libraryCategory = lCategory
        }
        if let lComment = try container.decodeIfPresent(String.self, forKey: .libraryComment) {
            libraryComment = lComment
        }
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(functionType, forKey: .functionType)
        try container.encode(name, forKey: .name)
        try container.encode(header, forKey: .header)
        try container.encode(body, forKey: .body)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(comment, forKey: .comment)
        try container.encode(libraryName, forKey: .libraryName)
        try container.encode(libraryCategory, forKey: .libraryCategory)
        try container.encode(libraryComment, forKey: .libraryComment)
    }
    
    static func ==(lhs:CodeFunction, rhs:CodeFunction) -> Bool { // Implement Equatable
        return lhs.uuid == rhs.uuid
    }
    
    init(_ type: FunctionType, _ name: String)
    {
        functionType = type
        self.name = name
        
        var funcName = name
        var returnType = "void"
        
        if type == .FreeFlow {
            returnType = "float4"
        } else
        if type == .Colorize {
            funcName = "colorize"
        } else
        if type == .SkyDome {
            funcName = "skyDome"
        } else
        if type == .SDF2D {
            funcName = "shapeDistance"
        } else
        if type == .Render2D {
            funcName = "computeColor"
        }

        header.fragment = CodeFragment(type == .FreeFlow ? .TypeDefinition : .ConstTypeDefinition, returnType, funcName)
        
        if type == .FreeFlow {
            header.fragment.addProperty(.Selectable)
            header.fragment.addProperty(.Dragable)
        }
    }
    
    func createOutVariableBlock(_ typeName: String,_ name: String) -> CodeBlock
    {
        let b = CodeBlock(CodeBlock.BlockType.OutVariable)
        
        b.fragment.fragmentType = .OutVariable
        b.fragment.addProperty(.Selectable)
        b.fragment.addProperty(.Monitorable)
        if name != "out" {
            b.fragment.addProperty(.Dragable)
        }
        b.fragment.typeName = typeName
        b.fragment.name = name
        b.fragment.evaluatesTo = typeName
        
        if typeName == "float" {
            let constValue = CodeFragment(.ConstantValue, "float", "", [.Selectable, .Dragable, .Targetable])
            b.statement.fragments.append(constValue)
            
            if name == "outDistance" {
                constValue.values["min"] = -10000
                constValue.values["max"] = 10000
                constValue.values["value"] = 0
            }
        } else {
            let constant = CodeFragment(.ConstantDefinition, typeName, typeName, [.Selectable, .Dragable, .Targetable], [typeName], typeName)
            b.statement.fragments.append(constant)
            
            var components : Int = 4
            
            if typeName.contains("2") {
                components = 2
            } else
            if typeName.contains("3") {
                components = 3
            }
            
            for index in 0..<components {
                let argStatement = CodeStatement(.Arithmetic)
                
                let constValue = CodeFragment(.ConstantValue, "float", "", [.Selectable, .Dragable, .Targetable])
                if name == "outColor" {
                    if functionType == .Colorize || functionType == .SkyDome {
                        if index == 0 {
                            constValue.setValue(0.161)
                        } else
                        if index == 1 {
                            constValue.setValue(0.165)
                        } else
                        if index == 2 {
                            constValue.setValue(0.184)
                        }
                    } else {
                        if index == 0 {
                            constValue.setValue(0)
                        } else
                        if index == 1 {
                            constValue.setValue(0)
                        } else
                        if index == 2 {
                            constValue.setValue(0)
                        }
                    }
                }
                argStatement.fragments.append(constValue)
                constant.arguments.append(argStatement)
            }
        }
        return b
    }
    
    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        ctx.blockNumber = 1
        ctx.cVariables = [:]
        ctx.cSyntaxBlocks = [:]
        ctx.cSyntaxLevel = []
        
        ctx.openSyntaxBlock(uuid)
        
        references = 0
        dependsOn = []
        
        // Add the function arguments as variables
        for v in header.statement.fragments {
            //ctx.cVariables[v.uuid] = v
            ctx.registerVariableForSyntaxBlock(v)
        }
        
        //
        if functionType == .FreeFlow && ctx.monitorFragment != nil && body.count > 0 {
            let outFragment = body[body.count-1].fragment
            // Correct the out fragment return type
            outFragment.typeName = outFragment.parentBlock!.parentFunction!.header.fragment.typeName
            ctx.registerVariableForSyntaxBlock(outFragment)
        }
        
        let rStart = ctx.rectStart()
        var maxRight : Float = 0

        // --- Comment
        if comment.isEmpty == false {
            
            let commentText = "// " + comment
            ctx.font.getTextRect(text: commentText, scale: ctx.fontScale, rectToUse: ctx.tempRect)
            ctx.drawText(commentText, mmView.skin.Code.border)
            ctx.cY += ctx.lineHeight + ctx.gapY
            if ctx.cX + ctx.tempRect.width + ctx.gapX > maxRight {
                maxRight = ctx.cX + ctx.tempRect.width + ctx.gapX
            }
        }

        ctx.cBlock = header
        header.parentFunction = self
        header.draw(mmView, ctx)
        if header.rect.right() > maxRight {
            maxRight = header.rect.right()
        }
        
        for b in body {
            ctx.cBlock = b
            b.parentFunction = self
            b.parentBlock = nil

            ctx.cIndent = ctx.indent
            ctx.cX = ctx.border + ctx.startX + ctx.cIndent
            b.draw(mmView, ctx)
            
            if b.rect.right() > maxRight {
                maxRight = b.rect.right()
            }
            ctx.blockNumber += 1
        }
        
        ctx.rectEnd(rect, rStart)
        if rect.right() < maxRight {
            rect.width = maxRight - rect.x
        }
        
        //mmView.drawBox.draw( x: ctx.border, y: rect.y, width: 2, height: rect.height, round: 0, borderSize: 0, fillColor: mmView.skin.Code.border, fragment: ctx.fragment )
        ctx.drawFunctionState(self)
        
        ctx.closeSyntaxBlock(uuid)
    }
}

/// A code component which is a list of functions.
class CodeComponent         : Codable, Equatable
{
    enum ComponentType      : Int, Codable {
        case Colorize, SkyDome, SDF2D, SDF3D, Render2D, Render3D, Boolean, FunctionContainer, Camera2D, Camera3D, Domain2D, Domain3D
    }
    
    enum PropertyGizmoMapping: Int, Codable {
        case None, AllScale, XScale, YScale, ZScale
    }
    
    let componentType       : ComponentType
    
    var functions           : [CodeFunction] = []
    var uuid                : UUID = UUID()
    
    var selected            : UUID? = nil

    var rect                : MMRect = MMRect()
    
    // Properties and their animation
    var properties          : [UUID] = []
    var artistPropertyNames : [UUID:String] = [:]
    var propertyGizmoMap    : [UUID:PropertyGizmoMapping] = [:]
    var sequence            : MMTlSequence = MMTlSequence()
    
    // CloudKit
    var libraryName         : String = ""
    var libraryCategory     : String = "Noise"
    var libraryComment      : String = ""

    // Values
    var values              : [String:Float] = [:]
    
    // Code Generation
    var code                : String? = nil
    var globalCode          : String? = nil

    // Subcomponent, used for boolean operation
    var subComponent        : CodeComponent? = nil

    private enum CodingKeys: String, CodingKey {
        case componentType
        case functions
        case uuid
        case selected
        case properties
        case artistPropertyNames
        case propertyGizmoMap
        case sequence
        case libraryName
        case libraryCategory
        case libraryComment
        case values
        case subComponent
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        componentType = try container.decode(ComponentType.self, forKey: .componentType)
        functions = try container.decode([CodeFunction].self, forKey: .functions)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        selected = try container.decode(UUID?.self, forKey: .selected)
        properties = try container.decode([UUID].self, forKey: .properties)
        artistPropertyNames = try container.decode([UUID:String].self, forKey: .artistPropertyNames)
        if let map = try container.decodeIfPresent([UUID:PropertyGizmoMapping].self, forKey: .propertyGizmoMap) {
            propertyGizmoMap = map
        }
        sequence = try container.decode(MMTlSequence.self, forKey: .sequence)
        libraryName = try container.decode(String.self, forKey: .libraryName)
        if let category = try container.decodeIfPresent(String.self, forKey: .libraryCategory) {
            libraryCategory = category
        }
        libraryComment = try container.decode(String.self, forKey: .libraryComment)
        values = try container.decode([String:Float].self, forKey: .values)
        subComponent = try container.decode(CodeComponent?.self, forKey: .subComponent)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(componentType, forKey: .componentType)
        try container.encode(functions, forKey: .functions)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(selected, forKey: .selected)
        try container.encode(properties, forKey: .properties)
        try container.encode(artistPropertyNames, forKey: .artistPropertyNames)
        try container.encode(propertyGizmoMap, forKey: .propertyGizmoMap)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(libraryName, forKey: .libraryName)
        try container.encode(libraryCategory, forKey: .libraryCategory)
        try container.encode(libraryComment, forKey: .libraryComment)
        try container.encode(values, forKey: .values)
        try container.encode(subComponent, forKey: .subComponent)
    }
    
    static func ==(lhs:CodeComponent, rhs:CodeComponent) -> Bool { // Implement Equatable
        return lhs.uuid == rhs.uuid
    }
    
    init(_ type: ComponentType = .Colorize,_ name: String = "")
    {
        componentType = type
        self.libraryName = name
    }
    
    func createFunction(_ name: String)
    {
        let f = CodeFunction(.FreeFlow, name)
        f.body.append(CodeBlock(.Empty))
        functions.append(f)
    }
    
    func createDefaultFunction(_ type: CodeFunction.FunctionType)
    {
        if type == .Colorize {
            let f = CodeFunction(type, "colorize")
            f.comment = "Returns a color for the given uv position [0..1]"
            
            let arg1 = CodeFragment(.VariableDefinition, "float2", "uv", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg1)
            
            let arg2 = CodeFragment(.VariableDefinition, "float2", "size", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg2)
            
            let b = CodeBlock(.Empty)
            b.fragment.addProperty(.Selectable)
            f.body.append(b)
            f.body.append(f.createOutVariableBlock("float4", "outColor"))
            functions.append(f)
        } else
        if type == .SkyDome {
            let f = CodeFunction(type, "skyDome")
            f.comment = "Returns a color for the given ray direction"
            
            let arg1 = CodeFragment(.VariableDefinition, "float2", "uv", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg1)
            
            let arg2 = CodeFragment(.VariableDefinition, "float2", "size", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg2)
            
            let arg3 = CodeFragment(.VariableDefinition, "float3", "dir", [.Selectable, .Dragable, .NotCodeable], ["float3"], "float3")
            f.header.statement.fragments.append(arg3)
            
            let b = CodeBlock(.Empty)
            b.fragment.addProperty(.Selectable)
            f.body.append(b)
            f.body.append(f.createOutVariableBlock("float4", "outColor"))
            functions.append(f)
        } else
        if type == .SDF2D {
            let f = CodeFunction(type, "shapeDistance")
            f.comment = "Returns the distance to the shape for the given position"
            
            let arg1 = CodeFragment(.VariableDefinition, "float2", "pos", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg1)
            
            let b = CodeBlock(.Empty)
            b.fragment.addProperty(.Selectable)
            f.body.append(b)
            f.body.append(f.createOutVariableBlock("float", "outDistance"))
            functions.append(f)
        } else
        if type == .Render2D {
            let f = CodeFunction(type, "computeColor")
            f.comment = "Computes the pixel color for the given material"
            
            let arg1 = CodeFragment(.VariableDefinition, "float2", "uv", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg1)
            
            let arg2 = CodeFragment(.VariableDefinition, "float2", "size", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg2)
            
            let arg3 = CodeFragment(.VariableDefinition, "float", "distance", [.Selectable, .Dragable, .NotCodeable], ["float"], "float")
            f.header.statement.fragments.append(arg3)
            
            let arg4 = CodeFragment(.VariableDefinition, "float4", "backColor", [.Selectable, .Dragable, .NotCodeable], ["float4"], "float4")
            f.header.statement.fragments.append(arg4)
            
            let arg5 = CodeFragment(.VariableDefinition, "float4", "matColor", [.Selectable, .Dragable, .NotCodeable], ["float4"], "float4")
            f.header.statement.fragments.append(arg5)
            
            let b = CodeBlock(.Empty)
            b.fragment.addProperty(.Selectable)
            f.body.append(b)
            f.body.append(f.createOutVariableBlock("float4", "outColor"))
            functions.append(f)
        } else
        if type == .Boolean {
            let f = CodeFunction(type, "booleanOperator")
            f.comment = "Choose between the two shapes based on their distances stored in .x"
            
            let arg1 = CodeFragment(.VariableDefinition, "float4", "shapeA", [.Selectable, .Dragable, .NotCodeable], ["float4"], "float4")
            f.header.statement.fragments.append(arg1)
            
            let arg2 = CodeFragment(.VariableDefinition, "float4", "shapeB", [.Selectable, .Dragable, .NotCodeable], ["float4"], "float4")
            f.header.statement.fragments.append(arg2)
            
            let b = CodeBlock(.Empty)
            b.fragment.addProperty(.Selectable)
            f.body.append(b)
            f.body.append(f.createOutVariableBlock("float4", "outShape"))
            functions.append(f)
        } else
        if type == .Camera2D {
            let f = CodeFunction(type, "camera")
            f.comment = "Translates an incoming position."
            
            let arg1 = CodeFragment(.VariableDefinition, "float2", "position", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg1)
            
            let b = CodeBlock(.Empty)
            b.fragment.addProperty(.Selectable)
            f.body.append(b)
            f.body.append(f.createOutVariableBlock("float2", "outPosition"))
            functions.append(f)
        } else
        if type == .Camera3D {
            let f = CodeFunction(type, "camera")
            f.comment = "Generates a camera ray."
            
            let arg1 = CodeFragment(.VariableDefinition, "float2", "uv", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg1)
            
            let arg2 = CodeFragment(.VariableDefinition, "float2", "size", [.Selectable, .Dragable, .NotCodeable], ["float2"], "float2")
            f.header.statement.fragments.append(arg2)
            
            let b = CodeBlock(.Empty)
            b.fragment.addProperty(.Selectable)
            f.body.append(b)
            f.body.append(f.createOutVariableBlock("float3", "outPosition"))
            f.body.append(f.createOutVariableBlock("float3", "outDirection"))
            functions.append(f)
        }
    }
    
    func codeAt(_ x: Float,_ y: Float,_ ctx: CodeContext)
    {
        ctx.hoverFunction = nil
        ctx.hoverBlock = nil
        ctx.hoverFragment = nil
        
        func parseBlock(_ b: CodeBlock)
        {
            func parseFragments(_ fragment: CodeFragment)
            {
                var processArguments = true
                if fragment.fragmentType == .ConstantDefinition && fragment.isSimplified {
                    // If fragment is simplified, skip arguments
                    processArguments = false
                }
                
                if processArguments {
                    for statement in fragment.arguments {
                        for arg in statement.fragments {
                            if arg.rect.contains(x, y) {
                                ctx.hoverFragment = arg
                                return
                            }
                            parseFragments(arg)
                        }
                    }
                }
                if ctx.hoverFragment == nil {
                    if fragment.rect.contains(x, y) {
                        ctx.hoverFragment = fragment
                        return
                    }
                }
            }
            
            // Check for block marker
            if y >= b.rect.y && y <= b.rect.y + ctx.lineHeight && x <= ctx.border {
                ctx.hoverBlock = b
                return
            }
            
            // Check for the left sided fragment
            if b.fragment.supports(.Selectable) && b.fragment.rect.contains(x, y) {
                ctx.hoverFragment = b.fragment
                return
            }
            
            // Parse If, Else
            if b.fragment.fragmentType == .If || b.fragment.fragmentType == .Else || b.fragment.fragmentType == .For {
                for statement in b.fragment.arguments {
                    for fragment in statement.fragments {
                        parseFragments(fragment)
                        if ctx.hoverFragment != nil {
                            return;
                        }
                    }
                }
                
                if ctx.hoverFragment == nil {
                    for bchild in b.children {
                        parseBlock(bchild)
                        if ctx.hoverFragment != nil {
                            return
                        }
                    }
                }
            }
            
            // Check for assignment fragment
            if (b.blockType == .VariableReference || b.blockType == .OutVariable) && b.assignment.supports(.Selectable) && b.assignment.rect.contains(x, y) {
                ctx.hoverFragment = b.assignment
                return
            }
            
            // recursively parse the right sided fragments
            for fragment in b.statement.fragments {
                parseFragments(fragment)
                if ctx.hoverFragment != nil {
                    return;
                }
            }
        }
        
        for f in functions {
            
            // Check for func marker
            let fY : Float = f.rect.y + (f.comment.isEmpty ? 0 : ctx.lineHeight + ctx.gapY)
            if y >= fY && y <= fY + ctx.lineHeight && x <= ctx.border {
                ctx.hoverFunction = f
                break
            }
            
            // ---
            
            // Function return type
            if f.header.fragment.supports(.Selectable) && f.header.fragment.rect.contains(x, y) {
                ctx.hoverFragment = f.header.fragment
                break
            }
            
            // Function argument
            for arg in f.header.statement.fragments {
                if arg.rect.contains(x, y) {
                    ctx.hoverFragment = arg
                    break
                }
            }
            
            for b in f.body {
                parseBlock(b)
            }
        }
     }
    
    func selectUUID(_ uuid: UUID,_ ctx: CodeContext)
    {
        ctx.selectedFunction = nil
        ctx.selectedBlock = nil
        ctx.selectedFragment = nil
        
        for f in functions {
            
            // Check for func marker
            if uuid == f.uuid {
                ctx.selectedFunction = f
                break
            }
            
            // ---
            
            // Function return type
            if f.header.fragment.supports(.Selectable) && f.header.fragment.uuid == uuid {
                ctx.selectedFragment = f.header.fragment
                break
            }
            
            // Function argument
            for arg in f.header.statement.fragments {
                if arg.uuid == uuid {
                    ctx.selectedFragment = arg
                    break
                }
            }
            
            for b in f.body {
                
                // Check for block marker
                if b.uuid == uuid {
                    ctx.selectedBlock = b
                    break
                }
                
                // Check for the left sided fragment
                if b.fragment.supports(.Selectable) && b.fragment.uuid == uuid {
                    ctx.selectedFragment = b.fragment
                    break
                }
                                
                // recursively parse the right sided fragments
                func parseFragments(_ fragment: CodeFragment)
                {
                    for statement in fragment.arguments {
                        for arg in statement.fragments {
                            if arg.uuid == uuid {
                                ctx.selectedFragment = arg
                                return
                            }
                            parseFragments(arg)
                        }
                    }
                    //if ctx.selectedFragment == nil {
                        if fragment.uuid == uuid {
                            ctx.selectedFragment = fragment
                            return
                        }
                    //}
                }
                
                for fragment in b.statement.fragments {
                    parseFragments(fragment)
                    if ctx.selectedFragment != nil {
                        break;
                    }
                }
            }
        }
    }
    
    func getPropertyOfUUID(_ uuid: UUID) -> (CodeFragment?, CodeFragment?)
    {
        for f in functions {
            for b in f.body {
                // Check for the left sided fragment
                if b.fragment.uuid == uuid {
                    return (b.fragment, b.statement.fragments[0])
                }
            }
        }
        return (nil,nil)
     }

    func draw(_ mmView: MMView,_ ctx: CodeContext)
    {
        let rStart = ctx.rectStart()
        ctx.cComponent = self
        
        code = ""
        globalCode = ""
        
        for f in functions {
            
            if f.functionType == .FreeFlow {
                ctx.insideGlobalCode = true
            } else {
                ctx.insideGlobalCode = false
            }
            
            ctx.functionHasMonitor = false
            
            ctx.cFunction = f
            ctx.cX = ctx.border + ctx.startX
            ctx.cIndent = 0
            
            f.draw(mmView, ctx)
            
            if f.functionType == .FreeFlow {
                if ctx.monitorFragment != nil && ctx.functionHasMonitor == true {
                    ctx.addCode("*__funcData->__monitorOut = __monitorOut;\n")
                }
                ctx.addCode("return out;\n")
                ctx.addCode("}\n")
            }
            
            ctx.cY += CodeContext.fSpace
            ctx.functionMap[f.uuid] = f
        }
        
        ctx.rectEnd(rect, rStart)
        
        //if globalCode!.count > 0 {
            //print(globalCode!)
        //}
    }
}

/// The editor context to draw the code in
class CodeContext
{
    let mmView              : MMView
    let font                : MMFont
    var fontScale           : Float = 0.45
    
    weak var fragment       : MMFragment? = nil
    
    // Running vars
    var cX                  : Float = 0
    var cY                  : Float = 0
    var cIndent             : Float = 0

    weak var cComponent     : CodeComponent? = nil
    weak var cFunction      : CodeFunction? = nil
    weak var cBlock         : CodeBlock? = nil
    
    var cVariables          : [UUID:CodeFragment] = [:]
    var cSyntaxBlocks       : [UUID:[CodeFragment]] = [:]
    var cSyntaxLevel        : [UUID] = []

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
    
    weak var hoverFunction  : CodeFunction? = nil
    weak var hoverBlock     : CodeBlock? = nil
    weak var hoverFragment  : CodeFragment? = nil
    
    weak var selectedFunction: CodeFunction? = nil
    weak var selectedBlock   : CodeBlock? = nil
    weak var selectedFragment: CodeFragment? = nil
    
    weak var dropFragment   : CodeFragment? = nil
    var dropIsValid         : Bool = false
    var dropOriginalUUID    : UUID = UUID()

    var tempRect            : MMRect = MMRect()
    
    var propertyDataOffset  : Int = 0
    
    weak var monitorFragment: CodeFragment? = nil
    var monitorComponents   : Int = 0
    
    var insideGlobalCode    : Bool = false
    
    var functionMap         : [UUID:CodeFunction] = [:]
    var functionHasMonitor  : Bool = false
    
    static var fSpace       : Float = 30

    init(_ view: MMView,_ fragment: MMFragment?,_ font: MMFont,_ fontScale: Float)
    {
        mmView = view
        self.fragment = fragment
        self.font = font
        self.fontScale = fontScale
    }
    
    func reset(_ editorWidth: Float = 10000,_ propertyDataOffset: Int = 0,_ monitorFragment: CodeFragment? = nil)
    {
        //fontScale = 0.45
        startX = 10
        
        cY = CodeContext.fSpace
        cIndent = 0
        
        gapX = 5
        gapY = 1
        indent = 20
        border = font.getTextRect(text: "func", scale: fontScale).width + 2 * gapX
        
        hoverAlpha = 0.5
        selectionAlpha = 0.7
        
        lineHeight = font.getLineHeight(fontScale)

        self.editorWidth = editorWidth
        self.propertyDataOffset = propertyDataOffset
        self.monitorFragment = monitorFragment
        
        // Compute monitor components
        monitorComponents = 0
        if let fragment = monitorFragment {
            monitorComponents = 1
            if fragment.typeName.contains("2") {
                monitorComponents = 2
            } else
            if fragment.typeName.contains("3") {
                monitorComponents = 3
            }
            if fragment.typeName.contains("4") {
                monitorComponents = 4
            }
        }
        
        insideGlobalCode = false
        dropIsValid = false
    }
    
    // Inserts the monitor code for the given variable
    func insertMonitorCode(_ fragment: CodeFragment)
    {
        let outVariableName = "__monitorOut"
        
        functionHasMonitor = true
                
        var code : String = ""
        if fragment.typeName.contains("2") {
            code += "\(outVariableName).x = " + fragment.name + ".x;\n";
            code += "\(outVariableName).y = " + fragment.name + ".y;\n";
            code += "\(outVariableName).z = 0;\n";
            code += "\(outVariableName).w = 1;\n";
        } else
        if fragment.typeName.contains("3") {
            code += "\(outVariableName).x = " + fragment.name + ".x;\n";
            code += "\(outVariableName).y = " + fragment.name + ".y;\n";
            code += "\(outVariableName).z = " + fragment.name + ".z;\n";
            code += "\(outVariableName).w = 1;\n";
        } else
        if fragment.typeName.contains("4") {
            code += "\(outVariableName).x = " + fragment.name + ".x;\n";
            code += "\(outVariableName).y = " + fragment.name + ".y;\n";
            code += "\(outVariableName).z = " + fragment.name + ".z;\n";
            code += "\(outVariableName).w = " + fragment.name + ".w;\n";
        } else {
            code += "\(outVariableName) = float4(float3(" + fragment.name + "),1);\n";
        }
        addCode(code)
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
    
    func openSyntaxBlock(_ uuid: UUID)
    {
        cIndent += indent
        cSyntaxBlocks[uuid] = []
        cSyntaxLevel.append(uuid)
    }
    
    func closeSyntaxBlock(_ uuid: UUID)
    {
        cIndent -= indent
        
        if let variablesForBlock = cSyntaxBlocks[uuid] {
            for frag in variablesForBlock {
                cVariables[frag.uuid] = nil
                
                if let monitor = monitorFragment {
                    if monitor.uuid == frag.uuid {
                        // MONITOR !!! ADD MONITOR CODE
                        insertMonitorCode(monitor)
                    }
                }
            }
        }
        
        cSyntaxBlocks[uuid] = nil
        cSyntaxLevel.removeLast()
    }
    
    func registerVariableForSyntaxBlock(_ variable: CodeFragment)
    {
        cVariables[variable.uuid] = variable
        if let currentSyntaxUUID = cSyntaxLevel.last {
            cSyntaxBlocks[currentSyntaxUUID]?.append(variable)
        }
    }
    
    func drawText(_ text: String,_ color: SIMD4<Float>)
    {
        if let frag = fragment {
            mmView.drawText.drawText(font, text: text, x: cX, y: cY, scale: fontScale, color: color, fragment: frag)
        }
    }
    
    func addCode(_ source: String)
    {
        if insideGlobalCode {
            if cComponent!.globalCode != nil {
                cComponent!.globalCode! += source
            }
        } else {
            if cComponent!.code != nil {
                cComponent!.code! += source
            }
        }
    }
    
    func drawHighlight(_ rect: MMRect,_ alpha: Float = 0.5)
    {
        if let frag = fragment {
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: frag )
        }
    }
    
    func drawFunctionState(_ function: CodeFunction)
    {
        if let frag = fragment {
            if function === hoverFunction || function.uuid == cComponent!.selected {
                let alpha : Float = function.uuid == cComponent!.selected ? selectionAlpha : hoverAlpha
                mmView.drawBox.draw( x: function.rect.x - gapX / 2, y: function.rect.y, width: function.rect.width, height: function.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: frag )
            }
        }
    }
    
    func drawBlockState(_ block: CodeBlock)
    {
        if let frag = fragment {
            if block === hoverBlock || block.uuid == cComponent!.selected {
                let alpha : Float = block.uuid == cComponent!.selected ? selectionAlpha : hoverAlpha
                mmView.drawBox.draw( x: block.rect.x, y: block.rect.y, width: block.rect.width, height: block.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: frag )
            }
        }
    }
    
    func drawFragmentState(_ fragment: CodeFragment)
    {
        if let drop = dropFragment, fragment == hoverFragment {
                      
            #if DEBUG
            print("drawFragmentState, drop =", drop.fragmentType, ", fragment =", fragment.fragmentType)
            #endif
            
            // Dragging a function, need to check for recursion
            if drop.fragmentType == .Primitive && drop.referseTo != nil {
                if let pBlock = drop.parentBlock {
                    if let function = pBlock.parentFunction {
                        if function.rect.contains(fragment.rect.x, fragment.rect.y) || function.rect.y > fragment.rect.y {
                            dropIsValid = false
                            return
                        }
                    }
                }
            }
            
            // Drop on an empty line (.VariableDefinition)
            if cBlock!.blockType == .Empty && (drop.fragmentType == .VariableDefinition || drop.fragmentType == .VariableReference || drop.fragmentType == .OutVariable || (drop.name.starts(with: "if") && drop.typeName == "block" ) || (drop.name.starts(with: "for") && drop.typeName == "block" ) ) {
                drawHighlight(fragment.rect, hoverAlpha)
                dropIsValid = true
            } else
            if fragment.supports(.Targetable)
            {
                if fragment.uuid == dropOriginalUUID {
                    // Exclusion: Dont allow drop on itself
                    #if DEBUG
                    print("Exclusion #1")
                    #endif
                } else
                if drop.fragmentType == .ConstantDefinition && fragment.fragmentType == .ConstantValue {
                    // Exclusion: Dont allow a floatx to be dropped on a constant value (float)
                    #if DEBUG
                    print("Exclusion #2")
                    #endif
                } else
                if drop.fragmentType == .ConstantDefinition && fragment.fragmentType == .VariableReference && drop.evaluateComponents() != fragment.evaluateComponents() {
                    // Exclusion: Dont allow a floatx to be dropped on a variable reference
                    #if DEBUG
                    print("Exclusion #3")
                    #endif
                } else
                if drop.fragmentType == .ConstantDefinition && fragment.fragmentType == .ConstantDefinition && drop.typeName != fragment.typeName {
                    // Exclusion: Dont allow a floatx to be dropped on a floatx when the type is not the same
                    #if DEBUG
                    print("Exclusion #4")
                    #endif
                } else
                /*
                if drop.fragmentType == .VariableReference && fragment.fragmentType == .ConstantDefinition && drop.typeName != fragment.typeName {
                    // Exclusion: Dont allow a "var floatx" to be dropped on a floatx when the type is not the same
                    #if DEBUG
                    print("Exclusion #5")
                    #endif
                } else*/
                if drop.fragmentType == .VariableReference && fragment.fragmentType == .Primitive && drop.typeName != fragment.typeName {
                    // Exclusion: Dont allow a "var floatx" to be dropped on a floatx when the type is not the same
                    #if DEBUG
                    print("Exclusion #6")
                    #endif
                } else
                if drop.fragmentType == .Primitive && drop.supportsType( fragment.evaluateType() ) == false {
                    // Exclusion: When the .Primitive does not support the type of the destination
                    #if DEBUG
                    print("Exclusion #7")
                    #endif
                } else
                if drop.fragmentType == .Primitive && fragment.fragmentType == .VariableDefinition && fragment.parentBlock!.blockType == .ForHeader {
                    // Exclusion: Dont allow to drop a primitive on the left side of a variable definition in a for header
                    #if DEBUG
                    print("Exclusion #8")
                    #endif
                } else
                // Allow drop when not .VariableDefinition (coming straight from the source list)
                if drop.fragmentType != .VariableDefinition {
                    drawHighlight(fragment.rect, hoverAlpha)
                    dropIsValid = true
                }
            }
        } else
        if fragment === hoverFragment || fragment.uuid == cComponent!.selected {
            let alpha : Float = fragment.uuid == cComponent!.selected ? selectionAlpha : hoverAlpha
            drawHighlight(fragment.rect, alpha)
        }
    }
}
