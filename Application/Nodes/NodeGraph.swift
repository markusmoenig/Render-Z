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
        case None, Maximize, Dragging, Terminal, TerminalConnection, NodeUI, NodeUIMouseLocked, Preview, MasterDrag, MasterDragging, Close, MasterNode
    }
    
    enum ContentType : Int {
        case Objects, Layers, Scenes, Game
    }
    
    var nodes           : [Node] = []
    
    var xOffset         : Float = 0
    var yOffset         : Float = 0
    var scale           : Float = 1

    var drawNodeState   : MTLRenderPipelineState?
    var drawPatternState: MTLRenderPipelineState?

    var app             : App?
    var mmView          : MMView!
    var maximizedNode   : Node?
    var hoverNode       : Node?
    var currentNode     : Node?
    
    var playNode        : Node? = nil
    var playToExecute   : [Node] = []

    var currentMaster   : Node? = nil
    var currentMasterUUID: UUID? = nil
    
    var currentObjectUUID: UUID? = nil
    var currentLayerUUID: UUID? = nil
    var currentSceneUUID: UUID? = nil

    var hoverUIItem     : NodeUI?

    var hoverTerminal   : (Terminal, Terminal.Connector, Float, Float)?
    var connectTerminal : (Terminal, Terminal.Connector, Float, Float)?

    var selectedUUID    : [UUID] = []
    
    var dragStartPos    : float2 = float2()
    var nodeDragStartPos: float2 = float2()
    
    var mousePos        : float2 = float2()

    var nodeHoverMode   : NodeHoverMode = .None
    var nodesButton     : MMButtonWidget!
    
    var contentType     : ContentType = .Objects
    var typeScrollButton: MMScrollButton!
    var contentScrollButton: MMScrollButton!
    var currentContent  : [Node] = []
    
    var addButton       : MMButtonWidget!
    var removeButton    : MMButtonWidget!
    var editButton      : MMButtonWidget!
    var playButton      : MMButtonWidget!

    var nodeList        : NodeList?
    var animating       : Bool = false
    var leftRegionMode  : LeftRegionMode = .Nodes
    
    var builder         : Builder!
    var physics         : Physics!
    var timeline        : MMTimeline!
    var diskBuilder     : DiskBuilder!

    var previewSize     : float2 = float2(320, 200)

    // --- Icons
    
    var executeIcon     : MTLTexture?
    
    // --- Static Node Skin
    
    static var tOffY    : Float = 45 // Vertical Offset of the first terminal
    static var tLeftY   : Float = 1.5 // Offset from the left for .Left Terminals
    static var tRightY  : Float = 20 // Offset from the right for .Right Terminals
    static var tSpacing : Float = 25 // Spacing between terminals

    static var tRadius  : Float = 7 // Radius of terminals
    static var tDiam    : Float = 14 // Diameter of terminals
    
    static var bodyY    : Float = 60 // Start of the y position of the body

    // ---
    
    private enum CodingKeys: String, CodingKey {
        case nodes
        case xOffset
        case yOffset
        case scale
        case currentMasterUUID
        case previewSize
    }
    
    required init()
    {
        let object = Object()

        object.name = "New Object"
        object.sequences.append( MMTlSequence() )
        object.currentSequence = object.sequences[0]
        object.setupTerminals()
        nodes.append(object)
        
        /*
        let layer = Layer()
        layer.name = "New Layer"
        nodes.append(layer)
        
        let scene = Layer()
        scene.name = "New Scene"
        nodes.append(scene)
        */
        
        let game = Game()
        game.name = "Game"
        nodes.append(game)

        setCurrentMaster(node: object)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([Node].self, ofFamily: NodeFamily.self, forKey: .nodes)
        xOffset = try container.decode(Float.self, forKey: .xOffset)
        yOffset = try container.decode(Float.self, forKey: .yOffset)
        scale = try container.decode(Float.self, forKey: .scale)
        currentMasterUUID = try container.decode(UUID?.self, forKey: .currentMasterUUID)
        previewSize = try container.decode(float2.self, forKey: .previewSize)
        setCurrentMaster(uuid: currentMasterUUID)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(xOffset, forKey: .xOffset)
        try container.encode(yOffset, forKey: .yOffset)
        try container.encode(scale, forKey: .scale)
        try container.encode(currentMasterUUID, forKey: .currentMasterUUID)
        try container.encode(previewSize, forKey: .previewSize)
    }
    
    /// Called when a new instance of the NodeGraph class was created, sets up all necessary dependencies.
    func setup(app: App)
    {
        self.app = app
        mmView = app.mmView
        
        timeline = MMTimeline(app.mmView)
        builder = Builder(self)
        physics = Physics(self)
        diskBuilder = DiskBuilder(self)

        let renderer = app.mmView.renderer!
        
        var function = renderer.defaultLibrary.makeFunction( name: "drawNode" )
        drawNodeState = renderer.createNewPipelineState( function! )
        function = renderer.defaultLibrary.makeFunction( name: "nodeGridPattern" )
        drawPatternState = renderer.createNewPipelineState( function! )
        
        nodesButton = MMButtonWidget( app.mmView, text: "Nodes" )
        nodesButton.clicked = { (event) -> Void in
            self.setLeftRegionMode(.Nodes)
        }
        nodesButton.addState(.Checked)
        
        // Sets the states of the add/remove buttons
        func setButtonStates()
        {
            if self.contentType == .Game {
                self.addButton.isDisabled = true
                self.removeButton.isDisabled = true
            } else {
                self.addButton.isDisabled = false
                self.removeButton.isDisabled = currentContent.count == 0
            }
        }
        
        typeScrollButton = MMScrollButton(app.mmView, items:["Objects", "Layers", "Scenes", "Game"])
        typeScrollButton.changed = { (index)->() in
            self.contentType = ContentType(rawValue: index)!
            self.updateContent(self.contentType)
            if self.currentContent.count > 0 {
                self.currentMaster!.updatePreview(nodeGraph: self, hard: false)
            }
            self.nodeList!.switchTo(NodeListItem.DisplayType(rawValue: index+1)!)

            setButtonStates()
        }
        
        contentScrollButton = MMScrollButton(app.mmView, items:[])
        contentScrollButton.changed = { (index)->() in
            let node = self.currentContent[index]
            self.setCurrentMaster(node: node)
            if self.currentContent.count > 0 {
                node.updatePreview(nodeGraph: self, hard: false)
            }
        }
        
        addButton = MMButtonWidget(app.mmView, text: "Add" )
        addButton.clicked = { (event) -> Void in
            if self.contentType == .Objects {
                getStringDialog(view: app.mmView, title: "Add Object", message: "Object name", defaultValue: "New Object", cb: { (name) -> Void in

                    let object = Object()
                    object.name = name
                    object.sequences.append( MMTlSequence() )
                    object.currentSequence = object.sequences[0]
                    object.setupTerminals()
                    
                    self.nodes.append(object)
                    self.setCurrentMaster(node: object)
                    self.updateNodes()
                    self.updateContent(self.contentType)
                } )
                self.addButton.removeState(.Checked)
            } else
            if self.contentType == .Layers {
                getStringDialog(view: app.mmView, title: "Add Layer", message: "Layer name", defaultValue: "New Layer", cb: { (name) -> Void in
                    
                    let layer = Layer()
                    layer.name = name
                    
                    self.nodes.append(layer)
                    self.setCurrentMaster(node: layer)
                    self.updateNodes()
                    self.updateContent(self.contentType)
                } )
                self.addButton.removeState(.Checked)
            }
            
            setButtonStates()
        }
        
        removeButton = MMButtonWidget(app.mmView, text: "Remove" )
        removeButton.clicked = { (event) -> Void in
            let node = self.currentContent[self.contentScrollButton.index]
            let index  = self.nodes.firstIndex(where: { $0.uuid == node.uuid })!
            self.nodes.remove(at: index)
            self.updateContent(self.contentType)
            
            self.removeButton.removeState(.Checked)
            setButtonStates()
        }
        
        var smallButtonSkin = MMSkinButton()
        smallButtonSkin.height = 30
        smallButtonSkin.fontScale = 0.4
        smallButtonSkin.margin.left = 8

        editButton = MMButtonWidget(app.mmView, skinToUse: smallButtonSkin, text: "Edit..." )
        editButton.clicked = { (event) -> Void in
            self.editButton.removeState(.Checked)
            
            self.maximizedNode = self.currentMaster!
            self.deactivate()
            self.maximizedNode!.maxDelegate!.activate(self.app!)
        }

        playButton = MMButtonWidget( app.mmView, skinToUse: smallButtonSkin, text: "Run Behavior" )
        playButton.clicked = { (event) -> Void in
            
            if self.playNode == nil {
                
                // --- Start Playing
                self.playToExecute = []
                self.playNode = self.currentMaster!

                let node = self.playNode
                if node!.type == "Object" {
                    var object = node as! Object
                    object.setupExecution(nodeGraph: self)
                    object = object.playInstance!
                    self.playToExecute.append(object)
                } else
                if node!.type == "Layer" {
                    let layer = node as! Layer
                    layer.setupExecution(nodeGraph: self)
                    for inst in layer.objectInstances {
                        self.playToExecute.append(inst.instance!)
                    }
                    self.playToExecute.append(layer)
                }
                
                for exe in self.playToExecute {
                    exe.behaviorRoot = BehaviorTreeRoot(exe)
                    exe.behaviorTrees = self.getBehaviorTrees(for: exe)
                }
                
                self.playButton.addState(.Checked)
                app.mmView.lockFramerate(true)
            } else {
                
                let node = self.playNode
                
                if node!.type == "Object" {
                    let object = node as! Object
                    object.playInstance = nil
                } else
                if self.playNode!.type == "Layer" {
                    let layer = self.playNode as! Layer
                    layer.physicsInstance = nil
                }
                
                self.playNode!.updatePreview(nodeGraph: app.nodeGraph, hard: true)
                self.playNode = nil
                self.playToExecute = []
                self.playButton.removeState(.Checked)
                app.mmView.unlockFramerate(true)
            }
        }
        
        nodeList = NodeList(app.mmView, app:app)
        
        // --- Register icons at first time start
//        if app.mmView.icons["execute"] == nil {
//            executeIcon = app.mmView.registerIcon("execute")
//        } else {
//            executeIcon = app.mmView.icons["execute"]
//        }
        
        updateNodes()
        updateContent(.Objects)
    }

    ///
    func activate()
    {
        app?.mmView.registerWidgets(widgets: nodesButton, nodeList!, typeScrollButton, contentScrollButton, addButton, removeButton)
        app?.mmView.widgets.insert(editButton, at: 0)
        app?.mmView.widgets.insert(playButton, at: 0)
        app!.leftRegion!.rect.width = 200
        nodeHoverMode = .None
    }
    
    ///
    func deactivate()
    {
        app?.mmView.deregisterWidgets(widgets: nodesButton, nodeList!, playButton, typeScrollButton, contentScrollButton, addButton, removeButton, editButton)
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
    
    func keyDown(_ event: MMKeyEvent)
    {
        if currentNode != nil {
            for uiItem in currentNode!.uiItems {
                if uiItem.brand == .KeyDown {
                    uiItem.keyDown(event)
                }
            }
        }
    }
    
    func keyUp(_ event: MMKeyEvent)
    {
    }
    
    func mouseDown(_ event: MMMouseEvent)
    {
        setCurrentNode()
                
//        #if !os(OSX)
        mouseMoved( event )
//        #endif

        if nodeHoverMode != .None && nodeHoverMode != .Preview {
            app?.mmView.mouseTrackWidget = app?.editorRegion?.widget
        }
        
        if nodeHoverMode == .NodeUI {
            hoverUIItem!.mouseDown(event)
            nodeHoverMode = .NodeUIMouseLocked
            setCurrentNode(hoverNode!)
            return
        }
        
        if nodeHoverMode == .MasterDrag {
            dragStartPos.x = event.x
            dragStartPos.y = event.y
            
            nodeDragStartPos.x = previewSize.x
            nodeDragStartPos.y = previewSize.y
            nodeHoverMode = .MasterDragging
            return
        }
        
        if nodeHoverMode == .Terminal {
            
            if hoverTerminal!.0.connections.count != 0 {
                for conn in hoverTerminal!.0.connections {
                    disconnectConnection(conn)
                }
            } else {
                nodeHoverMode = .TerminalConnection
                mousePos.x = event.x
                mousePos.y = event.y
                setCurrentNode(hoverNode!)
            }
        } else
        if let selectedNode = nodeAt(event.x, event.y) {
            setCurrentNode(selectedNode)

//            let offX = selectedNode.rect.x - event.x
            let offY = selectedNode.rect.y - event.y
            
            if nodeHoverMode == .Maximize {
                maximizedNode = selectedNode
                deactivate()
                maximizedNode!.maxDelegate!.activate(app!)
                nodeHoverMode = .None
                app?.mmView.mouseTrackWidget = nil
                return
            }
            if nodeHoverMode == .Close {
                deleteNode(selectedNode)
                nodeHoverMode = .None
                hoverNode = nil
                return
            }
            
            if offY < 26 && selectedNode !== currentMaster {
                dragStartPos.x = event.x
                dragStartPos.y = event.y
                
                nodeDragStartPos.x = selectedNode.xPos
                nodeDragStartPos.y = selectedNode.yPos
                nodeHoverMode = .Dragging
                
                //app?.mmView.mouseTrackWidget = app?.editorRegion?.widget
                app?.mmView.lockFramerate()
            }
        }
    }
    
    func mouseUp(_ event: MMMouseEvent)
    {
        if nodeHoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseUp(event)
        }

        if nodeHoverMode == .TerminalConnection && connectTerminal != nil {
            connectTerminals(hoverTerminal!.0, connectTerminal!.0)
        }
        
        app?.mmView.mouseTrackWidget = nil
        app?.mmView.unlockFramerate()
        nodeHoverMode = .None
    }
    
    func mouseMoved(_ event: MMMouseEvent)
    {
        let oldNodeHoverMode = nodeHoverMode
        
        if nodeHoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseMoved(event)
            return
        }
        
        // Drag Node
        if nodeHoverMode == .Dragging {
            
            hoverNode!.xPos = nodeDragStartPos.x + event.x - dragStartPos.x
            hoverNode!.yPos = nodeDragStartPos.y + event.y - dragStartPos.y
            mmView.update()
            return
        }
        
        // Resize Drag Master Node
        if nodeHoverMode == .MasterDragging {
            
            previewSize.x = floor(nodeDragStartPos.x - (event.x - dragStartPos.x))
            previewSize.y = floor(nodeDragStartPos.y + (event.y - dragStartPos.y))
            
            previewSize.x = max(previewSize.x, 80)
            previewSize.y = max(previewSize.y, 80)
            
            previewSize.x = min(previewSize.x, app!.editorRegion!.rect.width - 50)
            previewSize.y = min(previewSize.y, app!.editorRegion!.rect.height - 50)

            currentMaster!.updatePreview(nodeGraph: self)
            mmView.update()
            return
        }
        
        hoverNode = nodeAt(event.x, event.y)
        
        // Resizing the master node ?
        if hoverNode === currentMaster {
            if event.x > hoverNode!.rect.x + 5 && event.x < hoverNode!.rect.x + 35 && event.y < hoverNode!.rect.y + hoverNode!.rect.height - 5 && event.y > hoverNode!.rect.y + hoverNode!.rect.height - 35 {
                nodeHoverMode = .MasterDrag
                mmView.update()
                return
            }
        }
        
        if nodeHoverMode == .TerminalConnection {
            
            mousePos.x = event.x
            mousePos.y = event.y
           
            if hoverNode != nil {
                if let connectTerminal = terminalAt(hoverNode!, event.x, event.y) {
                    
                    self.connectTerminal = nil
                    if hoverTerminal!.0.brand == connectTerminal.0.brand && hoverTerminal!.1 != connectTerminal.1 {
                        self.connectTerminal = connectTerminal
                        
                        mousePos.x = connectTerminal.2
                        mousePos.y = connectTerminal.3
                    }
                }
            }
            mmView.update()
            return
        }
        
        nodeHoverMode = .None
        
        if hoverNode != nil {
            let x = event.x - hoverNode!.rect.x
            let y =  event.y - hoverNode!.rect.y
            
            // Maximize
            if hoverNode!.maxDelegate != nil {
                if hoverNode !== currentMaster {

                    let iconSize : Float = 18 * scale
                    let xStart : Float = hoverNode!.rect.width - 61 * scale
                    let yStart : Float = 27 * scale
                    
                    if x > xStart && x < xStart + iconSize && y > yStart && y < yStart + iconSize
                    {
                        nodeHoverMode = .Maximize
                        mmView.update()
                        return
                    }
                }
            }
            
            // Node Close
            if true {
                if hoverNode !== currentMaster {
                    
                    let iconSize : Float = 18 * scale
                    let xStart : Float = hoverNode!.rect.width - 38 * scale
                    let yStart : Float = 27 * scale
                    
                    if x > xStart && x < xStart + iconSize && y > yStart && y < yStart + iconSize
                    {
                        nodeHoverMode = .Close
                        mmView.update()
                        return
                    }
                }
            }
            
            if let terminalTuple = terminalAt(hoverNode!, event.x, event.y) {
                nodeHoverMode = .Terminal
                hoverTerminal = terminalTuple
                mmView.update()
                return
            }
            
            if hoverNode !== currentMaster {
                // --- Look for NodeUI item under the mouse, master has no UI
                let uiItemX = hoverNode!.rect.x + (hoverNode!.rect.width - hoverNode!.uiArea.width*scale) / 2
                var uiItemY = hoverNode!.rect.y + NodeGraph.bodyY * scale
                let uiRect = MMRect()
                let titleWidth : Float = (hoverNode!.uiMaxTitleSize.x + NodeUI.titleSpacing) * scale
                for uiItem in hoverNode!.uiItems {
                    
                    uiRect.x = uiItemX + titleWidth
                    uiRect.y = uiItemY
                    uiRect.width = uiItem.rect.width * scale - uiItem.titleLabel!.rect.width - NodeUI.titleMargin.width() - NodeUI.titleSpacing
                    uiRect.height = uiItem.rect.height * scale

                    if uiRect.contains(event.x, event.y) {
                        hoverUIItem = uiItem
                        nodeHoverMode = .NodeUI
                        hoverUIItem!.mouseMoved(event)
                        mmView.update()
                        return
                    }
                    uiItemY += uiItem.rect.height * scale
                }
            }
            
            // --- Check if mouse is over the preview area
            // --- Preview
            if let texture = hoverNode!.previewTexture {
                
                let rect = MMRect()
                if hoverNode !== currentMaster {
                    
                    rect.x = hoverNode!.rect.x + (hoverNode!.rect.width - 200*scale) / 2
                    rect.y = hoverNode!.rect.y + NodeGraph.bodyY * scale + hoverNode!.uiArea.height * scale
                    rect.width = Float(texture.width) * scale
                    rect.height = Float(texture.height) * scale
                } else {
                    // master
                    rect.x = hoverNode!.rect.x + 34
                    rect.y = hoverNode!.rect.y + 34 + 25
                    
                    rect.width = previewSize.x
                    rect.height = previewSize.y
                    
                    nodeHoverMode = .MasterNode
                }
            
                if rect.contains(event.x, event.y) {
                    nodeHoverMode = .Preview
                    mmView.update()
                    return
                }
            }
        }
        if oldNodeHoverMode != nodeHoverMode {
            mmView.update()
        }
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
            
            // --- Draw Nodes
            
            if playNode != nil {
                
                for node in nodes {
                    node.playResult = .Unused
                }
                
                for exe in playToExecute {
                    _ = exe.execute(nodeGraph: self, root: exe.behaviorRoot!, parent: exe.behaviorRoot!.rootNode)
                }
                playNode!.updatePreview(nodeGraph: self)
            }
            
            if let masterNode = currentMaster {

                for node in nodes {
                    if masterNode.subset!.contains(node.uuid) {
                        drawNode( node, region: region)
                    }
                }
                
                // --- Ongoing Node connection attempt ?
                if nodeHoverMode == .TerminalConnection {
                    
                    let color = getColorForTerminal(hoverTerminal!.0)
                    app!.mmView.drawLine.draw( sx: hoverTerminal!.2 - 2, sy: hoverTerminal!.3 - 2, ex: mousePos.x, ey: mousePos.y, radius: 2 * scale, fillColor : float4(color.x, color.y, color.z, 1) )
                }
                
                // --- DrawConnections
                for node in nodes {
                    if masterNode.subset!.contains(node.uuid) || node === masterNode {
                        
                        for terminal in node.terminals {
                            
                            if terminal.connector == .Right || terminal.connector == .Bottom {
                                for connection in terminal.connections {
                                    drawConnection(connection)
                                }
                            }
                        }
                    }
                }
                drawMasterNode( masterNode, region: region)
            }
            
            renderer.setClipRect()
        } else
        if region.type == .Left {
            nodeList!.rect.copy(region.rect)
            nodeList!.draw()
        } else
        if region.type == .Top {
            region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: nodesButton)
            //region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: playButton)
            
            typeScrollButton.rect.x = 200
            typeScrollButton.rect.y = nodesButton.rect.y
            typeScrollButton.draw()
            
            if contentType != .Game {
                contentScrollButton.rect.x = typeScrollButton.rect.x + typeScrollButton.rect.width + 15
                contentScrollButton.rect.y = typeScrollButton.rect.y
                contentScrollButton.draw()
            
                addButton.rect.x = contentScrollButton.rect.x + contentScrollButton.rect.width + 10
                addButton.rect.y = contentScrollButton.rect.y
                addButton.draw()
                
                removeButton.rect.x = addButton.rect.x + addButton.rect.width + 10
                removeButton.rect.y = contentScrollButton.rect.y
                removeButton.draw()
            }
            /*
            editButton.rect.x = removeButton.rect.x + removeButton.rect.width + 10
            editButton.rect.y = contentScrollButton.rect.y
            editButton.draw()
            
            playButton.rect.x = editButton.rect.x + editButton.rect.width + 10
            playButton.rect.y = contentScrollButton.rect.y
            playButton.draw()
            */

            nodesButton.draw()
            playButton.draw()
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

        node.rect.width = max(node.minimumSize.x, node.uiArea.width + 50) * scale
        node.rect.height = (node.minimumSize.y + node.uiArea.height) * scale
        
        if node.label == nil {
            node.label = MMTextLabel(app!.mmView, font: app!.mmView.openSans, text: node.name, scale: 0.5 * scale)
        }
        
        let iconWidth : Float = node.maxDelegate == nil ? 20 : 40
        
        if let label = node.label {
            if label.rect.width + (40+iconWidth) * scale > node.rect.width {
                node.rect.width = label.rect.width + (40+iconWidth) * scale
            }
        }

        let vertexBuffer = renderer.createVertexBuffer( MMRect( node.rect.x, node.rect.y, node.rect.width, node.rect.height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // --- Fill the node data
        
        node.data.size.x = node.rect.width
        node.data.size.y = node.rect.height
        
        node.data.selected = selectedUUID.contains(node.uuid) ? 1 : 0
        node.data.borderRound = 4

        if playNode != nil && node.playResult != nil {
            if node.playResult! == .Success {
                node.data.selected = 2
            } else
            if node.playResult! == .Failure {
                node.data.selected = 3
            } else if node.playResult! == .Failure {
                node.data.selected = 4
            }
        }
        
        node.data.hoverIndex = 0
        if nodeHoverMode == .Maximize && node.uuid == hoverNode!.uuid {
            node.data.hoverIndex = 1
        } else
        if nodeHoverMode == .Close && node.uuid == hoverNode!.uuid {
            node.data.hoverIndex = 2
        }
        
        node.data.hasIcons1.x = node.maxDelegate != nil ? 1 : 0
        node.data.hasIcons1.y = 1

        node.data.scale = scale
        
        var leftTerminalCount : Int = 0
        var topTerminalCount : Int = 0
        var rightTerminalCount : Int = 0
        var bottomTerminalCount : Int = 0

        var color : float3 = float3()
        var leftTerminalY : Float = NodeGraph.tOffY * scale
        for (index,terminal) in node.terminals.enumerated() {
            color = getColorForTerminal(terminal)
            if terminal.connector == .Left {
                
                if index == 0 {
                    node.data.leftTerminals.0 = float4( color.x, color.y, color.z, leftTerminalY)
                }

                leftTerminalCount += 1
                leftTerminalY += NodeGraph.tSpacing * 2
            }  else
            if terminal.connector == .Top {
                
                node.data.topTerminal = float4( color.x, color.y, color.z, 3 * scale)
                topTerminalCount += 1
            } else
            if terminal.connector == .Right {
                
                color = getColorForTerminal(terminal)

                node.data.rightTerminal = float4( color.x, color.y, color.z, NodeGraph.tOffY * scale)
                rightTerminalCount += 1
            } else
            if terminal.connector == .Bottom {
                
                node.data.bottomTerminal = float4( color.x, color.y, color.z, 10 * scale)

                bottomTerminalCount += 1
            }
        }
        
        node.data.leftTerminalCount = Float(leftTerminalCount)
        node.data.topTerminalCount = Float(topTerminalCount)
        node.data.rightTerminalCount = Float(rightTerminalCount)
        node.data.bottomTerminalCount = Float(bottomTerminalCount)

        // --- Draw It
        
        if node.buffer == nil {
            node.buffer = renderer.device.makeBuffer(length: MemoryLayout<NODE_DATA>.stride, options: [])!
        }
        
        memcpy(node.buffer!.contents(), &node.data, MemoryLayout<NODE_DATA>.stride)
        renderEncoder.setFragmentBuffer(node.buffer!, offset: 0, index: 0)
        renderEncoder.setRenderPipelineState(drawNodeState!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        // --- Label
        if let label = node.label {
            if label.scale != 0.5 * scale {
                label.setText(node.name, scale: 0.5 * scale)
            }
            //label.rect.x = node.rect.x + 20 * scale
            //label.rect.y = node.rect.y + 23 * scale
            //label.draw()
            label.drawCentered(x: node.rect.x + 10 * scale, y: node.rect.y + 23 * scale, width: node.rect.width - (iconWidth+20) * scale, height: label.rect.height)
        }
        
        // --- UI
        let uiItemX = node.rect.x + (node.rect.width - node.uiArea.width*scale) / 2 - 2.5 * scale
        var uiItemY = node.rect.y + NodeGraph.bodyY * scale

        for uiItem in node.uiItems {
            uiItem.rect.x = uiItemX
            uiItem.rect.y = uiItemY
            
            if nodeHoverMode == .NodeUIMouseLocked && node === hoverNode && uiItem === hoverUIItem! {
                uiItemY += uiItem.rect.height * scale
                continue
            }
            
            uiItem.draw(mmView: app!.mmView, maxTitleSize: node.uiMaxTitleSize, scale: scale)
            uiItemY += uiItem.rect.height * scale
        }
        
        if nodeHoverMode == .NodeUIMouseLocked && node === hoverNode {
            hoverUIItem!.draw(mmView: app!.mmView, maxTitleSize: node.uiMaxTitleSize, scale: scale)
        }
        
        // --- Preview
        if let texture = node.previewTexture {
            app!.mmView.drawTexture.draw(texture, x: node.rect.x + (node.rect.width - 200*scale)/2, y: node.rect.y + NodeGraph.bodyY * scale + node.uiArea.height * scale, zoom: 1/scale)
        }
    }
    
    /// Draw the master node
    func drawMasterNode(_ node: Node, region: MMRegion)
    {
        if contentType == .Game { return }

        let renderer = app!.mmView.renderer!
        let renderEncoder = renderer.renderEncoder!
        let scaleFactor : Float = app!.mmView.scaleFactor
        
        node.rect.width = previewSize.x + 70
        node.rect.height = previewSize.y + 64 + 25
        
        node.rect.x = region.rect.x + region.rect.width - node.rect.width + 11 + 10
        node.rect.y = region.rect.y - 22
        
        let vertexBuffer = renderer.createVertexBuffer( MMRect( node.rect.x, node.rect.y, node.rect.width, node.rect.height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // --- Fill the node data
        
        node.data.size.x = node.rect.width
        node.data.size.y = node.rect.height
        
        node.data.selected = 0
        node.data.borderRound = 16
        
        node.data.hoverIndex = 0
        if nodeHoverMode == .Maximize && node.uuid == hoverNode!.uuid {
            node.data.hoverIndex = 1
        }
        
        node.data.hasIcons1.x = 0
        node.data.hasIcons1.y = 0
        
        node.data.scale = 1
        
        var leftTerminalCount : Int = 0
        var topTerminalCount : Int = 0
        var rightTerminalCount : Int = 0
        var bottomTerminalCount : Int = 0
        
        var color : float3 = float3()
        var leftTerminalY : Float = NodeGraph.tOffY
        for (index,terminal) in node.terminals.enumerated() {
            color = getColorForTerminal(terminal)
            if terminal.connector == .Left {
                
                if index == 0 {
                    node.data.leftTerminals.0 = float4( color.x, color.y, color.z, leftTerminalY)
                }
                
                leftTerminalCount += 1
                leftTerminalY += NodeGraph.tSpacing * 2
            }  else
            if terminal.connector == .Top {
                
                node.data.topTerminal = float4( color.x, color.y, color.z, 3)
                topTerminalCount += 1
            } else
            if terminal.connector == .Right {
                
                color = getColorForTerminal(terminal)
                
                node.data.rightTerminal = float4( color.x, color.y, color.z, NodeGraph.tOffY)
                rightTerminalCount += 1
            } else
            if terminal.connector == .Bottom {
                
                node.data.bottomTerminal = float4( color.x, color.y, color.z, 10)
                
                bottomTerminalCount += 1
            }
        }
        
        node.data.leftTerminalCount = Float(leftTerminalCount)
        node.data.topTerminalCount = Float(topTerminalCount)
        node.data.rightTerminalCount = Float(rightTerminalCount)
        node.data.bottomTerminalCount = Float(bottomTerminalCount)
        
        // --- Draw It
        
        if node.buffer == nil {
            node.buffer = renderer.device.makeBuffer(length: MemoryLayout<NODE_DATA>.stride, options: [])!
        }
        
        memcpy(node.buffer!.contents(), &node.data, MemoryLayout<NODE_DATA>.stride)
        renderEncoder.setFragmentBuffer(node.buffer!, offset: 0, index: 0)
        renderEncoder.setRenderPipelineState(drawNodeState!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        // --- Preview
        if let texture = node.previewTexture {
            let x : Float = node.rect.x + 34
            let y : Float = node.rect.y + 34 + 25
            app!.mmView.drawTexture.draw(texture, x: x, y: y, zoom: 1)
            
            // Preview Border
            app!.mmView.drawBox.draw( x: x, y: y, width: previewSize.x, height: previewSize.y, round: 0, borderSize: 3, fillColor: float4(repeating: 0), borderColor: float4(0, 0, 0, 1) )
        }
        
        // --- Buttons
        
        editButton.rect.x = node.rect.x + 35
        editButton.rect.y = node.rect.y + 25
        editButton.draw()
        
        playButton.rect.x = editButton.rect.x + editButton.rect.width + 10
        playButton.rect.y = editButton.rect.y
        playButton.draw()
        
        // --- Node Drag Handles
        
        let dragColor = nodeHoverMode == .MasterDrag || nodeHoverMode == .MasterDragging ? float4(repeating:1) : float4(0.5, 0.5, 0.5, 1)
        
        var sX: Float = node.rect.x + 20
        var sY: Float = node.rect.y + node.rect.height - 30
        var eX: Float = node.rect.x + 30
        var eY: Float = node.rect.y + node.rect.height - 20

        app!.mmView.drawLine.draw(sx: sX, sy: sY, ex: eX, ey: eY, radius: 1.2, fillColor: dragColor)
        
        sX = node.rect.x + 18
        sY = node.rect.y + node.rect.height - 23
        eX = node.rect.x + 23
        eY = node.rect.y + node.rect.height - 18
        
        app!.mmView.drawLine.draw(sx: sX, sy: sY, ex: eX, ey: eY, radius: 1.2, fillColor: dragColor)
    }
    
    /// Draws the given connection
    func drawConnection(_ conn: Connection)
    {
        func getPointForConnection(_ conn:Connection) -> (Float, Float)
        {
            var x : Float = 0
            var y : Float = 0
            let terminal = conn.terminal!
            let node = terminal.node!
            
            let scale = node === currentMaster ? 1 : self.scale

            var bottomCount : Float = 0
            for terminal in node.terminals {
                if terminal.connector == .Bottom {
                    bottomCount += 1
                }
            }
            
            var bottomX : Float = (node.rect.width - (bottomCount * NodeGraph.tDiam * scale + (bottomCount - 1) * NodeGraph.tSpacing * scale )) / 2 - 3.5 * scale
            
            for t in node.terminals {
                if t.connector == .Left || t.connector == .Right {
                    if t.uuid == conn.terminal!.uuid {
                        if t.connector == .Left {
                            x = NodeGraph.tLeftY * scale + NodeGraph.tRadius * scale
                        } else {
                            x = node.rect.width - NodeGraph.tRightY * scale + NodeGraph.tRadius * scale
                        }
                     
                        y = NodeGraph.tOffY * scale
                        break
                    }
                    
                    y += NodeGraph.tRadius * scale
                } else
                if t.connector == .Top {
                    if t.uuid == conn.terminal!.uuid {
                        x = node.rect.width / 2 - 3 * scale
                        y = 3 * scale + NodeGraph.tRadius * scale
                        
                        break;
                    }
                } else
                if t.connector == .Bottom {
                    if t.uuid == terminal.uuid {
                        x = bottomX + NodeGraph.tRadius * scale
                        y = node.rect.height - 3 * scale - NodeGraph.tRadius * scale
                        
                        break;
                    }
                    bottomX += NodeGraph.tSpacing * scale + NodeGraph.tDiam * scale
                }
            }
            
            return (node.rect.x + x, node.rect.y + y)
        }
        
        /// Returns the connection identified by its UUID in the given terminal
        func getConnectionInTerminal(_ terminal: Terminal, uuid: UUID) -> Connection?
        {
            for conn in terminal.connections {
                if conn.uuid == uuid {
                    return conn
                }
            }
            return nil
        }
        
        let fromTuple = getPointForConnection(conn)
        
        let toConnection = getConnectionInTerminal(conn.toTerminal!, uuid: conn.toUUID)
        
        let toTuple = getPointForConnection(toConnection!)

        let color = getColorForTerminal(conn.terminal!)
        app!.mmView.drawLine.draw( sx: fromTuple.0, sy: fromTuple.1, ex: toTuple.0, ey: toTuple.1, radius: 2 * scale, fillColor : float4(color.x,color.y,color.z,1) )
    }
    
    /// Returns the node (if any) at the given mouse coordinates
    func nodeAt(_ x: Float, _ y: Float) -> Node?
    {
        if let masterNode = currentMaster {
            for node in nodes {
                if masterNode.subset!.contains(node.uuid) || node === masterNode {
                    if node.rect.contains( x, y ) {
                        return node
                    }
                }
            }
        }
        return nil
    }
    
    /// Returns the terminal and the terminal connector at the given mouse position for the given node (if any)
    func terminalAt(_ node: Node, _ x: Float, _ y: Float) -> (Terminal, Terminal.Connector, Float, Float)?
    {
        let scale : Float = node === currentMaster ? 1 : self.scale
        
        var lefTerminalY : Float = NodeGraph.tOffY * scale
        var rightTerminalY : Float = NodeGraph.tOffY * scale
        
        var bottomCount : Float = 0
        for terminal in node.terminals {
            if terminal.connector == .Bottom {
                bottomCount += 1
            }
        }
        var bottomX : Float = (node.rect.width - (bottomCount * NodeGraph.tDiam * scale + (bottomCount - 1) * NodeGraph.tSpacing * scale )) / 2 - 3.5 * scale
        
        for terminal in node.terminals {

            if terminal.connector == .Left {
                if y >= node.rect.y + lefTerminalY && y <= node.rect.y + lefTerminalY + NodeGraph.tDiam * scale {
                    if x >= node.rect.x && x <= node.rect.x + NodeGraph.tLeftY * scale + NodeGraph.tDiam * scale {
                        return (terminal, .Left, node.rect.x + NodeGraph.tLeftY * scale + NodeGraph.tRadius * scale, node.rect.y + lefTerminalY + NodeGraph.tRadius * scale)
                    }
                }
                lefTerminalY += NodeGraph.tSpacing * scale
            } else
            if terminal.connector == .Top {
                if y >= node.rect.y + 3 * scale && y <= node.rect.y + 3 * scale + NodeGraph.tDiam * scale {
                    if x >= node.rect.x + node.rect.width / 2 - NodeGraph.tRadius * scale - 3 * scale && x <= node.rect.x + node.rect.width / 2 + NodeGraph.tRadius * scale - 3 * scale {
                        return (terminal, .Top, node.rect.x + node.rect.width / 2 - 3 * scale, node.rect.y + 3 * scale + NodeGraph.tRadius * scale)
                    }
                }
            } else
            if terminal.connector == .Right {
                if y >= node.rect.y + rightTerminalY && y <= node.rect.y + rightTerminalY + NodeGraph.tDiam * scale {
                    if x >= node.rect.x + node.rect.width - NodeGraph.tRightY * scale && x <= node.rect.x + node.rect.width {
                        return (terminal, .Right, node.rect.x + node.rect.width - NodeGraph.tRightY * scale + NodeGraph.tRadius * scale, node.rect.y + rightTerminalY + NodeGraph.tRadius * scale)
                    }
                }
                rightTerminalY += NodeGraph.tSpacing * scale
            } else
            if terminal.connector == .Bottom {
                if y >= node.rect.y + node.rect.height - 0 * scale - NodeGraph.tDiam * scale && y <= node.rect.y + node.rect.height - 0 * scale {
                    if x >= node.rect.x + bottomX && x <= node.rect.x + bottomX + NodeGraph.tDiam * scale {
                        return (terminal, .Bottom, node.rect.x + bottomX + NodeGraph.tRadius * scale, node.rect.y + node.rect.height - 3 * scale - NodeGraph.tRadius * scale)
                    }
                    bottomX += NodeGraph.tSpacing * scale + NodeGraph.tDiam * scale
                }
            }
        }

        return nil
    }
    
    /// Connects two terminals
    func connectTerminals(_ terminal1: Terminal,_ terminal2: Terminal)
    {
        let t1Connection = Connection(from: terminal1, to: terminal2)
        let t2Connection = Connection(from: terminal2, to: terminal1)
        
        t1Connection.toUUID = t2Connection.uuid
        t2Connection.toUUID = t1Connection.uuid
        
        terminal1.connections.append(t1Connection)
        terminal2.connections.append(t2Connection)
        
        terminal1.node!.onConnect(myTerminal: terminal1, toTerminal: terminal2)
        terminal2.node!.onConnect(myTerminal: terminal2, toTerminal: terminal1)
    }
    
    /// Disconnects the connection
    func disconnectConnection(_ conn: Connection)
    {
        let terminal = conn.terminal!
        terminal.connections.removeAll{$0.uuid == conn.uuid}

        let toTerminal = conn.toTerminal!
        toTerminal.connections.removeAll{$0.uuid == conn.toUUID!}
        
        terminal.node!.onConnect(myTerminal: terminal, toTerminal: toTerminal)
        toTerminal.node!.onConnect(myTerminal: toTerminal, toTerminal: terminal)
    }
    
    /// Returns the color for the given terminal
    func getColorForTerminal(_ terminal: Terminal) -> float3
    {
        var color : float3
        
        switch(terminal.brand)
        {
            case .Properties:
                color = float3(0.62, 0.506, 0.165)
            case .Object:
                color = float3(repeating: 1)//float3(0.192, 0.573, 0.478)
            case .Behavior:
                color = float3(0.129, 0.216, 0.612)
            default:
                color = float3()
        }
        
        if playNode != nil {
            if terminal.node!.playResult != nil {
                if terminal.node!.playResult! == .Success {
                    color = float3(0.192, 0.573, 0.478);
                } else
                if terminal.node!.playResult! == .Failure {
                    color = float3(0.988, 0.129, 0.188);
                } else
                if terminal.node!.playResult! == .Running {
                    color = float3(0,0,0);
                }
            }
        }
        
        return color
    }
    
    /// Decode a new nodegraph from JSON
    func decodeJSON(_ json: String) -> NodeGraph?
    {
        if let jsonData = json.data(using: .utf8)
        {
            if let graph =  try? JSONDecoder().decode(NodeGraph.self, from: jsonData) {
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
    
    /// Sets the current node
    func setCurrentNode(_ node: Node?=nil)
    {
        if node == nil {
            selectedUUID = []
            currentNode = nil
        } else {
            selectedUUID = [node!.uuid]
            currentNode = node
        }
    }
    
    /// gets all behavior tree nodes for the given master node
    func getBehaviorTrees(for masterNode:Node) -> [BehaviorTree]
    {
        if masterNode.subset == nil { return [] }
        var trees : [BehaviorTree] = []
        
        for node in nodes {
            if masterNode.subset!.contains(node.uuid) {
                if let treeNode = node as? BehaviorTree {
                    if node.properties["status"] == 0 {
                        trees.append(treeNode)
                    }
                }
            }
        }
        
        return trees
    }
    
    /// Gets all property nodes for the given master node
    func getPropertyNodes(for masterNode:Node) -> [Node]
    {
        if masterNode.subset == nil { return [] }
        var props : [Node] = []
        
        for node in nodes {
            if masterNode.subset!.contains(node.uuid) {
                if node.brand == .Property {
                    props.append(node)
                }
            }
        }
        
        return props
    }
    
    /// Gets the first node of the given type
    func getNodeOfType(_ type: String) -> Node?
    {
        for node in nodes {
            if node.type == type {
                return node
            }
        }
        return nil
    }
    
    /// Update the content type
    func updateContent(_ type : ContentType)
    {
        var items : [String] = []
        currentContent = []
        var index : Int = 0
        var currentFound : Bool = false
        
        for node in nodes {
            if type == .Objects {
                let object : Object? = node as? Object
                if object != nil {
                    if object!.uuid == currentObjectUUID {
                        index = items.count
                        currentFound = true
                        if currentMasterUUID != currentObjectUUID {
                            setCurrentMaster(node: node)
                        }
                    }
                    items.append(node.name)
                    currentContent.append(node)
                }
            } else
            if type == .Layers {
                let layer : Layer? = node as? Layer
                if layer != nil {
                    if layer!.uuid == currentLayerUUID {
                        index = items.count
                        currentFound = true
                        if currentMasterUUID != currentLayerUUID {
                            setCurrentMaster(node: node)
                        }
                    }
                    items.append(node.name)
                    currentContent.append(node)
                }
            } else
            if type == .Game {
                let game : Game? = node as? Game
                if game != nil {
                    if game!.uuid == currentLayerUUID {
                        index = items.count
                        currentFound = true
                        setCurrentMaster(node: node)
                    }
                    items.append(node.name)
                    currentContent.append(node)
                }
            }
        }
        if currentFound == false {
            if currentContent.count > 0 {
                setCurrentMaster(node: currentContent[0])
            }
        }
        contentScrollButton.setItems(items, fixedWidth: 250)
        contentScrollButton.index = index
    }
    
    /// Sets the current master node
    func setCurrentMaster(node: Node?=nil, uuid: UUID?=nil)
    {
        currentMaster = nil
        currentMasterUUID = nil
        
        func setCurrentMasterUUID(_ uuid: UUID)
        {
            currentMasterUUID = uuid
            if contentType == .Objects {
                currentObjectUUID = uuid
            } else
            if contentType == .Layers {
                currentLayerUUID = uuid
            } else
            if contentType == .Scenes {
                currentSceneUUID = uuid
            }
        }
        
        if node != nil {
            currentMaster = node!
            setCurrentMasterUUID(node!.uuid)
        } else
        if uuid != nil {
            for node in nodes {
                if node.uuid == uuid {
                    currentMaster = node
                    currentMasterUUID = node.uuid
                    setCurrentMasterUUID(node.uuid)
                    break
                }
            }
        }
    }
    
    /// Hard updates the given node
    func updateNode(_ node: Node, updatePreview: Bool = true)
    {
        /// Returns the terminal of the given UUID
        func getTerminalOfUUID(_ uuid: UUID) -> Terminal?
        {
            for node in nodes {
                for terminal in node.terminals {
                    if terminal.uuid == uuid {
                        return terminal
                    }
                }
            }
            return nil
        }
        
        if updatePreview && node.type == "Object" {
            let object = node as! Object
            object.instance = app!.nodeGraph.builder.buildObjects(objects: [object], camera: app!.camera)
        }
        
        for terminal in node.terminals {
            for conn in terminal.connections {
                conn.toTerminal = getTerminalOfUUID(conn.toTerminalUUID)
            }
        }
        
        // Update the UI and special role items
        node.setupUI(mmView: app!.mmView)
        for item in node.uiItems {
            if item.role == .AnimationPicker {
                if let masterObject = getMasterForNode(node) as? Object {
                    if let picker = item as? NodeUIAnimationPicker {
                        picker.items = []
                        for seq in masterObject.sequences {
                            picker.items.append(seq.name)
                            if picker.index < 0 && picker.index >= Float(picker.items.count) {
                                picker.index = 0
                                node.properties[item.variable] = picker.index
                            }
                        }
                        node.computeUIArea(mmView: app!.mmView)
                    }
                }
            }
        }
        if updatePreview {
            node.updatePreview(nodeGraph: self, hard: true)
        }
    }
    
    /// Hard updates all nodes
    func updateNodes(updatePreviews: Bool = true)
    {
        for node in nodes {
            updateNode(node, updatePreview: updatePreviews)
        }
        maximizedNode = nil
    }
    
    /// Hard updates all nodes belonging to this master node
    func updateMasterNodes(_ masterNode: Node)
    {
        if let subset = masterNode.subset {
            for clientNode in subset {
                for node in nodes {
                    if node.uuid == clientNode {
                        updateNode(node, updatePreview: false)
                        break
                    }
                }
            }
        }
    }
    
    /// Returns the master node for the given client node
    func getMasterForNode(_ clientNode: Node) -> Node?
    {
        var masterNode : Node? = nil
        
        for node in nodes {
            if node.subset != nil {
                if node === clientNode {
                    masterNode = node
                    break
                }
                if node.subset!.contains(clientNode.uuid) {
                    masterNode = node
                    break
                }
            }
        }
        
        return masterNode
    }
    
    /// Deletes the given node
    func deleteNode(_ node: Node)
    {
        // Remove connections
        for t in node.terminals {
            for conn in t.connections {
                disconnectConnection(conn)
            }
        }
        // Remove node from master subset
        if let master = currentMaster {
            master.subset!.remove(at: master.subset!.firstIndex(where: { $0 == node.uuid })!)
        }
        // Remove from nodes
        nodes.remove(at: nodes.firstIndex(where: { $0.uuid == node.uuid })!)
        mmView.update()
    }
}
