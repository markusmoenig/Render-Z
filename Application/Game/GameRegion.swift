//
//  GameRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class GameRegion: MMRegion
{
    var app                     : GameApp
    var widget                  : GameWidget!
    
    var nodeGraph               : NodeGraph!
    var gameNode                : Game? = nil
    
    init( _ view: MMView, app: GameApp )
    {
        self.app = app

        super.init( view, type: .Editor )
        
        widget = GameWidget(view, gameRegion: self, app: app)
        registerWidgets( widgets: widget! )
    }
    
    override func build()
    {
        widget.rect.copy(rect)
        
        nodeGraph.previewSize.x = rect.width
        nodeGraph.previewSize.y = rect.height
        
        nodeGraph.mmScreen!.rect.x = rect.x
        nodeGraph.mmScreen!.rect.y = rect.y
        nodeGraph.mmScreen!.rect.width = rect.width
        nodeGraph.mmScreen!.rect.height = rect.height
                
        //mmView.drawBox.draw( x: rect.x, y: rect.y, width: 100, height: 44, round: 10, borderSize: 1, fillColor : float4(1, 1, 1, 1.000), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
        
        if let game = gameNode {
            _ = game.execute(nodeGraph: nodeGraph, root: game.behaviorRoot!, parent: game.behaviorRoot!.rootNode)
            
            if let scene = game.currentScene {
                for texture in scene.outputTextures {
                    app.mmView.drawTexture.draw(texture, x: rect.x, y: rect.y)
                }
                
                if nodeGraph.debugMode != .None {

                    if scene.layerObjects != nil && scene.layerObjects!.count > 0 && scene.layerObjects![0].gameCamera != nil {
                        
                        nodeGraph.debugBuilder.render(width: nodeGraph.previewSize.x, height: nodeGraph.previewSize.y, instance: nodeGraph.debugInstance, camera: scene.layerObjects![0].gameCamera! )
                        app.mmView.drawTexture.draw(nodeGraph.debugInstance.texture!, x: rect.x, y: rect.y, zoom: 1)
                    }
                    nodeGraph.debugInstance.clear()
                }
            }
        }
        
        #if os(iOS)
        if app.embeddedCB != nil {
            app.closeButton.rect.x = rect.x
            app.closeButton.rect.y = rect.y
            app.closeButton.draw()
        }
        #endif
    }
    
    override func resize(width: Float, height: Float)
    {
        //print("resize", width, height)
    }
    
    func start(_ graph: NodeGraph)
    {
        nodeGraph = graph
        gameNode = app.nodeGraph.getNodeOfType("Game") as? Game
        
        nodeGraph.mmView = mmView
        nodeGraph.previewSize.x = rect.width
        nodeGraph.previewSize.y = rect.height
        nodeGraph.mmScreen = MMScreen(mmView)
        nodeGraph.timeline = MMTimeline(mmView)
        nodeGraph.builder = Builder(nodeGraph)
        nodeGraph.physics = Physics(nodeGraph)
        nodeGraph.diskBuilder = DiskBuilder(nodeGraph)
        
        nodeGraph.updateNodes()
        if let game = gameNode {
            game.setupExecution(nodeGraph: graph)
            
            game.behaviorRoot = BehaviorTreeRoot(game)
            game.behaviorTrees = graph.getBehaviorTrees(for: game)
            
            mmView.lockFramerate(true)
            
            #if os(OSX)
                var windowFrame = mmView.window!.frame
            
                var width : Float = 1200; var height : Float = 900
            
                if let osx = app.nodeGraph.getNodeOfType("Platform OSX") as? GamePlatformOSX {
                    let size = osx.getScreenSize()
                    width = size.x
                    height = size.y
                }

                windowFrame.size = NSMakeSize(CGFloat(width / mmView.scaleFactor), CGFloat(height / mmView.scaleFactor))
                mmView.window!.setFrame(windowFrame, display: true)
            #endif
        }
    }
}
