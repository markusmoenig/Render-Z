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
        name = "Physics Properties"
    }
    
    override func setup()
    {
        type = "Object Physics"
        brand = .Property
        
        helpUrl = "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/overview"
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
            NodeUIDropDown(self, variable: "physicsSupportsRotation", title: "Rotation", items: ["No", "Yes"], index: 1)
        ]
        
        super.setupUI(mmView: mmView)
    }
    
    override func updateUIState()
    {
        let mode = properties["physicsMode"]!

        uiItems[1].isDisabled = mode == 0 || mode == 1
        uiItems[2].isDisabled = mode == 0 || mode == 1
        uiItems[3].isDisabled = mode == 0// || mode == 1
        uiItems[4].isDisabled = mode == 0 || mode == 1

        super.updateUIState()
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

            return .Success
        }
        return .Failure
    }
}

/// Sets a physic property
class SetObjectPhysics : Node
{
    override init()
    {
        super.init()
        
        name = "Set Physic Property"
        uiConnections.append(UINodeConnection(.ObjectInstance))
    }
    
    override func setup()
    {
        brand = .Function
        type = "Set Object Physics"
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
            NodeUIDropDown(self, variable: "property", title: "Property", items: ["Mass", "Restitution"], index: 0),
            NodeUINumber(self, variable: "value", title: "Value", range: nil, value: 1),
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
                    let property = properties["property"]!
                    let value = properties["value"]!
                    
                    if let body = inst.body {
                        if property == 0 {
                            body.mass = value
                        } else
                        if property == 1 {
                            body.restitution = value
                        }
                        playResult = .Success
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
        uiConnections.append(UINodeConnection(.ValueVariable))
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

            NodeUIValueVariableTarget(self, variable: "power", title: "Force Value", connection: uiConnections[1]),

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
            
            if let powerVariable = uiConnections[1].target as? ValueVariable {
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
        uiConnections.append(UINodeConnection(.ValueVariable))
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

            NodeUIValueVariableTarget(self, variable: "power", title: "Force Value", connection: uiConnections[1]),

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
            
            if let powerVariable = uiConnections[1].target as? ValueVariable {
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
                        for (_, distance) in body.distanceInfos {
                            if distance < 0 {
                                playResult = .Success
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
                    uv /= float2(object.properties["scaleX"]!, object.properties["scaleY"]!)
                    
                    uv = rotateCW(uv, angle: object.properties["rotate"]! * Float.pi / 180 );
                    
                    var d : float2 = simd_abs( uv ) - float2(shape.properties[shape.widthProperty]!, shape.properties[shape.heightProperty]!)
                    let dist : Float = simd_length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0)
                    
                    //print( dist, dist - radius )
                    if dist < radius {
                        playResult = .Success
                    }
                }
                
                
            }
        }
        return playResult!
    }
}

