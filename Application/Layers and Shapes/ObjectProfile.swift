//
//  ObjectProfile.swift
//  Shape-Z
//
//  Created by Markus Moenig on 26/4/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ObjectProfile : Node
{
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override init()
    {
        super.init()
        
        type = "Object Profile"
        name = "3D Profile"
        brand = .Property
        
        maxDelegate = ObjectProfileMaxDelegate()
        minimumSize = Node.NodeWithPreviewSize
        
        properties["edgeHeight"] = 0
        properties["edgeType"] = 0
        properties["borderHeight"] = 0
        properties["centerHeight"] = 0
        properties["centerAt"] = 200
        
        properties["pointCount"] = 0
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Object Profile"
        maxDelegate = ObjectProfileMaxDelegate()
        minimumSize = Node.NodeWithPreviewSize
        brand = .Property
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIDropDown(self, variable: "status", title: "Status", items: ["Enabled", "Disabled"], index: 0)
        ]
        super.setupUI(mmView: mmView)
    }
    
    /// Apply the control points to the objects profile array
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        
        if properties["status"] != nil && properties["status"]! == 0 {
            if let object = root.objectRoot {
                object.profile = []
                
                let edge = float4(0, properties["edgeHeight"]!, properties["edgeType"]!, 0)
                object.profile!.append(edge)

                let pointCount = Int(properties["pointCount"]!)
                for index in 0..<pointCount {
                    let control = float4(properties["point_\(index)_At"]!, properties["point_\(index)_Height"]!, properties["point_\(index)_Type"]!, 0)
                    object.profile!.append(control)
                }
                let center = float4(properties["centerAt"]!, properties["centerHeight"]!, -1, -1)
                object.profile!.append(center)
                
                //print(center.x, center.y)
            }
        }
        return playResult!
    }
    
    override func updatePreview(nodeGraph: NodeGraph, hard: Bool = false)
    {
        /*
        let size = nodeGraph.previewSize
        if previewTexture == nil || Float(previewTexture!.width) != size.x || Float(previewTexture!.height) != size.y {
            previewTexture = nodeGraph.builder.compute!.allocateTexture(width: size.x, height: size.y, output: true)
        }*/
        /*
        let prevOffX = properties["prevOffX"]
        let prevOffY = properties["prevOffY"]
        let prevScale = properties["prevScale"]
        let camera = Camera(x: prevOffX != nil ? prevOffX! : 0, y: prevOffY != nil ? prevOffY! : 0, zoom: prevScale != nil ? prevScale! : 1)
        */
    }
}
