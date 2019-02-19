//
//  NodeGraph.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class NodeGraph : Codable
{
    enum LeftRegionMode
    {
        case Closed, Nodes
    }
    
    enum NodeHoverMode : Float {
        case None, Maximize, Dragging, Terminal, TerminalConnection
    }
    
    var nodes           : [Node] = []
    
    var xOffset         : Float = 0
    var yOffset         : Float = 0
    var scale           : Float = 1

    var drawNodeState   : MTLRenderPipelineState?
    var drawPatternState: MTLRenderPipelineState?

    var app             : App?
    var maximizedNode   : Node?
    var hoverNode       : Node?
    
    var hoverTerminal   : (Terminal, TerminalConnector, Float, Float)?
    var connectTerminal : (Terminal, TerminalConnector, Float, Float)?

    var selectedUUID    : [UUID] = []
    
    var dragStartPos    : float2 = float2()
    var nodeDragStartPos: float2 = float2()
    
    var mousePos        : float2 = float2()

    var nodeHoverMode   : NodeHoverMode = .None
    var nodesButton     : MMButtonWidget!
    
    var nodeList        : NodeList?
    var animating       : Bool = false
    var leftRegionMode  : LeftRegionMode = .Nodes
    
    
    private enum CodingKeys: String, CodingKey {
        case nodes
        case xOffset
        case yOffset
        case scale
    }
    
    required init()
    {
        let object = Object()
        object.name = "New Object"
        object.sequences.append( MMTlSequence() )
        object.currentSequence = object.sequences[0]
        object.setupTerminals()
        
        nodes.append(object)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([Node].self, ofFamily: NodeFamily.self, forKey: .nodes)
        xOffset = try container.decode(Float.self, forKey: .xOffset)
        yOffset = try container.decode(Float.self, forKey: .yOffset)
        scale = try container.decode(Float.self, forKey: .scale)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(xOffset, forKey: .xOffset)
        try container.encode(yOffset, forKey: .yOffset)
        try container.encode(scale, forKey: .scale)
    }
    
    /// Called when a new instance of the NodeGraph class was created, sets up all necessary dependencies.
    func setup(app: App)
    {
        self.app = app
        
        let renderer = app.mmView.renderer!
        
        var function = renderer.defaultLibrary.makeFunction( name: "drawNode" )
        drawNodeState = renderer.createNewPipelineState( function! )
        function = renderer.defaultLibrary.makeFunction( name: "moduloPattern" )
        drawPatternState = renderer.createNewPipelineState( function! )
        
        nodesButton = MMButtonWidget( app.mmView, text: "Nodes" )
        nodesButton.clicked = { (event) -> Void in
            self.setLeftRegionMode(.Nodes)
        }
        nodesButton.addState(.Checked)
        
        nodeList = NodeList(app.mmView, app:app)
    }

    /// Controls the tab mode in the left region
    func setLeftRegionMode(_ mode: LeftRegionMode )
    {
        if animating { return }
        let leftRegion = app!.leftRegion!
        if self.leftRegionMode == mode && leftRegionMode != .Closed {
            app!.mmView.startAnimate( startValue: leftRegion.rect.width, endValue: 0, duration: 500, cb: { (value,finished) in
                leftRegion.rect.width = value
                if finished {
                    self.animating = false
                    self.leftRegionMode = .Closed
                    self.nodesButton.removeState( .Checked )
                }
            } )
            animating = true
        } else if leftRegion.rect.width != 200 {
            
            app!.mmView.startAnimate( startValue: leftRegion.rect.width, endValue: 200, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                }
                leftRegion.rect.width = value
            } )
            animating = true
        }
        self.leftRegionMode = mode
    }
    
    func mouseDown(_ event: MMMouseEvent)
    {
        selectedUUID = []
        
        #if !os(OSX)
        mouseMoved( event )
        #endif
        
        if nodeHoverMode == .Terminal {
            nodeHoverMode = .TerminalConnection
        } else
        if let selectedNode = nodeAt(event.x, event.y) {
            selectedUUID = [selectedNode.uuid]
            
//            let offX = selectedNode.rect.x - event.x
            let offY = selectedNode.rect.y - event.y
            
            if nodeHoverMode == .Maximize {
                maximizedNode = selectedNode
                deactivate()
                maximizedNode!.maxDelegate!.activate(app!)
                nodeHoverMode = .None
            } else
            if offY < 26 {
                dragStartPos.x = event.x
                dragStartPos.y = event.y
                
                nodeDragStartPos.x = selectedNode.xPos
                nodeDragStartPos.y = selectedNode.yPos
                nodeHoverMode = .Dragging
                
                app?.mmView.mouseTrackWidget = app?.editorRegion?.widget
                app?.mmView.lockFramerate()
            }
        }
    }
    
    func mouseUp(_ event: MMMouseEvent)
    {
        app?.mmView.mouseTrackWidget = nil
        app?.mmView.unlockFramerate()
        nodeHoverMode = .None
    }
    
    func mouseMoved(_ event: MMMouseEvent)
    {
        if nodeHoverMode == .Dragging {
            
            hoverNode!.xPos = nodeDragStartPos.x + event.x - dragStartPos.x
            hoverNode!.yPos = nodeDragStartPos.y + event.y - dragStartPos.y
            
            return
        }
        
        if nodeHoverMode == .TerminalConnection {
            
            mousePos.x = event.x
            mousePos.y = event.y
            
            if let connectTerminal = terminalAt(hoverNode!, event.x, event.y) {
                print("possible connection")
            } else {
                print("no")
            }


            return
        }
        
        nodeHoverMode = .None
        
        hoverNode = nodeAt(event.x, event.y)
        if hoverNode != nil {
            let x = event.x - hoverNode!.rect.x
            let y =  event.y - hoverNode!.rect.y
            
            if x > 125 && y < 26 {
                nodeHoverMode = .Maximize
                return
            }
            
            if let terminalTuple = terminalAt(hoverNode!, event.x, event.y) {
                nodeHoverMode = .Terminal
                hoverTerminal = terminalTuple
                return
            }
        }
    }
    
    ///
    func activate()
    {
        app?.mmView.registerWidgets(widgets: nodesButton, nodeList!)
        app!.leftRegion!.rect.width = 200
    }
    
    ///
    func deactivate()
    {
        app?.mmView.deregisterWidgets(widgets: nodesButton, nodeList!)
    }
    
    /// Draws the given region
    func drawRegion(_ region: MMRegion)
    {
        if region.type == .Editor {
            
            let renderer = app!.mmView.renderer!
            let scaleFactor : Float = app!.mmView.scaleFactor

            renderer.setClipRect(region.rect)
            
            // --- Background
            let settings: [Float] = [
                region.rect.width, region.rect.height,
                ];
            
            let renderEncoder = renderer.renderEncoder!
            
            let vertexBuffer = renderer.createVertexBuffer( MMRect( region.rect.x, region.rect.y, region.rect.width, region.rect.height, scale: scaleFactor ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            let buffer = renderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            
            renderEncoder.setRenderPipelineState( drawPatternState! )
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            // --- Draw Node Graph
            
            for node in nodes {
                drawNode( node, region: region)
            }
            
            // --- Node Connection going on ?
            
            if nodeHoverMode == .TerminalConnection {
                
                let color = float4(0,0,0,1)
                app!.mmView.drawLine.draw( sx: hoverTerminal!.2 - 2, sy: hoverTerminal!.3 - 2, ex: mousePos.x, ey: mousePos.y, radius: 2, fillColor : color )
            }
            
            renderer.setClipRect()
        } else
        if region.type == .Left {
            nodeList!.rect.copy(region.rect)
            nodeList!.draw()
        } else
        if region.type == .Top {
            region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: nodesButton )
            nodesButton.draw()
        } else
        if region.type == .Right {
            region.rect.width = 0
        } else
        if region.type == .Bottom {
            region.rect.height = 0
        }
    }
    
    /// Draw a single node
    func drawNode(_ node: Node, region: MMRegion)
    {
        let renderer = app!.mmView.renderer!
        let renderEncoder = renderer.renderEncoder!
        let scaleFactor : Float = app!.mmView.scaleFactor

        node.rect.x = region.rect.x + node.xPos + xOffset
        node.rect.y = region.rect.y + node.yPos + yOffset

        node.rect.width = 150
        node.rect.height = 270

        let vertexBuffer = renderer.createVertexBuffer( MMRect( node.rect.x, node.rect.y, node.rect.width, node.rect.height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let data: [Float] = [
            node.rect.width, node.rect.height,
            selectedUUID.contains(node.uuid) ? 1 : 0,
            nodeHoverMode == .Maximize && node.uuid == hoverNode!.uuid ? 1 : 0
        ];
        
        let buffer = renderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState(drawNodeState!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        node.titleTextBuffer = app!.mmView.drawText.drawText(app!.mmView.openSans, text: node.name, x: node.rect.x + 10, y: node.rect.y + 6, scale: 0.4, color: float4( 0.765, 0.765, 0.765, 1), textBuffer: node.titleTextBuffer)
        
        // --- Terminals
        
        func drawTerminal(_ x: Float,_ y: Float, terminal: Terminal, connector: TerminalConnector) {
            
            let hasHover = (nodeHoverMode == .Terminal || nodeHoverMode == .TerminalConnection) && hoverTerminal != nil && hoverTerminal!.0.uuid == terminal.uuid && hoverTerminal!.1 == connector
            
            let color = !hasHover ? float4(1) : float4(0,0,0,1)
            app!.mmView.drawSphere.draw( x: x, y: y, radius: 7, borderSize: 2, fillColor : color, borderColor: float4( 0, 0, 0, 1 ) )
        }
        
        var terminalY : Float = 35
        for terminal in node.terminals {
            if terminal.name == "" {
                
            } else {
                if terminal.connector == .In || terminal.connector == .InOut {
                    drawTerminal(node.rect.x + 5, node.rect.y + terminalY, terminal: terminal, connector: .In)
                }
                
                if terminal.connector == .Out || terminal.connector == .InOut {
                    drawTerminal(node.rect.x + node.rect.width - 6 - 14, node.rect.y + terminalY, terminal: terminal, connector: .Out)
                }
                
                // --- Node UI
                
                terminal.textBuffer = app!.mmView.drawText.drawText(app!.mmView.openSans, text: terminal.name, x: node.rect.x + 30, y: node.rect.y + terminalY - 1, scale: 0.4, color: float4( 0, 0, 0, 1), textBuffer: terminal.textBuffer)
            }
            
            terminalY += 25
        }
        
        // ---
        if let texture = node.previewTexture {
            app!.mmView.drawTexture.draw(texture, x: node.rect.x + 10, y: node.rect.y + 140)
        }
    }
    
    /// Returns the node (if any) at the given mouse coordinates
    func nodeAt(_ x: Float, _ y: Float) -> Node?
    {
        for node in nodes {
            if node.rect.contains( x, y ) {
                return node
            }
        }
        return nil
    }
    
    /// Returns the terminal and the terminal connector at the given mouse position for the given node (if any)
    func terminalAt(_ node: Node, _ x: Float, _ y: Float) -> (Terminal, TerminalConnector, Float, Float)?
    {
        var terminalY : Float = 35
        for terminal in node.terminals {
            if terminal.name == "" {
                
            } else
            if y >= node.rect.y + terminalY && y <= node.rect.y + terminalY + 15 {
                if terminal.connector == .In || terminal.connector == .InOut {
                    if x >= node.rect.x + 5 && x <= node.rect.x + 5 + 15 {
                        return (terminal, .In, node.rect.x + 8.5, node.rect.y + terminalY + 7)
                    }
                }
                
                if terminal.connector == .Out || terminal.connector == .InOut {
                    if x >= node.rect.x + node.rect.width - 6 - 14 && x <= node.rect.x + node.rect.width - 5 {
                        return (terminal, .Out, node.rect.x + node.rect.width - 6 - 7, node.rect.y + terminalY + 7)
                    }
                }
            }
            
            terminalY += 25
        }

        return nil
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
    
    /// Updates all nodes
    func updateNodes()
    {
        for node in nodes {
            
            if node.type == "Object" {
                let object = node as! Object
                object.instance = app!.builder.buildObjects(objects: [object], camera: app!.camera, timeline: app!.timeline )
            }
            
            node.updatePreview(app: app!)
        }
        maximizedNode = nil
    }
}
