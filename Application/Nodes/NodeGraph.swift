//
//  NodeGraph.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class NodeGraph : Codable
{
    var nodes           : [Node]
    var app             : App?
    
    private enum CodingKeys: String, CodingKey {
        case nodes
    }
    
    enum NodeCodingKeys: String, CodingKey {
        case name
        case nodes
    }
    
    required init()
    {
        nodes = []
        
        let object = Object()
        nodes.append(object)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: NodeCodingKeys.self)
//        nodes = try container.decode([Node].self, forKey: .nodes)
        nodes = try container.decode([Node].self, ofFamily: NodeFamily.self, forKey: .nodes)

    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
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
