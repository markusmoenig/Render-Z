//
//  CodeSemantics.swift
//  Render-Z
//
//  Created by Markus Moenig on 27/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class CodeFragment
{
    enum FragmentType {
        case Variable
    }
    
    let fragmentType        : FragmentType
    let typeName            : String
    var name                : String
    
    init(_ type: FragmentType,_ typeName: String,_ name: String)
    {
        fragmentType = type
        self.typeName = typeName
        self.name = name
    }
}

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
    
    var parameters          : [CodeFragment] = []
    var returns             : CodeFragment? = nil

    var rects               : [String: MMRect] = [:]
    var hoverArea           : HoverArea = .None

    init(_ type: FunctionType, _ name: String)
    {
        functionType = type
        self.name = name
        
        rects["body"] = MMRect()
    }
    
    func returnType() -> String {
        if returns == nil {
            return "void"
        } else {
            return returns!.typeName
        }
    }
}

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
}
