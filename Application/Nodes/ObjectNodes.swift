//
//  Nodes.swift
//  Shape-Z
//
//  Created by Markus Moenig on 20.02.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class ObjectPhysics : Node
{
    override init()
    {
        super.init()
        name = "Physical Properties"
    }
    
    override func setup()
    {
        type = "Object Physics"
        brand = .Property
        
        helpUrl = "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/pages/9109521/Physical+Properties"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIDropDown(self, variable: "physicsMode", title: "Mode", items: ["Off", "Static", "Dynamic"], index: 1),
            NodeUINumber(self, variable: "physicsMass", title: "Mass", range: float2(0, 100), value: 1),
            NodeUINumber(self, variable: "physicsRestitution", title: "Restitution", range: float2(0, 5), value: 0.2),
            NodeUINumber(self, variable: "physicsFriction", title: "Friction", range: float2(0, 1), value: 0.3),
            NodeUIDropDown(self, variable: "physicsSupportsRotation", title: "Rotation", items: ["No", "Yes"], index: 1),
            NodeUIDropDown(self, variable: "physicsCollisions", title: "Collisions", items: ["Natural", "Reflect", "Custom"], index: 0)
        ]
        
        super.setupUI(mmView: mmView)
    }
    
    override func updateUIState(mmView: MMView)
    {
        let mode = properties["physicsMode"]!
        let collisions = properties["physicsCollisions"]!

        uiItems[1].isDisabled = mode == 0 || mode == 1
        uiItems[2].isDisabled = mode == 0 /*|| mode == 1*/ || collisions == 1
        uiItems[3].isDisabled = mode == 0 || collisions == 1
        uiItems[4].isDisabled = mode == 0 || mode == 1 || collisions == 1
        uiItems[5].isDisabled = mode == 0 || mode == 1

        super.updateUIState(mmView: mmView)
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
        if let object = root.objectRoot {
            let value = properties["physicsMode"]!
            object.properties["physicsMode"] = value
            object.properties["physicsMass"] = properties["physicsMass"]!
            object.properties["physicsRestitution"] = properties["physicsRestitution"]!
            object.properties["physicsFriction"] = properties["physicsFriction"]!
            object.properties["physicsSupportsRotation"] = properties["physicsSupportsRotation"]!
            object.properties["physicsCollisions"] = properties["physicsCollisions"]!

            return .Success
        }
        return .Failure
    }
}

class ObjectGlow : Node
{
    override init()
    {
        super.init()
        name = "Glow Effect"
    }
    
    override func setup()
    {
        type = "Object Glow"
        brand = .Property
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIDropDown(self, variable: "glowMode", title: "Mode", items: ["Off", "On"], index: 1),
            NodeUIColor(self, variable: "glowColor", title: "Color", value: float3(1,1,1)),
            NodeUINumber(self, variable: "glowOpacity", title: "Opacity", range: float2(0, 1), value: 1),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUINumber(self, variable: "glowSize", title: "Size", range: float2(0, 50), value: 10),
        ]
        
        super.setupUI(mmView: mmView)
    }
    
    override func updateUIState(mmView: MMView)
    {
        let mode = properties["glowMode"]!
        
        uiItems[1].isDisabled = mode == 0
        uiItems[2].isDisabled = mode == 0
        uiItems[4].isDisabled = mode == 0

        super.updateUIState(mmView: mmView)
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
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        if let object = root.objectRoot {
            let value = properties["glowMode"]!
            object.properties["glowMode"] = value
            object.properties["glowSize"] = properties["glowSize"]!
            object.properties["glowColor_r"] = properties["glowColor_r"]!
            object.properties["glowColor_g"] = properties["glowColor_g"]!
            object.properties["glowColor_b"] = properties["glowColor_b"]!
            object.properties["glowOpacity"] = properties["glowOpacity"]!

            return .Success
        }
        return .Failure
    }
    
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        if let master = nodeGraph?.currentMaster as? Object {
            master.updatePreview(nodeGraph: nodeGraph!, hard: true)//variable == "glowMode" )
            nodeGraph?.mmView.update()
        }
        
        if noUndo == false {
            super.variableChanged(variable: variable, oldValue: oldValue, newValue: newValue, continuous: continuous)
        }
    }
}

/// Get/Set Object Prop.
class GetSetObjectProperty : Node
{
    var recursionBlocker : Bool = false
    
    override init()
    {
        super.init()
        
        name = "Get Set Property"
        uiConnections.append(UINodeConnection(.ObjectInstance))
        uiConnections.append(UINodeConnection(.Float2Variable))
        uiConnections.append(UINodeConnection(.DirectionVariable))
        uiConnections.append(UINodeConnection(.FloatVariable))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Get Set Object Property"
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
            NodeUIObjectInstanceTarget(self, variable: "instance", title: "Of Instance", connection: uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "property", title: "Property", items: ["Position", "Scale", "Rotation", "Active", "Opacity", "Mass", "Restitution", "Friction", "Velocity", "Collision Normal"], index: 0),
            NodeUIDropDown(self, variable: "mode", title: "Mode", items: ["Get", "Set"], index: 0),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIFloat2VariableTarget(self, variable: "float2", title: "Float2", connection: uiConnections[1])
        ]
        super.setupUI(mmView: mmView)
    }
    
    override func updateUIState(mmView: MMView)
    {
        if recursionBlocker == true { return }
        recursionBlocker = true
        let property = Int(properties["property"]!)
        
        let posProperties : [Int] = [0, 1, 8, 9]
        let dirProperties : [Int] = []
        let valueProperties : [Int] = [2, 3, 4, 5, 6, 7]

        if posProperties.contains(property) && uiItems[5].role != .Float2VariableTarget {
            uiItems.removeLast()
            uiItems.append(NodeUIFloat2VariableTarget(self, variable: "float2", title: "Float2", connection: uiConnections[1]))
            computeUIArea(mmView: mmView)
        } else
        if dirProperties.contains(property) && uiItems[5].role != .DirectionVariableTarget {
            uiItems.removeLast()
            uiItems.append(NodeUIDirectionVariableTarget(self, variable: "direction", title: "Direction", connection: uiConnections[2]))
            computeUIArea(mmView: mmView)
        } else
        if valueProperties.contains(property) && uiItems[5].role != .FloatVariableTarget {
            uiItems.removeLast()
            uiItems.append(NodeUIFloatVariableTarget(self, variable: "float", title: "Float", connection: uiConnections[3]))
            computeUIArea(mmView: mmView)
        }
        
        super.updateUIState(mmView: mmView)
        recursionBlocker = false
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
    
    /// Execute the given animation
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if root.objectRoot != nil {
            if uiConnections[0].connectedTo != nil {
                if let inst = nodeGraph.getInstance(uiConnections[0].connectedTo!) {
                    let property = properties["property"]!
                    let mode = properties["mode"]!

                    let posVariable = uiConnections[1].target as? Float2Variable
                    //let dirVariable = uiConnections[2].target as? DirectionVariable
                    let valueVariable = uiConnections[3].target as? FloatVariable

                    if property == 0 && posVariable != nil { // Position
                        if mode == 0 {
                            posVariable!.setValue(float2(inst.properties["posX"]!,inst.properties["posY"]!))
                        } else {
                            let value = posVariable!.getValue()
                            inst.properties["posX"]! = value.x
                            inst.properties["posY"]! = value.y
                        }
                        playResult = .Success
                    } else
                    if property == 1 && posVariable != nil { // Scale
                        if mode == 0 {
                            posVariable!.setValue(float2(inst.properties["scaleX"]!,inst.properties["scaleY"]!))
                        } else {
                            let value = posVariable!.getValue()
                            inst.properties["scaleX"]! = value.x
                            inst.properties["scaleY"]! = value.y
                        }
                        playResult = .Success
                    } else
                    if property == 2 && valueVariable != nil { // Rotation
                        if mode == 0 {
                            valueVariable!.setValue(inst.properties["rotate"]!)
                        } else {
                            inst.properties["rotate"]! = valueVariable!.getValue()
                        }
                        playResult = .Success
                    } else
                    if property == 3 && valueVariable != nil { // Active
                        if mode == 0 {
                            //valueVariable!.setValue(inst.properties["rotate"]!)
                        } else {
                            //inst.properties["rotate"]! = valueVariable!.getValue()
                        }
                        playResult = .Success
                    } else
                    if property == 4 && valueVariable != nil { // Opacity
                        if mode == 0 {
                            //valueVariable!.setValue(inst.properties["rotate"]!)
                        } else {
                            //inst.properties["rotate"]! = valueVariable!.getValue()
                        }
                        playResult = .Success
                    } else
                    if property == 5 && valueVariable != nil { // Mass
                        if let body = inst.body {
                            if mode == 0 {
                                valueVariable!.setValue(body.mass)
                            } else {
                                let value = valueVariable!.getValue()
                                body.mass = value
                                if value == 0 {
                                    body.invMass = 0
                                } else {
                                    body.invMass = 1 / value
                                }
                            }
                            playResult = .Success
                        }
                    } else
                    if property == 6 && valueVariable != nil { // Restitution
                        if let body = inst.body {
                            if mode == 0 {
                                valueVariable!.setValue(body.restitution)
                            } else {
                                let value = valueVariable!.getValue()
                                body.restitution = value
                            }
                            playResult = .Success
                        }
                    } else
                    if property == 7 && valueVariable != nil { // Friction
                        if let body = inst.body {
                            if mode == 0 {
                                valueVariable!.setValue(body.dynamicFriction)
                            } else {
                                let value = valueVariable!.getValue()
                                body.dynamicFriction = value
                                body.staticFriction = value + 0.2
                                if value == 0 {
                                    body.invMass = 0
                                } else {
                                    body.invMass = 1 / value
                                }
                            }
                            playResult = .Success
                        }
                    } else
                    if property == 8 && posVariable != nil { // Velocity
                        if let body = inst.body {
                            if mode == 0 {
                                posVariable!.setValue(body.velocity)
                                playResult = .Success
                            } else {
                                if body.collisionMode == 2 {
                                    // Only set velocity when in custom collision mode
                                    let value = posVariable!.getValue()
                                    body.velocity = value
                                    
                                    let delta : Float = 1/60
                                    body.integrateVelocity(delta)
                                    body.integrateForces(delta)
                                    
                                    body.force = float2(0,0)
                                    body.torque = 0
                                    
                                    playResult = .Success
                                }
                            }
                        }
                    } else
                    if property == 9 && posVariable != nil { // Collision Normal
                        if let body = inst.body {
                            if mode == 0 {
                                posVariable!.setValue(body.manifold != nil ? body.manifold!.normal : float2(0,0))
                            }
                            playResult = .Success
                        }
                    }
                }
            }
        }
        
        return playResult!
    }
}

/// Resets an object
class ResetObject : Node
{
    override init()
    {
        super.init()
        
        name = "Reset Object"
        uiConnections.append(UINodeConnection(.ObjectInstance))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Object Reset"
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
            NodeUIObjectInstanceTarget(self, variable: "master", title: "Instance", connection: uiConnections[0])
        ]
        super.setupUI(mmView: mmView)
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
    
    /// Execute the given animation
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if root.objectRoot != nil {
            if uiConnections[0].connectedTo != nil {
                if let inst = nodeGraph.getInstance(uiConnections[0].connectedTo!) {

                    //let object = inst.instanceOf!
                    
                    inst.properties["posX"] = inst.properties["copy_posX"]
                    inst.properties["posY"] = inst.properties["copy_posY"]
                    inst.properties["rotate"] = inst.properties["copy_rotate"]

                    if let body = inst.body {
                        body.velocity = float2(0,0)
                        body.angularVelocity = 0
                        playResult = .Success
                    }
                }
            }
        }
        
        return playResult!
    }
}

class ObjectAnimation : Node
{
    override init()
    {
        super.init()
        
        name = "Play Animation"
        uiConnections.append(UINodeConnection(.Animation))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Object Animation"
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
            NodeUIAnimationTarget(self, variable: "animation", title: "Animation", connection: uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "mode", title: "Mode", items: ["Loop", "Inverse Loop", "Goto Start", "Goto End"], index: 0),
            NodeUINumber(self, variable: "scale", title: "Scale", range: float2(0, 20), value: 1)
        ]
        super.setupUI(mmView: mmView)
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
    
    /// Execute the given animation
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure

        func applySequence(_ object: Object) {
            for seq in object.sequences {
                if seq.uuid == uiConnections[0].connectedTo {
                    
                    let mode = properties["mode"]!
                    let scale = properties["scale"]!
                    
                    object.setSequence(sequence: seq, timeline: nodeGraph.timeline)
                    object.setAnimationMode(Object.AnimationMode(rawValue: Int(mode))!, scale: scale)
                    
                    playResult = .Success
                    
                    break
                }
            }
        }
        
        if let instance = uiConnections[0].target as? ObjectInstance {
            if let object = instance.instance {
                applySequence(object)
            } else {
                // --- No instance, this should only happen in behavior preview for objects!
                if let object = root.objectRoot {
                    applySequence(object)
                }
            }
        }
        
        return playResult!
    }
}

/// Tests the current state of the animation
class ObjectAnimationState : Node
{
    override init()
    {
        super.init()
        
        name = "Get Animation State"
        uiConnections.append(UINodeConnection(.ObjectInstance))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Object Animation State"
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
            NodeUIObjectInstanceTarget(self, variable: "master", title: "Instance", connection: uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "state", title: "State", items: ["Not Animating", "At Start", "Going Forward", "Going Backward", "At End"], index: 0)
        ]
        super.setupUI(mmView: mmView)
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
    
    /// Execute the given animation
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if root.objectRoot != nil {
            if uiConnections[0].connectedTo != nil {
                if let inst = nodeGraph.getInstance(uiConnections[0].connectedTo!) {
                    let state = properties["state"]!
                    
                    if Int(state) == inst.animationState.rawValue {
                        playResult = .Success
                    }
                }
            }
        }
        
        return playResult!
    }
}

/// Returns the distance to another object instance (both have to be under physics control)
class ObjectDistanceTo : Node
{
    override init()
    {
        super.init()
        
        name = "Distance To"
        
        uiConnections.append(UINodeConnection(.ObjectInstance))
        uiConnections.append(UINodeConnection(.ObjectInstance))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Object Distance To"
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
            NodeUIObjectInstanceTarget(self, variable: "from", title: "From", connection: uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIObjectInstanceTarget(self, variable: "to", title: "To", connection: uiConnections[1]),

            NodeUISeparator(self, variable:"", title: ""),
            NodeUIDropDown(self, variable: "mode", title: "Distance", items: ["Equal To", "Smaller As", "Bigger As"], index: 0),
            NodeUINumber(self, variable: "value", title: "Value", range: nil, value: 1)
        ]
        super.setupUI(mmView: mmView)
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
    
    /// Execute the given animation
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if uiConnections[0].connectedTo != nil {
            if let fromInstance = nodeGraph.getInstance(uiConnections[0].connectedTo!) {
                if uiConnections[1].connectedTo != nil {
                    if let toInstance = nodeGraph.getInstance(uiConnections[1].connectedTo!) {
                        if fromInstance.body != nil && toInstance.body != nil {
                            if let distance = fromInstance.body!.distanceInfos[toInstance.uuid] {
                             
                                let myMode : Float = properties["mode"]!
                                let myValue : Float = properties["value"]!
                                
                                if myMode == 0 {
                                    // Equal to
                                    if distance == myValue {
                                        playResult = .Success
                                    }
                                } else
                                if myMode == 1 {
                                    // Smaller as
                                    if distance < myValue {
                                        playResult = .Success
                                    }
                                } else
                                if myMode == 2 {
                                    // Bigger as
                                    if distance > myValue {
                                        playResult = .Success
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return playResult!
    }
}

/// Applies physical force to an object
class ObjectApplyForce : Node
{
    override init()
    {
        super.init()
        
        name = "Apply Force"
        
        uiConnections.append(UINodeConnection(.ObjectInstance))
        uiConnections.append(UINodeConnection(.FloatVariable))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Object Apply Force"
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
            NodeUIObjectInstanceTarget(self, variable: "master", title: "Instance", connection: uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),

            NodeUIFloatVariableTarget(self, variable: "power", title: "Force Value", connection: uiConnections[1]),

            NodeUINumber(self, variable: "scale", title: "Scale", range: float2(0, 100), value: 10),
        ]
        super.setupUI(mmView: mmView)
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
    
    /// Execute the given animation
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if root.objectRoot != nil {
            let scale = properties["scale"]!
            
            var power : Float = 0
            
            if let powerVariable = uiConnections[1].target as? FloatVariable {
//                let number = powerVariable.uiItems[0] as? NodeUINumber
                power = powerVariable.properties["value"]! * scale
            }
            
            //print( power, dir.x, dir.y )
            
            if uiConnections[0].connectedTo != nil {
                if let instance = nodeGraph.getInstance(uiConnections[0].connectedTo!) {

                    if let body = instance.body {
                        body.force.x = power * scale
                        body.force.y = power * scale
                        //print( body.force.x, body.force.y )
                    }
                }
            }
            
            playResult = .Success
        }
        
        return playResult!
    }
}

/// Applies directional physical force to an object
class ObjectApplyDirectionalForce : Node
{
    override init()
    {
        super.init()
        
        name = "Apply Directional Force"
        
        uiConnections.append(UINodeConnection(.ObjectInstance))
        uiConnections.append(UINodeConnection(.FloatVariable))
        uiConnections.append(UINodeConnection(.DirectionVariable))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Object Apply Directional Force"
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
            NodeUIObjectInstanceTarget(self, variable: "master", title: "Instance", connection: uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),

            NodeUIFloatVariableTarget(self, variable: "power", title: "Force Value", connection: uiConnections[1]),

            NodeUINumber(self, variable: "scale", title: "Scale", range: float2(0, 100), value: 10),
            NodeUISeparator(self, variable:"", title: ""),
            
            NodeUIDirectionVariableTarget(self, variable: "direction", title: "Force Direction", connection: uiConnections[2]),
        ]
        super.setupUI(mmView: mmView)
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
    
    /// Execute the given animation
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if root.objectRoot != nil {
            let scale = properties["scale"]!
            
            var power : Float = 0
            var dir : float2 = float2(0,0)
            
            if let powerVariable = uiConnections[1].target as? FloatVariable {
                //                let number = powerVariable.uiItems[0] as? NodeUINumber
                power = powerVariable.properties["value"]! * scale
            }
            
            if let dirVariable = uiConnections[2].target as? DirectionVariable {
                let angle = dirVariable.properties["angle"]!
                //print("angle", angle)
                dir.x = cos((360-angle) * Float.pi/180)
                dir.y = sin((360-angle) * Float.pi/180)
            }
            
            //print( power, dir.x, dir.y )
            
            if uiConnections[0].connectedTo != nil {
                if let instance = nodeGraph.getInstance(uiConnections[0].connectedTo!) {
                    
                    if let body = instance.body {
                        body.force.x = dir.x * power * scale
                        body.force.y = dir.y * power * scale
                        //print( body.force.x, body.force.y )
                    }
                }
            }
            
            playResult = .Success
        }
        
        return playResult!
    }
}

/// Detects any collision
class ObjectCollisionAny : Node
{
    override init()
    {
        super.init()
        
        name = "Collision (Any)"
        uiConnections.append(UINodeConnection(.ObjectInstance))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Object Collision (Any)"
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
            NodeUIObjectInstanceTarget(self, variable: "master", title: "Instance", connection: uiConnections[0])
        ]
        super.setupUI(mmView: mmView)
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

    /// Check if we collide with anything
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if root.objectRoot != nil {
            
            if uiConnections[0].connectedTo != nil {
                if let instance = nodeGraph.getInstance(uiConnections[0].connectedTo!) {
                    
                    if let body = instance.body {
                        if body.manifold != nil {
                            playResult = .Success
                        }
                    }
                
                    //if let body = instance.body {
                    //    for (_, distance) in body.distanceInfos {
                    //        if distance < 0.2 {
                    //            playResult = .Success
                    //            print("yesyes")
                    //        }
                    //    }
                    //}
                }
            }
        }
        
        return playResult!
    }
}

/// Detects a collection with another instance
class ObjectCollisionWith : Node
{
    override init()
    {
        super.init()
        
        name = "Collision With"
        uiConnections.append(UINodeConnection(.ObjectInstance))
        uiConnections.append(UINodeConnection(.ObjectInstance))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Object Collision With"
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
            NodeUIObjectInstanceTarget(self, variable: "master", title: "Instance", connection: uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUIObjectInstanceTarget(self, variable: "with", title: "With", connection: uiConnections[1])
        ]
        super.setupUI(mmView: mmView)
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
    
    /// Check if we collide with anything
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if root.objectRoot != nil {
            
            if uiConnections[0].connectedTo != nil {
                if let instance = nodeGraph.getInstance(uiConnections[0].connectedTo!) {
                    if uiConnections[1].connectedTo != nil {
                        if let withInstance = nodeGraph.getInstance(uiConnections[1].connectedTo!) {
                            if let body = instance.body {
                                if let distanceTo = body.distanceInfos[withInstance.uuid] {
                                
                                    if distanceTo < 0.2 {
                                        playResult = .Success
                                        //print("collision with", withInstance.name)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return playResult!
    }
}

/// Distance To Layer Area
class ObjectTouchLayerArea : Node
{
    override init()
    {
        super.init()
        
        name = "Touch Layer Area ?"
        uiConnections.append(UINodeConnection(.ObjectInstance))
        uiConnections.append(UINodeConnection(.LayerArea))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Object Touch Layer Area"
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
            NodeUIObjectInstanceTarget(self, variable: "master", title: "Instance", connection: uiConnections[0]),
            NodeUISeparator(self, variable:"", title: ""),
            NodeUILayerAreaTarget(self, variable: "layerArea", title: "Layer Area", connection: uiConnections[1])
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
    
    /// Return Success if the selected key is currently down
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        var instanceObject : Object? = nil
        
        if root.objectRoot != nil {
            if uiConnections[0].connectedTo != nil {
                if let inst = nodeGraph.getInstance(uiConnections[0].connectedTo!) {
                    instanceObject = inst
                }
            }
        }
        
        if instanceObject == nil {
            return playResult!
        }
        
        if uiConnections[1].masterNode == nil || uiConnections[1].target == nil { return playResult! }
        
        if let layer = uiConnections[1].masterNode as? Layer {
            if let area = uiConnections[1].target as? LayerArea {
                if area.areaObject == nil || area.areaObject!.shapes.count == 0 { return playResult! }
                
                if instanceObject!.disks.count > 0 {
                    //print("mouse", area.name, mouse.x, mouse.y)
                    
                    let x : Float = instanceObject!.properties["posX"]! + instanceObject!.disks[0].xPos
                    let y : Float = instanceObject!.properties["posY"]! + instanceObject!.disks[0].yPos
                    let radius : Float = instanceObject!.disks[0].distance / 2
                    
                    let object = area.areaObject!
                    let shape = object.shapes[0]
                    
                    func rotateCW(_ pos : float2, angle: Float) -> float2
                    {
                        let ca : Float = cos(angle), sa = sin(angle)
                        return pos * float2x2(float2(ca, -sa), float2(sa, ca))
                    }
                    
                    var uv = float2(x, y)
                    
                    uv -= float2(object.properties["posX"]!, object.properties["posY"]!)
                    //uv /= float2(object.properties["scaleX"]!, object.properties["scaleY"]!)
                    
                    uv = rotateCW(uv, angle: object.properties["rotate"]! * Float.pi / 180 );
                    
                    var d : float2 = simd_abs( uv ) - float2(shape.properties[shape.widthProperty]! * object.properties["scaleX"]!, shape.properties[shape.heightProperty]! * object.properties["scaleY"]!)
                    let dist : Float = simd_length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0)
                    
                    //print( dist, dist - radius )
                    if dist < radius {
                        playResult = .Success
                        
                        if nodeGraph.debugMode == .LayerAreas {
                            let pos = float2(object.properties["posX"]!, object.properties["posY"]!)
                            let size = float2(shape.properties[shape.widthProperty]! * object.properties["scaleX"]!, shape.properties[shape.heightProperty]! * object.properties["scaleY"]!)
                            nodeGraph.debugInstance!.addBox(pos, size, 0, 0, float4(0.541, 0.098, 0.125, 0.8))
                        }
                    }
                }
            }
        }
        return playResult!
    }
}

