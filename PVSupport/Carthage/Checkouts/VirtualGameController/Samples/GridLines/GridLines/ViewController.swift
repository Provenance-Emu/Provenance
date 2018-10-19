//
//  ViewController.swift
//  GridLines
//
//  Created by Rob Reuss on 10/1/17.
//  Copyright © 2017 Rob Reuss. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        //let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = SCNScene()
        
        sceneView.autoenablesDefaultLighting = false

        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
        
        let limit = 60
        let increment = 15
        let size = CGFloat(2.0)
        var color = UIColor.black
        var width = 0.01
        var height = 0.01
        var length = 0.01
        for x in stride(from: -limit, to: limit, by: increment) {
            width = 0.01
            height = 0.01
            length = 0.01
            for y in stride(from: -limit, to: limit, by: increment) {
                width = 0.01
                height = 0.01
                length = 0.01
                for z in stride(from: -limit, to: limit, by: increment) {
                    width = 0.01
                    height = 0.01
                    length = 0.01
                    /*
                    if x == -limit {
                        color = UIColor.blue
                        
                    } else if y == -limit {
                        color = UIColor.green
                        
                    } else if z == -limit {
                        color = UIColor.red
                        
                    }
                     */
                    let scaleValue = Float(0.10)
                    print("Placing plane at \(x) \(y) \(z)")
                    
                    let box = SCNBox(width: size, height: size, length: size, chamferRadius: 0)
                    let boxNode = SCNNode(geometry: box)
                    boxNode.scale = SCNVector3Make( scaleValue, scaleValue, scaleValue); //todo: make me swift
                    boxNode.simdPosition = float3(Float(x), Float(y), Float(z))
                    boxNode.opacity = 1.0
                    let material = SCNMaterial()
                    if z < 0 {
                        material.diffuse.contentsTransform = SCNMatrix4MakeScale(1,1,-1)
                        boxNode.geometry?.firstMaterial? = material
                    }

                    sceneView.scene.rootNode.addChildNode(boxNode)
                    
                    let plane = SCNText(string: "\(x),\(y),\(z)", extrusionDepth: 0.0)
                    plane.firstMaterial?.isDoubleSided = true
                    let textNode = SCNNode(geometry: plane)
                    textNode.scale = SCNVector3Make( scaleValue, scaleValue, scaleValue); //todo: make me swift
                    textNode.simdPosition = float3(Float(x + 1), Float(y), Float(z))
                    textNode.opacity = 1.0
                    textNode.geometry?.firstMaterial?.diffuse.contents = color
                    sceneView.scene.rootNode.addChildNode(textNode)
                }
            }
        }
        

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
