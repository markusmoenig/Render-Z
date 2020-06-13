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
    enum ShaderType {
        case Background, Ground, Terrain, Object
    }
    
    var shaderType  : ShaderType
    
    var scene       : Scene
    var object      : StageItem
    var camera      : CodeComponent
    
    init(scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
        
        shaderType = .Background

        if object.stageItemType == .PreStage {
            shaderType = .Background
            
            let preStage = scene.getStage(.PreStage)

            for item in preStage.getChildren() {
                if let comp = item.components[item.defaultName], comp.componentType == .SkyDome || comp.componentType == .Pattern {
                    //backComponent = comp
                }
            }
        }
    }
    
    func buildShader()
    {
        
    }
    
    func render(texture: MTLTexture)
    {
        
    }
}
