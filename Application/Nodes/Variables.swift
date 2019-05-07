//
//  Variables.swift
//  Shape-Z
//
//  Created by Markus Moenig on 04.05.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class ValueVariable : Node
{
    override init()
    {
        super.init()
        
        name = "Value"
        type = "Value Variable"
        brand = .Property
        
        properties["defaultValue"] = 0
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        print( "init", properties["defaultValue"] )

        uiItems = [
            NodeUINumber(self, variable: "value", title: "Value", range: nil, value: properties["defaultValue"]!),
            NodeUIDropDown(self, variable: "access", title: "Access", items: ["Public", "Private"], index: 1),
            NodeUISeparator(self, variable:"", title: "")
        ]

        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Value Variable"
        brand = .Property
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// A UI Variable changed
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false)
    {
        if variable == "value" {
            let number = uiItems[0] as! NodeUINumber
            number.defaultValue = newValue
            properties["defaultValue"] = newValue
        }
    }
    
    /// Restore default value
    override func finishExecution() {
        let number = uiItems[0] as! NodeUINumber
        properties["value"] = number.defaultValue
        number.value = number.defaultValue
    }
}

class DirectionVariable : Node
{
    override init()
    {
        super.init()
        
        name = "Direction"
        type = "Direction Variable"
        brand = .Property
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUINumber(self, variable: "angle", title: "Angle", range: float2(0,359), value: 0),
            NodeUIDropDown(self, variable: "access", title: "Access", items: ["Public", "Private"], index: 1),
            NodeUISeparator(self, variable:"", title: "")
        ]
        
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Direction Variable"
        brand = .Property
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Execute Object physic properties
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) ->    Result
    {
        return .Success
    }
    
    /// Restore default value
    override func finishExecution() {
        let number = uiItems[0] as! NodeUINumber
        properties["angle"] = number.defaultValue
        number.value = number.defaultValue
    }
}

class AddValueVariable : Node
{
    override init()
    {
        super.init()
        
        name = "Add Value"
        type = "Add Value Variable"
        
        uiConnections.append(UINodeConnection(.ValueVariable))
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "In", connector: .Top, brand: .Behavior, node: self)
        ]
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIMasterPicker(self, variable: "master", title: "Class", connection:  uiConnections[0]),
            NodeUIValueVariablePicker(self, variable: "node", title: "Variable", connection:  uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUINumber(self, variable: "value", title: "Value", range: nil, value: 1),
            NodeUINumber(self, variable: "max", title: "Max", range: nil, value: 100)
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Add Value Variable"
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Execute the given animation
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        if let target = uiConnections[0].target as? ValueVariable {
            let number = target.uiItems[0] as? NodeUINumber
            
            //number?.range.x = target.properties["min"]!
            //number?.range.y = target.properties["max"]!

            var value : Float = target.properties["value"]! + properties["value"]!
            //value = max( value, target.properties["min"]! )
            value = min( value, properties["max"]! )

            target.properties["value"] = value
            number?.value = value
        }
        
        return .Success
    }
}
