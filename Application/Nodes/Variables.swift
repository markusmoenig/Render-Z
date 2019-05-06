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
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUINumber(self, variable: "value", title: "Value", range: float2(0, 100), value: 0),
            NodeUIDropDown(self, variable: "access", title: "Access", items: ["Public", "Private"], index: 1),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUINumber(self, variable: "min", title: "Min", range: float2(-1000, 1000), value: 0),
            NodeUINumber(self, variable: "max", title: "Max", range: float2(-1000, 1000), value: 100)
        ]
        
        uiItems[3].role = .MinValue
        uiItems[4].role = .MaxValue

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
    
    /// Execute Object physic properties
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) ->    Result
    {
        return .Success
    }
    
    /// Restore default value
    override func finishExecution() {
        let number = uiItems[0] as! NodeUINumber
        properties["value"] = number.defaultValue
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
            NodeUIValueVariablePicker(self, variable: "node", title: "Node", connection:  uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUINumber(self, variable: "value", title: "Value", range: float2(-1000, 1000), value: 1)
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
            
            number?.range.x = target.properties["min"]!
            number?.range.y = target.properties["max"]!

            var value : Float = target.properties["value"]! + properties["value"]!
            value = max( value, target.properties["min"]! )
            value = min( value, target.properties["max"]! )

            target.properties["value"] = value
            number?.value = value
        }
        
        return .Success
    }
}
