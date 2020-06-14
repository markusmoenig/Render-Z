//
//  ObjectShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class ObjectShader  : BaseShader
{
    var scene       : Scene
    var object      : StageItem
    var camera      : CodeComponent
    
    init(scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
    }
    
    func buildShader()
    {
        
    }
    
    override func render(texture: MTLTexture)
    {
    }
}
