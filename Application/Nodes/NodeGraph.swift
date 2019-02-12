//
//  NodeGraph.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class NodeGraph : Codable
{
    var nodes           : [Node] = []
    
    var xOffset         : Float = 0
    var yOffset         : Float = 0
    var scale           : Float = 1

    var drawNodeState   : MTLRenderPipelineState?
    var drawPatternState: MTLRenderPipelineState?

    var app             : App?
    var maximizedNode   : Node?
    var selectedUUID    : [UUID] = []
    
    private enum CodingKeys: String, CodingKey {
        case nodes
        case xOffset
        case yOffset
        case scale
    }
    
    required init()
    {
        let object = Object()
        nodes.append(object)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([Node].self, ofFamily: NodeFamily.self, forKey: .nodes)
        xOffset = try container.decode(Float.self, forKey: .xOffset)
        yOffset = try container.decode(Float.self, forKey: .yOffset)
        scale = try container.decode(Float.self, forKey: .scale)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(xOffset, forKey: .xOffset)
        try container.encode(yOffset, forKey: .yOffset)
        try container.encode(scale, forKey: .scale)
    }
    
    func setup(app: App)
    {
        self.app = app
        
        let renderer = app.mmView.renderer!
        
        var function = renderer.defaultLibrary.makeFunction( name: "drawNode" )
        drawNodeState = renderer.createNewPipelineState( function! )
        function = renderer.defaultLibrary.makeFunction( name: "moduloPattern" )
        drawPatternState = renderer.createNewPipelineState( function! )
    }
    
    /// Draw the editor region
    func drawEditor(_ region: MMRegion)
    {
        if maximizedNode != nil {
            return;
        }
        
        let renderer = app!.mmView.renderer!
        let scaleFactor : Float = app!.mmView.scaleFactor

        renderer.setClipRect(region.rect)
        
        // --- Backgrouns
        let settings: [Float] = [
            region.rect.width, region.rect.height,
            ];
        
        let renderEncoder = renderer.renderEncoder!
        
        let vertexBuffer = renderer.createVertexBuffer( MMRect( region.rect.x, region.rect.y, region.rect.width, region.rect.height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = renderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( drawPatternState! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        
        // --- Draw Node Graph
        
        for node in nodes {
            drawNode( node, region: region)
        }
        
        renderer.setClipRect()
    }
    
    /// Draw a single node
    func drawNode(_ node: Node, region: MMRegion)
    {
        let renderer = app!.mmView.renderer!
        let renderEncoder = renderer.renderEncoder!
        let scaleFactor : Float = app!.mmView.scaleFactor

        node.rect.x = region.rect.x + node.xPos + xOffset
        node.rect.y = region.rect.y + node.yPos + yOffset

        node.rect.width = 130
        node.rect.height = 270

        let vertexBuffer = renderer.createVertexBuffer( MMRect( node.rect.x, node.rect.y, node.rect.width, node.rect.height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        var data: [Float] = [
            node.rect.width, node.rect.height,
            1, 0
        ];
        
        let buffer = renderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState(drawNodeState!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Decode a new nodegraph from JSON
    func decodeJSON(_ json: String) -> NodeGraph?
    {
        if let jsonData = json.data(using: .utf8)
        {
            if let graph =  try? JSONDecoder().decode(NodeGraph.self, from: jsonData) {
                print( json )
                return graph
            }
        }
        return nil
    }
    
    /// Encode the whole NodeGraph to JSON
    func encodeJSON() -> String
    {
        let encodedData = try? JSONEncoder().encode(self)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
        {
            return encodedObjectJsonString
        }
        return ""
    }
}
