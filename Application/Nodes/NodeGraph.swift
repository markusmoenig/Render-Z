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
    enum DebugMode
    {
        case None, Physics
    }
    
    enum LeftRegionMode
    {
        case Closed, Nodes
    }
    
    enum NodeHoverMode : Float {
        case None, Dragging, Terminal, TerminalConnection, NodeUI, NodeUIMouseLocked, Preview, MasterDrag, MasterDragging, MasterNode, MenuHover, MenuOpen, OverviewEdit
    }
    
    enum ContentType : Int {
        case Objects, Layers, Scenes, Game, ObjectsOverview, LayersOverview, ScenesOverview
    }
    
    var debugMode       : DebugMode = .None
    var nodes           : [Node] = []

    var drawNodeState   : MTLRenderPipelineState?
    var drawPatternState: MTLRenderPipelineState?

    var app             : App? = nil
    var mmView          : MMView!
    var mmScreen        : MMScreen? = nil

    var maximizedNode   : Node?
    var hoverNode       : Node?
    var currentNode     : Node?
    
    var previewNode     : Node? = nil
    var playNode        : Node? = nil
    var playToExecute   : [Node] = []
    var playPhysicLayers: [Layer] = []

    var currentMaster   : Node? = nil
    var currentMasterUUID: UUID? = nil
    
    var currentObjectUUID: UUID? = nil
    var currentLayerUUID: UUID? = nil
    var currentSceneUUID: UUID? = nil

    var hoverUIItem     : NodeUI?
    var hoverUITitle    : NodeUI?

    var hoverTerminal   : (Terminal, Terminal.Connector, Float, Float)?
    var connectTerminal : (Terminal, Terminal.Connector, Float, Float)?

    var selectedUUID    : [UUID] = []
    
    var dragStartPos    : float2 = float2()
    var nodeDragStartPos: float2 = float2()
    var childsOfSel     : [Node] = []
    var childsOfSelPos  : [UUID:float2] = [:]
    
    var mousePos        : float2 = float2()

    var nodeHoverMode   : NodeHoverMode = .None
    var nodesButton     : MMButtonWidget!
    
    var contentType     : ContentType = .Objects
    var overviewMaster  : Node = Node()
    var overviewIsOn    : Bool = false
    
    var objectsOverCam  : Camera? = Camera()
    var layersOverCam   : Camera? = Camera()
    var scenesOverCam   : Camera? = Camera()

    //var typeScrollButton: MMScrollButton!
    var contentScrollButton: MMScrollButton!
    
    // Current available class nodes (selectable master nodes)
    var currentContent  : [Node] = []
    
    var objectsButton   : MMButtonWidget!
    var layersButton    : MMButtonWidget!
    var scenesButton    : MMButtonWidget!
    var gameButton      : MMButtonWidget!
    
    var overviewButton  : MMButtonWidget!

    var editButton      : MMButtonWidget!
    var playButton      : MMButtonWidget!

    var nodeList        : NodeList?
    var animating       : Bool = false
    var leftRegionMode  : LeftRegionMode = .Nodes
    
    var builder         : Builder!
    var physics         : Physics!
    var timeline        : MMTimeline!
    var diskBuilder     : DiskBuilder!
    var debugBuilder    : DebugBuilder!
    var debugInstance   : DebugBuilderInstance!

    var behaviorMenu    : MMMenuWidget!
    var previewInfoMenu : MMMenuWidget!

    var previewSize     : float2 = float2(320, 200)

    var editLabel       : MMTextLabel!
    
    var refList         : ReferenceList!
    var validHoverTarget: NodeUIDropTarget? = nil
    
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
        
        debugBuilder = DebugBuilder(self)
        debugInstance = debugBuilder.build(camera: Camera())
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([Node].self, ofFamily: NodeFamily.self, forKey: .nodes)
        currentMasterUUID = try container.decode(UUID?.self, forKey: .currentMasterUUID)
        previewSize = try container.decode(float2.self, forKey: .previewSize)
        setCurrentMaster(uuid: currentMasterUUID)
        
        debugBuilder = DebugBuilder(self)
        debugInstance = debugBuilder.build(camera: Camera())
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
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
        
        /*
        typeScrollButton = MMScrollButton(app.mmView, items:["Objects", "Layers", "Scenes", "Game"])
        typeScrollButton.changed = { (index)->() in
            self.contentType = ContentType(rawValue: index)!
            self.updateContent(self.contentType)
            if self.currentMaster != nil && self.currentContent.count > 0 {
                self.currentMaster!.updatePreview(nodeGraph: self, hard: false)
            }
            self.nodeList!.switchTo(NodeListItem.DisplayType(rawValue: index+1)!)
        }*/
        
        contentScrollButton = MMScrollButton(app.mmView, items:[])
        contentScrollButton.changed = { (index)->() in
            self.stopPreview()
            
            if !self.overviewIsOn {
                let node = self.currentContent[index]
                self.setCurrentMaster(node: node)
                if self.currentContent.count > 0 {
                    node.updatePreview(nodeGraph: self, hard: false)
                }
            } else {
                let node = self.currentContent[index]
                self.setCurrentNode(node)
                if self.contentType == .ObjectsOverview {
                    self.currentObjectUUID = node.uuid
                } else
                if self.contentType == .LayersOverview {
                    self.currentLayerUUID = node.uuid
                } else
                if self.contentType == .ScenesOverview {
                    self.currentSceneUUID = node.uuid
                }
            }
        }
        
        objectsButton = MMButtonWidget(app.mmView, text: "Objects" )
        objectsButton.textYOffset = 1.5
        objectsButton.addState(.Checked)
        objectsButton.clicked = { (event) -> Void in
            self.stopPreview()
            self.editButton.setText("Shape...")
            self.editButton.isDisabled = false

            self.objectsButton.addState(.Checked)
            self.layersButton.removeState(.Checked)
            self.scenesButton.removeState(.Checked)
            self.gameButton.removeState(.Checked)
            self.overviewButton.isDisabled = false

            self.contentType = .Objects
            self.updateContent(self.contentType)
            
            if self.currentContent.count == 0 || event.x != 0 {
                self.overviewButton.addState(.Checked)
                self.overviewIsOn = true
            }
            
            if !self.overviewButton.states.contains(.Checked) {
                if self.currentMaster != nil && self.currentContent.count > 0 {
                    self.currentMaster!.updatePreview(nodeGraph: self, hard: false)
                }
                self.nodeList!.switchTo(.Object)
            } else {
                self.contentType = .ObjectsOverview
                self.setOverviewMaster()
            }
        }
        
        layersButton = MMButtonWidget(app.mmView, text: "Layers" )
        layersButton.rect.width = objectsButton.rect.width
        layersButton.clicked = { (event) -> Void in
            self.stopPreview()
            self.editButton.setText("Arrange...")
            self.editButton.isDisabled = false

            self.objectsButton.removeState(.Checked)
            self.layersButton.addState(.Checked)
            self.scenesButton.removeState(.Checked)
            self.gameButton.removeState(.Checked)
            self.overviewButton.isDisabled = false

            self.contentType = .Layers
            self.updateContent(self.contentType)
            
            if self.currentContent.count == 0 || event.x != 0 {
                self.overviewButton.addState(.Checked)
                self.overviewIsOn = true
            }
            
            if !self.overviewButton.states.contains(.Checked) {
                if self.currentMaster != nil && self.currentContent.count > 0 {
                    self.currentMaster!.updatePreview(nodeGraph: self, hard: false)
                }
                self.nodeList!.switchTo(.Layer)
            } else {
                self.contentType = .LayersOverview
                self.setOverviewMaster()
            }
        }
        
        scenesButton = MMButtonWidget(app.mmView, text: "Scenes" )
        scenesButton.rect.width = objectsButton.rect.width
        scenesButton.clicked = { (event) -> Void in
            self.stopPreview()
            self.editButton.setText("Arrange...")
            self.editButton.isDisabled = false

            self.objectsButton.removeState(.Checked)
            self.layersButton.removeState(.Checked)
            self.scenesButton.addState(.Checked)
            self.gameButton.removeState(.Checked)
            self.overviewButton.isDisabled = false

            self.contentType = .Scenes
            self.updateContent(self.contentType)
            
            if self.currentContent.count == 0 || event.x != 0 {
                self.overviewButton.addState(.Checked)
                self.overviewIsOn = true
            }
            
            if !self.overviewButton.states.contains(.Checked) {
                if self.currentMaster != nil && self.currentContent.count > 0 {
                    self.currentMaster!.updatePreview(nodeGraph: self, hard: false)
                }
                self.nodeList!.switchTo(.Scene)
            } else {
                self.contentType = .ScenesOverview
                self.setOverviewMaster()
            }
        }
        
        gameButton = MMButtonWidget(app.mmView, text: "Game" )
        gameButton.rect.width = objectsButton.rect.width
        gameButton.clicked = { (event) -> Void in
            self.stopPreview()
            self.editButton.setText("Arrange...")
            self.editButton.isDisabled = true

            self.objectsButton.removeState(.Checked)
            self.layersButton.removeState(.Checked)
            self.scenesButton.removeState(.Checked)
            self.gameButton.addState(.Checked)
            self.overviewButton.isDisabled = true
            
            self.contentType = .Game
            self.updateContent(self.contentType)
            if self.currentMaster != nil && self.currentContent.count > 0 {
                self.currentMaster!.updatePreview(nodeGraph: self, hard: false)
            }
            self.nodeList!.switchTo(.Game)
        }
        
        overviewButton = MMButtonWidget(app.mmView, text: "Overview" )
        overviewButton.clicked = { (event) -> Void in
            self.stopPreview()
            
            if !self.overviewIsOn {
                self.overviewButton.addState(.Checked)
                self.overviewIsOn = true
            } else {
                self.overviewButton.removeState(.Checked)
                self.overviewIsOn = false
            }
            
            self.overviewButton.removeState(.Checked)
            self.overviewIsOn = false
            
            if self.contentType == .Objects || self.contentType == .ObjectsOverview {
                self.objectsButton._clicked(MMMouseEvent(0, 0))
            }
            if self.contentType == .Layers || self.contentType == .LayersOverview {
                self.layersButton._clicked(MMMouseEvent(0, 0))
            }
            if self.contentType == .Scenes || self.contentType == .ScenesOverview {
                self.scenesButton._clicked(MMMouseEvent(0, 0))
            }
            if self.contentType == .Game {
                self.gameButton._clicked(MMMouseEvent(0, 0))
            }
        }
        
        var smallButtonSkin = MMSkinButton()
        smallButtonSkin.height = 30
        smallButtonSkin.fontScale = 0.4
        smallButtonSkin.margin.left = 8
        
        editButton = MMButtonWidget(app.mmView, skinToUse: smallButtonSkin, text: "Shape..." )
        editButton.clicked = { (event) -> Void in
            self.stopPreview()

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
                self.playPhysicLayers = []
                self.playNode = self.previewNode
                self.mmScreen = MMScreen(self.mmView)

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
                    if layer.physicsInstance != nil {
                        self.playPhysicLayers.append(layer)
                    }
                    self.playToExecute.append(layer)
                } else
                if node!.type == "Scene" {
                    let scene = node as! Scene
                    scene.setupExecution(nodeGraph: self)

                    for layerUUID in scene.layers {
                        for n in self.nodes {
                            if n.uuid == layerUUID
                            {
                                let layer = n as! Layer
                                layer.setupExecution(nodeGraph: self)
                                for inst in layer.objectInstances {
                                    self.playToExecute.append(inst.instance!)
                                }
                                if layer.physicsInstance != nil {
                                    self.playPhysicLayers.append(layer)
                                }
                                self.playToExecute.append(layer)
                            }
                        }
                    }
                    self.playToExecute.append(scene)
                } else
                if node!.type == "Game" {
                    let game = node as! Game

                    game.setupExecution(nodeGraph: self)
                    self.playToExecute.append(game)
                }
                
                // -- Init behavior trees
                for exe in self.playToExecute {
                    exe.behaviorRoot = BehaviorTreeRoot(exe)
                    exe.behaviorTrees = []
                    let trees = self.getBehaviorTrees(for: exe)
                    
                    for tree in trees {
                        let status = tree.properties["status"]!
                        
                        if status == 0 {
                            // Always execute
                            exe.behaviorTrees!.append(tree)
                        } else
                        if status == 1 {
                            // Execute all "On Startup" behavior trees
                            _ = tree.execute(nodeGraph: self, root: exe.behaviorRoot!, parent: exe.behaviorRoot!.rootNode)
                        }
                    }
                }
                
                self.playButton.addState(.Checked)
                app.mmView.lockFramerate(true)
            } else {
                self.stopPreview()
            }
        }
        
        nodeList = NodeList(app.mmView, app:app)
        
        // --- Register icons at first time start
//        if app.mmView.icons["execute"] == nil {
//            executeIcon = app.mmView.registerIcon("execute")
//        } else {
//            executeIcon = app.mmView.icons["execute"]
//        }
        
        editLabel = MMTextLabel(mmView, font: mmView.openSans, text: "EDIT", scale: 0.3)
        
        // Behavior Menu (Debug Options)
        var behaviorItems : [MMMenuItem] = []
        
        let noDebugItem =  MMMenuItem( text: "Debug Info: None", cb: {
            self.debugMode = .None
        } )
        behaviorItems.append(noDebugItem)
        
        let physicsDebugItem =  MMMenuItem( text: "Debug Info: Physics", cb: {
            self.debugMode = .Physics
        } )
        behaviorItems.append(physicsDebugItem)
        
        behaviorMenu = MMMenuWidget(mmView, items: behaviorItems)
        // ---
        
        previewInfoMenu = MMMenuWidget(mmView, type: .LabelMenu)
        
        updateNodes()
        updateContent(.Objects)
        
        refList = ReferenceList(self)
        refList.createVariableList()
    }

    ///
    func activate()
    {
        app?.mmView.registerWidgets(widgets: nodesButton, nodeList!, contentScrollButton, objectsButton, layersButton, scenesButton, gameButton)
        app?.mmView.widgets.insert(editButton, at: 0)
        app?.mmView.widgets.insert(playButton, at: 0)
        app?.mmView.widgets.insert(behaviorMenu, at: 0)
        app?.mmView.widgets.insert(previewInfoMenu, at: 0)
        if app!.properties["NodeGraphNodesOpen"] == nil || app!.properties["NodeGraphNodesOpen"]! == 1 {
            app!.leftRegion!.rect.width = 200
        } else {
            app!.leftRegion!.rect.width = 0
        }
        nodeHoverMode = .None
    }
    
    ///
    func deactivate()
    {
        app?.mmView.deregisterWidgets(widgets: nodesButton, nodeList!, playButton, contentScrollButton, objectsButton, layersButton, scenesButton, gameButton, editButton, behaviorMenu, previewInfoMenu)
        app!.properties["NodeGraphNodesOpen"] = leftRegionMode == .Closed ? 0 : 1
    }
    
    /// Stop previewing the playNode
    func stopPreview()
    {
        if playNode == nil { return }
        
        let node = self.playNode
        
        if node!.type == "Object" {
            let object = node as! Object
            object.playInstance = nil
        } else
        if self.playNode!.type == "Layer" {
            let layer = self.playNode as! Layer
            layer.physicsInstance = nil
        } else
        if self.playNode!.type == "Scene" {
            let scene = node as! Scene
            
            for layerUUID in scene.layers {
                for n in self.nodes {
                    if n.uuid == layerUUID
                    {
                        let layer = n as! Layer
                        layer.physicsInstance = nil
                        layer.builderInstance = nil
                    }
                }
            }
        }
        
        // Send finish to all nodes
        for node in self.nodes {
            node.finishExecution()
        }
        
        self.playNode!.updatePreview(nodeGraph: app!.nodeGraph, hard: true)
        self.playNode = nil
        self.playToExecute = []
        self.playButton.removeState(.Checked)
        app!.mmView.unlockFramerate(true)
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
        if refList.isActive && refList.rect.contains(event.x, event.y){
            refList.mouseDown(event)
            return
        }
        
        self.setCurrentNode()
        
        func setCurrentNode(_ node: Node)
        {
            if overviewIsOn == true {
                if let index = self.currentContent.firstIndex(of: node) {
                    self.contentScrollButton.index = index
                    
                    if self.contentType == .ObjectsOverview {
                        self.currentObjectUUID = node.uuid
                    } else
                    if self.contentType == .LayersOverview {
                        self.currentLayerUUID = node.uuid
                    } else
                    if self.contentType == .ScenesOverview {
                        self.currentSceneUUID = node.uuid
                    }
                }
            }
            self.setCurrentNode(node)
        }
        
        #if os(OSX)
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
        }
        #endif
        
        if let screen = mmScreen {
            screen.mouseDownPos.x = event.x
            screen.mouseDownPos.y = event.y
            screen.mouseDown = true
        }
                
//        #if !os(OSX)
        if nodeHoverMode != .MenuOpen || mmView.mouseTrackWidget == nil {
            
            if hoverNode != nil && hoverNode!.menu != nil {
                if !hoverNode!.menu!.states.contains(.Opened) {
                    nodeHoverMode = .None
                }
            }
            
            mouseMoved( event )
        }
//        #endif

        if nodeHoverMode == .OverviewEdit {
            setCurrentNode(hoverNode!)
            #if os(OSX)
            if overviewIsOn {
                self.overviewButton.clicked!(MMMouseEvent(0,0))
                nodeHoverMode = .None
            } else {
                activateNodeDelegate(hoverNode!)
            }
            #endif
            return
        }
        
        if nodeHoverMode != .None && nodeHoverMode != .Preview {
            app?.mmView.mouseTrackWidget = app?.editorRegion?.widget
        }
        
        if nodeHoverMode == .MenuHover {
            if let menu = hoverNode!.menu {
                menu.mouseDown(event)

                if menu.states.contains(.Opened) {
                    nodeHoverMode = .MenuOpen
                    menu.removeState(.Hover)
                }
            }
            setCurrentNode(hoverNode!)
            return
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
            
            if offY < 26 && selectedNode !== currentMaster {
                dragStartPos.x = event.x
                dragStartPos.y = event.y
                nodeHoverMode = .Dragging
                
                //app?.mmView.mouseTrackWidget = app?.editorRegion?.widget
                app?.mmView.lockFramerate()
                
                // --- Get all nodes of the currently selected
                childsOfSel = []
                
                func getChilds(_ n: Node)
                {
                    if !childsOfSel.contains(n) {
                        
                        childsOfSel.append(n)
                        childsOfSelPos[n.uuid] = float2(n.xPos, n.yPos)
                    }
                    
                    for terminal in n.terminals {
                        
                        if terminal.connector == .Bottom {
                            for conn in terminal.connections {
                                let toTerminal = conn.toTerminal!
                                getChilds(toTerminal.node!)
                            }
                        }
                    }
                }
                getChilds(selectedNode)
            }
        }
    }
    
    func mouseUp(_ event: MMMouseEvent)
    {
        if refList.isActive && refList.rect.contains(event.x, event.y){
            refList.mouseUp(event)
            return
        }
        
        if nodeHoverMode == .OverviewEdit {
            #if os(iOS)
            if overviewIsOn {
                self.overviewButton.clicked!(MMMouseEvent(0,0))
                nodeHoverMode = .None
            } else {
                activateNodeDelegate(hoverNode!)
            }
            return
            #endif
        }
        
        if nodeHoverMode == .MenuOpen {
            hoverNode!.menu!.mouseUp(event)
            nodeHoverMode = .None
            return
        }
        
        if let screen = mmScreen {
            screen.mouseDown = false
        }
        
        if nodeHoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseUp(event)
        }

        if nodeHoverMode == .TerminalConnection && connectTerminal != nil {
            connectTerminals(hoverTerminal!.0, connectTerminal!.0)
            updateNode(hoverTerminal!.0.node!)
            updateNode(connectTerminal!.0.node!)
        }
        
        app?.mmView.mouseTrackWidget = nil
        app?.mmView.unlockFramerate()
        nodeHoverMode = .None
        
        #if os(iOS)
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
        }
        #endif
    }
    
    func mouseMoved(_ event: MMMouseEvent)
    {
        if refList.isActive && refList.mouseIsDown == true && refList.rect.contains(event.x, event.y){
            refList.mouseMoved(event)
            return
        }
        
        /*
        if let dragSource = refList.dragSource {
            
            return
        }*/
        
        if currentMaster == nil { return }
        var scale : Float = currentMaster!.camera!.zoom
        
        if let screen = mmScreen {
            screen.mousePos.x = event.x
            screen.mousePos.y = event.y
        }
        
        let oldNodeHoverMode = nodeHoverMode
        
        // Disengage hover types for the ui items
        if hoverUIItem != nil {
            hoverUIItem!.mouseLeave()
        }
        
        if hoverUITitle != nil {
            hoverUITitle?.titleHover = false
            hoverUITitle = nil
            mmView.update()
        }
        //
        
        if nodeHoverMode == .MenuOpen {
            hoverNode!.menu!.mouseMoved(event)
            return
        }
        
        if nodeHoverMode == .MenuHover {
            if let menu = hoverNode!.menu {
                if !menu.rect.contains(event.x, event.y) {
                    menu.removeState(.Hover)
                    nodeHoverMode = .None
                    mmView.update()
                }
            }
            return
        }
        
        if nodeHoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseMoved(event)
            return
        }
        
        // Adjust scale
        if hoverNode != nil && hoverNode!.behaviorTree != nil {
            scale *= hoverNode!.behaviorTree!.properties["treeScale"]!
        }
        
        // Drag Node
        if nodeHoverMode == .Dragging {            
            for n in childsOfSel {
                if let pos = childsOfSelPos[n.uuid] {
                    n.xPos = pos.x + (event.x - dragStartPos.x) / scale
                    n.yPos = pos.y + (event.y - dragStartPos.y) / scale
                }
            }
            mmView.update()
            return
        }
        
        // Resize Drag Master Node
        if nodeHoverMode == .MasterDragging {
            
            previewSize.x = floor(nodeDragStartPos.x - (event.x - dragStartPos.x))
            previewSize.y = floor(nodeDragStartPos.y + (event.y - dragStartPos.y))
            
            previewSize.x = max(previewSize.x, 260)
            previewSize.y = max(previewSize.y, 80)
            
            previewSize.x = min(previewSize.x, app!.editorRegion!.rect.width - 50)
            previewSize.y = min(previewSize.y, app!.editorRegion!.rect.height - 65)

            currentMaster!.updatePreview(nodeGraph: self)
            mmView.update()
            return
        }
        
        hoverNode = nodeAt(event.x, event.y)
        
        // Resizing the master node ?
        if currentMaster != nil && hoverNode === currentMaster {
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
    
            // Check if menu hover
            if let menu = hoverNode!.menu {
                if menu.rect.contains(event.x, event.y)
                {
                    nodeHoverMode = .MenuHover
                    if !menu.states.contains(.Hover) {
                        menu.addState(.Hover)
                    }
                    menu.mouseMoved(event)
                    mmView.update()
                    return
                }
            }
            
            // Check for terminal
            if let terminalTuple = terminalAt(hoverNode!, event.x, event.y) {
                nodeHoverMode = .Terminal
                hoverTerminal = terminalTuple
                mmView.update()
                return
            }
            
            // Check for top left edit area
            
            if event.x > hoverNode!.rect.x + 8 * scale && event.y > hoverNode!.rect.y + 12 * scale && event.x <= hoverNode!.rect.x + 45 * scale && event.y <= hoverNode!.rect.y + 40 * scale {
                if overviewIsOn || (overviewIsOn == false && hoverNode!.maxDelegate != nil) {
                    nodeHoverMode = .OverviewEdit
                    mmView.update()
                    return
                }
            } else
            if nodeHoverMode == .OverviewEdit
            {
                //print("no")
                mmView.update()
            }
            
            if hoverNode !== currentMaster {
                // --- Look for NodeUI item under the mouse, master has no UI
                let uiItemX = hoverNode!.rect.x + (hoverNode!.rect.width - hoverNode!.uiArea.width*scale) / 2
                var uiItemY = hoverNode!.rect.y + NodeGraph.bodyY * scale
                let uiRect = MMRect()
                let titleWidth : Float = (hoverNode!.uiMaxTitleSize.x + NodeUI.titleSpacing) * scale
                validHoverTarget = nil
                for uiItem in hoverNode!.uiItems {
                    
                    if uiItem.supportsTitleHover {
                        uiRect.x = uiItemX
                        uiRect.y = uiItemY
                        uiRect.width = titleWidth - NodeUI.titleSpacing * scale
                        uiRect.height = uiItem.rect.height * scale
                        
                        if uiRect.contains(event.x, event.y) {
                            uiItem.titleHover = true
                            hoverUITitle = uiItem
                            mmView.update()
                            return
                        }
                    }
                    
                    uiRect.x = uiItemX + titleWidth
                    uiRect.y = uiItemY
                    uiRect.width = uiItem.rect.width * scale - uiItem.titleLabel!.rect.width - NodeUI.titleMargin.width() - NodeUI.titleSpacing
                    uiRect.height = uiItem.rect.height * scale

                    let dropTarget = uiItem as? NodeUIDropTarget
                    
                    if dropTarget != nil {
                        uiRect.width = hoverNode!.uiMaxWidth * scale
                        dropTarget!.hoverState = .None
                    }
                    
                    if uiRect.contains(event.x, event.y) {
                        
                        if refList.dragSource != nil {
                            if dropTarget != nil {
                                if refList.dragSource!.id == dropTarget!.targetID {
                                    dropTarget!.hoverState = .Valid
                                    validHoverTarget = dropTarget
                                } else {
                                    dropTarget!.hoverState = .Invalid
                                }
                            }
                        }
                        
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

            debugInstance.clear()
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
            
            // --- Run nodes when playing
            
            if playNode != nil {
                
                for node in nodes {
                    node.playResult = .Unused
                }
                
                // --- Step the physics in all physics based layers
                for physicsLayer in playPhysicLayers {
                    if physicsLayer.physicsInstance != nil {
                        physics.step(instance: physicsLayer.physicsInstance!)
                    }
                }
                // ---
                
                for exe in playToExecute {
                    let root = exe.behaviorRoot!
                    
                    /*if let runningNode = root.runningNode {
                        _ = runningNode.execute(nodeGraph: self, root: root, parent: exe.behaviorRoot!.rootNode)
                    } else {*/
                        //root.hasRun = []
                        _ = exe.execute(nodeGraph: self, root: root, parent: exe.behaviorRoot!.rootNode)
                    //}
                }
                playNode?.updatePreview(nodeGraph: self)
            }
            
            // --- Draw Nodes

            if let masterNode = currentMaster {

                let toDraw = getNodesOfMaster(for: currentMaster!)
                
                for node in toDraw {
                    drawNode( node, region: region)
                }
                
                // --- Ongoing Node connection attempt ?
                if nodeHoverMode == .TerminalConnection {
                    let scale : Float = currentMaster!.camera!.zoom

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
            
            contentScrollButton.rect.x = 200
            contentScrollButton.rect.y = 4 + 44
            contentScrollButton.draw()
            
            region.layoutH( startX: 200 + contentScrollButton.rect.width + 15, startY: 4 + 44, spacing: 10, widgets: objectsButton, layersButton, scenesButton, gameButton)

            nodesButton.draw()
            objectsButton.draw()
            layersButton.draw()
            scenesButton.draw()
            gameButton.draw()
            
            /*
            overviewButton.rect.x = gameButton.rect.x + gameButton.rect.width + 20
            overviewButton.rect.y = gameButton.rect.y
            overviewButton.isDisabled = contentType == .Game
            overviewButton.draw()*/
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
        var scale : Float = currentMaster!.camera!.zoom

        node.rect.x = region.rect.x + node.xPos * scale + currentMaster!.camera!.xPos
        node.rect.y = region.rect.y + node.yPos * scale + currentMaster!.camera!.yPos
        
        if let behaviorTree = node.behaviorTree {
            let treeScale = behaviorTree.properties["treeScale"]!
            scale *= treeScale
            node.rect.x += (behaviorTree.rect.x + behaviorTree.rect.width / 2 - node.rect.x) * (1.0 - treeScale)
            node.rect.y += (behaviorTree.rect.y + behaviorTree.rect.height / 2 - node.rect.y) * (1.0 - treeScale)
            
            node.rect.width = max(node.minimumSize.x, node.uiArea.width + 50) * scale
            node.rect.height = (node.minimumSize.y + node.uiArea.height) * scale
            
            if behaviorTree.rect.contains(node.rect.x, node.rect.y) {
                return
            }
        } else {
            node.rect.width = max(node.minimumSize.x, node.uiArea.width + 50) * scale
            node.rect.height = (node.minimumSize.y + node.uiArea.height) * scale
        }
        
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
        
        if !overviewIsOn {
            if node.brand == .Behavior {
                node.data.brandColor = mmView.skin.Node.behaviorColor
            } else
            if node.brand == .Property {
                node.data.brandColor = mmView.skin.Node.propertyColor
            } else
            if node.brand == .Function {
                node.data.brandColor = mmView.skin.Node.functionColor
            } else
            if node.brand == .Arithmetic {
                node.data.brandColor = mmView.skin.Node.arithmeticColor
            }
        } else {
            node.data.brandColor = mmView.skin.Node.functionColor
        }

        if playNode != nil && node.playResult != nil {
            if node.playResult! == .Success {
                node.data.selected = 2
            } else
            if node.playResult! == .Failure {
                node.data.selected = 3
            } else if node.playResult! == .Running {
                node.data.selected = 4
            }
        }
        
        node.data.hoverIndex = 0
        node.data.hasIcons1.x = 0

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
            label.drawCentered(x: node.rect.x + 10 * scale, y: node.rect.y + 23 * scale, width: node.rect.width - 50 * scale, height: label.rect.height)
        }
        
        if nodeHoverMode == .OverviewEdit && node === hoverNode {
            if editLabel.scale != 0.3 * scale {
                editLabel.setText("EDIT", scale: 0.3 * scale)
            }
            editLabel.rect.x = node.rect.x + 10 * scale
            editLabel.rect.y = node.rect.y + 20 * scale
            editLabel.draw()
//            editLabel.draw(x: node.rect.x + 10 * scale, y: node.rect.y + 10 * scale, width: node.rect.x + 40 * scale, height: editLabel.rect.height)
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
            
            uiItem.draw(mmView: app!.mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: scale)
            uiItemY += uiItem.rect.height * scale
        }
        
        // --- Preview
        if let texture = node.previewTexture {
            if node.subset == nil {
                app!.mmView.drawTexture.draw(texture, x: node.rect.x + (node.rect.width - 200*scale)/2, y: node.rect.y + NodeGraph.bodyY * scale + node.uiArea.height * scale, zoom: 1/scale)
            }
        } else
        if node.maxDelegate != nil && node.minimumSize == Node.NodeWithPreviewSize {
            let rect : MMRect = MMRect( node.rect.x + (node.rect.width - 200*scale)/2, node.rect.y + NodeGraph.bodyY * scale + node.uiArea.height * scale, 200 * scale, 140 * scale)
            
            node.livePreview(nodeGraph: self, rect: rect)

            // Preview Border
            app!.mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 3, fillColor: float4(repeating: 0), borderColor: float4(0, 0, 0, 1) )
        }
        
        // Draw active UI item
        if nodeHoverMode == .NodeUIMouseLocked && node === hoverNode {
            hoverUIItem!.draw(mmView: app!.mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: scale)
        }
        
        // Node Menu
        
        if node.menu == nil {
            createNodeMenu(node)
        }
        
        node.menu!.rect.x = node.rect.x + node.rect.width - 48 * scale
        node.menu!.rect.y = node.rect.y + 18 * scale
        node.menu!.rect.width = 30 * scale
        node.menu!.rect.height = 28 * scale
        node.menu!.draw()
    }
    
    /// Draw the master node
    func drawMasterNode(_ node: Node, region: MMRegion)
    {
        if contentType == .ObjectsOverview || contentType == .LayersOverview || contentType == .ScenesOverview { return }
        
        previewSize.x = min(previewSize.x, app!.editorRegion!.rect.width - 50)
        previewSize.y = min(previewSize.y, app!.editorRegion!.rect.height - 65)
        
        node.rect.width = previewSize.x + 70
        node.rect.height = previewSize.y + 64 + 25
        
        node.rect.x = region.rect.x + region.rect.width - node.rect.width + 11 + 10
        node.rect.y = region.rect.y - 22
        
        app!.mmView.drawBox.draw( x: node.rect.x, y: node.rect.y, width: node.rect.width, height: node.rect.height, round: 16, borderSize: 8, fillColor: float4(0.118, 0.118, 0.118, 1.000), borderColor: float4(0.173, 0.173, 0.173, 1.000) )
        
        // --- Preview
        
        var textures : [MTLTexture] = []
        
        let x : Float = node.rect.x + 34
        let y : Float = node.rect.y + 34 + 25
        
        if refList.isActive == false {
            // --- Preview
            
            func printBehaviorOnlyText()
            {
                mmView.drawText.drawTextCentered(mmView.openSans, text: "Behavior Only", x: x, y: y, width: previewSize.x, height: previewSize.y, scale: 0.4, color: float4(1,1,1,1))
            }
            
            if let scene = previewNode as? Scene {
                if playNode != nil {
                    textures = scene.outputTextures
                } else {
                    printBehaviorOnlyText()
                }
            } else
            if let game = previewNode as? Game {
                if let scene = game.currentScene {
                    textures = scene.outputTextures
                } else {
                    printBehaviorOnlyText()
                }
            } else
            if let layer = previewNode as? Layer {
                if let texture = layer.previewTexture {
                    if layer.builderInstance != nil {
                        textures.append(texture)
                    }
                }
            } else
            if let object = previewNode as? Object {
                if let texture = object.previewTexture {
                    if object.instance != nil {
                        textures.append(texture)
                    }
                }
            }
            
            for texture in textures {
                app!.mmView.drawTexture.draw(texture, x: x, y: y, zoom: 1)
            }
            
            // Draw Debug
            
            if debugMode != .None {
                let camera = createNodeCamera(node)
                
                debugBuilder.render(width: previewSize.x, height: previewSize.y, instance: debugInstance, camera: camera)
                app!.mmView.drawTexture.draw(debugInstance.texture!, x: x, y: y, zoom: 1)
            }
            
            // Preview Border
            app!.mmView.drawBox.draw( x: x, y: y, width: previewSize.x, height: previewSize.y, round: 0, borderSize: 1, fillColor: float4(repeating: 0), borderColor: float4(0, 0, 0, 1) )
        } else {
            // Visible reference list
            
            refList.rect.x = x
            refList.rect.y = y
            refList.rect.width = previewSize.x
            refList.rect.height = previewSize.y
            
            refList.draw()
        }
            
        
        // If previewing fill in the screen dimensions
        if let screen = mmScreen {
            screen.rect.x = x
            screen.rect.y = y
            screen.rect.width = previewSize.x
            screen.rect.height = previewSize.y
        }
        
        // --- Buttons
        
        editButton.rect.x = node.rect.x + 35
        editButton.rect.y = node.rect.y + 25
        editButton.draw()
        
        playButton.rect.x = editButton.rect.x + editButton.rect.width + 10
        playButton.rect.y = editButton.rect.y
        playButton.draw()
        
        behaviorMenu.rect.x = node.rect.x + node.rect.width - 64
        behaviorMenu.rect.y = node.rect.y + 26
        behaviorMenu.rect.width = 30
        behaviorMenu.rect.height = 28
        behaviorMenu.draw()
        
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
        
        // --- Preview Info Label
        
        previewInfoMenu.rect.x = node.rect.x + node.rect.width - previewInfoMenu.rect.width - 36
        previewInfoMenu.rect.y = node.rect.y + node.rect.height - 28
        previewInfoMenu.draw()
    }
    
    /// Draws the given connection
    func drawConnection(_ conn: Connection)
    {
        var scale : Float = currentMaster!.camera!.zoom
        let terminal = conn.terminal!
        let node = terminal.node!
        
        if let behaviorTree = node.behaviorTree {
            let treeScale = behaviorTree.properties["treeScale"]!
            scale *= treeScale
        } else
        if let behaviorTree = node as? BehaviorTree {
            let treeScale = behaviorTree.properties["treeScale"]!
            scale *= treeScale
        }

        func getPointForConnection(_ conn: Connection) -> (Float, Float)?
        {
            var x : Float = 0
            var y : Float = 0
            let terminal = conn.terminal!
            let node = terminal.node!
            
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
                        x = node.rect.width / 2 - 6 * scale
                        y = 3 * scale + NodeGraph.tRadius * scale
                        
                        break;
                    }
                } else
                if t.connector == .Bottom {
                    if t.uuid == terminal.uuid {
                        x = bottomX + NodeGraph.tRadius * scale - 1 * scale
                        y = node.rect.height - 3 * scale - NodeGraph.tRadius * scale
                        
                        break;
                    }
                    bottomX += NodeGraph.tSpacing * scale + NodeGraph.tDiam * scale
                }
            }
            
            if let behaviorRoot = node.behaviorTree {
                if behaviorRoot.rect.contains(node.rect.x + x, node.rect.y + y) {
                    return nil
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
        
        func drawIt(_ from: (Float,Float), _ to: (Float, Float), _ color: float3)
        {
            //let dist = simd_distance(float2(from.0, from.1), float2(to.0, to.1)) / 4
            
            let cx = from.0// > to.0 ? from.0 - dist : from.0  dist
            let cy = (from.1 + to.1 ) / 2
            
            app!.mmView.drawSpline.draw( sx: from.0, sy: from.1, cx: cx, cy: cy, ex: to.0, ey: to.1, radius: 2 * scale, fillColor : float4(color.x,color.y,color.z,1) )
        }
        
        let fromTuple = getPointForConnection(conn)
        
        let toConnection = getConnectionInTerminal(conn.toTerminal!, uuid: conn.toUUID)
        
        let toTuple = getPointForConnection(toConnection!)

        let color = getColorForTerminal(conn.terminal!)
        
        if fromTuple != nil && toTuple != nil {
            drawIt(fromTuple!, toTuple!, color)
        }
    }
    
    /// Returns the node (if any) at the given mouse coordinates
    func nodeAt(_ x: Float, _ y: Float) -> Node?
    {
        var found : Node? = nil
        if let masterNode = currentMaster {
            for node in nodes {
                if masterNode.subset!.contains(node.uuid) || node === masterNode {
                    if node.rect.contains( x, y ) {
                        // Master always has priority
                        if node === masterNode {
                            return node
                        }
                        // --- If the node is inside its root tree due to scaling skip it
                        if let behaviorTree = node.behaviorTree {
                            if behaviorTree.rect.contains(x, y) {
                                continue
                            }
                        }
                        found = node
                    }
                }
            }
        }
        return found
    }
    
    /// Returns the terminal and the terminal connector at the given mouse position for the given node (if any)
    func terminalAt(_ node: Node, _ x: Float, _ y: Float) -> (Terminal, Terminal.Connector, Float, Float)?
    {
        var scale : Float = currentMaster!.camera!.zoom

        if let behaviorTree = node.behaviorTree {
            let treeScale = behaviorTree.properties["treeScale"]!
            scale *= treeScale
        }
        
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
        
        updateNode(terminal.node!)
        updateNode(toTerminal.node!)
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
                    color = float3(0.620, 0.506, 0.165)
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
                    trees.append(treeNode)
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
    
    /// Gets all nodes for the given master node
    func getNodesOfMaster(for masterNode:Node) -> [Node]
    {
        if masterNode.subset == nil { return [] }
        var nodeList : [Node] = []
        
        for node in nodes {
            if masterNode.subset!.contains(node.uuid) {
                nodeList.append(node)
            }
        }
        
        return nodeList
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
                if let object = node as? Object {
                    if object.uuid == currentObjectUUID {
                        index = items.count
                        currentFound = true
                        setCurrentMaster(node: node)
                    }
                    items.append(node.name)
                    currentContent.append(node)
                }
            } else
            if type == .Layers {
                if let layer = node as? Layer {
                    if layer.uuid == currentLayerUUID {
                        index = items.count
                        currentFound = true
                        setCurrentMaster(node: node)
                    }
                    items.append(node.name)
                    currentContent.append(node)
                }
            } else
            if type == .Scenes {
                if let scene = node as? Scene {
                    if scene.uuid == currentSceneUUID {
                        index = items.count
                        currentFound = true
                        setCurrentMaster(node: node)
                    }
                    items.append(node.name)
                    currentContent.append(node)
                }
            } else
            if type == .Game {
                if let game = node as? Game {
                    if game.uuid == currentLayerUUID {
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
            } else {
                currentMaster = nil
            }
        }
        contentScrollButton.setItems(items, fixedWidth: 220)
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
        
        // Update the nodes for the new master
        if currentMaster != nil && app != nil {
            updateMasterNodes(currentMaster!)
            if currentMaster!.camera == nil {
                currentMaster!.camera = Camera()
            }
            currentMaster!.updatePreview(nodeGraph: self)
            
            // --- Update the previewInfoMenu
            
            func getPreviewClassText(_ node: Node) -> String
            {
                return "Preview: " + node.name + " (" + node.type + (node === currentMaster ? " - Self)" : ")")
            }
            
            previewInfoMenu.setText(getPreviewClassText(currentMaster!), 0.3)
            
            var items : [MMMenuItem] = []
            var selfItem = MMMenuItem( text: getPreviewClassText(currentMaster!), cb: {} )
            selfItem.cb = {
                self.stopPreview()
                self.refList.isActive = false
                if let node = selfItem.custom! as? Node {
                    self.previewInfoMenu.setText(getPreviewClassText(node), 0.3)
                    self.previewNode = node
                    self.mmView.update()
                }
            }
            selfItem.custom = currentMaster!
            items.append(selfItem)
            
            let occurences = getOccurencesOf(currentMaster!)
            for node in occurences {
                var item = MMMenuItem( text: getPreviewClassText(node), cb: {} )
                item.cb = {
                    self.stopPreview()
                    self.refList.isActive = false
                    if let node = item.custom! as? Node {
                        self.previewInfoMenu.setText(getPreviewClassText(node), 0.3)
                        node.updatePreview(nodeGraph: self)
                        self.previewNode = node
                        self.mmView.update()
                    }
                }
                item.custom = node
                items.append(item)
            }
            // Animations
            var animationsItem = MMMenuItem( text: "Animations", cb: {} )
            animationsItem.cb = {
                self.stopPreview()
                self.refList.isActive = true
                self.refList.createAnimationList()
                self.previewInfoMenu.setText("Animations", 0.3)
            }
            items.append(animationsItem)
            
            // Behavior Trees
            var behaviorTreesItem = MMMenuItem( text: "Behavior Trees", cb: {} )
            behaviorTreesItem.cb = {
                self.stopPreview()
                self.refList.isActive = true
                self.refList.createBehaviorTreesList()
                self.previewInfoMenu.setText("Behavior Trees", 0.3)
            }
            items.append(behaviorTreesItem)
            
            // Layer Areas
            var areasItem = MMMenuItem( text: "Layer Areas", cb: {} )
            areasItem.cb = {
                self.stopPreview()
                self.refList.isActive = true
                self.refList.createLayerAreaList()
                self.previewInfoMenu.setText("Layer Areas", 0.3)
            }
            items.append(areasItem)
            
            // Object Instances
            var instanceItem = MMMenuItem( text: "Object Instances", cb: {} )
            instanceItem.cb = {
                self.stopPreview()
                self.refList.isActive = true
                self.refList.createInstanceList()
                self.previewInfoMenu.setText("Object Instances", 0.3)
            }
            items.append(instanceItem)
            
            // Variables
            var variablesItem = MMMenuItem( text: "Variables", cb: {} )
            variablesItem.cb = {
                self.stopPreview()
                self.refList.isActive = true
                self.refList.createVariableList()
                self.previewInfoMenu.setText("Variables", 0.3)
            }
            items.append(variablesItem)

            previewInfoMenu.setItems(items)
            previewNode = node
            if refList != nil {
                refList.update()
            }
        }
    }
    
    /// Sets the overview master node
    func setOverviewMaster()
    {
        overviewMaster.subset = []
        setCurrentNode(currentMaster != nil ? currentMaster : nil)
            
        if contentType == .ObjectsOverview {
            for node in nodes {
                if let object = node as? Object {
                    overviewMaster.subset!.append(node.uuid)
                    if currentObjectUUID == object.uuid {
                        setCurrentNode(node)
                    }
                }
            }
            overviewMaster.camera = objectsOverCam
        } else
        if contentType == .LayersOverview {
            for node in nodes {
                if let layer = node as? Layer {
                    overviewMaster.subset!.append(node.uuid)
                    if currentLayerUUID == layer.uuid {
                        setCurrentNode(node)
                    }
                }
            }
            overviewMaster.camera = layersOverCam
        } else
        if contentType == .ScenesOverview {
            for node in nodes {
                if let scene = node as? Scene {
                    overviewMaster.subset!.append(node.uuid)
                    if currentSceneUUID == scene.uuid {
                        setCurrentNode(node)
                    }
                }
            }
            overviewMaster.camera = scenesOverCam
        }
        
        currentMaster = overviewMaster
        nodeList!.switchTo(NodeListItem.DisplayType(rawValue: contentType.rawValue+1)!)
    }
    
    /// Hard updates the given node
    func updateNode(_ node: Node)
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
        
        /// Recursively goes up the tree to find the root
        func getRootNode(_ node: Node) -> Node?
        {
            var rc : Node? = nil
            
            for terminal in node.terminals {
                
                if terminal.connector == .Top && terminal.connections.count > 0 {
                    if let destTerminal = terminal.connections[0].toTerminal {
                        rc = destTerminal.node!
                        let behaviorTree = rc as? BehaviorTree
                        if behaviorTree == nil {
                            rc = getRootNode(destTerminal.node!)
                        }
                    }
                }
            }
            
            return rc
        }
        
        node.nodeGraph = self
        node.behaviorTree = nil
        for terminal in node.terminals {
            for conn in terminal.connections {
                conn.toTerminal = getTerminalOfUUID(conn.toTerminalUUID)
            }
            
            // Go up the tree to see if it is connected to a behavior tree and if yes link it
            if terminal.connector == .Top {
                let rootNode = getRootNode(node)
                if let behaviorTree = rootNode as? BehaviorTree {
                    node.behaviorTree = behaviorTree
                }
            }
        }

        // Update the UI and special role items
        node.setupUI(mmView: mmView)
        
        // Init the uiConnectors
        for conn in node.uiConnections {
            conn.nodeGraph = self
        }
        
        // Validates a given UINodeConnection
        func validateConn(_ conn: UINodeConnection)
        {
            if conn.masterNode == nil || conn.target == nil {
                conn.connectedMaster = nil
                conn.connectedTo = nil
                conn.masterNode = nil
                conn.target = nil
                conn.targetName = nil
            }
        }
        
        for item in node.uiItems {
            
            // .ObjectInstanceTarget Drop Target
            if item.role == .ObjectInstanceTarget {
                if let target = item as? NodeUIObjectInstanceTarget {
                    let conn = target.uiConnection!
                    
                    if conn.connectedMaster != nil {
                        conn.masterNode = getNodeForUUID(conn.connectedMaster!)
                    }
                    
                    if conn.connectedMaster != nil && conn.connectedTo != nil {
                        if let layer = conn.masterNode as? Layer {
                            for inst in layer.objectInstances {
                                if inst.uuid == conn.connectedTo {
                                    conn.target = inst
                                    conn.targetName = inst.name
                                    break
                                }
                            }
                        } else {
                            conn.masterNode = nil
                        }
                    }
                    validateConn(conn)
                }
                node.computeUIArea(mmView: mmView)
            }
            
            // Fill up an master picker with self + all global masters
            if item.role == .MasterPicker {
                
                if let master = getMasterForNode(node) /* as? Object*/ {
                    
                    if let picker = item as? NodeUIMasterPicker {
                        
                        let conn = picker.uiConnection
                        let type = conn.connectionType
                        
                        if type != .ObjectInstance && type != .LayerArea {
                            if let _ = master as? Object {
                                picker.items = ["Self"]
                                picker.uuids = [master.uuid]
                            }
                        } else
                        if type == .LayerArea {
                            if let _ = master as? Layer {
                                picker.items = ["Self"]
                                picker.uuids = [master.uuid]
                            }
                        }
                        
                        if type == .Object || type == .Animation {
                            // Animation: Only pick other Objects as Layers etc dont have animations
                            for n in nodes {
                                if n.subset != nil && n.uuid != master.uuid && (n as? Object) != nil {
                                    picker.items.append(n.name)
                                    picker.uuids.append(n.uuid)
                                }
                            }
                        } else
                        if type == .ObjectInstance {
                            // ObjectInstance: Only pick object instances in layers
                            for n in nodes {
                                if let layer = n as? Layer {
                                    for inst in layer.objectInstances {
                                        picker.items.append(layer.name + ": " + inst.name)
                                        picker.uuids.append(inst.uuid)
                                    }
                                }
                            }
                        } else
                        if type == .LayerArea {
                            // LayerArea: Only pick layers
                            for n in nodes {
                                if let layer = n as? Layer {
                                    if n.uuid != master.uuid {
                                        picker.items.append(layer.name)
                                        picker.uuids.append(layer.uuid)
                                    }
                                }
                            }
                        } else
                        if type == .Scene {
                            // Scene: Only pick scenes ...
                            for n in nodes {
                                if let scene = n as? Scene {
                                    if n.uuid != master.uuid {
                                        picker.items.append(scene.name)
                                        picker.uuids.append(scene.uuid)
                                    }
                                }
                            }
                        } else
                        if type == .FloatVariable {
                            // Value Variable. Pick every master which has a value variable
                            for n in nodes {
                                if n.subset != nil && n.uuid != master.uuid {
                                    let subs = getNodesOfMaster(for: n)
                                    for s in subs {
                                        if s.type == "Float Variable" {
                                            picker.items.append(n.name)
                                            picker.uuids.append(n.uuid)
                                            break
                                        }
                                    }
                                }
                            }
                        } else
                        if type == .DirectionVariable {
                            // Direction Variable. Pick every master which has a direction variable
                            for n in nodes {
                                if n.subset != nil && n.uuid != master.uuid {
                                    let subs = getNodesOfMaster(for: n)
                                    for s in subs {
                                        if s.type == "Direction Variable" {
                                            picker.items.append(n.name)
                                            picker.uuids.append(n.uuid)
                                            break
                                        }
                                    }
                                }
                            }
                        }
                        
                        if type != .ObjectInstance {
                            // Assign masterNode and picker index
                            if conn.connectedMaster != nil {
                                // --- Find the connection
                                var found : Bool = false
                                for (index, uuid) in picker.uuids.enumerated() {
                                    if uuid == conn.connectedMaster {
                                        picker.index = Float(index)
                                        conn.masterNode = getNodeForUUID(uuid)
                                        found = true
                                        break
                                    }
                                }
                                if !found {
                                    // If not found set the connectedMaster to nil
                                    conn.connectedMaster = nil
                                    conn.masterNode = nil
                                }
                            }
                            
                            if conn.connectedMaster == nil && picker.uuids.count > 0 {
                                // Not connected, connect to first element(self)
                                
                                let firstListNode = getNodeForUUID(picker.uuids[0])
                                if firstListNode != nil {
                                    if type == .LayerArea && (firstListNode as? Layer) != nil {
                                        conn.connectedMaster = picker.uuids[0]
                                        conn.masterNode = firstListNode
                                        picker.index = 0
                                    } else
                                    if type != .LayerArea && (firstListNode as? Object) != nil {
                                        conn.connectedMaster = picker.uuids[0]
                                        conn.masterNode = firstListNode
                                        picker.index = 0
                                    } else
                                    if type == .Scene && (firstListNode as? Scene) != nil {
                                        conn.connectedMaster = picker.uuids[0]
                                        conn.masterNode = firstListNode
                                        picker.index = 0
                                    }
                                }
                            }
                        } else
                        if type == .ObjectInstance
                        {
                            // For object instances only assign picker index as instance is created live during execution
                            conn.masterNode = nil
                            for (index, uuid) in picker.uuids.enumerated() {
                                if uuid == conn.connectedMaster {
                                    picker.index = Float(index)
                                    break
                                }
                            }
                        }
                        node.computeUIArea(mmView: mmView)
                    }
                }
            }
            
            // .AnimationTarget Drop Target
            if item.role == .AnimationTarget {
                if let target = item as? NodeUIAnimationTarget {
                    let conn = target.uiConnection!
                    
                    var animInstance : ObjectInstance? = nil
                    
                    if conn.connectedMaster != nil {
                        for node in nodes {
                            if let layer = node as? Layer {
                                for inst in layer.objectInstances {
                                    if inst.uuid == conn.connectedMaster {
                                        animInstance = inst
                                        conn.masterNode = layer
                                        break
                                    }
                                }
                            }
                        }
                    }
                    
                    if animInstance != nil && conn.connectedTo != nil {
                        conn.target = animInstance!
                        conn.targetName = ""
                        if let object = getNodeForUUID(animInstance!.objectUUID) as? Object {
                            for seq in object.sequences {
                                if seq.uuid == conn.connectedTo {
                                    conn.targetName = seq.name
                                    break
                                }
                            }
                        }
                        if conn.targetName == "" {
                            conn.masterNode = nil
                        }
                    } else {
                        conn.masterNode = nil
                    }
                    validateConn(conn)
                }
                node.computeUIArea(mmView: mmView)
            }
            
            // Animation picker, show the animations of the selected object
            if item.role == .AnimationPicker {
                if let picker = item as? NodeUIAnimationPicker {
                    
                    let conn = picker.uiConnection
                    let object = conn.masterNode as! Object
                    
                    picker.items = []
                    picker.uuids = []
                    
                    for seq in object.sequences {
                        picker.items.append(seq.name)
                        picker.uuids.append(seq.uuid)
                    }
                    
                    if conn.connectedTo != nil {
                        // --- Find the connection
                        var found : Bool = false
                        for (index, seq) in object.sequences.enumerated() {
                            if seq.uuid == conn.connectedTo {
                                picker.index = Float(index)
                                conn.target = seq
                                found = true
                                break
                            }
                        }
                        if !found {
                            // If not found set the connection to nil
                            conn.connectedTo = nil
                            conn.target = nil
                        }
                    }
                    
                    if conn.connectedTo == nil && object.sequences.count > 0 {
                        // Not connected, connect to first element(self)
                        conn.connectedTo = object.sequences[0].uuid
                        conn.target = object.sequences[0]
                        picker.index = 0
                    }
                    
                    node.computeUIArea(mmView: mmView)
                }
            }
            
            // .BehaviorTreeTarget Drop Target
            if item.role == .BehaviorTreeTarget {
                if let target = item as? NodeUIBehaviorTreeTarget {
                    let conn = target.uiConnection!
                    
                    if conn.connectedMaster != nil {
                        conn.masterNode = getNodeForUUID(conn.connectedMaster!)
                    }
                    if conn.connectedTo != nil {
                        if let target = getNodeForUUID(conn.connectedTo!) {
                            conn.target = target
                            conn.targetName = target.name
                        }
                    }
                    validateConn(conn)
                }
                node.computeUIArea(mmView: mmView)
            }
            
            // .ValueVariableTarget Drop Target
            if item.role == .FloatVariableTarget {
                if let target = item as? NodeUIFloatVariableTarget {
                    let conn = target.uiConnection!
                    
                    if conn.connectedMaster != nil {
                        conn.masterNode = getNodeForUUID(conn.connectedMaster!)
                    }
                    if conn.connectedTo != nil {
                        if let target = getNodeForUUID(conn.connectedTo!) {
                            conn.target = target
                            conn.targetName = target.name
                        }
                    }
                    validateConn(conn)
                }
                node.computeUIArea(mmView: mmView)
            }
            
            // ValueVariable picker, show the value variables of the master
            if item.role == .FloatVariablePicker {
                if let picker = item as? NodeUIFloatVariablePicker {
                    
                    let conn = picker.uiConnection
                    //let object = conn.masterNode as! Object
                    
                    picker.items = []
                    picker.uuids = []
                    
                    conn.target = nil
                    let subs = getNodesOfMaster(for: conn.masterNode!)
                    var index : Int = 0
                    var first : Node? = nil
                    for s in subs {
                        if s.type == "Float Variable" {
                            if first == nil {
                                first = s
                            }
                            picker.items.append(s.name)
                            picker.uuids.append(s.uuid)
                            if conn.connectedTo == s.uuid {
                                conn.target = s
                                picker.index = Float(index)
                            }
                            index += 1
                        }
                    }
                    
                    if conn.target == nil && picker.items.count > 0 {
                        // Not connected, connect to first node
                        conn.connectedTo = first?.uuid
                        conn.target = first
                        picker.index = 0
                    } else
                    if conn.target == nil {
                        conn.connectedTo = nil
                    }
                    
                    node.computeUIArea(mmView: mmView)
                }
            }
            
            // .PositionVariableTarget Drop Target
            if item.role == .Float2VariableTarget {
                if let target = item as? NodeUIFloat2VariableTarget {
                    let conn = target.uiConnection!

                    if conn.connectedMaster != nil {
                        conn.masterNode = getNodeForUUID(conn.connectedMaster!)
                    }
                    if conn.connectedTo != nil {
                        if let target = getNodeForUUID(conn.connectedTo!) {
                            conn.target = target
                            conn.targetName = target.name
                        }
                    }
                    validateConn(conn)
                }
                node.computeUIArea(mmView: mmView)
            }
            
            // .DirectionVariableTarget Drop Target
            if item.role == .DirectionVariableTarget {
                if let target = item as? NodeUIDirectionVariableTarget {
                    let conn = target.uiConnection!
                    
                    if conn.connectedMaster != nil {
                        conn.masterNode = getNodeForUUID(conn.connectedMaster!)
                    }
                    if conn.connectedTo != nil {
                        if let target = getNodeForUUID(conn.connectedTo!) {
                            conn.target = target
                            conn.targetName = target.name
                        }
                    }
                    validateConn(conn)
                }
                node.computeUIArea(mmView: mmView)
            }
            
            // DirectionVariable picker, show the direction variables of the master
            if item.role == .DirectionVariablePicker {
                if let picker = item as? NodeUIDirectionVariablePicker {
                    
                    let conn = picker.uiConnection
                    //let object = conn.masterNode as! Object
                    
                    picker.items = []
                    picker.uuids = []
                    
                    conn.target = nil
                    let subs = getNodesOfMaster(for: conn.masterNode!)
                    var index : Int = 0
                    var first : Node? = nil
                    for s in subs {
                        if s.type == "Direction Variable" {
                            if first == nil {
                                first = s
                            }
                            picker.items.append(s.name)
                            picker.uuids.append(s.uuid)
                            if conn.connectedTo == s.uuid {
                                conn.target = s
                                picker.index = Float(index)
                            }
                            index += 1
                        }
                    }
                    
                    if conn.target == nil && picker.items.count > 0 {
                        // Not connected, connect to first node
                        conn.connectedTo = first?.uuid
                        conn.target = first
                        picker.index = 0
                    } else
                    if conn.target == nil {
                        conn.connectedTo = nil
                    }
                    
                    node.computeUIArea(mmView: mmView)
                }
            }
            
            // .LayerAreaTarget Drop Target
            if item.role == .LayerAreaTarget {
                if let target = item as? NodeUILayerAreaTarget {
                    let conn = target.uiConnection!
                    
                    if conn.connectedMaster != nil {
                        conn.masterNode = getNodeForUUID(conn.connectedMaster!)
                    }
                    if conn.connectedTo != nil {
                        if let target = getNodeForUUID(conn.connectedTo!) {
                            conn.target = target
                            conn.targetName = target.name
                        }
                    }
                    validateConn(conn)
                }
                node.computeUIArea(mmView: mmView)
            }
            
            // LayerArea picker, show the layer areas of the master
            if item.role == .LayerAreaPicker {
                if let picker = item as? NodeUILayerAreaPicker {
                    let conn = picker.uiConnection
                    if conn.masterNode != nil {
                        let layer = conn.masterNode as! Layer
                        
                        picker.items = []
                        picker.uuids = []
                        
                        conn.target = nil
                        let subs = getNodesOfMaster(for: layer)
                        var index : Int = 0
                        var first : Node? = nil
                        for s in subs {
                            if s.type == "Layer Area" {
                                if first == nil {
                                    first = s
                                }
                                picker.items.append(s.name)
                                picker.uuids.append(s.uuid)
                                if conn.connectedTo == s.uuid {
                                    conn.target = s
                                    picker.index = Float(index)
                                }
                                index += 1
                            }
                        }
                        
                        if conn.target == nil && picker.items.count > 0 {
                            // Not connected, connect to first node
                            conn.connectedTo = first?.uuid
                            conn.target = first
                            picker.index = 0
                        } else
                        if conn.target == nil {
                            conn.connectedTo = nil
                        }
                        
                        node.computeUIArea(mmView: mmView)
                    }
                }
            }
            
        }
    }
    
    /// Hard updates all nodes
    func updateNodes()
    {
        for node in nodes {
            updateNode(node)
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
                        updateNode(node)
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
        
        // Check if this node is the gizmo UI node
        if masterNode == nil && app?.gizmo.gizmoNode.uuid == clientNode.uuid {
            return currentMaster
        }
        
        return masterNode
    }
    
    /// Get the node for the given uuid
    func getNodeForUUID(_ uuid: UUID) -> Node?
    {
        for node in nodes {
            if node.uuid == uuid {
                return node
            }
        }
        
        return nil
    }
    
    /// Returns the instances of the given object
    func getInstancesOf(_ uuid: UUID) -> [Object]
    {
        var instances : [Object] = []
        
        for node in nodes {
            if let layer = node as? Layer {
                for inst in layer.objectInstances {
                    if inst.objectUUID == uuid {
                        if inst.instance != nil {
                            instances.append(inst.instance!)
                        }
                    }
                }
            }
        }
        
        return instances
    }
    
    /// Return the instance with the given UUID
    func getInstance(_ uuid: UUID) -> Object?
    {
        for node in nodes {
            if let layer = node as? Layer {
                for inst in layer.objectInstances {
                    if inst.uuid == uuid {
                        return inst.instance
                    }
                }
            }
        }
        
        return nil
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
            if let index = master.subset!.firstIndex(where: { $0 == node.uuid }) {
                master.subset!.remove(at: index)
            }
        }
        // Remove from nodes
        nodes.remove(at: nodes.firstIndex(where: { $0.uuid == node.uuid })!)
        refList.update()
        mmView.update()
    }
    
    func activateNodeDelegate(_ node: Node)
    {
        maximizedNode = node
        deactivate()
        maximizedNode!.maxDelegate!.activate(app!)
        nodeHoverMode = .None
        app?.mmView.mouseTrackWidget = nil
    }
    
    func createNodeMenu(_ node: Node)
    {
        var items : [MMMenuItem] = []
        
        if node.maxDelegate != nil {
            let editNodeItem =  MMMenuItem( text: "Edit " + node.type, cb: {
                
                if node.type == "Object" || node.type == "Layer" || node.type == "Scene" {
                    self.overviewButton.clicked!(MMMouseEvent(0,0))
                    //self.overviewButton.removeState(.Checked)
                    //self.overviewIsOn = false
                } else {
                    self.activateNodeDelegate(node)
                }
            } )
            items.append(editNodeItem)
        }
        
        if node.helpUrl != nil {
            let helpNodeItem =  MMMenuItem( text: "Help for " + node.type, cb: {
                showHelp(node.helpUrl)
            } )
            items.append(helpNodeItem)
        }
        
        /*
        let duplicateNodeItem =  MMMenuItem( text: "Duplicate", cb: {
            if node.type == "Object" {
                
                let encodedData = try? JSONEncoder().encode(node)
                if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
                {
                    print( encodedObjectJsonString)
                }
            }
        } )
        items.append(duplicateNodeItem)
        */

        let renameNodeItem =  MMMenuItem( text: "Rename", cb: {
            getStringDialog(view: self.mmView, title: "Rename Node", message: "Node name", defaultValue: node.name, cb: { (name) -> Void in
                node.name = name
                node.label = nil
                if !self.overviewIsOn {
                    self.updateMasterNodes(self.currentMaster!)
                } else {
                    if self.contentType == .ObjectsOverview {
                        self.updateContent(.Objects)
                        self.setOverviewMaster()
                    } else
                    if self.contentType == .LayersOverview {
                        self.updateContent(.Layers)
                        self.setOverviewMaster()
                    } else
                    if self.contentType == .ScenesOverview {
                        self.updateContent(.Scenes)
                        self.setOverviewMaster()
                    }
                }
                self.setCurrentNode(node)
                self.mmView.update()
            } )
        } )
        items.append(renameNodeItem)
            
        let deleteNodeItem =  MMMenuItem( text: "Delete", cb: {
            self.deleteNode(node)
            self.nodeHoverMode = .None
            self.hoverNode = nil
            self.updateNodes()
        } )
        items.append(deleteNodeItem)
        
        node.menu = MMMenuWidget(mmView, items: items)
    }
    
    /// Returns the platform size (if any) for the current platform
    func getPlatformSize() -> float2
    {
        var size : float2 = float2(800,600)
        
        #if os(OSX)
        if let osx = getNodeOfType("Platform OSX") as? GamePlatformOSX {
            size = osx.getScreenSize()
        } else {
            size = float2(mmView.renderer.cWidth, mmView.renderer.cHeight)
        }
        #elseif os(iOS)
        if let ipad = getNodeOfType("Platform IPAD") as? GamePlatformIPAD {
            size = ipad.getScreenSize()
        } else {
            size = float2(mmView.renderer.cWidth, mmView.renderer.cHeight)
        }
        #endif
        return size
    }
    
    /// Returns all nodes which contain a reference of this node (objects in layers, layers in scenes).
    func getOccurencesOf(_ node: Node) -> [Node]
    {
        var layers : [Node] = []
        
        // Find the occurenes of an object in the layers
        if node.type == "Object" {
            for n in nodes {
                if let layer = n as? Layer {
                    for inst in layer.objectInstances {
                        if inst.objectUUID == node.uuid {
                            if !layers.contains(layer) {
                                layers.append(layer)
                            }
                        }
                    }
                }
            }
        } else
        if node.type == "Layer" {
            layers.append(node)
        }
        
        var scenes : [Node] = []

        // Find the occurenes of the layers in the scenes
        for layer in layers {
            for n in nodes {
                if let scene = n as? Scene {
                    for uuid in scene.layers {
                        if uuid == layer.uuid {
                            if !scenes.contains(scene) {
                                scenes.append(scene)
                            }
                        }
                    }
                }
            }
        }

        return layers + scenes
    }
    
    /// Accept a drag from the reference list to a NodeUIDropTarget
    func acceptDragSource(_ dragSource: MMDragSource)
    {
        let uiTarget = validHoverTarget!
        if let source = dragSource as? ReferenceListDrag {

            let refItem = source.refItem!
            
            func targetDropped(_ oldMaster: UUID?,_ oldConnection: UUID?,_ newMaster: UUID?,_ newConnection: UUID?)
            {
                mmView.undoManager!.registerUndo(withTarget: self) { target in
                    
                    uiTarget.uiConnection.connectedMaster = newMaster
                    uiTarget.uiConnection.connectedTo = newConnection
                    
                    self.updateNode(uiTarget.node)
                    targetDropped(newMaster, newConnection, oldMaster, oldConnection)
                }
            }
            
            targetDropped(refItem.classUUID, refItem.uuid, uiTarget.uiConnection.connectedMaster, uiTarget.uiConnection.connectedTo)
            
            uiTarget.uiConnection.connectedMaster = refItem.classUUID
            uiTarget.uiConnection.connectedTo = refItem.uuid
            
            updateNode(uiTarget.node)
            uiTarget.hoverState = .None
        }
    }
}
