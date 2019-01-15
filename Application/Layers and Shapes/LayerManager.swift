//
//  LayerManager.swift
//  Shape-Z
//
//  Created by Markus Moenig on 15/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class LayerManager : Codable
{
    var layers          : [Layer]
    
    var currentLayer    : Layer!
    var currentIndex    : Int!
    
    var width           : Float!
    var height          : Float!

    private enum CodingKeys: String, CodingKey {
        case layers
    }
    
    init()
    {
        layers = []
        
        layers.append( Layer() )
        
        currentLayer = layers[0]
        currentIndex = 0
        
        width = 0
        height = 0
    }
    
    @discardableResult func run(width:Float, height:Float) -> MTLTexture
    {
        self.width = width; self.height = height
        let texture = currentLayer.run(width:width, height:height)
        return texture
    }
}
