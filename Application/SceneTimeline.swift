//
//  SceneGraph.swift
//  Shape-Z
//
//  Created by Markus Moenig on 1/2/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class SceneGraphSkin {
    
    //let normalInteriorColor     = SIMD4<Float>(0,0,0,0)
    let normalInteriorColor     = SIMD4<Float>(0.227, 0.231, 0.235, 1.000)
    let normalBorderColor       = SIMD4<Float>(0.5,0.5,0.5,1)
    let normalTextColor         = SIMD4<Float>(0.8,0.8,0.8,1)
    let selectedTextColor       = SIMD4<Float>(0.212,0.173,0.137,1)
    
    let selectedItemColor       = SIMD4<Float>(0.4,0.4,0.4,1)

    let selectedBorderColor     = SIMD4<Float>(0.976, 0.980, 0.984, 1.000)

    let normalTerminalColor     = SIMD4<Float>(0.835, 0.773, 0.525, 1)
    let selectedTerminalColor   = SIMD4<Float>(0.835, 0.773, 0.525, 1.000)
    
    let renderColor             = SIMD4<Float>(0.325, 0.576, 0.761, 1.000)
    let worldColor              = SIMD4<Float>(0.396, 0.749, 0.282, 1.000)
    let groundColor             = SIMD4<Float>(0.631, 0.278, 0.506, 1.000)
    let objectColor             = SIMD4<Float>(0.765, 0.600, 0.365, 1.000)
    let variablesColor          = SIMD4<Float>(0.714, 0.349, 0.271, 1.000)
    let postFXColor             = SIMD4<Float>(0.275, 0.439, 0.353, 1.000)
    let lightColor              = SIMD4<Float>(0.494, 0.455, 0.188, 1.000)

    let tempRect                = MMRect()
    let fontScale               : Float
    let font                    : MMFont
    let lineHeight              : Float
    let itemHeight              : Float = 30
    let margin                  : Float = 20
    
    let tSize                   : Float = 15
    let tHalfSize               : Float = 15 / 2
    
    let itemListWidth           : Float
        
    init(_ font: MMFont, fontScale: Float = 0.4, graphZoom: Float) {
        self.font = font
        self.fontScale = fontScale
        self.lineHeight = font.getLineHeight(fontScale)
        
        itemListWidth = 140 * graphZoom
    }
}

class SceneTimelineItem {
        
    enum SceneTimelineItemType {
        case Stage, StageItem, ShapesContainer, ShapeItem, BooleanItem, VariableContainer, VariableItem, DomainContainer, DomainItem, ModifierContainer, ModifierItem, ImageItem, PostFXContainer, PostFXItem, FogContainer, FogItem, CloudsContainer, CloudsItem
    }
    
    var itemType                : SceneTimelineItemType
    
    let component               : CodeComponent?
    let node                    : CodeComponent?
    let parentComponent         : CodeComponent?
    
    let rect                    : MMRect = MMRect()
    var navRect                 : MMRect? = nil

    init(_ type: SceneTimelineItemType, component: CodeComponent? = nil, node: CodeComponent? = nil, parentComponent: CodeComponent? = nil)
    {
        itemType = type
        self.component = component
        self.node = node
        self.parentComponent = parentComponent
    }
}

class SceneTimeline            : MMWidget
{
    enum SceneGraphState {
        case Closed, Open
    }
    
    enum InfoState {
        case Boolean, Modifier, UV, Material
    }
    
    var sceneGraphState         : SceneGraphState = .Closed
    var animating               : Bool = false
    
    var infoState               : InfoState = .Boolean
    
    var needsUpdate             : Bool = true
    
    var componentMap            : [UUID:MMRect] = [:]
    
    var graphX                  : Float = 250
    var graphY                  : Float = 250
    var graphZoom               : Float = 0.62
    
    var dispatched              : Bool = false
    
    var currentComponent        : CodeComponent? = nil
    
    var currentUUID             : UUID? = nil
    
    var mousePos                : SIMD2<Float> = SIMD2<Float>(0,0)
    var mouseDownPos            : SIMD2<Float> = SIMD2<Float>(0,0)
    var mouseDownItemPos        : SIMD2<Float> = SIMD2<Float>(0,0)
    
    var currentWidth            : Float = 0
    var openWidth               : Float = 300
    
    //var toolBarWidgets          : [MMWidget] = []
    //let toolBarHeight           : Float = 30
    
    var menuWidget              : MMMenuWidget
    var itemMenu                : MMMenuWidget
    
    var plusLabel               : MMTextLabel? = nil
    
    var toolBarButtonSkin       : MMSkinButton
    
    var zoomBuffer              : Float = 0
    
    var mouseIsDown             : Bool = false
    var clickWasConsumed        : Bool = false
    
    var navRect                 : MMRect = MMRect()
    var visNavRect              : MMRect = MMRect()
    
    var dragVisNav              : Bool = false
        
    var labels                  : [UUID:MMTextLabel] = [:]
    var textLabels              : [String:MMTextLabel] = [:]
    
    let minimizeIcon            : MTLTexture
    let maximizeIcon            : MTLTexture
    
    let minMaxButtonRect        = MMRect()
    
    var itemMenuSkin            : MMSkinMenuWidget
    
    // The nav ratios
    var ratioX                  : Float = 0
    var ratioY                  : Float = 0
    
    var hasMinMaxButton         = false
    var minMaxButtonHoverState  = false
    
    var clipboard               : [String:String] = [:]
    
    // Everything related to maximizedObjects
    
    let closeButton             : MMButtonWidget!
    var lastInfoUUID            : UUID? = nil
    
    var infoMenuWidget          : MMMenuWidget
    var bottomOffset            : Float = 0
    
    var infoButtonSkin          : MMSkinButton
    var infoButtons             : [MMWidget] = []
    
    var infoBoolButton          : MMButtonWidget!
    var infoModifierButton      : MMButtonWidget!
    
    //var xrayShader              : XRayShader? = nil
    //var xrayTexture             : MTLTexture? = nil
    
    var xrayOrigin              = float3(0,0,5)
    var xrayLookAt              = float3(0,0,0)
    
    var xrayCamera              : CodeComponent? = nil
    var xrayAngle               : Float = 0
    var xrayZoom                : Float = 5
    
    var xraySelectedId          : Int = -1
    
    var xrayNeedsUpdate         : Bool = false
    var xrayUpdateLocked        : Bool = false
    
    var shapesTB                : MMTextBuffer? = nil
    var addMaterialTB           : MMTextBuffer? = nil
    var useLastMaterialTB       : MMTextBuffer? = nil
    
    var currentMaxComponent     : CodeComponent? = nil
    
    override init(_ view: MMView)
    {
        menuWidget = MMMenuWidget(view, type: .Hidden)
        
        infoButtonSkin = MMSkinButton()
        infoButtonSkin.margin = MMMargin( 8, 4, 8, 4 )
        infoButtonSkin.borderSize = 0
        infoButtonSkin.height = view.skin.Button.height - 5
        infoButtonSkin.fontScale = 0.40
        infoButtonSkin.round = 20
        
        toolBarButtonSkin = MMSkinButton()
        toolBarButtonSkin.margin = MMMargin( 8, 4, 8, 4 )
        toolBarButtonSkin.borderSize = 0
        toolBarButtonSkin.height = view.skin.Button.height - 5
        toolBarButtonSkin.fontScale = 0.40
        toolBarButtonSkin.round = 20
        
        itemMenuSkin = MMSkinMenuWidget()
        //itemMenuSkin.button.color = SIMD4<Float>(1,1,1,0.3)
        itemMenuSkin.button.color = SIMD4<Float>(0.227, 0.231, 0.235, 1.000)
        itemMenuSkin.button.borderColor = SIMD4<Float>(0.537, 0.533, 0.537, 1.000)
        
        itemMenu = MMMenuWidget(view, skinToUse: itemMenuSkin, type: .BoxedMenu)
        itemMenu.rect.width /= 1.5
        itemMenu.rect.height /= 1.5
        
        infoMenuWidget = MMMenuWidget(view, skinToUse: itemMenuSkin, type: .BoxedMenu)
        infoMenuWidget.rect.width /= 1.5
        infoMenuWidget.rect.height /= 1.5
        
        minMaxButtonRect.width = itemMenu.rect.width
        minMaxButtonRect.height = itemMenu.rect.height
        
        minimizeIcon = view.icons["minimize"]!
        maximizeIcon = view.icons["maximize"]!
        
        // Close Button
        let state = view.drawCustomState.createState(source:
            """
            
            float sdLine( float2 uv, float2 pa, float2 pb, float r) {
                float2 o = uv-pa;
                float2 l = pb-pa;
                float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
                return -(r-distance(o,l*h));
            }
            
            fragment float4 drawCloseButton(RasterizerData in [[stage_in]],
                                           constant MM_CUSTOMSTATE_DATA *data [[ buffer(0) ]] )
            {
                float2 uv = in.textureCoordinate * data->size;
                uv -= data->size / 2;
            
                float dist = sdLine( uv, float2( data->size.x / 2, data->size.y / 2 ), float2( -data->size.x / 2, -data->size.y / 2 ), 2 );
                dist = min( dist, sdLine( uv, float2( -data->size.x / 2, data->size.y / 2 ), float2( data->size.x/2, -data->size.y/2 ), 2 ) );
            
                float4 col = float4( 1, 1, 1, m4mFillMask( dist ) );
                return col;
            }
            """, name: "drawCloseButton")
        
        closeButton = MMButtonWidget(view, customState: state)
                
        super.init(view)
        
        zoom = view.scaleFactor
    }
    
    func libraryLoaded()
    {
        var menuItems = [
            MMMenuItem(text: "Add Object", cb: { () in
                //getStringDialog(view: self.mmView, title: "New Object", message: "Object name", defaultValue: "New Object", cb: { (value) -> Void in
                /*
                 if let scene = globalApp!.project.selected {
                 
                 let shapeStage = scene.getStage(.ShapeStage)
                 
                 let undo = globalApp!.currentEditor.undoStageStart(shapeStage, "Add Object")
                 let objectItem = shapeStage.createChild("New Object")//value)
                 
                 objectItem.components[objectItem.defaultName]!.values["_posY"] = 1
                 objectItem.values["_graphX"]! = (self.mouseDownPos.x - self.rect.x) / self.graphZoom - self.graphX
                 objectItem.values["_graphY"]! = (self.mouseDownPos.y - self.rect.y) / self.graphZoom - self.graphY
                 
                 globalApp!.sceneGraph.setCurrent(stage: shapeStage, stageItem: objectItem)
                 globalApp!.currentEditor.undoStageEnd(shapeStage, undo)
                 globalApp!.currentEditor.updateOnNextDraw(compile: true)
                 }*/
                //} )
            })
        ]
        
        let list = globalApp!.libraryDialog.getItems(ofId: "Light3D")
        for l in list {
            menuItems.append( MMMenuItem(text: "Add \(l.titleLabel.text)", cb: { () in
                //getStringDialog(view: self.mmView, title: "New Light", message: "Light name", defaultValue: "Light", cb: { (value) -> Void in
                if let scene = globalApp!.project.selected {
                    /*
                     let lightStage = scene.getStage(.LightStage)
                     
                     let undo = globalApp!.currentEditor.undoStageStart(lightStage, "Add \(l.titleLabel.text)")
                     let lightItem = lightStage.createChild("\(l.titleLabel.text)")
                     
                     lightItem.values["_graphX"]! = (self.mouseDownPos.x - self.rect.x) / self.graphZoom - self.graphX
                     lightItem.values["_graphY"]! = (self.mouseDownPos.y - self.rect.y) / self.graphZoom - self.graphY
                     
                     scene.invalidateCompilerInfos()
                     globalApp!.sceneGraph.setCurrent(stage: lightStage, stageItem: lightItem)
                     globalApp!.currentEditor.updateOnNextDraw(compile: true)
                     globalApp!.currentEditor.undoStageEnd(lightStage, undo)
                     */
                }
                //} )
            }))
        }
        
        menuWidget.setItems(menuItems)
    }
    
    func activate()
    {
        //for w in toolBarWidgets {
        //    mmView.widgets.insert(w, at: 0)
        //}
        mmView.widgets.insert(menuWidget, at: 0)
        mmView.widgets.insert(itemMenu, at: 0)
    }
    
    func deactivate()
    {
        //for w in toolBarWidgets {
        //    mmView.deregisterWidget(w)
        //}
        mmView.deregisterWidget(menuWidget)
        mmView.deregisterWidget(itemMenu)
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        /*
         if maximizedObject != nil {
         xrayAngle += event.deltaX!
         
         #if os(OSX)
         xrayZoom += event.deltaY!
         #endif
         
         xrayZoom = min(xrayZoom, 20)
         xrayZoom = max(xrayZoom, 1)
         
         let c = cos(xrayAngle.degreesToRadians)
         let s = sin(xrayAngle.degreesToRadians)
         
         xrayOrigin.x = xrayZoom * c
         xrayOrigin.z = xrayZoom * s
         
         setPropertyValue3(component: xrayCamera!, name: "origin", value: xrayOrigin)
         xrayNeedsUpdate = true
         mmView.update()
         return
         }*/
        
#if os(iOS)
        if connectingTerminals {
            return
        }
        graphX += event.deltaX! * 2
        graphY += event.deltaY! * 2
#elseif os(OSX)
        //if mmView.commandIsDown && event.deltaY! != 0 {
        graphZoom += event.deltaY! * 0.003
        graphZoom = max(0.2, graphZoom)
        graphZoom = min(1, graphZoom)
        //} else {
        //    graphX -= event.deltaX! * 2
        //    graphY -= event.deltaY! * 2
        //}
#endif
        if !dispatched {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.mmView.unlockFramerate()
                self.dispatched = false
            }
            dispatched = true
        }
        
        if mmView.maxFramerateLocks == 0 {
            mmView.lockFramerate()
        }
    }
    
    override func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        clickWasConsumed = true
        
        /*
         if maximizedObject != nil {
         
         if firstTouch == true {
         zoomBuffer = xrayZoom
         }
         
         xrayZoom = zoomBuffer * scale
         
         xrayZoom = min(xrayZoom, 20)
         xrayZoom = max(xrayZoom, 1)
         
         let c = cos(xrayAngle.degreesToRadians)
         let s = sin(xrayAngle.degreesToRadians)
         
         xrayOrigin.x = xrayZoom * c
         xrayOrigin.z = xrayZoom * s
         
         setPropertyValue3(component: xrayCamera!, name: "origin", value: xrayOrigin)
         xrayNeedsUpdate = true
         mmView.update()
         return
         }*/
        
        if firstTouch == true {
            zoomBuffer = graphZoom
        }
        
        graphZoom = max(0.2, zoomBuffer * scale)
        graphZoom = min(1, graphZoom)
        mmView.update()
    }
    
    func clearSelection()
    {
        currentComponent = nil
        currentUUID = nil
        
        globalApp!.artistEditor.setComponent(CodeComponent(.Dummy))
        globalApp!.developerEditor.setComponent(CodeComponent(.Dummy))
    }
    
    func setCurrent(component: CodeComponent? = nil)
    {
        currentComponent = component
        if let component = component {
            currentUUID = component.uuid
            globalApp!.currentEditor.setComponent(component)
        } else {
            currentUUID = nil
        }
    }
    
    /*
     func setCurrent(stage: Stage, stageItem: StageItem? = nil, component: CodeComponent? = nil)
     {
     currentStage = stage
     currentStageItem = stageItem
     currentComponent = nil
     currentUUID = nil
     
     infoListWidget.selectedItem = nil
     
     currentUUID = stage.uuid
     globalApp!.artistEditor.designEditor.blockRendering = true
     
     /*
      if let stageItem = stageItem {
      globalApp!.project.selected?.setSelected(stageItem)
      if component == nil {
      if let defaultComponent = stageItem.components[stageItem.defaultName] {
      globalApp!.currentEditor.setComponent(defaultComponent)
      if globalApp!.currentEditor === globalApp!.developerEditor {
      globalApp!.currentEditor.updateOnNextDraw(compile: false)
      }
      currentComponent = defaultComponent
      } else {
      globalApp!.currentEditor.setComponent(CodeComponent(.Dummy))
      }
      }
      currentUUID = stageItem.uuid
      }
      
      if let component = component {
      globalApp!.currentEditor.setComponent(component)
      if globalApp!.currentEditor === globalApp!.developerEditor {
      globalApp!.currentEditor.updateOnNextDraw(compile: false)
      }
      
      currentComponent = component
      currentUUID = component.uuid
      } else
      if currentComponent == nil {
      globalApp!.currentEditor.setComponent(CodeComponent())
      }
      
      if maximizedObject != nil {
      
      xrayNeedsUpdate = true
      xraySelectedId = -1
      
      if let component = currentComponent {
      
      if component.componentType == .SDF3D {
      currentMaxComponent = component
      } else
      if component.componentType == .Transform3D {
      currentMaxComponent = nil
      }
      }
      }*/
     
     globalApp!.artistEditor.designEditor.blockRendering = false
     needsUpdate = true
     mmView.update()
     }*/
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        clickWasConsumed = false
        
        //let realX       : Float = (x - rect.x)
        //let realY       : Float = (y - rect.y)
        for (uuid, rect) in componentMap {
            if rect.contains(event.x, event.y) {
                print(uuid)
                if let comp = globalApp!.project.selected?.componentOfUUID(uuid) {
                    self.setCurrent(component: comp)
                }
            }
        }
        
        
        /*
        if hasMinMaxButton {
            if minMaxButtonRect.contains(event.x, event.y) {
                minMaxButtonHoverState = true
                clickWasConsumed = true
                mmView.update()
                return
            }
        }*/
        
#if os(iOS)
        for b in buttons {
            if b.rect!.contains(event.x, event.y) {
                hoverButton = b
                break
            }
        }
#endif
        
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        
        mouseDownItemPos.x = graphX
        mouseDownItemPos.y = graphY
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        mousePos.x = event.x
        mousePos.y = event.y
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
    }
    
    /// Click at the given position
    func clickAt(x: Float, y: Float) -> Bool
    {
        //let realX       : Float = (x - rect.x)
        //let realY       : Float = (y - rect.y)
        print("here")
        for (uuid, rect) in componentMap {
            if rect.contains(x, y) {
                print(uuid)
                if let comp = globalApp!.project.selected?.componentOfUUID(uuid) {
                    self.setCurrent(component: comp)
                    return true
                }
            }
        }
        
        return false
    }
    
    override func update()
    {
        buildMenu(uuid: currentUUID)
        needsUpdate = false
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if globalApp!.hasValidScene == false {
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, fillColor : SIMD4<Float>( 0.125, 0.129, 0.137, 1))
            return
        }
        
        componentMap = [:]
        
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, fillColor : SIMD4<Float>( 0.125, 0.129, 0.137, 1))
        
        let items = globalApp!.project.selected!.items;
        
        let skin : SceneGraphSkin = SceneGraphSkin(mmView.openSans, fontScale: 0.4 * graphZoom, graphZoom: graphZoom)
        
        var r = MMRect(self.rect);
        r.height = 20;
        
        for item in items {
            
            mmView.drawBox.draw( x: r.x, y: r.y, width: r.width, height: r.height, round: 0, borderSize: 1.0, fillColor : skin.renderColor, borderColor: item.uuid == currentUUID ? skin.selectedBorderColor : skin.normalBorderColor);
            
            componentMap[item.uuid] = MMRect(r)
            
            r.y += 20;
        }
        
        /*
         if globalApp!.hasValidScene == false {
         mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, fillColor : SIMD4<Float>( 0.125, 0.129, 0.137, 1))
         closeMaximized()
         return
         }
         
         let skin : SceneGraphSkin = SceneGraphSkin(mmView.openSans, fontScale: 0.4 * graphZoom, graphZoom: graphZoom)
         
         // Build the menu
         if needsUpdate {
         update()
         }
         
         minMaxButtonRect.x = 0
         minMaxButtonRect.y = 0
         
         if let scene = globalApp!.project.selected {
         
         if maximizedObject != nil {
         drawMaximized()
         } else {
         mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, fillColor : SIMD4<Float>( 0.125, 0.129, 0.137, 1))
         mmView.renderer.setClipRect(MMRect(rect.x, rect.y /* + toolBarHeight + 1*/, rect.width - 1, rect.height /*- toolBarHeight - 1*/))
         parse(scene: scene, skin: skin)
         }
         
         if menuWidget.states.contains(.Opened) {
         menuWidget.draw()
         }
         
         // Item Menu
         if itemMenu.items.count > 0 || hasMinMaxButton {
         if let uuid = currentUUID {
         if let currentItem = itemMap[uuid] {
         
         var dist : Float = 5
         if let comp = currentItem.component {
         if comp.componentType == .Pattern || comp.componentType == .Material3D {
         dist = 10
         }
         }
         
         func isMinimized() -> Bool {
         var minimized : Bool = false
         
         if let comp = currentComponent, comp.componentType == .Ground3D {
         minimized = comp.values["minimized"] == 1
         } else
         if let comp = currentComponent, comp.componentType == .Transform3D {
         minimized = comp.values["minimized"] != 1
         } else
         if let stage = currentStage
         {
         minimized = stage.values["minimized"] == 1
         }
         
         return minimized
         }
         
         var isRight = true
         
         if hasMinMaxButton {
         minMaxButtonRect.x = rect.x + currentItem.rect.right() + dist
         if minMaxButtonRect.right() + itemMenu.rect.width + 5 > rect.x + rect.width {
         minMaxButtonRect.x = rect.x + currentItem.rect.x - itemMenu.rect.width - dist
         isRight = false
         }
         minMaxButtonRect.y = rect.y + currentItem.rect.y + (currentItem.rect.height - itemMenu.rect.width) / 2
         
         mmView.drawBox.draw( x: minMaxButtonRect.x, y: minMaxButtonRect.y, width: minMaxButtonRect.width, height: minMaxButtonRect.height, round: itemMenuSkin.button.round, fillColor : minMaxButtonHoverState ? itemMenuSkin.button.activeColor : itemMenuSkin.button.color)
         mmView.drawTexture.draw(isMinimized() ? maximizeIcon : minimizeIcon, x: minMaxButtonRect.x + 5, y: minMaxButtonRect.y + 5)
         dist += itemMenu.rect.width + 5
         }
         
         if itemMenu.items.count > 0 {
         itemMenu.rect.x = rect.x + currentItem.rect.right() + dist
         if itemMenu.rect.right() > rect.x + rect.width || isRight == false {
         itemMenu.rect.x = rect.x + currentItem.rect.x - itemMenu.rect.width - dist
         }
         
         itemMenu.rect.y = rect.y + currentItem.rect.y + (currentItem.rect.height - itemMenu.rect.width) / 2
         itemMenu.draw()
         } else {
         itemMenu.rect.x = 0
         itemMenu.rect.y = 0
         }
         } else {
         itemMenu.rect.x = 0
         itemMenu.rect.y = 0
         }
         } else {
         itemMenu.rect.x = 0
         itemMenu.rect.y = 0
         }
         }
         mmView.renderer.setClipRect()
         }
         
         // Connecting Terminals ?
         if connectingTerminals == true && selectedTerminal != nil {
         mmView.drawLine.drawDotted(sx: selectedTerminal!.3 + 7.5 * graphZoom, sy: selectedTerminal!.4 + 7.5 * graphZoom, ex: mousePos.x, ey: mousePos.y, radius: 1.5, fillColor: skin.normalTerminalColor)
         }
         
         if maximizedObject != nil {
         return
         }
         
         // Build the navigator
         navRect.width = 200 / 2
         navRect.height = 160 / 2
         navRect.x = rect.x//rect.right() - navRect.width
         navRect.y = rect.bottom() - navRect.height
         
         mmView.renderer.setClipRect(MMRect(navRect.x, navRect.y, navRect.width - 1, navRect.height))
         
         mmView.drawBox.draw( x: navRect.x, y: navRect.y, width: navRect.width, height: navRect.height, round: 0, borderSize: 1, fillColor : SIMD4<Float>(0.165, 0.169, 0.173, 1.000), borderColor: SIMD4<Float>(0, 0, 0, 1) )
         
         // Find the min / max values of the items
         
         var minX : Float = 10000
         var minY : Float = 10000
         var maxX : Float = -10000
         var maxY : Float = -10000
         
         for n in navItems {
         //for (_, n) in itemMap {
         if n.navRect == nil { n.navRect = MMRect() }
         if n.rect.x < minX { minX = n.rect.x }
         if n.rect.y < minY { minY = n.rect.y }
         if n.rect.right() > maxX { maxX = n.rect.right() }
         if n.rect.bottom() > maxY { maxY = n.rect.bottom() }
         }
         
         let border : Float = 10
         
         ratioX =  (navRect.width - border*2) / (maxX - minX)
         ratioY =  (navRect.height - border*2) / (maxY - minY)
         
         for n in navItems {
         //for (_, n) in itemMap {
         
         n.navRect!.x = border + navRect.x + (n.rect.x - minX) * ratioX
         n.navRect!.y = border + navRect.y + (n.rect.y - minY) * ratioY
         n.navRect!.width = n.rect.width * ratioX
         n.navRect!.height = n.rect.height * ratioY
         
         var selected : Bool = n.stage === currentStage
         if selected {
         if ( n.stageItem !== currentStageItem) {
         selected = false
         }
         }
         
         let color : SIMD4<Float>
         
         if n.stage.stageType == .PreStage {
         color = skin.worldColor
         } else
         if n.stage.stageType == .ShapeStage {
         if let comp = n.component, comp.componentType == .Ground3D {
         color = skin.groundColor
         } else {
         color = skin.objectColor
         }
         } else
         if n.stage.stageType == .RenderStage {
         color = skin.renderColor
         } else
         if n.stage.stageType == .VariablePool {
         color = skin.variablesColor
         } else
         if n.stage.stageType == .LightStage {
         color = skin.lightColor
         } else {
         color = skin.postFXColor
         }
         
         mmView.drawBox.draw( x:n.navRect!.x, y: n.navRect!.y, width: n.navRect!.width, height: n.navRect!.height, round: 0, borderSize: 1, fillColor: selected ? color : skin.normalInteriorColor, borderColor: color)
         }
         
         visNavRect.x = navRect.x + border - minX * ratioX + openWidth - rect.width
         visNavRect.y = navRect.y + border - minY * ratioY// + toolBarHeight * ratioY
         visNavRect.width = rect.width * ratioX
         visNavRect.height = rect.height * ratioY// - toolBarHeight * ratioY
         
         mmView.drawBox.draw( x: visNavRect.x, y: visNavRect.y, width: visNavRect.width, height: visNavRect.height, round: 6, fillColor : SIMD4<Float>(1, 1, 1, 0.1) )
         mmView.renderer.setClipRect()
         */
    }
    
    // Build the menu
    func buildMenu(uuid: UUID?)
    {
        itemMenu.setItems([])
        var items : [MMMenuItem] = []
        /*
         
         hasMinMaxButton = false
         minMaxButtonHoverState = false
         
         func buildChangeComponent(_ item: SceneGraphItem, name: String, ids: [String])
         {
         if let stageItem = item.stageItem {
         let menuItem = MMMenuItem(text: "Change " + name, cb: { () in
         globalApp!.libraryDialog.show(ids: ids, cb: { (json) in
         if let comp = decodeComponentFromJSON(json) {
         let undo = globalApp!.currentEditor.undoStageItemStart(stageItem, "Change " + name)
         
         //comp.uuid = UUID()
         comp.selected = nil
         
         comp.uuid = item.component!.uuid
         globalApp!.currentEditor.setComponent(comp)
         globalApp!.project.selected!.updateComponent(comp)
         
         globalApp!.currentEditor.undoStageItemEnd(stageItem, undo)
         self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         if comp.componentType == .Material3D || comp.componentType == .UVMAP3D || comp.componentType == .Ground3D {
         stageItem.name = comp.libraryName
         stageItem.label = nil
         }
         }
         })
         } )
         items.append(menuItem)
         }
         }
         
         func buildChangeMaterial(_ item: SceneGraphItem, name: String)
         {
         if let stageItem = item.stageItem {
         let menuItem = MMMenuItem(text: "Change " + name, cb: { () in
         globalApp!.libraryDialog.showMaterials(cb: { (jsonComponent) in
         if jsonComponent.count > 0 {
         if let comp = decodeComponentAndProcess(jsonComponent) {
         let undo = globalApp!.currentEditor.undoStageItemStart(stageItem, "Change " + name)
         
         //comp.uuid = UUID()
         comp.selected = nil
         
         comp.uuid = item.component!.uuid
         globalApp!.currentEditor.setComponent(comp)
         globalApp!.project.selected!.updateComponent(comp)
         
         globalApp!.currentEditor.undoStageItemEnd(stageItem, undo)
         self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         if comp.componentType == .Material3D || comp.componentType == .UVMAP3D || comp.componentType == .Ground3D {
         stageItem.name = comp.libraryName
         stageItem.label = nil
         }
         }
         }
         })
         } )
         items.append(menuItem)
         }
         }
         
         if let uuid = uuid {
         if let item = itemMap[uuid] {
         
         //if maximizedObject != nil && (item.itemType != .ShapeItem || currentComponent == nil) {
         //    return
         //}
         
         if item.itemType == .Stage {
         hasMinMaxButton = true
         }
         
         if let comp = item.component {
         
         if comp.componentType == .RayMarch3D {
         buildChangeComponent(item, name: "RayMarcher", ids: ["RayMarch3D"])
         } else
         if comp.componentType == .Normal3D {
         buildChangeComponent(item, name: "Normal", ids: ["Normal3D"])
         } else
         if comp.componentType == .SkyDome {
         buildChangeComponent(item, name: "Sky Dome", ids: ["SkyDome", "Pattern2D"])
         } else
         if comp.componentType == .Pattern && item.stageItem!.stageItemType == .PreStage {
         var items : [String] = []
         if globalApp!.currentSceneMode == .TwoD {
         items = ["Pattern"]
         } else {
         items = ["SkyDome", "Pattern"]
         }
         buildChangeComponent(item, name: "Pattern", ids: items)
         } else
         if comp.componentType == .Camera3D {
         buildChangeComponent(item, name: "Camera", ids: ["Camera3D"])
         } else
         if comp.componentType == .Shadows3D {
         buildChangeComponent(item, name: "Shadows", ids: ["Shadows3D"])
         } else
         if comp.componentType == .AO3D {
         buildChangeComponent(item, name: "Occlusion", ids: ["AO3D"])
         } else
         if comp.componentType == .Ground3D {
         if globalApp!.artistEditor.getTerrain() != nil {
         hasMinMaxButton = false
         
         let switchToGround = MMMenuItem(text: "Delete Terrain", cb: { () in
         askUserDialog(view: self.mmView, title: "Delete Terrain ?", info: "Deleting the terrain will delete all terrain data and activate the analytical ground object agan. This cannot be undone!", cancelText: "Cancel", continueText: "Delete Terrain", cb: { (result) in
         
         if result == true {
         let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
         shapeStage.terrain = nil
         if let stageItem = self.currentStageItem {
         stageItem.name = "Ground"
         stageItem.label = nil
         
         globalApp!.developerEditor.codeEditor.markStageItemInvalid(stageItem)
         }
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         globalApp!.currentEditor.setComponent(comp)
         self.buildMenu(uuid: self.currentUUID)
         }
         })
         } )
         items.append(switchToGround)
         
         } else {
         hasMinMaxButton = true
         buildChangeComponent(item, name: "Ground", ids: ["Ground3D"])
         }
         
         items.append(MMMenuItem())
         if item.stageItem!.values["disabled"] == 1 {
         let enableItem = MMMenuItem(text: "Enable", cb: { () in
         item.stageItem!.values["disabled"] = nil
         if let comp = item.component {
         comp.values["minimized"] = 0
         }
         globalApp!.currentEditor.render()
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(enableItem)
         } else {
         let disableItem = MMMenuItem(text: "Disable", cb: { () in
         item.stageItem!.values["disabled"] = 1
         if let comp = item.component {
         comp.values["minimized"] = 1
         }
         globalApp!.currentEditor.render()
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(disableItem)
         }
         } else
         if comp.componentType == .UVMAP3D {
         buildChangeComponent(item, name: "UV Mapping", ids: ["UVMAP3D"])
         } else
         if comp.componentType == .Material3D {
         //if item.stage.terrain == nil {
         buildChangeMaterial(item, name: "Material")
         items.append(MMMenuItem())
         let uploadItem = MMMenuItem(text: "Upload...", cb: { () in
         let dialog = UploadMaterialsDialog(self.mmView, material: item.stageItem!)
         dialog.show()
         } )
         items.append(uploadItem)
         //}
         } else
         if comp.componentType == .Render2D || comp.componentType == .Render3D {
         let menuItem = MMMenuItem(text: "Change Renderer", cb: { () in
         globalApp!.libraryDialog.show(ids: [comp.componentType == .Render2D ? "Render2D" : "Render3D"], cb: { (json) in
         if let comp = decodeComponentFromJSON(json) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Change Renderer")
         
         comp.uuid = UUID()
         comp.selected = nil
         globalApp!.currentEditor.setComponent(comp)
         
         comp.uuid = item.component!.uuid
         globalApp!.project.selected!.updateComponent(comp)
         
         globalApp!.project.selected!.invalidateCompilerInfos()
         globalApp!.currentEditor.undoStageItemEnd(undo)
         self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         }
         })
         } )
         items.append(menuItem)
         } else
         if comp.componentType == .Modifier3D {
         var ids : [String] = []
         var listId : String = "modifier3D"
         if globalApp!.currentSceneMode == .ThreeD { ids = ["Modifier3D", "Modifier2D"] }
         else { ids = ["Modifier2D"]; listId = "modifier2D" }
         buildChangeComponent(item, name: "Modifier", ids: ids)
         
         var index : Int = -1
         var count : Int = 0
         
         if let stageItem = item.stageItem {
         if let firstIndex = stageItem.componentLists[listId]!.firstIndex(of: comp) {
         index = firstIndex
         count = stageItem.componentLists[listId]!.count
         }
         }
         
         if count > 1 {
         items.append(MMMenuItem())
         if index > 0 {
         let moveUpItem = MMMenuItem(text: "Move Up", cb: { () in
         let undo = globalApp!.currentEditor.undoStageItemStart("Move Up")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[listId]!.remove(at: index)
         item.stageItem!.componentLists[listId]!.insert(comp, at: index - 1)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(moveUpItem)
         }
         
         if index < item.stageItem!.componentLists[listId]!.count - 1 {
         let moveDownItem = MMMenuItem(text: "Move Down", cb: { () in
         let undo = globalApp!.currentEditor.undoStageItemStart("Move Down")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[listId]!.remove(at: index)
         item.stageItem!.componentLists[listId]!.insert(comp, at: index + 1)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(moveDownItem)
         }
         }
         
         items.append(MMMenuItem())
         let menuItem = MMMenuItem(text: "Remove", cb: { () in
         let id = "modifier" + getCurrentModeId()
         
         if let index = item.stageItem!.componentLists[id]!.firstIndex(of: item.component!) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Remove Modifier")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[id]!.remove(at: index)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         }
         } )
         items.append(menuItem)
         } else
         if comp.componentType == .Domain3D {
         buildChangeComponent(item, name: "Domain", ids: ["Domain3D"])
         
         let listId : String = "domain" + getCurrentModeId()
         
         var index : Int = -1
         var count : Int = 0
         
         if let stageItem = item.stageItem {
         if let firstIndex = stageItem.componentLists[listId]!.firstIndex(of: comp) {
         index = firstIndex
         count = stageItem.componentLists[listId]!.count
         }
         }
         
         if count > 1 {
         items.append(MMMenuItem())
         if index > 0 {
         let moveUpItem = MMMenuItem(text: "Move Up", cb: { () in
         let undo = globalApp!.currentEditor.undoStageItemStart("Move Up")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[listId]!.remove(at: index)
         item.stageItem!.componentLists[listId]!.insert(comp, at: index - 1)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(moveUpItem)
         }
         
         if index < item.stageItem!.componentLists[listId]!.count - 1 {
         let moveDownItem = MMMenuItem(text: "Move Down", cb: { () in
         let undo = globalApp!.currentEditor.undoStageItemStart("Move Down")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[listId]!.remove(at: index)
         item.stageItem!.componentLists[listId]!.insert(comp, at: index + 1)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(moveDownItem)
         }
         }
         
         items.append(MMMenuItem())
         let menuItem = MMMenuItem(text: "Remove", cb: { () in
         let id = "domain" + getCurrentModeId()
         
         if let index = item.stageItem!.componentLists[id]!.firstIndex(of: item.component!) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Remove Domain")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[id]!.remove(at: index)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         }
         } )
         items.append(menuItem)
         } else
         if comp.componentType == .Fog3D {
         buildChangeComponent(item, name: "Fog", ids: ["Fog3D"])
         
         let menuItem = MMMenuItem(text: "Remove", cb: { () in
         let id = "fog"
         
         if let index = item.stageItem!.componentLists[id]!.firstIndex(of: item.component!) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Remove Fog")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[id]!.remove(at: index)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         }
         } )
         items.append(menuItem)
         } else
         if comp.componentType == .Clouds3D {
         buildChangeComponent(item, name: "Clouds", ids: ["Clouds3D"])
         
         let menuItem = MMMenuItem(text: "Remove", cb: { () in
         let id = "clouds"
         
         if let index = item.stageItem!.componentLists[id]!.firstIndex(of: item.component!) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Remove Clouds")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[id]!.remove(at: index)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         }
         } )
         items.append(menuItem)
         } else
         if comp.componentType == .PostFX {
         buildChangeComponent(item, name: "FX", ids: ["PostFX"])
         var index : Int = -1
         var count : Int = 0
         
         if let stageItem = item.stageItem {
         if let firstIndex = stageItem.componentLists["PostFX"]!.firstIndex(of: comp) {
         index = firstIndex
         count = stageItem.componentLists["PostFX"]!.count
         }
         }
         
         if count > 1 {
         items.append(MMMenuItem())
         if index > 0 {
         let moveUpItem = MMMenuItem(text: "Move Up", cb: { () in
         let undo = globalApp!.currentEditor.undoStageItemStart("Move Up")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists["PostFX"]!.remove(at: index)
         item.stageItem!.componentLists["PostFX"]!.insert(comp, at: index - 1)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(moveUpItem)
         }
         
         if index < item.stageItem!.componentLists["PostFX"]!.count - 1 {
         let moveDownItem = MMMenuItem(text: "Move Down", cb: { () in
         let undo = globalApp!.currentEditor.undoStageItemStart("Move Down")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists["PostFX"]!.remove(at: index)
         item.stageItem!.componentLists["PostFX"]!.insert(comp, at: index + 1)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(moveDownItem)
         }
         items.append(MMMenuItem())
         }
         
         let menuItem = MMMenuItem(text: "Remove", cb: { () in
         let id = "PostFX"
         
         if let index = item.stageItem!.componentLists[id]!.firstIndex(of: item.component!) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Remove FX")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[id]!.remove(at: index)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         }
         } )
         items.append(menuItem)
         } else
         if comp.componentType == .Pattern {
         let disconnectItem = MMMenuItem(text: "Disconnect", cb: { () in
         let undo = globalApp!.currentEditor.undoStageItemStart(item.stageItem!, "Disconnect Pattern")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         self.removeConnectionsFor(item.stageItem!, comp)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         } )
         items.append(disconnectItem)
         
         let removeItem = MMMenuItem(text: "Remove", cb: { () in
         if let index = item.stageItem!.components[item.stageItem!.defaultName]!.components.firstIndex(of: item.component!) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Remove Pattern")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.components[item.stageItem!.defaultName]!.components.remove(at: index)
         self.removeConnectionsFor(item.stageItem!, comp)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         }
         } )
         items.append(removeItem)
         } else
         if comp.componentType == .Variable {
         
         if item.stageItem!.values["locked"] != 1 {
         let renameItem = MMMenuItem(text: "Rename Variable", cb: { () in
         if let frag = getVariable(from: comp) {
         getStringDialog(view: self.mmView, title: "Rename Variable", message: "Variable name", defaultValue: frag.name, cb: { (value) -> Void in
         let undo = globalApp!.currentEditor.undoComponentStart("Rename Variable")
         frag.name = value
         comp.libraryName = value
         globalApp!.project.selected!.updateComponent(comp)
         globalApp!.currentEditor.setComponent(comp)
         globalApp!.currentEditor.undoComponentEnd(undo)
         self.mmView.update()
         } )
         }
         } )
         items.append(renameItem)
         
         let removeItem = MMMenuItem(text: "Remove", cb: { () in
         if let index = item.stageItem!.componentLists["variables"]!.firstIndex(of: item.component!) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Remove Variable")
         item.stageItem!.componentLists["variables"]!.remove(at: index)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         }
         } )
         items.append(removeItem)
         }
         } else
         if item.itemType == .ShapeItem {
         let shapeId = "shapes3D"// + (comp.componentType == .SDF2D ? "2D" : "3D" )
         var index : Int = -1
         
         if let stageItem = item.stageItem {
         if let firstIndex = stageItem.componentLists[shapeId]!.firstIndex(of: comp) {
         index = firstIndex
         }
         }
         
         let copyItem = MMMenuItem(text: "Copy", cb: { () in
         self.clipboard[shapeId] = encodeComponentToJSON(comp)
         
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(copyItem)
         
         if self.clipboard[shapeId] != nil {
         let pasteItem = MMMenuItem(text: "Paste", cb: { () in
         if let c = decodeComponentAndProcess(self.clipboard[shapeId]!) {
         
         let undo = globalApp!.currentEditor.undoStageItemStart("Paste Shape")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[shapeId]!.insert(c, at: index)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         self.buildMenu(uuid: self.currentUUID)
         }
         } )
         items.append(pasteItem)
         }
         
         items.append(MMMenuItem())
         
         let changeItem = MMMenuItem(text: "Change Shape", cb: { () in
         self.getShape(item: item, replace: true)
         } )
         items.append(changeItem)
         
         if index > 0 {
         let moveUpItem = MMMenuItem(text: "Move Up", cb: { () in
         let undo = globalApp!.currentEditor.undoStageItemStart("Move Up")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[shapeId]!.remove(at: index)
         item.stageItem!.componentLists[shapeId]!.insert(comp, at: index - 1)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(moveUpItem)
         }
         
         if index < item.stageItem!.componentLists[shapeId]!.count - 1 {
         let moveDownItem = MMMenuItem(text: "Move Down", cb: { () in
         let undo = globalApp!.currentEditor.undoStageItemStart("Move Down")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
         item.stageItem!.componentLists[shapeId]!.remove(at: index)
         item.stageItem!.componentLists[shapeId]!.insert(comp, at: index + 1)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(moveDownItem)
         }
         
         items.append(MMMenuItem())
         
         let renameItem = MMMenuItem(text: "Rename", cb: { () in
         getStringDialog(view: self.mmView, title: "Rename Shape", message: "Shape name", defaultValue: comp.name, cb: { (value) -> Void in
         let undo = globalApp!.currentEditor.undoComponentStart("Rename Shape")
         comp.name = value
         comp.label = nil
         globalApp!.project.selected!.updateComponent(comp)
         globalApp!.currentEditor.setComponent(comp)
         globalApp!.currentEditor.undoComponentEnd(undo)
         self.mmView.update()
         } )
         } )
         items.append(renameItem)
         
         let deleteItem = MMMenuItem(text: "Remove", cb: { () in
         if let index = item.stageItem!.componentLists[shapeId]!.firstIndex(of: item.component!) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Remove Shape")
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(item.component!)
         item.stageItem!.componentLists[shapeId]!.remove(at: index)
         globalApp!.currentEditor.undoStageItemEnd(undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         }
         } )
         items.append(deleteItem)
         } else
         if item.itemType == .BooleanItem {
         let changeItem = MMMenuItem(text: "Change Boolean", cb: { () in
         globalApp!.libraryDialog.show(ids: ["Boolean"], cb: { (json) in
         if let comp = decodeComponentFromJSON(json) {
         let undo = globalApp!.currentEditor.undoStageItemStart("Change Boolean")
         
         comp.uuid = UUID()
         comp.selected = nil
         globalApp!.currentEditor.setComponent(comp)
         
         if let parent = item.parentComponent {
         parent.subComponent = comp
         globalApp!.project.selected!.updateComponent(parent)
         globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(parent)
         }
         
         globalApp!.currentEditor.undoStageItemEnd(undo)
         self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         }
         })
         } )
         items.append(changeItem)
         }
         }
         if item.itemType == .Stage && item.stage.stageType == .VariablePool {
         // Variable Stage
         let addItem = MMMenuItem(text: "Add Variable Pool", cb: { () in
         getStringDialog(view: self.mmView, title: "Variable Pool", message: "Pool name", defaultValue: "Variables", cb: { (value) -> Void in
         
         let variablePool = StageItem(.VariablePool, value)
         variablePool.componentLists["variables"] = []
         
         if globalApp!.currentSceneMode == .ThreeD {
         item.stage.children3D.append(variablePool)
         } else {
         item.stage.children2D.append(variablePool)
         }
         placeChild(modeId: getCurrentModeId(), parent: item.stage, child: variablePool, stepSize: 90, radius: 150)
         self.mmView.update()
         } )
         } )
         items.append(addItem)
         } else
         if item.itemType == .StageItem && item.stage.stageType == .VariablePool {
         // Variable Stage
         if item.stageItem!.values["locked"] != 1 {
         let renameItem = MMMenuItem(text: "Rename Pool", cb: { () in
         getStringDialog(view: self.mmView, title: "Rename Variable Pool", message: "Pool name", defaultValue: "Variables", cb: { (value) -> Void in
         let undo = globalApp!.currentEditor.undoStageItemStart("Rename Variable Pool")
         item.stageItem!.name = value
         globalApp!.currentEditor.undoStageItemEnd(undo)
         self.mmView.update()
         } )
         } )
         items.append(renameItem)
         
         let removeItem = MMMenuItem(text: "Remove", cb: { () in
         if globalApp!.currentSceneMode == .ThreeD {
         let index = item.stage.children3D.firstIndex(of: item.stageItem!)
         if let index = index {
         item.stage.children3D.remove(at: index)
         }
         } else {
         let index = item.stage.children2D.firstIndex(of: item.stageItem!)
         if let index = index {
         item.stage.children2D.remove(at: index)
         }
         }
         } )
         items.append(removeItem)
         }
         } else
         if item.itemType == .StageItem && item.stageItem!.stageItemType == .ShapeStage && (item.stageItem!.components[item.stageItem!.defaultName] == nil || (item.stageItem!.components[item.stageItem!.defaultName]!.componentType != .UVMAP3D &&
         item.stageItem!.components[item.stageItem!.defaultName]!.componentType != .Ground3D &&
         item.stageItem!.components[item.stageItem!.defaultName]!.componentType != .Material3D)) {
         
         hasMinMaxButton = true
         
         /*
          let addChildItem = MMMenuItem(text: "Add Child", cb: { () in
          
          //getStringDialog(view: self.mmView, title: "Child Object", message: "Object name", defaultValue: "Child Object", cb: { (value) -> Void in
          if let scene = globalApp!.project.selected {
          
          let shapeStage = scene.getStage(.ShapeStage)
          let undo = globalApp!.currentEditor.undoStageStart(shapeStage, "Add Child Object")
          let objectItem = shapeStage.createChild(/*value*/"Child Object", parent: item.stageItem!)
          
          objectItem.values["_graphX"]! = objectItem.values["_graphX"]!
          objectItem.values["_graphY"]! = objectItem.values["_graphY"]! + 270
          
          globalApp!.currentEditor.undoStageEnd(shapeStage, undo)
          globalApp!.sceneGraph.setCurrent(stage: shapeStage, stageItem: objectItem)
          }
          //} )
          } )
          items.append(addChildItem)
          */
         
         let scene = globalApp!.project.selected!
         let shapeStage = scene.getStage(.ShapeStage)
         let rc = shapeStage.getParentOfStageItem(item.stageItem!)
         if rc.1 != nil {
         // Has a parent, show "Add Material"
         
         // Check if child has a material already
         var hasMaterial : Bool = false
         for child in item.stageItem!.children {
         if let c = child.components[child.defaultName] {
         if c.componentType == .Material3D {
         hasMaterial = true
         break
         }
         }
         }
         
         if hasMaterial == false {
         // Child has no material, offer to add one
         let addMaterialItem = MMMenuItem(text: "Add Material", cb: { () in
         
         let undo = globalApp!.currentEditor.undoStageItemStart(item.stageItem!, "Add Material")
         
         item.stageItem!.addMaterial(defaults: true)
         
         globalApp!.developerEditor.codeEditor.markStageItemInvalid(item.stageItem!)
         globalApp!.currentEditor.undoStageItemEnd(item.stageItem!, undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         } )
         items.append(addMaterialItem)
         } else {
         // Child has material, offer to remove it
         let addMaterialItem = MMMenuItem(text: "Remove Material", cb: { () in
         
         let undo = globalApp!.currentEditor.undoStageItemStart(item.stageItem!, "Remove Material")
         
         var itemsToRemove : [StageItem] = []
         
         for child in item.stageItem!.children {
         if let c = child.components[child.defaultName] {
         if c.componentType == .UVMAP3D || c.componentType == .Material3D {
         itemsToRemove.append(child)
         }
         }
         }
         
         item.stageItem!.componentLists["patterns"] = nil
         for child in itemsToRemove {
         if let index = item.stageItem!.children.firstIndex(of: child) {
         item.stageItem!.children.remove(at: index)
         }
         }
         globalApp!.developerEditor.codeEditor.markStageItemInvalid(item.stageItem!)
         globalApp!.currentEditor.undoStageItemEnd(item.stageItem!, undo)
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         } )
         items.append(addMaterialItem)
         }
         } else {
         // Has no child, i.e. top level object, add "Upload"
         let uploadItem = MMMenuItem(text: "Upload...", cb: { () in
         let dialog = UploadObjectsDialog(self.mmView, object: item.stageItem!)
         dialog.show()
         } )
         //items.append(MMMenuItem())
         items.append(uploadItem)
         items.append(MMMenuItem())
         
         if item.stageItem!.values["disabled"] == 1 {
         let enableItem = MMMenuItem(text: "Enable", cb: { () in
         item.stageItem!.values["disabled"] = nil
         item.stageItem!.components[item.stageItem!.defaultName]!.values["minimized"] = 0
         globalApp!.currentEditor.render()
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(enableItem)
         items.append(MMMenuItem())
         } else {
         let disableItem = MMMenuItem(text: "Disable", cb: { () in
         item.stageItem!.values["disabled"] = 1
         item.stageItem!.components[item.stageItem!.defaultName]!.values["minimized"] = 1
         globalApp!.currentEditor.render()
         self.buildMenu(uuid: self.currentUUID)
         } )
         items.append(disableItem)
         items.append(MMMenuItem())
         }
         }
         
         let renameItem = MMMenuItem(text: "Rename", cb: { () in
         getStringDialog(view: self.mmView, title: "Rename Object", message: "Object name", defaultValue: item.stageItem!.name, cb: { (value) -> Void in
         let undo = globalApp!.currentEditor.undoStageItemStart("Rename Object")
         item.stageItem!.name = value
         item.stageItem!.label = nil
         globalApp!.currentEditor.undoStageItemEnd(undo)
         self.mmView.update()
         } )
         } )
         items.append(renameItem)
         
         let removeItem = MMMenuItem(text: "Remove", cb: { () in
         
         if let scene = globalApp!.project.selected {
         let shapeStage = scene.getStage(.ShapeStage)
         let parent = shapeStage.getParentOfStageItem(item.stageItem!)
         if parent.1 == nil {
         let undo = globalApp!.currentEditor.undoStageStart(shapeStage, "Remove Object")
         if let index = shapeStage.children2D.firstIndex(of: item.stageItem!) {
         shapeStage.children2D.remove(at: index)
         } else
         if let index = shapeStage.children3D.firstIndex(of: item.stageItem!) {
         shapeStage.children3D.remove(at: index)
         }
         globalApp!.currentEditor.undoStageEnd(shapeStage, undo)
         } else
         if let p = parent.1 {
         let undo = globalApp!.currentEditor.undoStageItemStart(p, "Remove Child Object")
         if let index = p.children.firstIndex(of: item.stageItem!) {
         p.children.remove(at: index)
         }
         globalApp!.currentEditor.undoStageItemEnd(p, undo)
         }
         //self.clearToolbar()
         }
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         } )
         items.append(removeItem)
         } else
         if item.itemType == .StageItem && item.stage.stageType == .LightStage {
         // Light
         
         let renameItem = MMMenuItem(text: "Rename Light", cb: { () in
         getStringDialog(view: self.mmView, title: "Rename Light", message: "Light name", defaultValue: item.stageItem!.name, cb: { (value) -> Void in
         let undo = globalApp!.currentEditor.undoStageItemStart("Rename Light")
         item.stageItem!.name = value
         globalApp!.currentEditor.undoStageItemEnd(undo)
         self.mmView.update()
         } )
         } )
         items.append(renameItem)
         
         let removeItem = MMMenuItem(text: "Remove", cb: { () in
         if let scene = globalApp!.project.selected {
         let lightStage = scene.getStage(.LightStage)
         let undo = globalApp!.currentEditor.undoStageStart(lightStage, "Remove Light")
         
         if globalApp!.currentSceneMode == .ThreeD {
         let index = item.stage.children3D.firstIndex(of: item.stageItem!)
         if let index = index {
         item.stage.children3D.remove(at: index)
         }
         } else {
         let index = item.stage.children2D.firstIndex(of: item.stageItem!)
         if let index = index {
         item.stage.children2D.remove(at: index)
         }
         }
         scene.invalidateCompilerInfos()
         globalApp!.currentEditor.updateOnNextDraw(compile: true)
         globalApp!.currentEditor.undoStageEnd(lightStage, undo)
         }
         
         } )
         items.append(removeItem)
         }
         }
         }*/
        
        itemMenu.setItems(items)
        if items.count == 0 {
            mmView.deregisterWidget(itemMenu)
        } else {
            mmView.widgets.insert(itemMenu, at: 0)
        }
    }
    
    /*
    /// Creates a button with a "+" text and draws it
    func drawPlusButton(item: SceneGraphItem, rect: MMRect, cb: @escaping ()->(), skin: SceneGraphSkin)
    {
        let button = SceneGraphButton(item: item)
        button.rect = rect
        button.cb = cb
        
        if plusLabel == nil || plusLabel!.scale != skin.fontScale + 0.1 {
            plusLabel = MMTextLabel(mmView, font: mmView.openSans, text: "+", scale: skin.fontScale + 0.1, color: skin.normalTextColor)
        }
        plusLabel!.rect.x = rect.x
        plusLabel!.rect.y = rect.y
        plusLabel!.draw()
        
        //plusLabel!.drawCentered(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        
        buttons.append(button)
    }*/
    
    // Returns a label for the given UUID
    func getLabel(_ uuid: UUID,_ text: String, skin: SceneGraphSkin) -> MMTextLabel
    {
        var label = labels[uuid]
        if label == nil || label!.scale != skin.fontScale {
            label = MMTextLabel(mmView, font: mmView.openSans, text: text, scale: skin.fontScale, color: skin.normalTextColor)
            labels[uuid] = label
        }
        return label!
    }
    
    // Returns a label for the given string
    func getLabel(_ text: String, skin: SceneGraphSkin) -> MMTextLabel
    {
        var label = textLabels[text]
        if label == nil || label!.scale != skin.fontScale {
            label = MMTextLabel(mmView, font: mmView.openSans, text: text, scale: skin.fontScale, color: skin.normalTextColor)
            textLabels[text] = label
        }
        return label!
    }
}
