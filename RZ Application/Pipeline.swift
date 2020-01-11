//
//  Pipeline.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class Pipeline
{
    var codeBuilder         : CodeBuilder
    var mmView              : MMView
    
    var texture             : MTLTexture? = nil
    
    init(_ mmView: MMView,_ codeBuilder: CodeBuilder)
    {
        self.mmView = mmView
        self.codeBuilder = codeBuilder
    }
    
    func start(_ width: Float,_ height: Float)
    {
        let component = CodeComponent(.SDF2D)
        
        let inst = codeBuilder.build(component)
        let test = codeBuilder.compute.allocateFloatTexture(width: width, height: height, output: false)
        
        codeBuilder.render(inst, test)
        
        let test2 = codeBuilder.compute.allocateTexture(width: width, height: height, output: false)

        let component2 = CodeComponent(.Render)
        let inst2 = codeBuilder.build(component2)

        codeBuilder.render(inst2, test2, test)

        texture = test2
    }
    
    func draw()
    {
        
    }
}
