//
//  GameNodes.swift
//  Shape-Z
//
//  Created by Markus Moenig on 22.04.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class GamePlatformOSX : Node
{
    override init()
    {
        super.init()
        
        name = "Platform: OSX"
    }
    
    override func setup()
    {
        type = "Platform OSX"
        brand = .Property
    }
    
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            //NodeUIDropDown(self, variable: "animationMode", title: "Mode", items: ["Loop", "Inverse Loop", "Goto Start", "Goto End"], index: 0),
            NodeUINumber(self, variable: "width", title: "Width", range: float2(100, 4096), int: true, value: 800),
            NodeUINumber(self, variable: "height", title: "Height", range: float2(100, 4096), int: true, value: 600)
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Platform OSX"
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    func getScreenSize() -> float2
    {
        return float2(properties["width"]!, properties["height"]!)
    }
    
    /// Return Success if the selected key is currently down
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        return playResult!
    }
}

class GamePlatformIPAD : Node
{
    override init()
    {
        super.init()
        
        name = "Platform: iPAD"
    }
    
    override func setup()
    {
        type = "Platform IPAD"
        brand = .Property
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIDropDown(self, variable: "type", title: "iPad", items: ["1536 x 2048", "2048 x 2732"], index: 0),
            NodeUIDropDown(self, variable: "orientation", title: "Orientation", items: ["Vertical", "Horizontal"], index: 0),
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Platform IPAD"
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    func getScreenSize() -> float2
    {
        var width : Float = 0
        var height : Float = 0
        
        let index = properties["type"]
        let orient = properties["orientation"]
        
        if index == 0 {
            width = 768; height = 1024
        }
        if index == 1 {
            width = 1536; height = 2048
        } else
            if index == 2 {
                width = 2048; height = 2732
        }
        
        if orient == 1 {
            let temp = height
            height = width
            width = temp
        }
        
        return float2(width, height)
    }
    
    /// Return Success if the selected key is currently down
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        return playResult!
    }
}

class GamePlayScene : Node
{
    var currentlyPlaying : Scene? = nil
    var gameNode         : Game? = nil

    var toExecute        : [Node] = []
    
    override init()
    {
        super.init()
        
        name = "Play Scene"
    }
    
    override func setup()
    {
        brand = .Function
        type = "Game Play Scene"
        uiConnections.append(UINodeConnection(.Scene))
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
            NodeUIMasterPicker(self, variable: "scene", title: "Scene", connection:  uiConnections[0]),
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
    
    override func finishExecution() {
        currentlyPlaying = nil
        gameNode = nil
    }
    
    /// Play the Scene
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if let scene = uiConnections[0].masterNode as? Scene {
            
            if scene !== currentlyPlaying {
                
                currentlyPlaying = scene
                camera = Camera()

                toExecute = []
                
                for layerUUID in scene.layers {
                    for n in nodeGraph.nodes {
                        if n.uuid == layerUUID
                        {
                            let layer = n as! Layer
                            layer.setupExecution(nodeGraph: nodeGraph)
                            for inst in layer.objectInstances {
                                toExecute.append(inst.instance!)
                            }
                            toExecute.append(layer)
                        }
                    }
                }
                
                scene.setupExecution(nodeGraph: nodeGraph)
                toExecute.append(scene)
                
                for exe in toExecute {
                    exe.behaviorRoot = BehaviorTreeRoot(exe)
                    exe.behaviorTrees = nodeGraph.getBehaviorTrees(for: exe)
                }
            }
            
            for exe in toExecute {
                _ = exe.execute(nodeGraph: nodeGraph, root: exe.behaviorRoot!, parent: exe.behaviorRoot!.rootNode)
            }
            
            if gameNode == nil {
                gameNode = nodeGraph.getNodeOfType("Game") as? Game
            }
            
            if let game = gameNode {
                scene.updatePreview(nodeGraph: nodeGraph)
                game.currentScene = scene
                
                playResult = .Success
            }
        }
        return playResult!
    }
}
