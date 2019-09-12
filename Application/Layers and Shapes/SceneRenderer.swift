//
//  SceneRenderer.swift
//  Shape-Z
//
//  Created by Markus Moenig on 5/8/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class SceneRenderer {
    
    var fragment        : MMFragment!
    var mmView          : MMView
    
    var nodeGraph       : NodeGraph!
        
    init(_ view : MMView )
    {
        mmView = view
        fragment = MMFragment(view)
    }
    
    func setup( nodeGraph: NodeGraph, instances: [Object] ) -> BuilderInstance?
    {
        self.nodeGraph = nodeGraph
        
        for inst in instances {
            inst.fragmentInstance = nodeGraph.builder.buildObjects(objects: [inst], camera: Camera(), fragment: fragment)
        }
        
        let builderInstance = BuilderInstance()
        builderInstance.objects = instances
        
        return builderInstance
    }
    
    func render( width: Float, height: Float, camera: Camera, instance: BuilderInstance, outTexture: MTLTexture? = nil )
    {
        let texture : MTLTexture
        
        if outTexture == nil {
            if fragment.width != width || fragment.height != height {
                fragment.allocateTexture(width: width, height: height)
            }
            texture = fragment.texture
        } else {
            texture = outTexture!
        }
        
        if fragment.encoderStart(outTexture: texture) {
            let sortedInstances = instance.objects.sorted(by: { $0.properties["z-index"]! < $1.properties["z-index"]! })
            for inst in sortedInstances {
                if inst.properties["active"] == 1 && inst.shapes.count > 0 {
                    updateInstance(width, height, inst, camera: camera)
                    fragment.encodeRun(inst.fragmentInstance!.fragmentState!, inBuffer: inst.fragmentInstance!.buffer, inTexture: mmView.openSans.atlas)
                }
            }
            fragment.encodeEnd()
        }
    }
    
    func updateInstance(_ width: Float,_ height: Float,_ inst: Object, camera: Camera)
    {
        let instance = inst.fragmentInstance!

        //print( inst.properties["posX"], inst.instanceOf!.properties["posY"] )
                
        instance.data![0] = camera.xPos
        instance.data![1] = camera.yPos
        instance.data![2] = 1/camera.zoom
        
        instance.data![4] = instance.layerGlobals!.position.x
        instance.data![5] = instance.layerGlobals!.position.y
        
        instance.data![6] = width//instance.layerGlobals!.limiterSize.x / 2
        instance.data![7] = height//instance.layerGlobals!.limiterSize.y / 2
        
        instance.data![8] = instance.data![8] + (1000/60) / 1000
        instance.data![9] = instance.layerGlobals!.normalSampling
        
        nodeGraph.builder.updateInstanceData(instance: instance, camera: camera, frame: 0)
        
        memcpy(instance.buffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
    }
}
