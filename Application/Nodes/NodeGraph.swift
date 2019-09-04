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
        case None, Physics, SceneAreas
    }
    
    enum LeftRegionMode
    {
        case Closed, Nodes
    }
    
    enum NodeHoverMode : Float {
        case None, Dragging, Terminal, TerminalConnection, NodeUI, NodeUIMouseLocked, Preview, MasterDrag, MasterDragging, MasterNode, MenuHover, MenuOpen, OverviewEdit, SideSlider
    }
    
    enum ContentType : Int {
        case Objects, Scenes, Game, ObjectsOverview, ScenesOverview
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
    var playBindings    : [Terminal] = []

    var currentMaster   : Node? = nil
    var currentMasterUUID: UUID? = nil
    
    var currentObjectUUID: UUID? = nil
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
    
    var contentType     : ContentType = .Objects
    var overviewMaster  : Node = Node()
    var overviewIsOn    : Bool = false
    
    var objectsOverCam  : Camera? = Camera()
    var scenesOverCam   : Camera? = Camera()

    //var typeScrollButton: MMScrollButton!
    var contentScrollButton: MMScrollButton!
    
    // Current available class nodes (selectable master nodes)
    var currentContent  : [Node] = []
    
    var objectsButton   : MMSwitchButtonWidget!
    var scenesButton    : MMSwitchButtonWidget!
    var gameButton      : MMButtonWidget!

    var editButton      : MMButtonWidget!
    var playButton      : MMButtonWidget!

    var sideSliderButton: MMSideSliderWidget!
    var nodeList        : NodeList?
    var animating       : Bool = false
    var leftRegionMode  : LeftRegionMode = .Nodes
    
    var builder         : Builder!
    var physics         : Physics!
    var timeline        : MMTimeline!
    var diskBuilder     : DiskBuilder!
    var debugBuilder    : DebugBuilder!
    var debugInstance   : DebugBuilderInstance!
    
    var sceneRenderer   : SceneRenderer!

    var behaviorMenu    : MMMenuWidget!
    var previewInfoMenu : MMMenuWidget!

    var previewSize     : float2 = float2(340, 200)
    
    var refList         : ReferenceList!
    var validHoverTarget: NodeUIDropTarget? = nil
    
    // --- Icons
    
    var executeIcon     : MTLTexture?
    
    // --- Static Node Skin
    
    static var tOffY    : Float = 68 // Vertical Offset of the first terminal
    static var tLeftY   : Float = 1.5 // Offset from the left for .Left Terminals
    static var tRightY  : Float = 20 // Offset from the right for .Right Terminals
    static var tSpacing : Float = 25 // Spacing between terminals

    static var tRadius  : Float = 7 // Radius of terminals
    static var tDiam    : Float = 14 // Diameter of terminals
    
    static var bodyY    : Float = 50 // Start of the y position of the body

    // ---
    
    private enum CodingKeys: String, CodingKey {
        case nodes
        case currentMasterUUID
        case overviewIsOn
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
        if let overview = try container.decodeIfPresent(Bool.self, forKey: .overviewIsOn) {
            overviewIsOn = overview
        }
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
        try container.encode(overviewIsOn, forKey: .overviewIsOn)
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
        sceneRenderer = SceneRenderer(mmView)

        let renderer = app.mmView.renderer!
        
        var function = renderer.defaultLibrary.makeFunction( name: "drawNode" )
        drawNodeState = renderer.createNewPipelineState( function! )
        function = renderer.defaultLibrary.makeFunction( name: "nodeGridPattern" )
        drawPatternState = renderer.createNewPipelineState( function! )
        
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
                if self.contentType == .ScenesOverview {
                    self.currentSceneUUID = node.uuid
                }
            }
        }
        
        func adjustVisibleButtons() {
            mmView.deregisterWidget(editButton)
            mmView.deregisterWidget(playButton)
            mmView.deregisterWidget(behaviorMenu)
            mmView.deregisterWidget(previewInfoMenu)
            
            let isGame : Bool = currentMaster != nil && currentMaster!.type == "Game"
            editButton.isDisabled = isGame

            if !overviewIsOn {
                mmView.widgets.insert(editButton, at: 0)
                mmView.widgets.insert(playButton, at: 0)
                mmView.widgets.insert(behaviorMenu, at: 0)
                mmView.widgets.insert(previewInfoMenu, at: 0)
            }
        }
        
        objectsButton = MMSwitchButtonWidget(app.mmView, text: "Object")
        objectsButton.textYOffset = 1.0
        objectsButton.addState(.Checked)
        objectsButton.clicked = { (event) -> Void in
            self.stopPreview()
            self.editButton.setText("Shape...")
            self.editButton.isDisabled = false

            self.objectsButton.addState(.Checked)
            self.scenesButton.removeState(.Checked)
            self.gameButton.removeState(.Checked)

            if self.objectsButton.state == .Several {
                self.contentType = .ObjectsOverview
                self.updateContent(self.contentType)
                self.overviewIsOn = true
            } else {
                self.contentType = .Objects
                self.updateContent(self.contentType)
                self.overviewIsOn = false
            }
            
            //if self.currentContent.count == 0 || event.x != 0 {
            //    self.overviewButton.addState(.Checked)
            //    self.overviewIsOn = true
            //}
            
            if self.overviewIsOn == false {
                if self.currentMaster != nil && self.currentContent.count > 0 {
                    self.currentMaster!.updatePreview(nodeGraph: self, hard: false)
                }
                self.nodeList!.switchTo(.Object)
            } else {
                self.contentType = .ObjectsOverview
                self.setOverviewMaster()
            }
            adjustVisibleButtons()
        }
        
        scenesButton = MMSwitchButtonWidget(app.mmView, text: "Scene", dotSize: .Large)
        scenesButton.rect.width = objectsButton.rect.width
        scenesButton.textYOffset = -1.5
        scenesButton.clicked = { (event) -> Void in
            self.stopPreview()
            self.editButton.setText("Arrange...")
            self.editButton.isDisabled = false

            self.objectsButton.removeState(.Checked)
            self.scenesButton.addState(.Checked)
            self.gameButton.removeState(.Checked)
            
            if self.scenesButton.state == .Several {
                self.contentType = .ScenesOverview
                self.updateContent(self.contentType)
                self.overviewIsOn = true
            } else {
                self.contentType = .Scenes
                self.updateContent(self.contentType)
                self.overviewIsOn = false
            }
            
            if self.overviewIsOn == false {
                if self.currentMaster != nil && self.currentContent.count > 0 {
                    self.currentMaster!.updatePreview(nodeGraph: self, hard: false)
                }
                self.nodeList!.switchTo(.Scene)
            } else {
                self.contentType = .ScenesOverview
                self.setOverviewMaster()
            }
            adjustVisibleButtons()
        }
        
        gameButton = MMButtonWidget(app.mmView, text: "Game" )
        gameButton.rect.width += 20
        gameButton.textYOffset = -1.5
        gameButton.clicked = { (event) -> Void in
            self.stopPreview()
            self.editButton.setText("Arrange...")
            self.editButton.isDisabled = true

            self.objectsButton.removeState(.Checked)
            self.scenesButton.removeState(.Checked)
            self.gameButton.addState(.Checked)
            self.overviewIsOn = false
            
            self.contentType = .Game
            self.updateContent(self.contentType)
            if self.currentMaster != nil && self.currentContent.count > 0 {
                self.currentMaster!.updatePreview(nodeGraph: self, hard: false)
            }
            self.nodeList!.switchTo(.Game)
            adjustVisibleButtons()
        }
        
        var smallButtonSkin = MMSkinButton()
        smallButtonSkin.height = mmView.skin.Button.height
        smallButtonSkin.round = mmView.skin.Button.round
        smallButtonSkin.fontScale = mmView.skin.Button.fontScale
        
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
                self.playNode = self.previewNode
                self.mmScreen = MMScreen(self.mmView)

                let node = self.playNode
                if node!.type == "Object" {
                    var object = node as! Object
                    object.setupExecution(nodeGraph: self)
                    object = object.playInstance!
                    self.playToExecute.append(object)
                } else
                if node!.type == "Scene" {
                    let scene = node as! Scene
                    scene.setupExecution(nodeGraph: self)
                    for inst in scene.objectInstances {
                        self.playToExecute.append(inst.instance!)
                    }
                    self.playToExecute.append(scene)
                } else
                if node!.type == "Game" {
                    let game = node as! Game

                    game.setupExecution(nodeGraph: self)
                    self.playToExecute.append(game)
                }
                
                // -- Collect bindings
                self.playBindings = []
                for node in self.nodes {
                    if node.bindings.count > 0 {
                        self.playBindings.append(contentsOf: node.bindings)
                    }
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
        sideSliderButton = MMSideSliderWidget(app.mmView)
        
        // --- Register icons at first time start
//        if app.mmView.icons["execute"] == nil {
//            executeIcon = app.mmView.registerIcon("execute")
//        } else {
//            executeIcon = app.mmView.icons["execute"]
//        }
        
        // Behavior Menu (Debug Options)
        var behaviorItems : [MMMenuItem] = []
        
        let noDebugItem =  MMMenuItem( text: "Debug Info: None", cb: {
            self.debugMode = .None
        } )
        behaviorItems.append(noDebugItem)
        
        let layerAreasDebugItem =  MMMenuItem( text: "Debug Info: Scene Areas", cb: {
            self.debugMode = .SceneAreas
        } )
        behaviorItems.append(layerAreasDebugItem)
        
        let physicsDebugItem =  MMMenuItem( text: "Debug Info: Physics", cb: {
            self.debugMode = .Physics
        } )
        behaviorItems.append(physicsDebugItem)
        
        behaviorMenu = MMMenuWidget(mmView, items: behaviorItems)
        // ---
        
        previewInfoMenu = MMMenuWidget(mmView, type: .LabelMenu)
        
        // --- Set default view
        if currentMasterUUID != nil{
            setCurrentMaster(uuid: currentMasterUUID!)
        }
        
        if currentMaster as? Object != nil {
            if !overviewIsOn {
                self.contentType = .Objects
                updateContent(self.contentType)
                nodeList!.switchTo(.Object)
                objectsButton.setState(.One)
            } else {
                self.contentType = .ObjectsOverview
                updateContent(self.contentType)
                nodeList!.switchTo(.ObjectOverview)
                objectsButton.setState(.Several)
            }
        } else
        if currentMaster as? Scene != nil {
            objectsButton.removeState(.Checked)
            scenesButton.addState(.Checked)
            if !overviewIsOn {
                self.contentType = .Scenes
                self.editButton.setText( "Arrange..." )
                updateContent(self.contentType)
                nodeList!.switchTo(.Scene)
                scenesButton.setState(.One)
            } else {
                self.contentType = .ScenesOverview
                updateContent(self.contentType)
                nodeList!.switchTo(.SceneOverview)
                scenesButton.setState(.Several)
            }
        } else
        if currentMaster as? Game != nil {
            objectsButton.removeState(.Checked)
            gameButton.addState(.Checked)
            self.editButton.setText( "Arrange..." )
            editButton.isDisabled = true
            self.contentType = .Game
            updateContent(self.contentType)
            overviewIsOn = false
            nodeList!.switchTo(.Game)
        }
        
        if overviewIsOn {
            setOverviewMaster()
        }
        
        //
        refList = ReferenceList(self)
        refList.createVariableList()
    }

    ///
    func activate()
    {
        mmView.registerWidgets(widgets: nodeList!, contentScrollButton, objectsButton, scenesButton, gameButton)
        if !overviewIsOn {
            mmView.widgets.insert(editButton, at: 0)
            mmView.widgets.insert(playButton, at: 0)
            mmView.widgets.insert(behaviorMenu, at: 0)
            mmView.widgets.insert(previewInfoMenu, at: 0)
        }
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
        mmView.deregisterWidgets(widgets: nodeList!, playButton, contentScrollButton, objectsButton, scenesButton, gameButton, editButton, behaviorMenu, previewInfoMenu)
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
        if self.playNode!.type == "Scene" {
            let scene = self.playNode as! Scene
            scene.physicsInstance = nil
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
            sideSliderButton.setMode(.Animating)
            app!.mmView.startAnimate( startValue: leftRegion.rect.width, endValue: 0, duration: 500, cb: { (value,finished) in
                leftRegion.rect.width = value
                self.app!.mmView.update()
                if finished {
                    self.animating = false
                    self.leftRegionMode = .Closed
                    DispatchQueue.main.async {
                        self.sideSliderButton.setMode(.Right)
                    }
                }
            } )
            animating = true
        } else if leftRegion.rect.width != 200 {
            sideSliderButton.setMode(.Animating)
            app!.mmView.startAnimate( startValue: leftRegion.rect.width, endValue: 200, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    DispatchQueue.main.async {
                        self.sideSliderButton.setMode(.Left)
                    }
                }
                leftRegion.rect.width = value
                self.app!.mmView.update()
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
            nodeHoverMode = .Preview
            hoverNode = currentMaster!
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
        
        if nodeHoverMode == .SideSlider {
            if hoverNode != nil {
                setCurrentNode(hoverNode!)
            }
            
            sideSliderButton.removeState(.Hover)
            self.setLeftRegionMode(.Nodes)
            nodeHoverMode = .None
            return
        }

        if nodeHoverMode == .OverviewEdit {
            setCurrentNode(hoverNode!)
            #if os(OSX)
            if overviewIsOn {
                if hoverNode!.type == "Object" {
                    objectsButton.setState(.One)
                    objectsButton.clicked!(MMMouseEvent(0,0))
                } else {
                    scenesButton.setState(.One)
                    currentSceneUUID = hoverNode!.uuid
                    scenesButton.clicked!(MMMouseEvent(0,0))
                }
                nodeHoverMode = .None
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
                if hoverNode!.type == "Object" {
                    objectsButton.setState(.One)
                    objectsButton.clicked!(MMMouseEvent(0,0))
                } else {
                    scenesButton.setState(.One)
                    currentSceneUUID = hoverNode!.uuid
                    scenesButton.clicked!(MMMouseEvent(0,0))
                }
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
            nodeHoverMode = .Preview
            hoverNode = currentMaster!
            return
        }
        
        // --- Side Slider
        
        let distToSideSlider : Float = simd_distance(float2(sideSliderButton.rect.x + sideSliderButton.rect.width/2, sideSliderButton.rect.y + sideSliderButton.rect.height/2), float2(event.x, event.y))
        if distToSideSlider <=  sideSliderButton.rect.width/2 {
            sideSliderButton.addState(.Hover)
            nodeHoverMode = .SideSlider
            return
        } else {
            sideSliderButton.removeState(.Hover)
        }
        
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
        
        // ---
        
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
            
            previewSize.x = max(previewSize.x, 340)
            previewSize.y = max(previewSize.y, 80)

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

            if overviewIsOn && event.x > hoverNode!.rect.x + hoverNode!.rect.width - 62 * scale && event.y > hoverNode!.rect.y + 15 * scale && event.x <= hoverNode!.rect.x + hoverNode!.rect.width - (62-16) * scale && event.y <= hoverNode!.rect.y + (15 + 20) * scale {
                if overviewIsOn || (overviewIsOn == false && hoverNode!.maxDelegate != nil) {
                    nodeHoverMode = .OverviewEdit
                    mmView.update()
                    return
                }
            } else
            if nodeHoverMode == .OverviewEdit
            {
                mmView.update()
            }
            
            if hoverNode !== currentMaster {
                // --- Look for NodeUI item under the mouse, master has no UI
                let uiItemX = hoverNode!.rect.x + 35 * scale
                var uiItemY = hoverNode!.rect.y + NodeGraph.bodyY * scale
                let uiRect = MMRect()
                validHoverTarget = nil
                for uiItem in hoverNode!.uiItems {
                    
                    if uiItem.supportsTitleHover {
                        uiRect.x = uiItem.titleLabel!.rect.x - 2 * scale
                        uiRect.y = uiItem.titleLabel!.rect.y - 2 * scale
                        uiRect.width = uiItem.titleLabel!.rect.width + 4 * scale
                        uiRect.height = uiItem.titleLabel!.rect.height + 6 * scale
                        
                        if uiRect.contains(event.x, event.y) {
                            uiItem.titleHover = true
                            hoverUITitle = uiItem
                            mmView.update()
                            return
                        }
                    }
                    
                    uiRect.x = uiItemX
                    uiRect.y = uiItemY
                    uiRect.width = uiItem.rect.width * scale
                    uiRect.height = uiItem.rect.height * scale

                    let dropTarget = uiItem as? NodeUIDropTarget
                    
                    if dropTarget != nil {
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
                
                for terminal in playBindings {
                    terminal.node?.executeReadBinding(self, terminal)
                }
                
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
                
                if overviewIsOn == false {
                    for node in toDraw {
                        drawNode( node, region: region)
                    }
                } else {
                    for node in toDraw {
                        drawOverviewNode( node, region: region)
                    }
                }
                
                // --- Ongoing Node connection attempt ?
                if nodeHoverMode == .TerminalConnection {
                    let scale : Float = currentMaster!.camera!.zoom

                    let color = getColorForTerminal(hoverTerminal!.0)
                    app!.mmView.drawLine.draw( sx: hoverTerminal!.2, sy: hoverTerminal!.3, ex: mousePos.x, ey: mousePos.y, radius: 2 * scale, fillColor : float4(color.x, color.y, color.z, 1) )
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
                
                // --- Draw the master
                drawMasterNode( masterNode, region: region)
            }
            
            // SideSlider
            
            sideSliderButton.rect.x = region.rect.x - 40
            sideSliderButton.rect.y = region.rect.y + (region.rect.height - 70) / 2
            sideSliderButton.rect.width = 70
            sideSliderButton.rect.height = 70
            sideSliderButton.draw()

            renderer.setClipRect()
        } else
        if region.type == .Left {
            nodeList!.rect.copy(region.rect)
            nodeList!.draw()
        } else
        if region.type == .Top {
            
            contentScrollButton.rect.x = 10
            contentScrollButton.rect.y = 4 + 44
            contentScrollButton.draw()
            
            region.layoutH( startX: 10 + contentScrollButton.rect.width + 15, startY: 4 + 44, spacing: 10, widgets: objectsButton, scenesButton, gameButton)

            objectsButton.draw()
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
    
    /// Draw an overview node
    func drawOverviewNode(_ node: Node, region: MMRegion)
    {
        let scale : Float = currentMaster!.camera!.zoom
        
        node.rect.x = region.rect.x + node.xPos * scale + currentMaster!.camera!.xPos
        node.rect.y = region.rect.y + node.yPos * scale + currentMaster!.camera!.yPos
        
        node.rect.width = 266 * scale
        node.rect.height = 116 * scale
    
        if node.label == nil {
            node.label = MMTextLabel(app!.mmView, font: app!.mmView.openSans, text: node.name, scale: 0.42 * scale, color: mmView.skin.Node.titleColor)
        }
        
        if let label = node.label {
            if label.rect.width > 110 {
                node.rect.width += label.rect.width - 110
            }
        }
        
        let nodeColor = float4(0.165, 0.169, 0.173, 1.000)
        let isSelected = selectedUUID.contains(node.uuid)
        let borderColor = isSelected ? float4(0.953, 0.957, 0.961, 1.000) : float4(0.282, 0.286, 0.290, 1.000)
        
        app!.mmView.drawBox.draw( x: node.rect.x, y: node.rect.y, width: node.rect.width, height: node.rect.height, round: 46 * scale, borderSize: 2, fillColor: nodeColor, borderColor: borderColor)
        
        app!.mmView.drawBox.draw( x: node.rect.x, y: node.rect.y, width: node.rect.height, height: node.rect.height, round: 46 * scale, borderSize: 2, fillColor: float4(0,0,0,1), borderColor: float4(0.282, 0.286, 0.290, 1.000))
        
        if isSelected {
            app!.mmView.drawBox.draw( x: node.rect.x, y: node.rect.y, width: node.rect.width, height: node.rect.height, round: 46 * scale, borderSize: 2, fillColor: float4(0,0,0,0), borderColor: float4(0.953, 0.957, 0.961, 1.000))
        }
        
        // --- Preview
        
        var previewTexture : MTLTexture? = nil
        let prevSize :Float = 94 * scale

        if let object = node as? Object {

            if object.previewTexture == nil {
                object.updatePreview(nodeGraph: self)
            } else
            if object.instance != nil {
                previewTexture = object.previewTexture
            }
        } else
        if let scene = node as? Scene {
            if scene.updateStatus != .Valid && scene.camera != nil {
                sceneRenderer.render(width: prevSize, height: prevSize, camera: scene.camera!)
            }
            
            if scene.objectInstances.count > 0 {
                if let texture = sceneRenderer.fragment!.texture {
                    previewTexture = texture
                }
            }
        }
        
        if let texture = previewTexture {
            
            let xFactor : Float = previewSize.x / prevSize
            let yFactor : Float = previewSize.y / prevSize
            let factor : Float = min(xFactor, yFactor)
            
            var topX : Float = node.rect.x + 12 * scale
            var topY : Float = node.rect.y + 11 * scale

            if xFactor < yFactor {
                topY += ((prevSize * factor) - (prevSize * yFactor)) / 2 * scale / factor
            } else {
                topX += ((prevSize * factor) - (prevSize * xFactor)) / 2 * scale / factor
            }
            
            mmView.renderer.setClipRect(MMRect(node.rect.x + 12 * scale, node.rect.y + 11 * scale, prevSize, prevSize))
            mmView.drawTexture.draw(texture, x: topX, y: topY, zoom: factor)
            mmView.renderer.setClipRect()
        }
        
        // --- Edit Button
        
        let editColor = nodeHoverMode == .OverviewEdit ? float4(1,1,1,1) : float4(0.9,0.9,0.9,1)
        
        let editX : Float = node.rect.x + node.rect.width - 64 * scale
        let editY : Float = node.rect.y + 17 * scale
        let editSize : Float = 14 * scale
        let editRadius : Float = 0.9 * scale
        
        mmView.drawLine.draw(sx: editX, sy: editY + editSize / 2, ex: editX, ey: editY, radius: editRadius, fillColor: editColor)
        mmView.drawLine.draw(sx: editX, sy: editY, ex: editX + editSize, ey: editY, radius: editRadius, fillColor: editColor)
        mmView.drawLine.draw(sx: editX + editSize, sy: editY, ex: editX + editSize , ey: editY + editSize, radius: editRadius, fillColor: editColor)
        mmView.drawLine.draw(sx: editX + editSize / 2, sy: editY + editSize, ex: editX + editSize, ey: editY + editSize, radius: editRadius, fillColor: editColor)
        mmView.drawLine.draw(sx: editX, sy: editY + editSize, ex: editX + editSize * 0.7, ey: editY + editSize * 0.3, radius: editRadius, fillColor: editColor)

        mmView.drawLine.draw(sx: editX + editSize * 0.7 - 5 * scale, sy: editY + editSize * 0.3, ex: editX + editSize * 0.7, ey: editY + editSize * 0.3, radius: editRadius, fillColor: editColor)
        mmView.drawLine.draw(sx: editX + editSize * 0.7, sy: editY + editSize * 0.3, ex: editX + editSize * 0.7, ey: editY + editSize * 0.3 + 5 * scale, radius: editRadius, fillColor: editColor)

        // Node Menu
        if node.menu == nil {
            createNodeMenu(node)
        }
        
        if node.menu!.states.contains(.Opened) {
            mmView.delayedDraws.append(node.menu!)
        } else {
            node.menu!.rect.x = node.rect.x + node.rect.width - 40 * scale
            node.menu!.rect.y = node.rect.y + 13 * scale
            node.menu!.rect.width = 26 * scale //30 * scale
            node.menu!.rect.height = 24 * scale //28 * scale
            node.menu!.draw()
        }
        
        // --- Label
        if let label = node.label {
            if label.scale != 0.42 * scale {
                label.setText(node.name, scale: 0.42 * scale)
            }
            label.rect.x = node.rect.x + 130 * scale
            label.rect.y = node.rect.y + node.rect.height - 30 * scale
            label.draw()
        }
    }
    
    /// Draw a node
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
            
            node.rect.width = max(node.minimumSize.x, node.uiArea.width + 30) * scale
            node.rect.height = (node.minimumSize.y + max(node.uiArea.height, 20)) * scale
            
            if behaviorTree.rect.contains(node.rect.x, node.rect.y) {
                return
            }
        } else {
            node.rect.width = max(node.minimumSize.x, node.uiArea.width + 30) * scale
            node.rect.height = (node.minimumSize.y + max(node.uiArea.height, 20)) * scale
        }
        
        if node.label == nil {
            node.label = MMTextLabel(app!.mmView, font: app!.mmView.openSans, text: node.name, scale: 0.42 * scale, color: mmView.skin.Node.titleColor)
        }
        
        if let label = node.label {
            if label.rect.width + 85 * scale > node.rect.width {
                node.rect.width = label.rect.width + 85 * scale
            }
        }

        let vertexBuffer = renderer.createVertexBuffer( MMRect( node.rect.x, node.rect.y, node.rect.width, node.rect.height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // --- Fill the node data
        
        node.data.size.x = node.rect.width
        node.data.size.y = node.rect.height
        
        node.data.selected = selectedUUID.contains(node.uuid) ? 1 : 0
        node.data.borderRound = 24
        
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
        
        // --- Parse UI Items to get the terminal positions
        let uiItemX = node.rect.x + 35 * scale//(node.rect.width - node.uiArea.width*scale) / 2 - 2.5 * scale
        var uiItemY = node.rect.y + NodeGraph.bodyY * scale
        
        for uiItem in node.uiItems {
            uiItem.rect.x = uiItemX
            uiItem.rect.y = uiItemY
            uiItemY += uiItem.rect.height * scale
        }
        
        // ---
        
        var leftTerminalCount : Int = 0
        var topTerminalCount : Int = 0
        var rightTerminalCount : Int = 0
        var bottomTerminalCount : Int = 0

        var color : float3 = float3()
        for terminal in node.terminals {
            color = getColorForTerminal(terminal)
            
            if terminal.connector == .Left {
                
                terminal.posX = NodeGraph.tRadius * scale
                terminal.posY = NodeGraph.tOffY * scale
                
                node.data.leftTerminal = float4( color.x, color.y, color.z, terminal.posY)

                leftTerminalCount += 1
            }  else
            if terminal.connector == .Top {
                
                terminal.posY = 3 * scale

                node.data.topTerminal = float4( color.x, color.y, color.z, terminal.posY)
                topTerminalCount += 1
            } else
            if terminal.connector == .Right {
                
                if terminal.uiIndex == -1 {
                    continue
                }
                let uiItem = node.uiItems[terminal.uiIndex]
                let titleHeaderHeight : Float = uiItem.titleLabel!.rect.height + NodeUI.titleSpacing * scale
                
                terminal.posX = node.rect.width - NodeGraph.tRightY * scale + NodeGraph.tDiam * scale
                terminal.posY = uiItem.rect.y - node.rect.y + titleHeaderHeight + (uiItem.rect.height * scale - titleHeaderHeight - NodeUI.itemSpacing * scale) / 2
                
                if rightTerminalCount == 0 {
                    node.data.rightTerminals.0 = float4( color.x, color.y, color.z, terminal.posY)
                } else
                if rightTerminalCount == 1 {
                    node.data.rightTerminals.1 = float4( color.x, color.y, color.z, terminal.posY)
                } else
                if rightTerminalCount == 2 {
                    node.data.rightTerminals.2 = float4( color.x, color.y, color.z, terminal.posY)
                } else
                if rightTerminalCount == 3 {
                    node.data.rightTerminals.3 = float4( color.x, color.y, color.z, terminal.posY)
                } else
                if rightTerminalCount == 4 {
                    node.data.rightTerminals.4 = float4( color.x, color.y, color.z, terminal.posY)
                } else
                if rightTerminalCount == 5 {
                    node.data.rightTerminals.5 = float4( color.x, color.y, color.z, terminal.posY)
                }
                rightTerminalCount += 1
            } else
            if terminal.connector == .Bottom {
                if bottomTerminalCount == 0 {
                    node.data.bottomTerminals.0 = float4( color.x, color.y, color.z, 10 * scale)
                } else
                if bottomTerminalCount == 1 {
                    node.data.bottomTerminals.1 = float4( color.x, color.y, color.z, 10 * scale)
                } else
                if bottomTerminalCount == 2 {
                    node.data.bottomTerminals.2 = float4( color.x, color.y, color.z, 10 * scale)
                } else
                if bottomTerminalCount == 3 {
                    node.data.bottomTerminals.3 = float4( color.x, color.y, color.z, 10 * scale)
                } else
                if bottomTerminalCount == 4 {
                    node.data.bottomTerminals.4 = float4( color.x, color.y, color.z, 10 * scale)
                }
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
            if label.scale != 0.42 * scale {
                label.setText(node.name, scale: 0.42 * scale)
            }
            label.rect.x = node.rect.x + 27 * scale
            label.rect.y = node.rect.y + 16 * scale
            label.draw()
            //label.drawCentered(x: node.rect.x + 10 * scale, y: node.rect.y + 23 * scale, width: node.rect.width - 50 * scale, height: label.rect.height)
        }
        
        // --- Draw UI, was parsed before
        uiItemY = node.rect.y + NodeGraph.bodyY * scale
        for uiItem in node.uiItems {
            uiItem.draw(mmView: app!.mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: scale)
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
        
        // Node Menu
        
        if node.menu == nil {
            createNodeMenu(node)
        }
        
        if node.menu!.states.contains(.Opened) {
            mmView.delayedDraws.append(node.menu!)
        } else {
            node.menu!.rect.x = node.rect.x + node.rect.width - 54 * scale
            node.menu!.rect.y = node.rect.y + 13 * scale
            node.menu!.rect.width = 26 * scale //30 * scale
            node.menu!.rect.height = 24 * scale //28 * scale
            node.menu!.draw()
        }
    }
    
    /// Draw the master node
    func drawMasterNode(_ node: Node, region: MMRegion)
    {
        if contentType == .ObjectsOverview || contentType == .ScenesOverview { return }
        
        previewSize.x = min(previewSize.x, app!.editorRegion!.rect.width - 40)
        previewSize.y = min(previewSize.y, app!.editorRegion!.rect.height - 70)
        
        node.rect.width = previewSize.x + 2
        node.rect.height = previewSize.y + 64 + 25
        
        node.rect.x = region.rect.x + region.rect.width - node.rect.width + 11 + 10
        node.rect.y = region.rect.y - 22
        
        app!.mmView.drawBox.draw( x: node.rect.x, y: node.rect.y, width: node.rect.width, height: node.rect.height, round: 32, borderSize: 2, fillColor: float4(0.165, 0.169, 0.173, 1.000), borderColor: float4(0.282, 0.286, 0.290, 1.000) )
        
        // --- Preview
        
        var textures : [MTLTexture] = []
        
        let x : Float = node.rect.x + 2
        let y : Float = node.rect.y + 34 + 25
        
        if refList.isActive == false {
            // --- Preview
            
            func printBehaviorOnlyText()
            {
                mmView.drawText.drawTextCentered(mmView.openSans, text: "Behavior Only", x: x, y: y, width: previewSize.x, height: previewSize.y, scale: 0.4, color: float4(1,1,1,1))
            }
            
            // Preview Border
            app!.mmView.drawBoxPattern.draw( x: x, y: y, width: previewSize.x - 23, height: previewSize.y, round: 26, borderSize: 0, fillColor: float4(0.306, 0.310, 0.314, 1.000), borderColor: float4(0.216, 0.220, 0.224, 1.000) )
            
            if let game = previewNode as? Game {
                if let _ = game.currentScene {
                    if let texture = sceneRenderer.fragment.texture {
                        textures.append(texture)
                    }
                } else {
                    printBehaviorOnlyText()
                }
            } else
            if let scene = previewNode as? Scene {
                if scene.updateStatus != .Valid {
                    scene.updatePreview(nodeGraph: self, hard: scene.updateStatus == .NeedsHardUpdate)
                }
                if let texture = sceneRenderer.fragment.texture {
                    textures.append(texture)
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
                let camera = createNodeCamera(playNode != nil ? playNode! : node)
                
                debugBuilder.render(width: previewSize.x, height: previewSize.y, instance: debugInstance, camera: camera)
                app!.mmView.drawTexture.draw(debugInstance.texture!, x: x, y: y, zoom: 1)
            }
        } else {
            // Visible reference list
            
            refList.rect.x = x
            refList.rect.y = y
            refList.rect.width = previewSize.x - 23
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
        
        editButton.rect.x = node.rect.x + 15
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
        
        let dragColor = nodeHoverMode == .MasterDrag || nodeHoverMode == .MasterDragging ? mmView.skin.ToolBarButton.hoverColor : mmView.skin.ToolBarButton.color
        app!.mmView.drawArc.draw(x: node.rect.x + 4.5, y: node.rect.y + node.rect.height - 26, sca: 3.14 * 1.75, scb: 3.14 * 0.25, ra: 10, rb: 2, fillColor: dragColor)
        
        // --- Preview Info Label
        
        previewInfoMenu.rect.x = node.rect.x + node.rect.width - previewInfoMenu.rect.width - 36
        previewInfoMenu.rect.y = node.rect.y + node.rect.height - 24
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
                     
                        x = t.posX
                        y = t.posY
                        break
                    }
                } else
                if t.connector == .Top {
                    if t.uuid == conn.terminal!.uuid {
                        x = node.rect.width / 2 - 6 * scale
                        y = 3 * scale// + NodeGraph.tRadius * scale / 2
                        
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
        
        var bottomCount : Float = 0
        for terminal in node.terminals {
            if terminal.connector == .Bottom {
                bottomCount += 1
            }
        }
        var bottomX : Float = (node.rect.width - (bottomCount * NodeGraph.tDiam * scale + (bottomCount - 1) * NodeGraph.tSpacing * scale )) / 2 - 3.5 * scale
        
        for terminal in node.terminals {
            if terminal.connector == .Top {
                if y >= node.rect.y + 3 * scale && y <= node.rect.y + 3 * scale + NodeGraph.tDiam * scale {
                    if x >= node.rect.x + node.rect.width / 2 - NodeGraph.tRadius * scale - 3 * scale && x <= node.rect.x + node.rect.width / 2 + NodeGraph.tRadius * scale - 3 * scale {
                        return (terminal, .Top, node.rect.x + node.rect.width / 2 - 3 * scale, node.rect.y + 3 * scale + NodeGraph.tRadius * scale)
                    }
                }
            } else
            if terminal.connector == .Left || terminal.connector == .Right{
                if y >= node.rect.y + terminal.posY - NodeGraph.tRadius * scale && y <= node.rect.y + terminal.posY + NodeGraph.tRadius * scale {
                    if x >= node.rect.x + terminal.posX - NodeGraph.tRadius * scale && x <= node.rect.x + terminal.posX + NodeGraph.tRadius * scale {
                        return (terminal, terminal.connector, node.rect.x + terminal.posX, node.rect.y + terminal.posY)
                    }
                }
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
        func applyUndo(_ terminal1_: UUID,_ terminal2_: UUID, connect: Bool)
        {
            mmView.undoManager!.registerUndo(withTarget: self) { target in
                let terminal1 = globalApp!.nodeGraph.getTerminalOfUUID(terminal1_)
                let terminal2 = globalApp!.nodeGraph.getTerminalOfUUID(terminal2_)

                if terminal1 != nil && terminal2 != nil {
                    
                    let node1 = terminal1!.node!
                    let node2 = terminal2!.node!

                    if !connect {
                        // Disconnect
                        terminal1!.connections.removeAll{$0.toTerminalUUID == terminal2_}
                        terminal2!.connections.removeAll{$0.toTerminalUUID == terminal1_}
                        
                        node1.onDisconnect(myTerminal: terminal1!, toTerminal: terminal2!)
                        node2.onDisconnect(myTerminal: terminal2!, toTerminal: terminal1!)
                    } else {
                        // Connect
                        let t1Connection = Connection(from: terminal1!, to: terminal2!)
                        let t2Connection = Connection(from: terminal2!, to: terminal1!)
                        
                        t1Connection.toUUID = t2Connection.uuid
                        t2Connection.toUUID = t1Connection.uuid
                        
                        terminal1!.connections.append(t1Connection)
                        terminal2!.connections.append(t2Connection)
                        
                        terminal1!.node!.onConnect(myTerminal: terminal1!, toTerminal: terminal2!)
                        terminal2!.node!.onConnect(myTerminal: terminal2!, toTerminal: terminal1!)
                    }
                    
                    applyUndo(terminal1_, terminal2_, connect: !connect)
                    
                    globalApp!.nodeGraph.updateNode(node1)
                    globalApp!.nodeGraph.updateNode(node2)
                    globalApp!.nodeGraph.mmView.update()
                }
            }
            mmView.undoManager!.setActionName("Connect Terminals")
        }
        
        applyUndo(terminal1.uuid, terminal2.uuid, connect: false)
        
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
    func disconnectConnection(_ conn: Connection, undo: Bool = true)
    {
        func applyUndo(_ terminal1_: UUID,_ terminal2_: UUID, connect: Bool)
        {
            mmView.undoManager!.registerUndo(withTarget: self) { target in
                let terminal1 = globalApp!.nodeGraph.getTerminalOfUUID(terminal1_)
                let terminal2 = globalApp!.nodeGraph.getTerminalOfUUID(terminal2_)
                
                if terminal1 != nil && terminal2 != nil {
                    
                    let node1 = terminal1!.node!
                    let node2 = terminal2!.node!
                    
                    if !connect {
                        // Disconnect
                        terminal1!.connections.removeAll{$0.toTerminalUUID == terminal2_}
                        terminal2!.connections.removeAll{$0.toTerminalUUID == terminal1_}
                        
                        node1.onDisconnect(myTerminal: terminal1!, toTerminal: terminal2!)
                        node2.onDisconnect(myTerminal: terminal2!, toTerminal: terminal1!)
                    } else {
                        // Connect
                        let t1Connection = Connection(from: terminal1!, to: terminal2!)
                        let t2Connection = Connection(from: terminal2!, to: terminal1!)
                        
                        t1Connection.toUUID = t2Connection.uuid
                        t2Connection.toUUID = t1Connection.uuid
                        
                        terminal1!.connections.append(t1Connection)
                        terminal2!.connections.append(t2Connection)
                        
                        terminal1!.node!.onConnect(myTerminal: terminal1!, toTerminal: terminal2!)
                        terminal2!.node!.onConnect(myTerminal: terminal2!, toTerminal: terminal1!)
                    }
                    
                    applyUndo(terminal1_, terminal2_, connect: !connect)
                    
                    globalApp!.nodeGraph.updateNode(node1)
                    globalApp!.nodeGraph.updateNode(node2)
                    globalApp!.nodeGraph.mmView.update()
                }
            }
            mmView.undoManager!.setActionName("Disconnect Terminals")
        }
        
        let terminal = conn.terminal!
        terminal.connections.removeAll{$0.uuid == conn.uuid}

        let toTerminal = conn.toTerminal!
        toTerminal.connections.removeAll{$0.uuid == conn.toUUID!}
        
        if undo {
            applyUndo(terminal.uuid, toTerminal.uuid, connect: true)
        }

        terminal.node!.onDisconnect(myTerminal: terminal, toTerminal: toTerminal)
        toTerminal.node!.onDisconnect(myTerminal: toTerminal, toTerminal: terminal)
        
        updateNode(terminal.node!)
        updateNode(toTerminal.node!)
    }
    
    /// Returns the color for the given terminal
    func getColorForTerminal(_ terminal: Terminal) -> float3
    {
        var color : float3
        
        /*
        switch(terminal.brand)
        {
            case .Properties:
                color = float3(0.62, 0.506, 0.165)
            case .Behavior:
                color = float3(0.129, 0.216, 0.612)
            default:
                color = float3()
        }*/
        
        if terminal.connections.isEmpty {
            color = float3(0.678, 0.682, 0.686)
        } else {
            color = float3(0.278, 0.482, 0.675)
        }
        
        if playNode != nil {
            if terminal.node!.playResult != nil {
                if terminal.node!.playResult! == .Success {
                    color = float3(0.278, 0.549, 0.224)
                } else
                if terminal.node!.playResult! == .Failure {
                    color = float3(0.729, 0.263, 0.239)
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
            if type == .Objects || type == .ObjectsOverview {
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
            if type == .Scenes || type == .ScenesOverview {
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
                    items.append(game.name)
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
                        node.updatePreview(nodeGraph: self, hard: true)
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
            
            // Object Instances
            var instanceItem = MMMenuItem( text: "Object Instances", cb: {} )
            instanceItem.cb = {
                self.stopPreview()
                self.refList.isActive = true
                self.refList.createInstanceList()
                self.previewInfoMenu.setText("Object Instances", 0.3)
            }
            items.append(instanceItem)
            
            // Scenes
            var scenesItem = MMMenuItem( text: "Scenes", cb: {} )
            scenesItem.cb = {
                self.stopPreview()
                self.refList.isActive = true
                self.refList.createSceneList()
                self.previewInfoMenu.setText("Scenes", 0.3)
            }
            items.append(scenesItem)
            
            // Scene Areas
            var areasItem = MMMenuItem( text: "Scene Areas", cb: {} )
            areasItem.cb = {
                self.stopPreview()
                self.refList.isActive = true
                self.refList.createSceneAreaList()
                self.previewInfoMenu.setText("Scene Areas", 0.3)
            }
            items.append(areasItem)
            
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
        
        if contentType == .Objects {
            nodeList?.switchTo(.Object)
        }
        if contentType == .Scenes {
            nodeList?.switchTo(.Scene)
        }
        if contentType == .Game {
            nodeList?.switchTo(.Game)
        }
        if contentType == .ObjectsOverview {
            nodeList?.switchTo(.ObjectOverview)
        }
        if contentType == .ScenesOverview {
            nodeList?.switchTo(.SceneOverview)
        }
        //nodeList!.switchTo(NodeListItem.DisplayType(rawValue: contentType.rawValue)!)
    }
    
    /// Hard updates the given node
    func updateNode(_ node: Node)
    {
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
                conn.targets = []
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
                        if let scene = conn.masterNode as? Scene {
                            for inst in scene.objectInstances {
                                if inst.uuid == conn.connectedTo {
                                    conn.target = inst
                                    conn.targets = [inst]
                                    conn.targetName = inst.name
                                    break
                                }
                            }
                        } else {
                            conn.masterNode = nil
                        }
                    }
                    validateConn(conn)
                    
                    // --- If not connected, list all instances of the master object of this node
                    if conn.target == nil {
                        let masterNode = getMasterForNode(node)
                        if let masterObject = masterNode as? Object {
                            for n in nodes {
                                if let scene = n as? Scene {
                                    for inst in scene.objectInstances {
                                        if inst.objectUUID == masterObject.uuid {
                                            if conn.target == nil {
                                                conn.masterNode = scene // This only updates the first found scene in the preview
                                                conn.connectedMaster = scene.uuid
                                                conn.target = inst
                                            }
                                            conn.targets.append(inst)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                node.computeUIArea(mmView: mmView)
            }
            
            // Fill up an master picker with self + all global masters
            if item.role == .MasterPicker {
                
                if let master = getMasterForNode(node) /* as? Object*/ {
                    
                    if let picker = item as? NodeUIMasterPicker {
                        
                        let conn = picker.uiConnection
                        let type = conn.connectionType
                        
                        if type != .ObjectInstance && type != .SceneArea {
                            if let _ = master as? Object {
                                picker.items = ["Self"]
                                picker.uuids = [master.uuid]
                            }
                        } else
                        if type == .SceneArea {
                            if let _ = master as? Scene {
                                picker.items = ["Self"]
                                picker.uuids = [master.uuid]
                            }
                        }
                        
                        if type == .Object || type == .Animation {
                            // Animation: Only pick other Objects as Scenes etc dont have animations
                            for n in nodes {
                                if n.subset != nil && n.uuid != master.uuid && (n as? Object) != nil {
                                    picker.items.append(n.name)
                                    picker.uuids.append(n.uuid)
                                }
                            }
                        } else
                        if type == .ObjectInstance {
                            // ObjectInstance: Only pick object instances in scenes
                            for n in nodes {
                                if let scene = n as? Scene {
                                    for inst in scene.objectInstances {
                                        picker.items.append(scene.name + ": " + inst.name)
                                        picker.uuids.append(inst.uuid)
                                    }
                                }
                            }
                        } else
                        if type == .SceneArea {
                            // SceneArea: Only pick layers
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
                                    if type == .SceneArea && (firstListNode as? Scene) != nil {
                                        conn.connectedMaster = picker.uuids[0]
                                        conn.masterNode = firstListNode
                                        picker.index = 0
                                    } else
                                    if type != .SceneArea && (firstListNode as? Object) != nil {
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
                            if let scene = node as? Scene {
                                for inst in scene.objectInstances {
                                    if inst.uuid == conn.connectedMaster {
                                        animInstance = inst
                                        conn.masterNode = scene
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
            
            // .SceneAreaTarget Drop Target
            if item.role == .SceneAreaTarget {
                if let target = item as? NodeUISceneAreaTarget {
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
            
            // .SceneTarget Drop Target
            if item.role == .SceneTarget {
                if let target = item as? NodeUISceneTarget {
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
                        let scene = conn.masterNode as! Scene
                        
                        picker.items = []
                        picker.uuids = []
                        
                        conn.target = nil
                        let subs = getNodesOfMaster(for: scene)
                        var index : Int = 0
                        var first : Node? = nil
                        for s in subs {
                            if s.type == "Scene Area" {
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
    
    /// Returns the instances of the given object
    func getInstancesOf(_ uuid: UUID) -> [Object]
    {
        var instances : [Object] = []
        
        for node in nodes {
            if let scene = node as? Scene {
                for inst in scene.objectInstances {
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
            if let scene = node as? Scene {
                for inst in scene.objectInstances {
                    if inst.uuid == uuid {
                        return inst.instance
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Deletes the given node
    func deleteNode(_ node: Node,_ undo: Bool = true)
    {
        let before = encodeJSON()
        
        // Remove connections
        for t in node.terminals {
            for conn in t.connections {
                disconnectConnection(conn, undo: false)
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
        
        // If node is an object, remove it from all instances in scenes
        if let object = node as? Object {
            for n in nodes {
                if let scene = n as? Scene {
                    while let index = scene.objectInstances.firstIndex(where: { $0.objectUUID == object.uuid }) {
                        scene.objectInstances.remove(at: index)
                    }
                }
            }
        }
        
        // Remove all references to this node in the uiConnections
        var nodesToUpdate : [Node] = []
        for n in nodes {
            for conn in n.uiConnections {
                if conn.connectedMaster == node.uuid || conn.connectedTo == node.uuid {
                    conn.connectedMaster = nil
                    conn.connectedTo = nil
                    conn.target = nil
                    conn.masterNode = nil
                    nodesToUpdate.append(n)
                }
            }
        }
        
        for n in nodesToUpdate {
            updateNode(n)
        }
        
        // ---
        
        if undo == true {
            let after = encodeJSON()
            globalStateUndo(oldState: before, newState: after, text: "Delete Node")
        
            refList.update()
            mmView.update()
        }
    }
    
    /// Performs a global undo / redo by saving / loading the whole project
    func globalStateUndo(oldState: String, newState: String, text: String? = nil)
    {
        func graphStatusChanged(_ oldState: String, _ newState: String)
        {
            mmView.undoManager!.registerUndo(withTarget: self) { target in
                self.app?.loadFrom(oldState)
                graphStatusChanged(newState, oldState)
            }
            if let undoText = text {
                self.mmView.undoManager!.setActionName(undoText)
            }
        }
        
        graphStatusChanged(oldState, newState)
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
                
                if node.type == "Object" {
                    self.objectsButton.setState(.One)
                    self.objectsButton.clicked!(MMMouseEvent(10,10))
                } else
                if node.type == "Scene" {
                    self.scenesButton.setState(.One)
                    self.currentSceneUUID = node.uuid
                    self.scenesButton.clicked!(MMMouseEvent(10,10))
                } else
                if node.maxDelegate != nil {
                    self.activateNodeDelegate(node)
                }
            } )
            items.append(editNodeItem)
        }
        
        if node.helpUrl != nil {
            let helpNodeItem =  MMMenuItem( text: "Help for Node", cb: {
                showHelp(node.helpUrl)
            } )
            items.append(helpNodeItem)
        }
        
        if node.type == "Object" {
            let duplicateNodeItem =  MMMenuItem( text: "Duplicate", cb: {
                if node.type == "Object" {
                    let encodedData = try? JSONEncoder().encode(node)
                    //print( encodedObjectJsonString)
                    if let duplicate =  try? JSONDecoder().decode(Object.self, from: encodedData!) {

                        duplicate.uuid = UUID()
                        duplicate.name = "Copy of " + duplicate.name
                        
                        for seq in duplicate.sequences {
                            seq.uuid = UUID()
                        }
                        
                        duplicate.subset = []
                        self.insertNode(duplicate)
                    }
                }
            } )
            items.append(duplicateNodeItem)
        }

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
    
    /// Returns all nodes which contain a reference of this node (objects in scenes).
    func getOccurencesOf(_ node: Node) -> [Node]
    {
        var scenes : [Node] = []
        
        // Find the occurenes of an object in the layers
        if node.type == "Object" {
            for n in nodes {
                if let scene = n as? Scene {
                    for inst in scene.objectInstances {
                        if inst.objectUUID == node.uuid {
                            if !scenes.contains(scene) {
                                scenes.append(scene)
                            }
                        }
                    }
                }
            }
        } else
        if node.type == "Scene" {
            scenes.append(node)
        }

        return scenes
    }
    
    /// Accept a drag from the reference list to a NodeUIDropTarget
    func acceptDragSource(_ dragSource: MMDragSource)
    {
        let uiTarget = validHoverTarget!
        var connIndex : Int = -1
        for (index,conn) in uiTarget.node.uiConnections.enumerated() {
            if uiTarget.uiConnection === conn {
                connIndex = index
                break
            }
        }
        
        if let source = dragSource as? ReferenceListDrag {

            let refItem = source.refItem!
            
            func targetDropped(_ uuid: UUID,_ connIndex: Int,_ oldMaster: UUID?,_ oldConnection: UUID?,_ newMaster: UUID?,_ newConnection: UUID?)
            {
                mmView.undoManager!.registerUndo(withTarget: self) { target in
                    
                    let node = globalApp!.nodeGraph.getNodeForUUID(uuid)!
                    let conn = node.uiConnections[connIndex]
                    
                    conn.connectedMaster = newMaster
                    conn.connectedTo = newConnection
                    conn.target = nil
                    
                    globalApp!.nodeGraph.updateNode(node)
                    targetDropped(uuid, connIndex, newMaster, newConnection, oldMaster, oldConnection)
                }
            }
            
            targetDropped(uiTarget.node.uuid, connIndex, refItem.classUUID, refItem.uuid, uiTarget.uiConnection.connectedMaster, uiTarget.uiConnection.connectedTo)
            
            uiTarget.uiConnection.connectedMaster = refItem.classUUID
            uiTarget.uiConnection.connectedTo = refItem.uuid
            
            updateNode(uiTarget.node)
            uiTarget.hoverState = .None
        }
    }
    
    /// Inserts a node into the graph
    func insertNode(_ node: Node, undo: Bool = true)
    {
        func nodeStatusChanged(_ node: Node,_ master: Node)
        {
            mmView.undoManager!.registerUndo(withTarget: self) { target in
                
                let index = self.nodes.firstIndex(where: { $0.uuid == node.uuid })
                if index != nil {
                    self.deleteNode(node)
                } else {
                    self.nodes.append(node)
                    master.subset!.append(node.uuid)
                    self.setCurrentNode()
                    self.updateMasterNodes(self.currentMaster!)
                    self.refList.update()
                }
                nodeStatusChanged(node, master)
            }
        }
        
        if currentMaster != nil {
            nodeStatusChanged(node, currentMaster!)
            
            node.setupTerminals()
            
            nodes.append(node)
            currentMaster?.subset!.append(node.uuid)
            setCurrentNode(node)
            updateNode(node)
            updateMasterNodes(currentMaster!)
            refList.update()
        }
    }
    
    /// Returns the scene for the given instance uuid
    func getSceneOfInstance(_ uuid: UUID) -> Scene? {
        for node in nodes {
            if let scene = node as? Scene {
                for inst in scene.objectInstances {
                    if inst.uuid == uuid {
                        return scene
                    }
                }
            }
        }
        return nil
    }
}
