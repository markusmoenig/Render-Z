//
//  EditorRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class EditorRegion: MMRegion
{
    var app                     : App
    
//    var compute                 : MMCompute
//    var kernelState             : MTLComputePipelineState?
    
    var layer                   : Layer
    
    init( _ view: MMView, app: App )
    {
        self.app = app
        
//        compute = MMCompute()

//        let library = compute.createLibraryFromSource(source: shader)
//        kernelState = compute.createState(name: "grayscaleKernel")
//        compute.allocateTexture(width: 100, height: 100)
        
        layer = Layer()
        
        let disk = MM2DDisk()
        disk.properties["radius"] = 100;
        
        layer.addShape(disk)
        
        layer.build()

        super.init( view, type: .Editor )
    }
    
    override func build()
    {
//        mmView.drawCube.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 2,  fillColor : float4( 0.620, 0.506, 0.165, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
        
//        compute.run( kernelState )
//        mmView.drawTexture.draw(compute.texture, x: rect.x + 50, y: rect.y + 50)
        
        layer.run(width: rect.width, height: rect.height)
        mmView.drawTexture.draw(layer.compute!.texture, x: rect.x, y: rect.y)
    }
}
