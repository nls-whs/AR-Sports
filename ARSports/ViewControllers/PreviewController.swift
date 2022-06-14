//
//  PreviewController.swift
//  ARSports
//
//  Created by Frederic on 23/11/2019.
//  Copyright © 2019 Frederic. All rights reserved.
//

import Foundation
import UIKit
import QuickLook
import ARKit
import SceneKit
import CoreData
import MobileCoreServices
import SummerSlider

/// The PreviewController Class is the ViewController for the Editing Screen for Excercises.
/// It includes functions to edit and save excercises from and to  CoreData
class PreviewController: UIViewController {
    
    @IBOutlet weak var descField: UITextView!
    @IBOutlet weak var RepsField: UITextField!
    @IBOutlet weak var SetsField: UITextField!
    @IBOutlet weak var TitleField: UITextField!
    @IBOutlet weak var DetailsView: UIStackView!
    ///Using SummerSlider, a project by SuperbDerrick, that extends the slider to display selection marks.
    @IBOutlet weak var frameSlider: SummerSlider!
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var SegementedController: UISegmentedControl!
    @IBOutlet weak var SelectedImageView: UIView!
    @IBOutlet weak var SelectedImage: UIImageView!
    @IBOutlet weak var ChangeImage: UIButton!
    @IBOutlet weak var ChangeVideo: UIButton!
    
    var animationName: String = ""
    var animation: Array<[QuatfContainer]> = []
    var keyframes: Set<Int> = Set<Int>()
    var bodyposition: [simd_float3] = []
    var boneNames: [String] = []
    var root: SCNNode?
    var skeleton: SCNNode?
    var currentFrame: Int = 0
    var marks = Set<Float>()
    var weights : Dictionary<String, Float> = [:]
    var weightValue:[String:Float] = ["Very High": 0.97, "High":0.95, "Normal":0.93, "Low": 0.9]
    //Optional Animation Stuff
    var sets: Int = 3
    var reps: Int = 10
    var desc: String = ""
    var section: String = "None"
    var initPose: [simd_quatf] = []
    
    // The important bones
    let relevantBones: Array = [1,2,3,4,7,8,9,12,13,14,15,16,17,18,19,20,21,22,47,48,49,50,51,52,53,63,64,65,66]
    
    @IBOutlet var keyframeBtn: UIButton!
    @IBOutlet var SaveBtn: UIBarButtonItem!
    @IBOutlet weak var SectionButton: UIButton!
    @IBOutlet weak var SelectedBoneLabel: UILabel!
    @IBOutlet weak var BoneAccuracyView: UIStackView!
    @IBOutlet weak var AccuracyBtn: UIButton!
    @IBOutlet weak var ExportVideoBtn: UIBarButtonItem!
    
    @IBAction func SaveAction(_ sender: Any) {
        self.save()
    }
    
    /// function to update the current Frame of the Skeleton, gets triggered from the slider.
    @IBAction func frameChanged(_ sender: SummerSlider) {
        currentFrame = Int(sender.value)
        print(sender.value)
        updateFrame(frame: animation[currentFrame], body: bodyposition[currentFrame])
        //Update keyframe button
        keyframeBtn.isSelected = keyframes.contains(currentFrame)
    }
    
    /// Exports the current video and opens the system export dialog.
    @IBAction func ExportVideoClicked(_ sender: Any) {
        /// Get the videos url
        let documentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL: URL = documentDirURL.appendingPathComponent(self.animationName).appendingPathComponent("video").appendingPathExtension("mov")
        
        self.dismiss(animated: true, completion: { () -> Void in
            
            let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            let activityController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            activityController.popoverPresentationController?.barButtonItem = (sender as! UIBarButtonItem)
            // Search for the ViewController of the Main Application
            if var topController = keyWindow?.rootViewController {
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                topController.present(activityController, animated: true)
            }
        })
    }
    
    /// Toggles the visibility of different elements in the tabs.
    @IBAction func SegmentChanged(_ sender: Any) {
        switch SegementedController.selectedSegmentIndex
        {
        case 0:
            sceneView.isHidden = false
            frameSlider.isHidden = false
            keyframeBtn.isHidden = false
            DetailsView.isHidden = true
            BoneAccuracyView.isHidden = true

        case 1:
            sceneView.isHidden = true
            frameSlider.isHidden = true
            keyframeBtn.isHidden = true
            DetailsView.isHidden = false
            BoneAccuracyView.isHidden = true

        case 2:
            sceneView.isHidden = false
            frameSlider.isHidden = true
            keyframeBtn.isHidden = true
            DetailsView.isHidden = true
            BoneAccuracyView.isHidden = false
            resetRobot();

        default:
            break
        }
    }
    /// Add or removes keyframes
    @IBAction func toggleKeyframe(_ sender: UIButton) {
        if keyframes.contains(currentFrame){
            keyframes.remove(currentFrame)
            keyframeBtn.isSelected = false
        }else{
            keyframes.insert(currentFrame)
            keyframeBtn.isSelected = true
        }
        //Update the slider
        frameSlider.markPositions = keyframes.map{(100.0 / Float(animation.count)) * Float($0)}
        frameSlider.reDraw()
        
    }
    
    /// Opens a Popup and displays all given categories
    /// Note: These shouldnt be hardcoded in a non prototype solution.
    @IBAction func showDirectionPopup(_ sender: UIView) {
        let items = ["Beginner", "Normal", "Expert", "None"]
        let controller = ArrayChoiceTableViewController(items) { (name) in
            print("\(name) selected")
            self.section = name
            self.SectionButton.setTitle(name, for: .normal)
        }
            controller.modalPresentationStyle = .popover
            controller.preferredContentSize = CGSize(width: 300, height: 200)
        let presentationController = controller.presentationController as! UIPopoverPresentationController
            presentationController.sourceView = sender
            presentationController.sourceRect = sender.bounds
            presentationController.permittedArrowDirections = [.down, .up]
        self.present(controller, animated: true)
    }
    
    /// Opens a Popup and displays all given accuracy
    @IBAction func showAccuracyPopup(_ sender: UIButton) {
        let items = ["Very High", "High", "Normal", "Low"]
        let controller = ArrayChoiceTableViewController(items) { (name) in
            print("\(name) selected")
            self.AccuracyBtn.setTitle(name, for: .normal)
            //update the weights
            self.weights[self.SelectedBoneLabel.text!] = self.weightValue[name]
        }
            controller.modalPresentationStyle = .popover
            controller.preferredContentSize = CGSize(width: 300, height: 200)
        let presentationController = controller.presentationController as! UIPopoverPresentationController
            presentationController.sourceView = sender
            presentationController.sourceRect = sender.bounds
            presentationController.permittedArrowDirections = [.down, .up]
        self.present(controller, animated: true)
    }
    
    /// Prepares the view and init most content.
    override func viewDidLoad() {
        // 1: Load .obj file
        print(animation.count)
        frameSlider.markWidth = 2.0
        var markarray = keyframes.map{(100.0 / Float(animation.count)) * Float($0)}
        frameSlider.markPositions = markarray
        frameSlider.maximumValue = Float(animation.count - 1)
        
        boneNames = ARSkeletonDefinition.defaultBody3D.jointNames
        guard let urlPath = Bundle.main.url(forResource: "robot", withExtension: "usdz") else {
            return
        }
        let scene = try! SCNScene(url: urlPath, options: [.checkConsistency: true])
        
        let robot = scene.rootNode.childNode(withName: "biped_robot_ace", recursively: true)
        
        skeleton = robot?.childNode(withName: "biped_robot_ace_skeleton", recursively: true)
        
        root = skeleton?.childNode(withName: "root", recursively: true)
        ///backup the robot so we can reset it later
        backupRobot()
        
        updateFrame(frame:animation[currentFrame], body: bodyposition[currentFrame] )
        
        TitleField.text = animationName
        SetsField.text = sets.description
        descField.text = desc
        RepsField.text = reps.description
        SectionButton.setTitle(section, for: .normal)
        updateImage()
        initWeights()

        //robot.scale = Vector(10,10,10)
        // 2: Add camera node
        let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
        // 3: Place camera
            cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        // 4: Set camera on scene
        scene.rootNode.addChildNode(cameraNode)
        
        // 5: Adding light to scene
        let lightNode = SCNNode()
            lightNode.light = SCNLight()
            lightNode.light?.type = .omni
            lightNode.position = SCNVector3(x: 0, y: 10, z: 35)
        scene.rootNode.addChildNode(lightNode)
        
        // 6: Creating and adding ambien light to scene
        let ambientLightNode = SCNNode()
            ambientLightNode.light = SCNLight()
            ambientLightNode.light?.type = .ambient
            ambientLightNode.light?.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        // Allow user to manipulate camera
        sceneView.allowsCameraControl = true
        
        // Show FPS logs and timming
        // sceneView.showsStatistics = true
        
        // Set background color
        sceneView.backgroundColor = UIColor.white
        
        // Allow user translate image
        sceneView.cameraControlConfiguration.allowsTranslation = false
        
        // Set scene settings
        sceneView.scene = scene
    }
    
    /// Updates the skeleton to display the next pose.
    func updateFrame(frame: [QuatfContainer], body: simd_float3){
        var position = body
        var i = 0
        for joint in frame{
            let name = boneNames[relevantBones[i]]
            root?.childNode(withName: "\(name)", recursively: true)?.simdOrientation = joint.quaternion
            i += 1
        }
        position.z = 0
        root?.simdPosition = position
    }
    
    /// Gets called when you touch a bone to edit the accuracy
    /// Note: this is kinda work in progress, as seen in 282,  the bone should be highlighted, didnt work in time tho.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first as! UITouch
        if(touch.view == self.sceneView){
            let viewTouchLocation:CGPoint = touch.location(in: sceneView)
            guard let result = sceneView.hitTest(viewTouchLocation, options: nil).last else {
                return
            }
            SelectedBoneLabel.text = result.boneNode?.name?.description
            let value = weights[(result.boneNode?.name!.description)!]
            let valueIndex = weightValue.values.firstIndex(of: value!)
            self.AccuracyBtn.setTitle(weightValue.keys[valueIndex!], for: .normal)
            //highlightNode((result.boneNode!))

        }
    }
    
    /// Add a hardcoded 0.97 to all bones as accuracy value.
    func initWeights(){
        //Add all 3D Bones to a set
        let Bone3DNames = (ARSkeletonDefinition.defaultBody3D.jointNames)

        /// check weights
        if(weights.isEmpty){
            weights = Dictionary.init()
            for name in Bone3DNames {
                weights[name] = 0.97
            }
        }
    }
    
    /// Resets the skeleton pose.
    func resetRobot(){
        for (i,boneRot) in initPose.enumerated(){
            let name = boneNames[relevantBones[i]]
            root?.childNode(withName: "\(name)", recursively: true)?.simdOrientation = boneRot
        }
        root?.simdPosition = simd_float3.init()
        
    }
    
    /// Gets the normal init pose and saves it in the beginning
    func backupRobot(){
       
        for i in 0...(relevantBones.count - 1){
            let name = boneNames[relevantBones[i]]
            initPose.append((root?.childNode(withName: "\(name)", recursively: true)!.simdOrientation)!)
        }
    }
    @IBAction func ChangeVideoClicked(_ sender: Any) {
        videoTapped()
    }
    
    @IBAction func ChangeImageClicked(_ sender: Any) {
        imageTapped()
    }
    
    /// Saves the edits to the current Excercise.
    func save() {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        // 1
        let managedContext =
            appDelegate.persistentContainer.viewContext
        // 2
        
        // fetch
        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest.init(entityName: "AnimationCore")
        fetchRequest.predicate = NSPredicate(format: "title = %@", animationName)
        do{
            let test = try managedContext.fetch(fetchRequest)
            let objectUpdate = test[0] as! NSManagedObject
            //Keyframes
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(keyframes){
                objectUpdate.setValue(encoded, forKey: "keyframes")
            }
            
            if let weightsencoded = try? encoder.encode(weights){
                objectUpdate.setValue(weightsencoded, forKey: "weights")
            }
            
            self.desc = descField.text
            self.reps = Int(RepsField?.text ?? "10")!
            self.sets = Int(SetsField?.text ?? "3")!
            
            objectUpdate.setValue(desc, forKeyPath: "desc")
            objectUpdate.setValue(reps, forKeyPath: "reps")
            objectUpdate.setValue(sets, forKeyPath: "sets")
            objectUpdate.setValue(section, forKeyPath: "section")
            
        }catch{
            print(error)
        }
        
        // 4
        do {
            try managedContext.save()
            
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    @objc func imageTapped() {
        let importMenu = UIDocumentPickerViewController(documentTypes: [String(kUTTypeBMP), String(kUTTypePNG), String(kUTTypeJPEG), String(kUTTypeImage)], in: .import)
            importMenu.delegate = self
            importMenu.modalPresentationStyle = .formSheet
        self.present(importMenu, animated: true, completion: nil)
    }
    
    @objc func videoTapped() {
        let importMenu = UIDocumentPickerViewController(documentTypes: [String(kUTTypeMPEG), String(kUTTypeMPEG4), String(kUTTypeVideo), String(kUTTypeQuickTimeMovie)], in: .import)
            importMenu.delegate = self
            importMenu.modalPresentationStyle = .formSheet
        self.present(importMenu, animated: true, completion: nil)
    }
    
    /// Replaces the image of the excercise.
    func updateImage(){
        let DirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(animationName)
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: DirURL, includingPropertiesForKeys: nil)
            let covers = directoryContents.filter{ $0.deletingPathExtension().lastPathComponent == "cover" }
            if covers.count > 0 {
                do {
                    let imageData = try Data(contentsOf: covers.first!)
                    SelectedImage.image = UIImage(data: imageData)
                } catch {
                    print("Error loading image : \(error)")
                }
            }
        } catch {
            print("Error loading image : \(error)")
        }
    }
}
/// Extension, reacts to DocumentPicker to handle imports
extension PreviewController : UIDocumentPickerDelegate,UINavigationControllerDelegate  {
    
    func documentMenu(_ documentMenu: UIDocumentPickerViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
     /// Method to handle imports.
     public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let sourceURL = urls.first else { return }
        print("import result : \(sourceURL)")
        if(sourceURL.pathExtension == "HEIC" || sourceURL.pathExtension == "jpeg"){
            
        
        // Create Animation Folder if it doesnt exists already
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let docURL = URL(string: documentsDirectory)!
        let dataPath = docURL.appendingPathComponent(animationName)
        if !FileManager.default.fileExists(atPath: dataPath.absoluteString) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.absoluteString, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription);
            }
        }
        // Duplicate picture and move it to the new folder
        let ext = sourceURL.pathExtension
        let destURL = dataPath.appendingPathComponent("cover").appendingPathExtension(ext)
         if FileManager.default.fileExists(atPath: destURL.absoluteString) {
            do {
                try FileManager.default.removeItem(at: URL(fileURLWithPath: destURL.absoluteString))
            } catch {
                print(error.localizedDescription);
            }
        }
        do { try FileManager.default.copyItem(at: sourceURL, to: URL(fileURLWithPath: destURL.absoluteString)) } catch {
            print("ERROR")}
        updateImage()
            
        } else {
            // Create Animation Folder if it doesnt exists already
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsDirectory = paths[0]
            let docURL = URL(string: documentsDirectory)!
            let dataPath = docURL.appendingPathComponent(animationName)
            if !FileManager.default.fileExists(atPath: dataPath.absoluteString) {
                do {
                    try FileManager.default.createDirectory(atPath: dataPath.absoluteString, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print(error.localizedDescription);
                }
            }
            // Duplicate picture and move it to the new folder
            let ext = sourceURL.pathExtension
            let destURL = dataPath.appendingPathComponent("video").appendingPathExtension(ext)
             if FileManager.default.fileExists(atPath: destURL.absoluteString) {
                do {
                    try FileManager.default.removeItem(at: URL(fileURLWithPath: destURL.absoluteString))
                } catch {
                    print(error.localizedDescription);
                }
            }
            do { try FileManager.default.copyItem(at: sourceURL, to: URL(fileURLWithPath: destURL.absoluteString)) } catch {
                print("ERROR")}
        }
    }


    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
                print("view was cancelled")
                dismiss(animated: true, completion: nil)
        }
}

/// Extension of the PreviewController:
/// Experiment to highlight a bone, didnt worked out right now, seems like the material  wasn't correct.
extension PreviewController{
    
        
    func createLineNode(fromPos origin: SCNVector3, toPos destination: SCNVector3, color: UIColor) -> SCNNode {
        let line = lineFrom(vector: origin, toVector: destination)
        let lineNode = SCNNode(geometry: line)
        let planeMaterial = SCNMaterial()
            planeMaterial.diffuse.contents = color
            planeMaterial.emission.contents = UIColor.green
            line.materials = [planeMaterial]

        return lineNode
    }

    func lineFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNGeometry {
        let indices: [Int32] = [0, 1]

        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)

        return SCNGeometry(sources: [source], elements: [element])
    }


    func highlightNode(_ node: SCNNode) {
        let (min, max) = node.boundingBox
        let zCoord = node.position.z
        let topLeft = SCNVector3Make(min.x, max.y, zCoord)
        let bottomLeft = SCNVector3Make(min.x, min.y, zCoord)
        let topRight = SCNVector3Make(max.x, max.y, zCoord)
        let bottomRight = SCNVector3Make(max.x, min.y, zCoord)


        let bottomSide = createLineNode(fromPos: bottomLeft, toPos: bottomRight, color: .yellow)
        let leftSide = createLineNode(fromPos: bottomLeft, toPos: topLeft, color: .yellow)
        let rightSide = createLineNode(fromPos: bottomRight, toPos: topRight, color: .yellow)
        let topSide = createLineNode(fromPos: topLeft, toPos: topRight, color: .yellow)

        [bottomSide, leftSide, rightSide, topSide].forEach {
            $0.name = "kHighlightingNode" // Whatever name you want so you can unhighlight later if needed
            node.addChildNode($0)
        }
    }

    func unhighlightNode(_ node: SCNNode) {
        let highlightningNodes = node.childNodes { (child, stop) -> Bool in
            child.name == "kHighlightingNode"
        }
        highlightningNodes.forEach {
            $0.removeFromParentNode()
        }
    }
    
}
