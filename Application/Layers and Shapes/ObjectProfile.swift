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
        
        name = "3D Profile"
    }
    
    override func setup()
    {
        type = "3D Profile"
        brand = .Property
        
        minimumSize = Node.NodeWithPreviewSize
        maxDelegate = ObjectProfileMaxDelegate()
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
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUISelector(self, variable: "status", title: "Status", items: ["Enabled", "Disabled"], index: 0)
        ]
        super.setupUI(mmView: mmView)
    }
    
    /// Apply the control points to the objects profile array
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        
        // Profile was not yet initialized
        if properties["edgeHeight"] == nil {
            return .Failure
        }
        
        if properties["status"] != nil && properties["status"]! == 0 {
            if let object = root.objectRoot {
                object.profile = []
                
                let edge = float4(0, properties["edgeHeight"]!, properties["edgeType"]!, 0)
                object.profile!.append(edge)
                
                let type = ObjectProfileMaxDelegate.SegmentType(rawValue: Int(properties["edgeType"]!))!
                if type == .Bezier {
                    let bezier = float4(properties["edgeControlAt"]!, properties["edgeControlHeight"]!, 0, 0)
                    object.profile!.append(bezier)
                } else {
                    object.profile!.append(float4())
                }

                let pointCount = Int(properties["pointCount"]!)
                for index in 0..<pointCount {
                    let control = float4(properties["point_\(index)_At"]!, properties["point_\(index)_Height"]!, properties["point_\(index)_Type"]!, 0)
                    object.profile!.append(control)
                    
                    let type = ObjectProfileMaxDelegate.SegmentType(rawValue: Int(properties["point_\(index)_Type"]!))!
                    if type == .Bezier {
                        let bezier = float4(properties["point_\(index)_ControlAt"]!, properties["point_\(index)_ControlHeight"]!, 0, 0)
                        object.profile!.append(bezier)
                    } else {
                        object.profile!.append(float4())
                    }
                }
                let center = float4(properties["centerAt"]!, properties["centerHeight"]!, -1, -1)
                object.profile!.append(center)

                //
                /*
                if let pts = object.profile {
                    for pt in pts {
                        print( pt.x, pt.y, pt.z )
                    }
                }*/
            }
        }
        return playResult!
    }
    
    override func livePreview(nodeGraph: NodeGraph, rect: MMRect)
    {
        let delegate = maxDelegate as! ObjectProfileMaxDelegate
        
        delegate.app = nodeGraph.app
        delegate.drawPattern(rect)
        
        delegate.scale = 1
        delegate.scaleX = 0.7
        delegate.lockCenterAt = true
        
        delegate.profile = self
        if delegate.mmView == nil {
            delegate.mmView = nodeGraph.mmView!
        }
        
        nodeGraph.mmView.renderer.setClipRect(rect)
        delegate.drawGraph(rect, nodePreview: true)
        nodeGraph.mmView.renderer.setClipRect()
    }
}
