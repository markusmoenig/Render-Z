//
//  Variables.swift
//  Shape-Z
//
//  Created by Markus Moenig on 04.05.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class FloatVariable : Node
{
    override init()
    {
        super.init()
        
        name = "Float"
        type = "Float Variable"
        brand = .Property
        
        properties["defaultValue"] = 0
    }
    
    override func setup()
    {
        type = "Float Variable"
        brand = .Property
        
        //helpUrl = "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/overview"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUINumber(self, variable: "value", title: "Value", range: nil, value: properties["defaultValue"]!),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "access", title: "Access", items: ["Public", "Private"], index: 1),
        ]
        
        let number = uiItems[0] as! NodeUINumber
        number.defaultValue = properties["defaultValue"]!

        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// A UI Variable changed
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        if variable == "value" {
            let number = uiItems[0] as! NodeUINumber
            number.defaultValue = newValue
            properties["defaultValue"] = newValue
        }
        if noUndo == false {
            super.variableChanged(variable: variable, oldValue: oldValue, newValue: newValue, continuous: continuous)
        }
    }
    
    /// Restore default value
    override func finishExecution() {
        let number = uiItems[0] as! NodeUINumber
        properties["value"] = number.defaultValue
        number.value = number.defaultValue
    }
    
    /// Returns the current value of the variable
    func getValue() -> Float
    {
        return properties["value"]!
    }

    /// Set a new value to the variable
    func setValue(_ value: Float)
    {
        properties["value"] = value
        
        if let number = uiItems[0] as? NodeUINumber {
            number.value = value
            number.updateLinked()
        }
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
            NodeUIAngle(self, variable: "orientation", title: "", value: 0),
            NodeUINumber(self, variable: "angle", title: "Angle", range: float2(0,360), value: 0),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "access", title: "Access", items: ["Public", "Private"], index: 1)
        ]
        
        uiItems[1].linkedTo = uiItems[0]
        uiItems[0].linkedTo = uiItems[1]
        
        if properties["defaultValue"] != nil {
            let number = uiItems[1] as! NodeUINumber
            number.defaultValue = properties["defaultValue"]!
        }
        
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
    
    /// A UI Variable changed
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        if variable == "angle" {
            let number = uiItems[1] as! NodeUINumber
            number.defaultValue = newValue
            properties["defaultValue"] = newValue
        }
        if noUndo == false {
            super.variableChanged(variable: variable, oldValue: oldValue, newValue: newValue, continuous: continuous)
        }
    }
    
    /// Restore default value
    override func finishExecution() {
        let number = uiItems[1] as! NodeUINumber
        properties["angle"] = number.defaultValue
        number.value = number.defaultValue
        number.updateLinked()
    }
    
    /// Returns the current value of the variable
    func getValue() -> Float
    {
        return properties["angle"]!
    }
    
    /// Set a new value to the variable
    func setValue(_ value: Float)
    {
        properties["angle"] = value
        
        if let number = uiItems[1] as? NodeUINumber {
            number.value = value
            number.updateLinked()
        }
    }
}

class Float2Variable : Node
{
    override init()
    {
        super.init()
        
        name = "Float2"
    }
    
    override func setup()
    {
        type = "Float2 Variable"
        brand = .Property
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUINumber(self, variable: "x", title: "X", range: nil, value: 0),
            NodeUINumber(self, variable: "y", title: "Y", range: nil, value: 0),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "access", title: "Access", items: ["Public", "Private"], index: 1)
        ]
        
        if properties["defaultValueX"] != nil {
            let numberX = uiItems[0] as! NodeUINumber
            numberX.defaultValue = properties["defaultValueX"]!
        }
        if properties["defaultValueY"] != nil {
            let numberY = uiItems[1] as! NodeUINumber
            numberY.defaultValue = properties["defaultValueY"]!
        }
        
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
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
    
    /// A UI Variable changed
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        if variable == "x" {
            let number = uiItems[0] as! NodeUINumber
            number.defaultValue = newValue
            properties["defaultValueX"] = newValue
        } else
        if variable == "y" {
            let number = uiItems[1] as! NodeUINumber
            number.defaultValue = newValue
            properties["defaultValueY"] = newValue
        }
        if noUndo == false {
            super.variableChanged(variable: variable, oldValue: oldValue, newValue: newValue, continuous: continuous)
        }
    }
    
    /// Restore default value
    override func finishExecution() {
        let numberX = uiItems[0] as! NodeUINumber
        let numberY = uiItems[1] as! NodeUINumber
        properties["x"] = numberX.defaultValue
        numberX.value = numberX.defaultValue
        properties["y"] = numberY.defaultValue
        numberY.value = numberY.defaultValue
    }
    
    /// Returns the current value of the variable
    func getValue() -> float2
    {
        return float2(properties["x"]!,properties["y"]!)
    }
    
    /// Set a new value to the variable
    func setValue(_ value: float2)
    {
        properties["x"] = value.x
        properties["y"] = value.y

        let numberX = uiItems[0] as! NodeUINumber
        let numberY = uiItems[1] as! NodeUINumber
        
        numberX.value = value.x
        numberY.value = value.y
    }
}

class ResetFloatVariable : Node
{
    override init()
    {
        super.init()
        
        name = "Reset Float"
        type = "Reset Float Variable"
        
        uiConnections.append(UINodeConnection(.FloatVariable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Reset Float Variable"
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
            NodeUIFloatVariableTarget(self, variable: "node", title: "Variable", connection:  uiConnections[0])
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Reset the value variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let target = uiConnections[0].target as? FloatVariable {
            let number = target.uiItems[0] as? NodeUINumber
            target.setValue(number!.defaultValue)
            
            playResult = .Success
        }
        
        return playResult!
    }
}

class AddConstFloatVariable : Node
{
    override init()
    {
        super.init()
        
        name = "Const Plus Float"
        uiConnections.append(UINodeConnection(.FloatVariable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Add Float Variable"
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
            NodeUIFloatVariableTarget(self, variable: "node", title: "Variable", connection:  uiConnections[0]),
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
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Add value to variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let target = uiConnections[0].target as? FloatVariable {
            
            var value : Float = target.getValue() + properties["value"]!
            value = min( value, properties["max"]! )
            target.setValue(value)
            
            playResult = .Success
        }
        
        return playResult!
    }
}

class SubtractConstFloatVariable : Node
{
    override init()
    {
        super.init()
        
        name = "Float Minus Const"
        uiConnections.append(UINodeConnection(.FloatVariable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Subtract Float Variable"
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
            NodeUIFloatVariableTarget(self, variable: "node", title: "Variable", connection:  uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUINumber(self, variable: "value", title: "Value", range: nil, value: 1),
            NodeUINumber(self, variable: "min", title: "Min", range: nil, value: 0)
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Subtract value from variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let target = uiConnections[0].target as? FloatVariable {
            let number = target.uiItems[0] as? NodeUINumber
            
            var value : Float = target.properties["value"]! - properties["value"]!
            value = max( value, properties["min"]! )
            
            target.properties["value"] = value
            number?.value = value
            number?.updateLinked()
            
            playResult = .Success
        }
        
        return playResult!
    }
}

class TestFloatVariable : Node
{
    override init()
    {
        super.init()
        
        name = "Test Float"
        uiConnections.append(UINodeConnection(.FloatVariable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Test Float Variable"
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
            NodeUIFloatVariableTarget(self, variable: "node", title: "Variable", connection:  uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "mode", title: "Test", items: ["Equal To", "Smaller As", "Bigger As"], index: 0),
            NodeUINumber(self, variable: "value", title: "Value", range: nil, value: 1)
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// test value from variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let target = uiConnections[0].target as? FloatVariable {
            
            let valueVariable : Float = target.properties["value"]!
            let myMode : Float = properties["mode"]!
            let myValue : Float = properties["value"]!

            if myMode == 0 {
                // Equal to
                if valueVariable == myValue {
                    playResult = .Success
                }
            } else
            if myMode == 1 {
                // Smaller as
                if valueVariable < myValue {
                    playResult = .Success
                }
            } else
            if myMode == 2 {
                // Bigger as
                if valueVariable > myValue {
                    playResult = .Success
                }
            }
        }
        
        return playResult!
    }
}

class RandomDirection : Node
{
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override init()
    {
        super.init()
        
        name = "Random Direction"
        uiConnections.append(UINodeConnection(.DirectionVariable))
    }
    
    override func setup()
    {
        type = "Random Direction"
        brand = .Arithmetic
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
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
            NodeUIAngle(self, variable: "orientation1", title: "", value: 0),
            NodeUINumber(self, variable: "from", title: "From Angle", range: float2(0,360), value: 0),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIAngle(self, variable: "orientation2", title: "", value: 90),
            NodeUINumber(self, variable: "to", title: "To Angle", range: float2(0,360), value: 90),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDirectionVariableTarget(self, variable: "direction", title: "Write To", connection: uiConnections[0])
        ]
        
        uiItems[1].linkedTo = uiItems[0]
        uiItems[0].linkedTo = uiItems[1]
        
        uiItems[4].linkedTo = uiItems[3]
        uiItems[3].linkedTo = uiItems[4]
        
        super.setupUI(mmView: mmView)
    }
    
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        
        let from = properties["from"]!
        let to = properties["to"]!
        
        let value : Float = Float.random(in: from...to)
        
        if let dirVariable = uiConnections[0].target as? DirectionVariable {
            dirVariable.setValue(value)
        }
        
        return playResult!
    }
}

class AddFloat2Variables : Node
{
    override init()
    {
        super.init()
        
        name = "Float2 Plus Float2"
        uiConnections.append(UINodeConnection(.Float2Variable))
        uiConnections.append(UINodeConnection(.Float2Variable))
        uiConnections.append(UINodeConnection(.Float2Variable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Add Float2 Variables"
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
            NodeUIFloat2VariableTarget(self, variable: "augend", title: "Add", connection:  uiConnections[0]),
            NodeUISeparator(self, variable: "", title: ""),
            NodeUIFloat2VariableTarget(self, variable: "addend", title: "To", connection:  uiConnections[1]),
            NodeUISeparator(self, variable: "", title: ""),
            NodeUIFloat2VariableTarget(self, variable: "sum", title: "Result", connection:  uiConnections[2])
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Subtract value from variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let augend = uiConnections[0].target as? Float2Variable {
            if let addend = uiConnections[1].target as? Float2Variable {
                if let result = uiConnections[2].target as? Float2Variable {
                    let sum = augend.getValue() + addend.getValue()
                    
                    result.setValue(sum)
                    playResult = .Success
                }
            }
        }
        
        return playResult!
    }
}

class SubtractFloat2Variables : Node
{
    override init()
    {
        super.init()
        
        name = "Float2 Minus Float2"
        uiConnections.append(UINodeConnection(.Float2Variable))
        uiConnections.append(UINodeConnection(.Float2Variable))
        uiConnections.append(UINodeConnection(.Float2Variable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Subtract Float2 Variables"
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
            NodeUIFloat2VariableTarget(self, variable: "subtrahend", title: "Subtract", connection:  uiConnections[0]),
            NodeUISeparator(self, variable: "", title: ""),
            NodeUIFloat2VariableTarget(self, variable: "minuend", title: "From", connection:  uiConnections[1]),
            NodeUISeparator(self, variable: "", title: ""),
            NodeUIFloat2VariableTarget(self, variable: "difference", title: "Result", connection:  uiConnections[2])
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Subtract value from variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let subtrahend = uiConnections[0].target as? Float2Variable {
            if let minuend = uiConnections[1].target as? Float2Variable {
                if let result = uiConnections[2].target as? Float2Variable {
                    let difference = minuend.getValue() - subtrahend.getValue()
                    
                    result.setValue(difference)
                    playResult = .Success
                }
            }
        }
        
        return playResult!
    }
}

class MultiplyConstFloat2Variable : Node
{
    override init()
    {
        super.init()
        
        name = "Multiply Const Float2"
        uiConnections.append(UINodeConnection(.Float2Variable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Multiply Const Float2"
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
            NodeUIFloat2VariableTarget(self, variable: "variable", title: "Variable", connection:  uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "coordinate", title: "Coordinate", items: ["XY", "X", "Y"], index: 0),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUINumber(self, variable: "x", title: "X", range: nil, value: 1),
            NodeUINumber(self, variable: "y", title: "Y", range: nil, value: 1),
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// test value from variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let variable = uiConnections[0].target as? Float2Variable {
            
            var value : float2 = variable.getValue()
            let myCoordinate : Float = properties["coordinate"]!
            let x : Float = properties["x"]!
            let y : Float = properties["y"]!
            
            if myCoordinate == 0 {
                value.x = value.x * x
                value.y = value.y * y
            } else
            if myCoordinate == 1 {
                value.x = value.x * x
            } else
            if myCoordinate == 2 {
                value.y = value.y * y
            }
            
            variable.setValue(value)
            playResult = .Success
        }
        
        return playResult!
    }
}

class TestFloat2Variable : Node
{
    override init()
    {
        super.init()
        
        name = "Test Float2"
        uiConnections.append(UINodeConnection(.Float2Variable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Test Float2 Variable"
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
            NodeUIFloat2VariableTarget(self, variable: "variable", title: "Variable", connection:  uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "coordinate", title: "Coordinate", items: ["X", "Y"], index: 0),
            NodeUIDropDown(self, variable: "mode", title: "Test", items: ["Equal To", "Smaller As", "Bigger As"], index: 0),
            NodeUINumber(self, variable: "value", title: "Value", range: nil, value: 1)
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// test value from variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let variable = uiConnections[0].target as? Float2Variable {
            
            let position : float2 = variable.getValue()
            let myCoordinate : Float = properties["coordinate"]!
            let myMode : Float = properties["mode"]!
            let myValue : Float = properties["value"]!
            
            var testValue : Float
            
            if myCoordinate == 0 {
                testValue = position.x
            } else {
                testValue = position.y
            }
            
            if myMode == 0 {
                // Equal to
                if testValue == myValue {
                    playResult = .Success
                }
            } else
            if myMode == 1 {
                // Smaller as
                if testValue < myValue {
                    playResult = .Success
                }
            } else
            if myMode == 2 {
                // Bigger as
                if testValue > myValue {
                    playResult = .Success
                }
            }
        }
        
        return playResult!
    }
}

class LimitFloat2Range : Node
{
    override init()
    {
        super.init()
        
        name = "Limit Float2 Range"
        uiConnections.append(UINodeConnection(.Float2Variable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Limit Float2 Range"
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
            NodeUIFloat2VariableTarget(self, variable: "variable", title: "Variable", connection:  uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "coordinate", title: "Coordinate", items: ["X", "Y"], index: 0),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUINumber(self, variable: "upper", title: "Upper", range: nil, value: 100),
            NodeUINumber(self, variable: "lower", title: "Lower", range: nil, value: -100),
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// test value from variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let variable = uiConnections[0].target as? Float2Variable {
            
            var position : float2 = variable.getValue()
            let myCoordinate : Float = properties["coordinate"]!
            let upperBorder : Float = properties["upper"]!
            let lowerBorder : Float = properties["lower"]!
            
            if myCoordinate == 0 {
                position.x = max(lowerBorder, position.x)
                position.x = min(upperBorder, position.x)
            } else {
                position.y = max(lowerBorder, position.y)
                position.y = min(upperBorder, position.y)
            }
            
            variable.setValue(position)
            
            playResult = .Success
        }
        
        return playResult!
    }
}

class ReflectFloat2Variables : Node
{
    override init()
    {
        super.init()
        
        name = "Reflect"
        uiConnections.append(UINodeConnection(.Float2Variable))
        uiConnections.append(UINodeConnection(.Float2Variable))
        uiConnections.append(UINodeConnection(.Float2Variable))
    }
    
    override func setup()
    {
        brand = .Arithmetic
        type = "Reflect Float2 Variables"
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
            NodeUIFloat2VariableTarget(self, variable: "velocity", title: "Velocity", connection:  uiConnections[0]),
            NodeUISeparator(self, variable: "", title: ""),
            NodeUIFloat2VariableTarget(self, variable: "normal", title: "Normal", connection:  uiConnections[1]),
            NodeUISeparator(self, variable: "", title: ""),
            NodeUIFloat2VariableTarget(self, variable: "result", title: "Result", connection:  uiConnections[2])
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Subtract value from variable
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        if let velocity = uiConnections[0].target as? Float2Variable {
            if let normal = uiConnections[1].target as? Float2Variable {
                if let result = uiConnections[2].target as? Float2Variable {
                    let reflect = simd_reflect(velocity.getValue(), normal.getValue())
                    
                    result.setValue(reflect)
                    playResult = .Success
                }
            }
        }
        
        return playResult!
    }
}

