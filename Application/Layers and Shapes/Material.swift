//
//  Material.swift
//  Shape-Z
//
//  Created by Markus Moenig on 21/3/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Material : Codable
{
    var name            : String
    var properties      : [String: Float]
    var uuid            : UUID
    
    var code            : String = ""
    var globalCode      : String = ""

    var widthProperty   : String = ""
    var heightProperty  : String = ""
    
    var pointCount      : Int = 0
    var isCompound      : Bool = false
    
    private enum CodingKeys: String, CodingKey {
        case name
        case properties
        case uuid
        case code
        case globalCode
        case widthProperty
        case heightProperty
        case pointCount
        case isCompound
    }
    
    required init()
    {
        properties = [:]
        name = "Unnamed Material"
     
        uuid = UUID()
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["rotate"] = 0
        properties["channel"] = 0
        properties["limiterType"] = 0
    }

    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        properties = try container.decode([String: Float].self, forKey: .properties)
        code = try container.decode(String.self, forKey: .code)
        globalCode = try container.decode(String.self, forKey: .globalCode)
        widthProperty = try container.decode(String.self, forKey: .widthProperty)
        heightProperty = try container.decode(String.self, forKey: .heightProperty)
        pointCount = try container.decode(Int.self, forKey: .pointCount)
        isCompound = try container.decode(Bool.self, forKey: .isCompound)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(properties, forKey: .properties)
        try container.encode(code, forKey: .code)
        try container.encode(globalCode, forKey: .globalCode)
        try container.encode(widthProperty, forKey: .widthProperty)
        try container.encode(heightProperty, forKey: .heightProperty)
        try container.encode(pointCount, forKey: .pointCount)
        try container.encode(isCompound, forKey: .isCompound)
    }
    
    /// Static function which returns the global MATERIAL_DATA definition
    static func getMaterialStructCode() -> String
    {
        let code =
        
        """
        
        typedef struct {
            float4  baseColor;
            float   subsurface;
            float   roughness;
            float   metallic;
            float   specular;
            float   specularTint;
            float   clearcoat;
            float   clearcoatGloss;
            float   anisotropic;
            float   sheen;
            float   sheenTint;
        } MATERIAL_DATA;

        void clearMaterial(thread MATERIAL_DATA *material)
        {
            material->subsurface = 0;
            material->roughness = 1;
            material->metallic = 0;
            material->specular = 0;
            material->specularTint = 0;
            material->clearcoat = 0;
            material->clearcoatGloss = 0;
            material->anisotropic = 0;
            material->sheen = 0;
            material->sheenTint = 0;
        }

        """
        return code
    }
    
    /// Creates the material code for the object
    func createCode( uvName: String, transProperties: [String:Float]? = nil, materialDataIndex: Int? = nil, materialName: String = "") -> String
    {
        var code = self.code
        let props = transProperties != nil ? transProperties : properties
        
        code = code.replacingOccurrences(of: "__uv__", with: String(uvName))
        code = code.replacingOccurrences(of: "__material__", with: ("&" + materialName))

        if pointCount == 0 {
            if materialDataIndex == nil {
                code = code.replacingOccurrences(of: "__value__", with: "float4(\(props!["value_x"]!), \(props!["value_y"]!), \(props!["value_z"]!), \(props!["value_w"]!) )")
            } else {
                let matDataCode = "layerData->materialData[\(materialDataIndex!)]"
                code = code.replacingOccurrences(of: "__value__", with: matDataCode)
            }
        } else {
            var materialIndex : Int = 0
            if materialDataIndex != nil {
                materialIndex  = materialDataIndex!
            }

            // Fill in point positions
            for index in 0..<pointCount {
                if materialDataIndex == nil {
                    code = code.replacingOccurrences(of: "__point_\(index)__", with: "float2(\(props!["point_\(index)_x"]!), \(props!["point_\(index)_y"]!)) * float2(1,-1)")
                } else {
                    let matDataCode = "layerData->materialData[\(materialIndex)].xy"
                    code = code.replacingOccurrences(of: "__point_\(index)__", with: matDataCode)
                    materialIndex += 1
                }
            }
            // Fill in point values
            for index in 0..<pointCount {
                if materialDataIndex == nil {
                    code = code.replacingOccurrences(of: "__pointvalue_\(index)__", with: "float4(\(props!["pointvalue_\(index)_x"]!), \(props!["pointvalue_\(index)_y"]!), \(props!["pointvalue_\(index)_z"]!), \(props!["pointvalue_\(index)_w"]!))")
                } else {
                    let matDataCode = "layerData->materialData[\(materialIndex)]"
                    code = code.replacingOccurrences(of: "__pointvalue_\(index)__", with: matDataCode)
                    materialIndex += 1
                }
            }
        }
        
        return code
    }
}
