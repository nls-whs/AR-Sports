//
//  ProgressController.swift
//  ARSports
//
//  Created by Frederic on 23/04/2020.
//  Copyright © 2020 Frederic. All rights reserved.
//

import Foundation
import ARKit
import SceneKit
import Speech
import RealityKit
import CoreData

/// ViewController of the Progress Tracker
class ProgressController : UIViewController,  ARSCNViewDelegate, SFSpeechRecognizerDelegate, UIPencilInteractionDelegate {
    @IBOutlet weak var arView: ARSCNView!
    @IBOutlet weak var DoneButton: UIBarButtonItem!
    @IBOutlet weak var PercentLabel: UILabel!
    let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let request = SFSpeechAudioBufferRecognitionRequest()
    var angleNode = SCNNode()
    var LArmAngleNode = SCNNode()
    var recognitionTask: SFSpeechRecognitionTask?
    var selectedArea: Int = 2
    var angle: Float = 0
    enum Area: Int {
        case Back = 0
        case LeftArm = 1
        case RightArm = 2
    }
    
    
    /// SceneRenderers renderer function, to add nodes to the ARView
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // This visualization covers only detected planes.
        guard let bodyAnchor = anchor as? ARBodyAnchor else {
            
            return
        }
        
        angleNode.transform = SCNMatrix4(bodyAnchor.transform)
        
        // Make the plane a child node of the ARView
        node.addChildNode(angleNode)
    }
    
    @IBAction func DoneButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    /// Renderer function gets called each frame, calculates the angle between two bones, updates the UI
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let anchor = anchor as? ARBodyAnchor{
            
            let arSkeleton = anchor.skeleton
            let spine7 = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue:"spine_7_joint"))
            let matrixspin7 = SCNMatrix4(spine7!)
            let spine7Position = matrixspin7.getPosition()

            /// Check what area needs to be tracked and uses the right bones and calculation
            /// Should be converter in a future project to an algorithm that works with two given bones out of the box.
            switch selectedArea {
            case Area.Back.rawValue:
                let upLeg = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "left_upLeg_joint"))
                let leg = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "left_leg_joint"))
                let matrixupleg = SCNMatrix4(upLeg!)
                let matrixleg = SCNMatrix4(leg!)
                let legPosition = matrixleg.getPosition()
                    self.angle = SCNVector3.angleBetween(legPosition, spine7Position)
                    self.angleNode.removeFromParentNode()
                    self.angleNode = createArc(angle: CGFloat(angle), start: CGFloat(0))
                    node.addChildNode(angleNode)
                    angleNode.transform = matrixupleg
                    angleNode.transform = SCNMatrix4Mult(SCNMatrix4MakeRotation(Float.pi, 1, 0, 0), angleNode.transform)
                    angleNode.scale = SCNVector3(0.5, 0.5, 0.5)
                DispatchQueue.main.async {
                    self.PercentLabel.text = ((self.angle * 180.0 / Float.pi)).description
                }
                break;
            case Area.LeftArm.rawValue:
                let lshoulder = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "left_shoulder_1_joint"))
                let lhand = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "left_hand_joint"))
                let lshoulderMatrix = SCNMatrix4(lshoulder!)
                let lhandMatrix = SCNMatrix4(lhand!)
                let lshoulderPos = lshoulderMatrix.getPosition()
                let lhandPos = lhandMatrix.getPosition()
                let vectorShoulderHand = lhandPos - lshoulderPos
                    self.angle = Float.pi - SCNVector3.angleBetween(vectorShoulderHand, spine7Position)
                    self.angleNode.removeFromParentNode()
                    self.angleNode = createArc(angle: CGFloat(angle), start: CGFloat(0))
                    node.addChildNode(angleNode)
                    angleNode.transform = lshoulderMatrix
                    angleNode.scale = SCNVector3(0.5, 0.5, 0.5)
                    angleNode.transform = SCNMatrix4Mult(SCNMatrix4MakeRotation(-(Float.pi / 2), 1, 0, 0), angleNode.transform)
                DispatchQueue.main.async {
                    self.PercentLabel.text = ((self.angle * 180.0 / Float.pi)).description
                }
                break;
            case Area.RightArm.rawValue:
                let rshoulder = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "right_shoulder_1_joint"))
                let rhand = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "right_hand_joint"))
                let rshoulderMatrix = SCNMatrix4(rshoulder!)
                let rhandMatrix = SCNMatrix4(rhand!)
                let rshoulderPos = rshoulderMatrix.getPosition()
                let rhandPos = rhandMatrix.getPosition()
                let vectorShoulderHand = rhandPos - rshoulderPos
                    self.angle = Float.pi - SCNVector3.angleBetween(vectorShoulderHand, spine7Position)
                    self.angleNode.removeFromParentNode()
                    self.angleNode = createArc(angle: CGFloat(angle), start: CGFloat(0))
                    node.addChildNode(angleNode)
                    angleNode.transform = rshoulderMatrix
                    angleNode.scale = SCNVector3(0.5, 0.5, 0.5)
                    angleNode.transform = SCNMatrix4Mult(SCNMatrix4MakeRotation(-(Float.pi / 2), 1, 0, 0), angleNode.transform)
                DispatchQueue.main.async {
                    self.PercentLabel.text = ((self.angle * 180.0 / Float.pi)).description
                }
                break;
            default:
                break;
            }
            

            //Update the color display depending on the angle
            //var color = UIColor.red
            //if(angle < Float.pi / 2.0){//90°
            //    color = UIColor.green
            //}
            //if(angle > Float.pi * 2.0 / 3.0){//120°
            //    color = UIColor.green
            //}
            
        }
    }
    
    /// When the Apple Pencil was tapped, save the angle
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        save(angleValue: self.angle)
    }
    
    /// Creates an arc from the given angle  and returns it as node
    func createArc(angle: CGFloat, start: CGFloat) -> SCNNode{
        // create bezier path
        let path = UIBezierPath()
        path.move(to: CGPoint.zero)
        path.addArc(withCenter: CGPoint.zero, radius: 0.5, startAngle: start, endAngle: angle, clockwise: true)
        path.flatness = 0
        path.close()
        // create shape
        let shape = SCNShape(path: path, extrusionDepth: 0.01)
        let mat = SCNMaterial()
        
        mat.diffuse.contents = UIColor.orange
        
        
        shape.materials = [mat]
        // create node
        let node = SCNNode(geometry: shape)
        node.scale = SCNVector3(0.3,0.3,0.01)
        node.opacity = 0.5
        return node
    }
    
    
    override func viewDidLoad() {
        arView.delegate = self
        arView.showsStatistics = true
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }
        arView.scene.rootNode.addChildNode(angleNode)
        arView.scene.rootNode.addChildNode(LArmAngleNode)
        
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        view.addInteraction(pencilInteraction)

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let configuration = ARBodyTrackingConfiguration()
            configuration.automaticSkeletonScaleEstimationEnabled = true
            configuration.planeDetection = .horizontal
        arView.session.run(configuration)
        
    }
    
    /// save function that stores the progress in core data.
    func save(angleValue:Float) {
        
        let alert = UIAlertController(title: "Progress Tracker",
                                      message: "Fortschritt \((angleValue * 180.0 / Float.pi)) speichern ?",
            preferredStyle: .alert)
        
        
        let cancelAction = UIAlertAction(title: "Cancel",style: .cancel){(action:UIAlertAction!) in }
        
        
        let saveAction = UIAlertAction(title: "Save", style: .default){
                                        (action:UIAlertAction!) in
                                        
            guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
                    return
            }
            
            /// 1: gets the current context
            let managedContext =
                appDelegate.persistentContainer.viewContext
            /// 2: gets the table
            let entity =
                NSEntityDescription.entity(forEntityName: "ProgressTable",
                                           in: managedContext)!
            
            let data = NSManagedObject(entity: entity,
                                       insertInto: managedContext)
            
            /// 3:  Now insert each value.
            data.setValue(Date.init(), forKeyPath: "createdAt")
            switch self.selectedArea {
            case Area.Back.rawValue:
                data.setValue(angleValue, forKeyPath: "back")
                break;
            case Area.LeftArm.rawValue:
                data.setValue(angleValue, forKeyPath: "lShoulder")
                break;
            case Area.RightArm.rawValue:
                data.setValue(angleValue, forKeyPath: "rShoulder")
                break;
            default:
                break;
            }
            
            
            // 4
            do {
                try managedContext.save()
                
            } catch let error as NSError {
                print("Could not save. \(error), \(error.userInfo)")
            }
            /// Open new ProgressOverview
            self.dismiss(animated: true) {
                let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
                
                if var topController = keyWindow?.rootViewController {
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                    }
                    let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                    let navView = storyBoard.instantiateViewController(withIdentifier: "ProgressOverview") as! UINavigationController
                    let progressView = navView.viewControllers[0] as! ProgressOverviewController
                    progressView.section = self.selectedArea
                    topController.present(navView, animated: true, completion: nil)
                }
            }
                                        
        }

        alert.addAction(cancelAction)
        alert.addAction(saveAction)
        
        present(alert, animated: true)

    }
    
}
/// NOT USED: Experiment with Speech Control
extension ProgressController {
    
    func recordAndRecognizeSpeech() {
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            return print(error)
        }
        guard let myRecognizer = SFSpeechRecognizer() else {
            return
        }
        if !myRecognizer.isAvailable {
            // Recognizer is not available right now
            return
        }
        recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { result, error in
            if let result = result {
                
                let bestString = result.bestTranscription.formattedString
                var lastString: String = ""
                for segment in result.bestTranscription.segments {
                    let indexTo = bestString.index(bestString.startIndex, offsetBy: segment.substringRange.location)
                    lastString = String(bestString[indexTo...])
                }
                print(lastString)
                //self.checkForColorsSaid(resultString: lastString)
            } else if let error = error {
                print(error)
            }
        })
    }
    
}

/// Extensions for Vectors
extension SCNVector3 {
    func length() -> Float{
        return sqrt(pow(self.x, 2) + pow(self.y, 2) + pow(self.z, 2))
    }
    
    static func dotProduct(left: SCNVector3, right: SCNVector3) -> Float {
        return left.x * right.x + left.y * right.y + left.z * right.z
    }
    
    static func angleBetween(_ v1:SCNVector3, _ v2:SCNVector3)->Float{
        let cosinus = SCNVector3.dotProduct(left: v1, right: v2) / v1.length() / v2.length()
        let angle = acos(cosinus)
        return angle
    }
    /**
     * Subtracts two SCNVector3 vectors and returns the result as a new SCNVector3.
     */
    static func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
    }
}

/// Extensions for SCNMatrix4
extension SCNMatrix4 {
    
    public func toSimd() -> float4x4 {
        #if swift(>=4.0)
        return float4x4(self)
        #else
        return float4x4(SCNMatrix4ToMat4(self))
        #endif
    }
    public func toGLK() -> GLKMatrix4 {
        return SCNMatrix4ToGLKMatrix4(self)
    }
    
    func getPosition() -> SCNVector3 {
        return SCNVector3(self.toSimd().columns.3.x, self.toSimd().columns.3.y, self.toSimd().columns.3.z)
    }
    
}


