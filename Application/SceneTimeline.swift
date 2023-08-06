//
//  SceneGraph.swift
//  Shape-Z
//
//  Created by Markus Moenig on 1/2/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class SceneTimelineSkin {
    
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

class SceneTimelineButton {
    
    let index                   : Int

    var rect                    : MMRect? = nil
    var cb                      : (() -> ())? = nil
    
    init(index: Int)
    {
        self.index = index
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
    enum SceneTimelineState {
        case Closed, Open
    }
    
    var sceneGraphState         : SceneTimelineState = .Closed
    var animating               : Bool = false
    
    var menus                   : [MMMenuWidget] = []

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
    var openWidth               : Float = 200
    
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
                //if let scene = globalApp!.project.selected {
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
                //}
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
        //mmView.widgets.insert(menuWidget, at: 0)
        //mmView.widgets.insert(itemMenu, at: 0)
        
        for menu in menus {
            mmView.widgets.insert(menu, at: 0)
        }
    }
    
    func deactivate()
    {
        //for w in toolBarWidgets {
        //    mmView.deregisterWidget(w)
        //}
        //mmView.deregisterWidget(menuWidget)
        //mmView.deregisterWidget(itemMenu)
        for menu in menus {
            mmView.deregisterWidget(menu)
        }
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
            globalApp!.project.selected!.setSelectedUUID(component.uuid)
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
                
        let skin : SceneTimelineSkin = SceneTimelineSkin(mmView.openSans, fontScale: 0.4 * graphZoom, graphZoom: graphZoom)
                
        let r = MMRect(self.rect);
        r.x += 1;
        r.y = r.y + r.height;
        r.height = 30;
        
        r.y -= 31;
        
        let tracks = globalApp!.project.selected!.items.count
        
        // Draw the component tracks
        for index in 0..<tracks + 1 {
            
            // Create menu widget if necessary
            if menus.count <= index {
                let menu = MMMenuWidget(mmView, type: .LabelMenu)
                menu.textLabel = MMTextLabel(mmView, font: mmView.openSans, text: "\(index+1)", scale: skin.fontScale + 0.2, color: skin.normalTextColor)
                menus.append(menu)
                mmView.widgets.insert(menu, at: 0)
            }
            
            if menus.count <= index {
                let menu = MMMenuWidget(mmView, type: .LabelMenu)
                menu.textLabel = MMTextLabel(mmView, font: mmView.openSans, text: "\(index+1)", scale: skin.fontScale + 0.2, color: skin.normalTextColor)
                menus.append(menu)
                mmView.widgets.insert(menu, at: 0)
            }
            
            if index < globalApp!.project.selected!.items.count {
                let uuid = globalApp!.project.selected!.items[index].uuid
                
                if globalApp!.project.selected!.items[index].componentType == .Shape {
                    mmView.drawBox.draw( x: r.x, y: r.y, width: r.width - 32, height: r.height, round: 10, borderSize: 2.0, fillColor : uuid == currentUUID ? skin.postFXColor : skin.normalInteriorColor, borderColor: skin.postFXColor )
                } else
                if globalApp!.project.selected!.items[index].componentType == .Shader {
                    mmView.drawBox.draw( x: r.x, y: r.y, width: r.width - 32, height: r.height, round: 10, borderSize: 2.0, fillColor : uuid == currentUUID ? skin.groundColor : skin.normalInteriorColor, borderColor: skin.groundColor )
                } else
                if globalApp!.project.selected!.items[index].componentType == .Camera3D {
                    mmView.drawBox.draw( x: r.x, y: r.y, width: r.width - 32, height: r.height, round: 10, borderSize: 2.0, fillColor : uuid == currentUUID ? skin.objectColor : skin.normalInteriorColor, borderColor: skin.objectColor)
                }
                
                mmView.drawText.drawTextCentered(mmView.openSans, text: globalApp!.project.selected!.items[index].libraryName, x: r.x, y: r.y, width: r.width - 31, height: r.height, scale: 0.4, color: uuid == currentUUID ? skin.selectedTextColor : skin.normalTextColor)
                
                componentMap[uuid] = MMRect(r)
                
                let items = [
                    MMMenuItem(text: "Rename", cb: { () in
                        getStringDialog(view: self.mmView, title: "Rename", message: "Shader name", defaultValue: globalApp!.project.selected!.items[index].libraryName, cb: { (value) -> Void in
                                let undo = globalApp!.currentEditor.undoComponentStart("Rename Shader")
                                let comp = globalApp!.project.selected!.items[index]
                                comp.libraryName = value
                                globalApp!.currentEditor.setComponent(comp)
                                globalApp!.currentEditor.undoComponentEnd(undo)
                                self.mmView.update()
                            } )
                    } ),
                    MMMenuItem(text: "Remove", cb: { () in
                        globalApp!.project.selected!.items.remove(at: index)
                        self.needsUpdate = true
                        self.mmView.update()
                    })
                ]
                menus[index].setItems(items)
            } else {
                let items = [
                    MMMenuItem(text: "Add Shader", cb: { () in
                        let codeComponent = CodeComponent(.Shader, "Shader")
                        codeComponent.createDefaultFunction(.Shader)
                        globalApp!.project.selected!.items.append(codeComponent)
                        globalApp!.currentEditor.updateOnNextDraw(compile: true)
                        self.needsUpdate = true
                        self.mmView.update()
                    }),
                    MMMenuItem(text: "Add Shape", cb: { () in
                        let codeComponent = CodeComponent(.Shape, "Shape")
                        codeComponent.createDefaultFunction(.Shape)
                        globalApp!.project.selected!.items.append(codeComponent)
                        globalApp!.currentEditor.updateOnNextDraw(compile: true)
                        self.needsUpdate = true
                        self.mmView.update()
                    }),
                    MMMenuItem(text: "Add Camera", cb: { () in
                        self.clearSelection()
                        globalApp!.libraryDialog.show(ids: ["Camera3D"], cb: { (json) in
                            if let comp = decodeComponentFromJSON(json) {
                                comp.uuid = UUID()
                                globalApp!.project.selected!.items.insert(comp, at: 0)
                                self.setCurrent(component: comp)
                                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                                self.needsUpdate = true
                                self.mmView.update()
                            }
                        })
                    })
                ]
                menus[index].setItems(items)
            }
            
            menus[index].rect.x = rect.x + rect.width - 30
            menus[index].rect.y = r.y
            menus[index].rect.y = r.y
            menus[index].rect.width = 30
            menus[index].rect.height = 30

            r.y -= 31;
            
            if menus[index].states.contains(.Opened) == false {
                menus[index].draw()
            }
        }
        
        // Draw opened menus
        for index in 0..<tracks + 1 {
            if menus[index].states.contains(.Opened) {
                menus[index].draw()
            }
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
    
    // Returns a label for the given UUID
    func getLabel(_ uuid: UUID,_ text: String, skin: SceneTimelineSkin) -> MMTextLabel
    {
        var label = labels[uuid]
        if label == nil || label!.scale != skin.fontScale {
            label = MMTextLabel(mmView, font: mmView.openSans, text: text, scale: skin.fontScale, color: skin.normalTextColor)
            labels[uuid] = label
        }
        return label!
    }
    
    // Returns a label for the given string
    func getLabel(_ text: String, skin: SceneTimelineSkin) -> MMTextLabel
    {
        var label = textLabels[text]
        if label == nil || label!.scale != skin.fontScale {
            label = MMTextLabel(mmView, font: mmView.openSans, text: text, scale: skin.fontScale, color: skin.normalTextColor)
            textLabels[text] = label
        }
        return label!
    }
    
    /// Switches between open and close states
    func switchState() {
        if animating { return }
        let rightRegion = globalApp!.rightRegion!
        openWidth = globalApp!.editorRegion!.rect.width * 0.3
        
        if sceneGraphState == .Open {
            globalApp!.currentPipeline!.cancel()
            globalApp!.mmView.startAnimate( startValue: rightRegion.rect.width, endValue: 0, duration: 500, cb: { (value,finished) in
                self.currentWidth = value
                if finished {
                    self.animating = false
                    self.sceneGraphState = .Closed
                    
                    self.mmView.deregisterWidget(self)
                    self.deactivate()
                    globalApp!.topRegion?.graphButton.removeState(.Checked)
                }
            } )
            animating = true
        } else if rightRegion.rect.height != openWidth {
            globalApp!.currentPipeline!.cancel()
            globalApp!.mmView.startAnimate( startValue: rightRegion.rect.width, endValue: openWidth, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.sceneGraphState = .Open
                    self.activate()
                    self.mmView.registerWidget(self)
                    globalApp!.topRegion?.graphButton.addState(.Checked)
                }
                self.currentWidth = value
            } )
            animating = true
        }
    }
}
