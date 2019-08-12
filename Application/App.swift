//
//  App.swift
//  Framework
//
//  Created by Markus Moenig on 9/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
//import CloudKit

// Necessary for undo / redo situations
var globalApp : App? = nil

class App
{
    var mmView          : MMView
    var leftRegion      : LeftRegion?
    var topRegion       : TopRegion?
    var rightRegion     : RightRegion?
    var bottomRegion    : BottomRegion?
    var editorRegion    : EditorRegion?
    
    var shapeFactory    : ShapeFactory = ShapeFactory()
    var materialFactory : MaterialFactory = MaterialFactory()
    var nodeGraph       : NodeGraph
    
    var changed         : Bool = false
    
    let gizmo           : Gizmo
    let closeButton     : MMButtonWidget!
    
    //let compute         : MMCompute = MMCompute()
    
    let camera          : Camera!
    let timeline        : MMTimeline!
    
    let mmFile          : MMFile!
    
    #if os(OSX)
    var viewController  : NSViewController?
    var gameController  : NSViewController?
    #else
    var viewController  : ViewController?
    #endif
    
    var properties      : [String:Float] = [:]
    
    init(_ view : MMView )
    {
        mmView = view
        mmFile = MMFile( view )
        
        nodeGraph = NodeGraph()
        
        // --- Reusable buttons
        
        // Close Button
        let state = mmView.drawCustomState.createState(source:
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
        
        closeButton = MMButtonWidget(mmView, customState: state)
        // ---
        /*
        let json = nodeGraph.encodeJSON()
        
        if let jsonData = json.data(using: .utf8)
        {
            print( json )

            do {
                if (try JSONDecoder().decode(NodeGraph.self, from: jsonData)) != nil {
                print( "yes" )
                }
            }
            catch {
                print("Error is : \(error)")
            }
        }*/
        
        gizmo = Gizmo(view)
        
        camera = Camera()
        timeline = MMTimeline(view)

        nodeGraph.setup(app: self)
        gizmo.app = self

        topRegion = TopRegion( mmView, app: self )
        leftRegion = LeftRegion( mmView, app: self )
        rightRegion = RightRegion( mmView, app: self )
        bottomRegion = BottomRegion( mmView, app: self )
        editorRegion = EditorRegion( mmView, app: self )
        
        mmView.leftRegion = leftRegion
        mmView.topRegion = topRegion
        mmView.rightRegion = rightRegion
        mmView.bottomRegion = bottomRegion
        mmView.editorRegion = editorRegion

        nodeGraph.activate()
        
        setChanged()

        
        /*
        let query = CKQuery(recordType: "SampleProjects", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.shapez.documents").publicCloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            records?.forEach({ (record) in
                
                print(record)
                
                // System Field from property
                //let recordName_fromProperty = record.recordID.recordName
                //print("System Field, recordName: \(recordName_fromProperty)")
                //let deeplink = record.value(forKey: "deeplink")
                //print("Custom Field, deeplink: \(deeplink ?? "")")
            })
        }*/
        
        globalApp = self
    }

    func loadFrom(_ json: String)
    {
//        print( json )
        if let jsonData = json.data(using: .utf8) {
            
            /*
            do {
                if (try JSONDecoder().decode(NodeGraph.self, from: jsonData)) != nil {
                    print( "yes" )
                }
            }
            catch {
                print("Error is : \(error)")
            }*/
            
            if let graph =  try? JSONDecoder().decode(NodeGraph.self, from: jsonData) {
                
                if nodeGraph.maximizedNode != nil {
                    nodeGraph.maximizedNode!.maxDelegate!.deactivate()
                }

                nodeGraph.deactivate()
                
                nodeGraph = graph
                
                /*
                var nodes : [Node] = []
                
                for n in nodeGraph.nodes {
                    if n.type != "Object" && n.type != "Scene" && n.type != "Game" {
                        var found = false
                        for nn in nodeGraph.nodes {
                            if let subset = nn.subset {
                                if subset.contains(n.uuid) {
                                    found = true
                                }
                            }
                        }
                        if found == false {
                            print("not found", n.name, n.type)
                        } else {
                            nodes.append(n)
                        }
                    } else {
                        nodes.append(n)
                    }
                }
                nodeGraph.nodes = nodes
                */
                
                nodeGraph.setup(app: self)
                nodeGraph.activate()
                nodeGraph.updateNodes()
            }
        }
    }
    
    func setChanged()
    {
        changed = true
        nodeGraph.maximizedNode?.maxDelegate?.setChanged()
    }
    
    func play()
    {
        topRegion!.playButton.isDisabled = true
        topRegion!.playButton.removeState(.Checked)
        topRegion!.playButton.removeState(.Hover)

        #if os(OSX)
        let mainStoryboard = NSStoryboard.init(name: "Main", bundle: nil)
        let controller = mainStoryboard.instantiateController(withIdentifier: "GameWindow")
        
        let appDelegate = (NSApplication.shared.delegate as! AppDelegate)
        appDelegate.gameView.app.load( nodeGraph.encodeJSON() )
        
        if let windowController = controller as? NSWindowController {
            windowController.showWindow(self)
        }
        #elseif os(iOS)
        
        let widgets = mmView.widgets
        
        mmView.widgets = []
        let gameApp = GameApp( mmView, embeddedCB: {
            
            self.topRegion!.playButton.isDisabled = false
            self.mmView.widgets = widgets
            self.mmView.unlockFramerate(true)
            
            self.mmView.leftRegion = self.leftRegion
            self.mmView.topRegion = self.topRegion
            self.mmView.rightRegion = self.rightRegion
            self.mmView.bottomRegion = self.bottomRegion
            self.mmView.editorRegion = self.editorRegion
        } )
        gameApp.load( nodeGraph.encodeJSON() )
        #endif
    }
    
    
    /// Updates the preview of the given object
    func updateObjectPreview(_ object: Object)
    {
        if nodeGraph.maximizedNode != nil {
            
            if object.instanceOf == nil {
                // --- This is an object
                if let objectMaxDelegate = object.maxDelegate as? ObjectMaxDelegate {
                    if nodeGraph.maximizedNode === object {
                        // Make sure the currently maximized node is the object
                        objectMaxDelegate.update(true, updateLists: true)
                    }
                }
            } else {
                // --- This is an instance, we need to update the scene of the instance
                if let scene = nodeGraph.getSceneOfInstance(object.uuid) {
                    if let sceneMaxDelegate = scene.maxDelegate as? SceneMaxDelegate {
                        if nodeGraph.maximizedNode === scene {
                            sceneMaxDelegate.update(true, updateLists: true)
                        }
                    }
                }
            }
        } else {
            if object.instanceOf == nil {
                // --- Object, updates its preview
                object.updatePreview(nodeGraph: nodeGraph, hard: true)
                if let objectMaxDelegate = object.maxDelegate as? ObjectMaxDelegate {
                    objectMaxDelegate.shapeListChanged = true
                    objectMaxDelegate.materialListChanged = true
                }
            } else {
                // --- Instance, update the layer instance
                if let layer = nodeGraph.getSceneOfInstance(object.uuid) {
                    layer.updatePreview(nodeGraph: nodeGraph, hard: true)
                }
            }
        }
        setChanged()
    }
}


