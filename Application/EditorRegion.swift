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
    var widget                  : EditorWidget!
    
    var patternState            : MTLRenderPipelineState?
    var result                  : MTLTexture?
    
    init( _ view: MMView, app: App )
    {
        self.app = app
        
//        let library = compute.createLibraryFromSource(source: shader)
//        kernelState = compute.createState(name: "moduloPattern")
//        compute.allocateTexture(width: 100, height: 100)

        super.init( view, type: .Editor )
        
        widget = EditorWidget(view, editorRegion: self, app: app)
        let function = mmView.renderer!.defaultLibrary.makeFunction( name: "moduloPattern" )
        patternState = mmView.renderer!.createNewPipelineState( function! )
        
        registerWidgets( widgets: widget! )
    }
    
    func drawPattern()
    {
        let mmRenderer = mmView.renderer!

        let scaleFactor : Float = mmView.scaleFactor
        let settings: [Float] = [
            rect.width, rect.height,
        ];
        
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( rect.x, rect.y, rect.width, rect.height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( patternState! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    
    }
    
    override func build()
    {
        widget.rect.copy(rect)
        drawPattern()
        
        if result == nil || app.layerManager.width != rect.width || app.layerManager.height != rect.height {
            compute()
        }
        
        if let texture = result {
            mmView.drawTexture.draw(texture, x: rect.x, y: rect.y)
        }
        
        app.changed = false
    }
    
    func compute()
    {
        result = app.layerManager.render(width: rect.width, height: rect.height)
    }
}
