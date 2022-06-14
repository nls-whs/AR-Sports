//
//  ViewController.swift
//  ARSports
//
//  Created by Frederic on 20/11/2019.
//  Copyright © 2019 Frederic. All rights reserved.
//
import RealityKit
import ARKit
import SceneKit
import UIKit
import Combine
import CoreData
import AVKit
// SwiftSound by Adam Cichy: https://github.com/adamcichy/SwiftySound
import SwiftySound //used to play sounds easily



/// The ViewController Class, used as Mainscreen for the recording of excercises and for the training
/// Contains an ARView and coordinates the incoming events from ARSessionDelegate
class ViewController: UIViewController, ARSessionDelegate, UIPopoverPresentationControllerDelegate ,SavingViewControllerDelegate, ResultViewControllerDelegate {
    
    @IBOutlet var arView: ARView!
    @IBOutlet var savePoseBtn: UIButton!
    @IBOutlet var recordBtn: UIButton!
    @IBOutlet var compareBtn: UIButton!
    @IBOutlet weak var keyframeStatus: UILabel!
    @IBOutlet var videoPlayerContainer: UIView!
    @IBOutlet var stateView: UIStackView!
    @IBOutlet var counterLabel: UILabel!
    @IBOutlet var countdownLabel: UILabel!
    @IBOutlet var countdownBG: UIView!
    @IBOutlet var ARSCNView: ARSCNView!
    
    /// The 3D character to display.
    var character: BodyTrackedEntity?
    let characterOffset: SIMD3<Float> = [0, 0, 0]
    let characterAnchor = AnchorEntity()
    let optimizeAnchor = AnchorEntity()
    
    /// The important bones
    let relevantBones: Array = [1,2,3,4,7,8,9,12,13,14,15,16,17,18,19,20,21,22,47,48,49,50,51,52,53,63,64,65,66]
    
    /// Used while recording an excercise.
    var skeleton: ARSkeleton3D?
    var savedPose: [QuatfContainer] = []
    var recordedAnimation: Array<[QuatfContainer]> = []
    var recordedBodyPosition: [simd_float3] = []
    var recording: Bool = false;
    var newPose: Bool = false;
    var currentAnimation: Animation?
    var boneNames: [String] = []
    var rootBasedPositions: Array<[Simd4x4Container]> = []
    
    
    /// Animation Tracking / Training Modus
    var training: Bool = false
    var animationName: String = ""
    var animation: Array<[QuatfContainer]> = []
    var keyframes: Set<Int> = Set<Int>()
    var keys: Array<[QuatfContainer]> = []
    var AnimationBodyPositions: Array<simd_float3> = []
    var bodyPosKeys: Array<simd_float3> = []
    var currentKey: Int = 0
    var oldcurrentKey: Int = -1
    var rootPositionKeys: Array<[simd_float4x4]> = []
    
    /// VisualHelper
    @IBOutlet var VHContainer: SCNView!
    var VHroot: SCNNode?
    var VHskeleton: SCNNode?
    var VHrobot: SCNNode?
    var VHCamera: SCNNode?
    var bone3DNames: [String] = []
    var arcNode: SCNNode?
    
    /// VideoRecorder
    var recorder: VideoRecorder?
    var startime: TimeInterval?
    var framecount: Int64 = 0
    let fileName: String = "temp"
    var documentDirectory: URL?
    
    /// Excercise Information: Used while training
    var currentExcercise: Excercise?
    var currentRepetion: Repetition?
    var stateCircles: [UIImageView] = []
    var counterValue: Int = 0
    var startedExcercise: Bool = false
    var timer: Timer?
    var breaktimer: Timer?
    var recordTimer: Timer?
    var runCount = 6
    var breakCount = 30
    var sets: Int = 3
    var reps: Int = 10
    var desc: String = ""
    var weights: Dictionary<String, Float> = [:]
    var groundLevel: Float = 0
    var oldGroundLevel: Float = 0
    var expause: Bool = false
    
    /// Settings
    var trackingModelVisibility: Bool = false
    
    /// NOT USED: Compare Button
    @IBAction func compareBtnClicked(_ sender: UIButton) {
        print(comparePoses(first: savedPose, second: getRotations(skeleton: skeleton!, debug: false), pos: nil))
    }
    /// NOT USED: Save Pose Button
    @IBAction func savePoseClicked(_ sender: UIButton) {
        savedPose = getRotations(skeleton: skeleton!, debug: false)
    }
    
    /// The ToggleRecord function, gets called when the user starts or ends a recording.
    @IBAction func toggleRecord(_ sender: UIButton) {
        recording = !recording
        /// check whats the current state is
        /// User stops recording.
        if !recording {
            currentAnimation = Animation(frames: recordedAnimation, rootBasedPositions: rootBasedPositions)
            currentAnimation?.printAnimationInformation()
            recordedAnimation.removeAll()
            addAnimation()
            recordTimer?.invalidate()
            self.recorder?.endRecording {
                
                print("END OF RECORDING")
                self.framecount = 0
                
                let documentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let fileURL: URL = documentDirURL.appendingPathComponent(self.fileName).appendingPathExtension("mov")
                print("Filesize: \(fileURL.fileSize)")
                
            }
            
        }
            /// User starts recording.
        else
        {
            /// Init recording file.
            self.documentDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let fileURL = documentDirectory!.appendingPathComponent(self.fileName).appendingPathExtension("mov")
            print("File Path: \(fileURL.path)")
            do{ try FileManager.init().removeItem(at: fileURL) } catch { print("Cant delete")}
            let size = CGSize(width: 1920, height: 1440)
            /// Create recorder and start recording.
            self.recorder = VideoRecorder(outputURL: fileURL, size: size)!
            recorder?.startRecording()
            recordTimer = Timer.scheduledTimer(timeInterval: (1.0 / 24), target: self, selector: #selector(recordingTimer), userInfo: nil, repeats: true)
        }
        /// toggle button state.
        sender.isSelected = recording;
    }
    
    /// View got closed, kill all threads that are still running, currently only timers.
    override func viewDidDisappear(_ animated: Bool) {
        ///disable all timers, otherwise the controller wont be cleared.
        timer?.invalidate()
        recordTimer?.invalidate()
        breaktimer?.invalidate()
    }
    
    /// The viewDidAppear funtion, gets called when the view needs to be initialized.
    /// Initialize the arView, weights array and ARBodyTrackingConfiguration
    /// Since we are using the view in different scenarios, also toggle visibility between different modes.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.session.delegate = self
        /// Since arView doesnt have constraints yet, set the position and size
        arView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        /// Add all 3D Bones to a set
        bone3DNames = (ARSkeletonDefinition.defaultBody3D.jointNames)
        /// check weights
        if(weights.isEmpty){
            weights = Dictionary.init()
            for name in bone3DNames {
                weights[name] = 0.97
            }
        }
        
        if training {
            /// Switch modes and hide elements
            countdownBG.isHidden = false
            savePoseBtn.isHidden = true
            compareBtn.isHidden = true
            recordBtn.isHidden = true
            keyframeStatus.isHidden = true
            ARSCNView.isHidden = false
            title = animationName
            
            /// Filter framesArray
            for item in keyframes.sorted(){
                keys.append(animation[item])
                bodyPosKeys.append(AnimationBodyPositions[item])
            }
            
            /// create the current excercise
            currentExcercise = Excercise(name: animationName,count: reps, sets: sets)
            
            /// Now the key array has all the keyframe animation frames
            initVisualHelper();
            
            /// Launch Excercise Popup
            showModal()
        }
        
        /// If the iOS device doesn't support body tracking, raise a developer error for
        /// this unhandled case.
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }
        
        /// Run a body tracking configration.
        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
        
        /// Helpful when debugging, debugOptions contain a few nice options to debug the ARView.
        //arView.debugOptions = [ARView.DebugOptions.showFeaturePoints]
        
        arView.scene.addAnchor(characterAnchor)
        arView.scene.addAnchor(optimizeAnchor)
        
        /// Asynchronously load the 3D character.
        var cancellable: AnyCancellable? = nil
        cancellable = Entity.loadBodyTrackedAsync(named: "robot").sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Error: Unable to load model: \(error.localizedDescription)")
                }
                cancellable?.cancel()
        }, receiveValue: { (character: Entity) in
            if let character = character as? BodyTrackedEntity {
                /// Scale the character to human size
                character.scale = [1.0, 1.0, 1.0]
                self.character = character
                cancellable?.cancel()
            } else {
                print("Error: Unable to load model as BodyTrackedEntity")
            }
        })
        
    }
    
    /// The recordUser(name: String) function, records the video of the back camera and saves it in the Folder of the animation
    func recordUser(name: String){
        let documentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL: URL = documentDirURL.appendingPathComponent(self.animationName).appendingPathComponent(name).appendingPathExtension("mov")
        print("File Path: \(fileURL.path)")
        do{ try FileManager.init().removeItem(at: fileURL) } catch { print("Cant delete")}
        
        let size = CGSize(width: 1920, height: 1440)
        self.recorder = VideoRecorder(outputURL: fileURL, size: size)!
        recorder?.startRecording()
        
        recordTimer = Timer.scheduledTimer(timeInterval: (1.0 / 24), target: self, selector: #selector(recordingTimer), userInfo: nil, repeats: true)
    }
    
    /// function to load the video from the folder and play it in the VideoPlayerContrainer.
    func loadVideoContent() {
        let vp = VideoPlayer()
        let documentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL: URL = documentDirURL.appendingPathComponent(self.animationName).appendingPathComponent("video").appendingPathExtension("mov")
        
        videoPlayerContainer.addSubview(vp.view)
        vp.playVideo(videoURL: fileURL)
    }
    
    /// show Modal, opens a modal that displays the selected excercise.
    /// prepares the viewcontroller of the modal with the required information and loads the video from the main thread.
    func showModal() {
        let popvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ExStarterVCID") as! ExStarterVC
        popvc.popoverPresentationController?.delegate = self
        popvc.titleText = animationName
        /// popvc.repetitions = String(currentExcercise?.count ?? 0)
        popvc.repetitions = reps
        popvc.sets = sets
        popvc.desc = desc
        popvc.delegate = self
        let documentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL: URL = documentDirURL.appendingPathComponent(self.animationName).appendingPathComponent("video").appendingPathExtension("mov")
        popvc.video = fileURL
        self.present(popvc, animated: true)
    }
    
    /// Delegate that gets called when the training starts.
    /// Load and plays the excercise video, creates the state view, and starts the countdown and records the user.
    func startTrainingDelegate(sets: Int, reps: Int) {
        self.sets = sets
        self.reps = reps;
        /// load and play the video
        loadVideoContent();
        /// init stateview
        initStateView();
        ///show countdown
        countdownLabel.isHidden = false
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        /// start Recording
        recordUser(name: "exercise")
    }
    
    /// function to close the result popup window.
    func closeResult() {
        countdownBG.isHidden = true
        self.navigationController?.popViewController(animated: true)
    }
    
    /// function to show the result modal, updates its required vars and play a result sound for the user.
    func showResultModal() {
        let popvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ResultModalVC") as! ResultController
            popvc.popoverPresentationController?.delegate = self
            popvc.lastExcercise = currentExcercise!
            popvc.keys = keys
            popvc.delegate = self
        startedExcercise = false
        countdownBG.isHidden = false;
        self.present(popvc, animated: true)
        Sound.play(file: "result", fileExtension: "wav")
    }
    
    /// function to get the current time for the timer and write the frame to the recorder class.
    @objc func recordingTimer() {
        /// render all frames to a video
        let frame = arView.session.currentFrame?.capturedImage
        if(frame != nil){
            let timestamp = arView.session.currentFrame?.timestamp
            if framecount == 0 {
                self.startime = timestamp
                ///timestamp = TimeInterval.init(exactly: 0.0)
            }
            recorder?.writeFrame(forTexture: arView.session.currentFrame!.capturedImage, time: (startime?.advanced(by: timestamp!))!)
            framecount += 1
        }
    }
    /// function that gets called when the pause screen is toggled.
    @objc func pauseExTimer() {
        if(breakCount > 0){
            breakCount -= 1
            Sound.play(file: "count", fileExtension: "wav")
            countdownBG.isHidden = false;
            countdownLabel.isHidden = false;
            countdownLabel.text = breakCount.description
            // use the pause to get a better floorposition
            //updateFloorPosition()
            
        }else{
            breaktimer?.invalidate()
            expause = false
            countdownBG.isHidden = true;
            countdownLabel.isHidden = true;
            breakCount = 30
        }
    }
    
    /// fire timer function, called in the countdown.
    @objc func fireTimer() {
        runCount -= 1
        countdownLabel.text = runCount.description
        Sound.play(file: "count", fileExtension: "wav")
        /// find the bone closest to the ground // this is in modelspace of the tracked skeleton
        /// only standing so far, would ask for foot, hand, back, breast and get the lowest one.
        updateFloorPosition()
        
        
        if runCount == 0 {
            timer?.invalidate()
            countdownLabel.isHidden = true
            countdownBG.isHidden = true
            ///start session
            startedExcercise = true
        }
    }
    
    /// The updateFloorPosition function checks the right and left foot y position to calculate the floor high in the current context.
    /// This seems to minimize the error of placing the optimal skeleton in the scene.
    func updateFloorPosition() {
        var lowestValue: Float = 1000
        let rnode = (VHskeleton?.childNode(withName: "right_foot_joint", recursively: true))
        let lnode = (VHskeleton?.childNode(withName: "left_foot_joint", recursively: true))
        if(rnode != nil && lnode != nil){
            let y = (lnode!.worldPosition.y + rnode!.worldPosition.y) / 2.0
            if y < lowestValue {
                lowestValue = y
            }
            // Ground on Tracked Skeleton is current hip position - lowestValue
            self.groundLevel = lowestValue
        }
    }
    
    /// runs when the cancel button is pressed, closes the the view
    func cancelTrainingDelegate() {
        startedExcercise = false
        self.navigationController?.popViewController(animated: true)
    }
    
    /// add a observer for the settings, once its triggered, it will update the value in the viewmodel
    override func viewDidLoad() {
        super.viewDidLoad()
        registerSettingsBundle()
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
        defaultsChanged()
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTapOnVideo(_:)))
        videoPlayerContainer.addGestureRecognizer(tap)
        
    }
    
    /// helper function to put the video to the other side of the screen
    @objc func handleTapOnVideo(_ sender: UITapGestureRecognizer? = nil) {
        let sizeOfView = self.view.bounds.size
        var rect = videoPlayerContainer.frame
        if rect.origin.x != 0 {
            rect.origin.x = 0
            counterLabel.textAlignment = .right
        } else {
            rect.origin.x = sizeOfView.width - rect.size.width - 147
            counterLabel.textAlignment = .left
        }
        videoPlayerContainer.frame = rect
    }
    
    
    /// viewWillDisappear function, gets called when the view is going to be popped of the navigation stack.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    /** Main loop of the ARSession.
       Each time its called, it provides the ARAnchors that got updated.
       In this application, we only use the ARBodyAnchor, once we get it, we can extract the information we need.
       For recording, we extract and convert the rotation in quaternion, and save it.
       We also need to save the position of the rootbone, so we can later place the skeleton in a view.
       For training, it get the rotations and compare the poses, we count repetitions and sets, and update the visual helper skeleton. */
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            skeleton = bodyAnchor.skeleton
                        
            /// CASE: Recording an Exercise
            if recording && skeleton != nil {
                recordedAnimation.append(getRotations(skeleton: skeleton!))
                recordedBodyPosition.append(simd_make_float3(bodyAnchor.transform.columns.3))
                // record modeltransforms of back, shoulder, arm, leg
                rootBasedPositions.append(getMatrixes(skeleton: skeleton!))
                
                
            }
            
            /// CASE: Trainings Loop, analyze the exercise, and end training
            if startedExcercise && training && skeleton != nil && !expause {
                let result = comparePoses(first: keys[currentKey], second: getRotations(skeleton: skeleton!, debug: false), pos: simd_make_float3(bodyAnchor.transform.columns.3))
                /// Debug Keyframe Status
                if result{
                    keyframeStatus.backgroundColor = .green
                }else{
                    keyframeStatus.backgroundColor = .red
                }
                if counterValue == reps {
                    /// break for a few seconds
                    /// then return to the workout again if sets > 0
                    if(sets - 1 > 0){
                        sets -= 1
                        counterValue = 0
                        counterLabel.text = String(counterValue)
                        /// lets pause
                        expause = true
                        breaktimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(pauseExTimer), userInfo: nil, repeats: true)
                        
                    }else{
                        recordTimer?.invalidate()
                        self.recorder?.endRecording {
                            
                            print("END OF USER RECORDING")
                            self.framecount = 0
                            let documentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                            let fileURL: URL = documentDirURL.appendingPathComponent(self.animationName).appendingPathComponent("exercise").appendingPathExtension("mov")
                            print("Filesize: \(fileURL.fileSize)")
                        }
                        /// showing the Result Modal
                        showResultModal()
                    }
                }
            }
            
            /// Now update the visual helper and put the tracked skeleton on top of them video
            /// Update the position of the character anchor's position.
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            characterAnchor.position = bodyPosition + characterOffset
            /// Also copy over the rotation of the body anchor, because the skeleton's pose
            /// in the world is relative to the body anchor's rotation.
            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
            
            if let character = character, character.parent == nil {
                /// Attach the character to its anchor as soon as
                /// 1. the body anchor was detected and
                /// 2. the character was loaded.
                /// Check for the Settings for Display Tracking Mannequin
                if trackingModelVisibility {
                    characterAnchor.addChild(character)
                }
            }
            
            
            
            if training {
                /// WIP: This is just a Y fix, so motions to x or z will be off. (can be fixed with another camera ?)
                /// Possible Solution: Get the position of the floor. maybe when starting,
                /// taking the feets coordination - offset as floor position (or distance between root and foot
                /// to know where the floor should be)
                /// Its working okayish, just in standing atm. This could be fixed with checking the 4 common lowest bones (foot, back, breast, root)
                /// Right now, only standing excercises will work.
                let footL = (VHskeleton?.childNode(withName: "left_foot_joint", recursively: true))
                let footR = (VHskeleton?.childNode(withName: "right_foot_joint", recursively: true))
                let foot = (footL!.worldPosition.y > footR!.worldPosition.y) ? footL : footR
                let groundoffset = (foot?.worldPosition.y.distance(to: groundLevel))! 
                
                if startedExcercise {
                    if abs(groundoffset) < Float(0.08) {
                        VHskeleton?.simdPosition = simd_make_float3(bodyPosition.x, (VHskeleton?.simdPosition.y)!, bodyPosition.z)
                    }else {
                        VHskeleton?.simdPosition = simd_make_float3(bodyPosition.x, (bodyPosition.y + groundoffset), bodyPosition.z)
                    }
                }else{
                    VHskeleton?.simdPosition = bodyPosition
                }
                
                VHskeleton?.simdOrientation = Transform(matrix: bodyAnchor.transform).rotation
                VHskeleton?.simdScale = characterAnchor.scale
                VHCamera?.transform = SCNMatrix4(arView.cameraTransform.matrix)
                
                /// if motion tracking is fine, continue to update the visual helper skeleton
                if boneNames.count > 32 {
                    updateOptimizePose();
                }
                self.oldGroundLevel = groundoffset
            }
        }
    }
    
    /// Method to update the optimal skeletons pose to the next pose that needs to be displayed.
    func updateOptimizePose(){
        /// Working update pose function
        /// only update the rotations if the currentkey changed
        if(oldcurrentKey != currentKey){
            /// currentkey changed, update the old one
            oldcurrentKey = currentKey
            let currentKeyTransform = keys[currentKey]
            
            for (j, transform) in currentKeyTransform.enumerated() {
                /// Only use tracked bones, which are stored in the relevantBones Array
                let name = bone3DNames[relevantBones[j]]
                VHskeleton?.childNode(withName: "\(name)", recursively: true)?.simdOrientation = transform.quaternion
            }
        }
    }
    
    
    /// function that created the state view, displaying how many keyframes were missed or reached.
    func initStateView(){
        /// Instantiate a new Plot_Demo object (inherits and has all properties of UIView)
        for _ in keys {
            let image: UIImage = UIImage(systemName: "circle.fill")!
            let imageview = UIImageView(image: image)
                imageview.tintColor = .white
                imageview.frame = CGRect(x: 0,y: 0,width: 5,height: 5)
            stateCircles.append(imageview)
            stateView.addArrangedSubview(imageview)
        }
    }
    
    /// helper method to reset the state counter.
    func revertState(){
        var i = 0
        for _ in self.keys {
            stateCircles[i].tintColor = .white
            i += 1
        }
    }
    
    /// Initalize the visual helper, loads the 3D View and Model and set up the view.
    func initVisualHelper(){
        
        guard let urlPath = Bundle.main.url(forResource: "robot_trans", withExtension: "usdz") else {
            return
        }
        /// 1: Initialize VH Variables
        let PreviewScene = try! SCNScene(url: urlPath, options: [.checkConsistency: true])
        VHrobot = PreviewScene.rootNode.childNode(withName: "biped_robot_ace", recursively: true)
        VHskeleton = VHrobot?.childNode(withName: "biped_robot_ace_skeleton", recursively: true)
        VHroot = VHskeleton?.childNode(withName: "root", recursively: true)
        
        /// 2: Add camera node
        VHCamera = SCNNode()
        VHCamera?.camera = SCNCamera()
        VHCamera?.name = "Cam"
        /// 3: Place camera
        VHCamera?.position = SCNVector3(x: 0, y: 0, z: 0)
        /// 4: Set camera on scene
        PreviewScene.rootNode.addChildNode(VHCamera!)
        
        /// 5: Adding light to scene
        let lightNode = SCNNode()
            lightNode.light = SCNLight()
            lightNode.light?.type = .omni
            lightNode.position = SCNVector3(x: 0, y: 10, z: 35)
        PreviewScene.rootNode.addChildNode(lightNode)
        
        /// 6: Creating and adding ambien light to scene
        let ambientLightNode = SCNNode()
            ambientLightNode.light = SCNLight()
            ambientLightNode.light?.type = .ambient
            ambientLightNode.light?.color = UIColor.darkGray
        PreviewScene.rootNode.addChildNode(ambientLightNode)
        
        /// Allow user to manipulate camera
        ARSCNView.allowsCameraControl = false
        
        /// Show FPS logs and timming
        // sceneView.showsStatistics = true
        
        /// Show no background
        ARSCNView.backgroundColor = .clear
        PreviewScene.background.contents = UIColor.clear
        
        /// Allow user translate image
        ARSCNView.cameraControlConfiguration.allowsTranslation = false
        
        /// Set scene settings
        ARSCNView.scene = PreviewScene
        ARSCNView.pointOfView = VHCamera
    }
    
    
    
    /// Function to convert the float4x4 array of a skeleton to a quaternion array.
    /// It also prints all given bones + their rotation angle in radian if the debug parameter is true.
    func getRotations(skeleton: ARSkeleton3D, debug: Bool = false) -> [QuatfContainer] {
        
        var rotations: [QuatfContainer]  = []
        
        for (i, joint) in skeleton.jointLocalTransforms.enumerated() {
            if relevantBones.contains(i){
                let jointRotation = Transform(matrix: joint).rotation
                    rotations.append(QuatfContainer(jointRotation))
                if boneNames.count <= 33{
                    boneNames.append(ARSkeletonDefinition.defaultBody3D.jointNames[i])
                }
                //Also print the name + the rotation
                if debug {
                    print("\(ARSkeletonDefinition.defaultBody3D.jointNames[i]) : \(rad2deg(angle: jointRotation.angle))")
                }
            }
        }
        return rotations
    }
    
    /// Method to get all tracked bones matrixes of the given ARSkeleton3D
    func getMatrixes(skeleton: ARSkeleton3D, debug: Bool = false) -> [Simd4x4Container] {
        
        var matrixes: [Simd4x4Container]  = []
        
        for (i, joint) in skeleton.jointModelTransforms.enumerated() {
            if relevantBones.contains(i){
                matrixes.append(Simd4x4Container(joint))
            }
        }
        return matrixes
    }
    
    /// helper function to convert radian to degree.
    func rad2deg(angle: Float) -> Float{
        return angle * 180 / .pi
    }
    
    /// function to compare a zip of tracked rotations and optimized ones, also respects the bones weight too
    func compareZip(arr:Zip2Sequence<[QuatfContainer], [QuatfContainer]>) -> Bool{
        var i = 0
        for (left, right) in arr {
            let weight = weights[boneNames[i]]
            let dotAbs = (abs(dot(left.quaternion, right.quaternion)))
            let state = dotAbs >= weight!
            if !state {
                if i > 15 {
                    ARSCNView.isHidden = false
                }
                return false
            }
            i += 1
        }
        ARSCNView.isHidden = true
        return true
    }
    
    /// Main Algorithmus to compare two arrays of rotations, returns if its the same or not.
    func comparePoses(first: [QuatfContainer], second: [QuatfContainer], pos: simd_float3?) -> Bool {
        
        if currentRepetion == nil {
            self.currentRepetion = Repetition.init()
        }
        let oldKey = currentKey
        let arr = zip(first, second)
        let fits = compareZip(arr: arr)
        
        /// Add frame to the full animation array
        /// Animation contains every frame (rotations)
        /// fullposition contains every frame (postitions)
        currentRepetion?.animation.append(second)
        currentRepetion?.fullposition.append(pos!)
        
        if !fits {
            /// Check wether the currentKey was missed and we are already on the next one
            keyframeStatus.backgroundColor = .red
            /// TODO: add name to quaternion class
            let arr2 = zip(keys[(currentKey + 1) % keys.count], second)
            //let fitsNext = arr2.allSatisfy{dot($0.quaternion, $1.quaternion) >= 1 - 0.03}
            let fitsNext = compareZip(arr: arr2)
            if fitsNext {
                /// Mark the current keyframe as missed
                currentRepetion?.states.append(false)
                stateCircles[currentKey].tintColor = .red
                
                /// search for the best fitting frame for the last keyframe
                currentRepetion?.frames.append((currentRepetion?.findBestFit(pose: keys[(currentKey + 1) % keys.count]))!)
                /// Now add the currentKey + 1
                stateCircles[(currentKey + 1) % keys.count].tintColor = .green
                currentRepetion?.frames.append(second)
                currentRepetion?.position.append(pos!)
                currentRepetion?.buffer.removeAll()
                currentRepetion?.states.append(true)
                /// Go the the next key
                self.currentKey = ((currentKey + 2) % (keys.count))
                
            }else{
                /// add to the buffer
                currentRepetion?.buffer.append(second)
            }
            
        }else{
            /// Save the the current array to a Repitition Object
            keyframeStatus.backgroundColor = .green
            stateCircles[currentKey].tintColor = .green
            currentRepetion?.frames.append(second)
            currentRepetion?.position.append(pos!)
            currentRepetion?.buffer.removeAll()
            currentRepetion?.states.append(true)
            self.currentKey = ((currentKey + 1) % (keys.count))
        }
        /// check if currentKey is now 0
        if currentKey < oldKey && !(currentRepetion?.states.isEmpty)! {
            /// One Repetition is over
            currentExcercise?.repetitions.append(currentRepetion!)
            print(currentRepetion?.states)
            counterValue += 1
            counterLabel.text = String(counterValue)
            Sound.play(file: "rep", fileExtension: "wav")
            revertState()
            currentRepetion = nil
        }
        return fits
    }
    
    /// If the recording is done, this will open a dialog that ask for the name of the animation.
    /// On successful and legitim input, save the animation to the database, create the animation folder and store the recorded video in there.
    func addAnimation() {
        let alert = UIAlertController(title: "Aufnahme",
                                      message: "Name der Übung festlegen",
                                      preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Save", style: .default) {
            [unowned self] action in
            
            guard let textField = alert.textFields?.first,
                let nameToSave = textField.text else {
                    return
            }
            
            self.save(name: nameToSave)
            
            /// Saved animation to Database
            /// Create Animation Folder if it doesnt exists already
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsDirectory = paths[0]
            let docURL = URL(string: documentsDirectory)!
            let dataPath = docURL.appendingPathComponent(nameToSave)
            if !FileManager.default.fileExists(atPath: dataPath.absoluteString) {
                do {
                    try FileManager.default.createDirectory(atPath: dataPath.absoluteString, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print(error.localizedDescription);
                }
            }
            
            /// rename the temp file to the actual name
            do{
                try FileManager.default.moveItem(at: (self.documentDirectory?.appendingPathComponent(self.fileName).appendingPathExtension("mov"))!, to: (self.documentDirectory?.appendingPathComponent(nameToSave).appendingPathComponent("video").appendingPathExtension("mov"))!)
            } catch let error as NSError{
                print("Renaming file went wrong: \(error)")
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel){
                (action:UIAlertAction!) in
                print("Cancel button tapped");
                //On cancel also delete the video
                do{
                    try FileManager.default.removeItem(at: (self.documentDirectory?.appendingPathComponent(self.fileName).appendingPathExtension("mov"))!)
                } catch let error as NSError{
                    print("Deleting file went wrong: \(error)")
                }
        }
        
        alert.addTextField()
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        ///Show the Popup Window
        present(alert, animated: true)
    }
    
    /// save function that stores the animation in the "database".
    func save(name: String) {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        /// 1: gets the current context
        let managedContext =
            appDelegate.persistentContainer.viewContext
        /// 2: gets the table
        let entity =
            NSEntityDescription.entity(forEntityName: "AnimationCore",
                                       in: managedContext)!
        
        let ani = NSManagedObject(entity: entity,
                                  insertInto: managedContext)
        
        /// 3:  Now insert each value.
        /// Title
        ani.setValue(name, forKeyPath: "title")
        
        /// Save Frames
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(currentAnimation?.frames){
            ani.setValue(encoded, forKey: "frames")
        }
        
        /// Save RootBasedPositions
        if let encoded = try? encoder.encode(currentAnimation?.rootBasedPositions){
            ani.setValue(encoded, forKey: "rootBasedPositions")
        }
        
        /// Save BodyPosition
        if let bodyencoded = try? encoder.encode(recordedBodyPosition){
            ani.setValue(bodyencoded, forKey: "bodyposition")
        }
        
        /// create empty array for keyframes
        if let keyframesencoded = try? encoder.encode(Set<Int>()){
            ani.setValue(keyframesencoded, forKey: "keyframes")
        }
        
        /// Save Weights
        if let weightsencoded = try? encoder.encode(weights){
            ani.setValue(weightsencoded, forKey: "weights")
        }
        
        //let setBack: Array<[QuatfContainer]> = try! JSONDecoder().decode(Array<[QuatfContainer]>.self, from: setStringAsData!)
        
        // 4
        do {
            try managedContext.save()
            
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    
}

/// Container class for quatf to de- and encode.
/// Needed so we can use the the simd_quatf for the animation and calculation.
/// Can en- and decode, so we can save it in the database easily as json.
class QuatfContainer: Codable {
    
    let quaternion: simd_quatf
    
    init(_ quaternion: simd_quatf) {
        self.quaternion = quaternion
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let axis = try container.decode(SIMD3<Float>.self, forKey: .axis)
        let angle = try container.decode(Float.self, forKey: .angle)
        quaternion = simd_quatf(angle: angle, axis: axis)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(quaternion.axis, forKey: .axis)
        try container.encode(quaternion.angle, forKey: .angle)
    }
    
    enum CodingKeys: String, CodingKey {
        case axis
        case angle
    }
    
}


/// Container class for quatf to de- and encode.
/// Needed so we can use the the simd_quatf for the animation and calculation.
/// Can en and decode, so we can save it in the database easily as json.
class Simd4x4Container: Codable {
    
    let position: simd_float4x4
    
    init(_ pos: simd_float4x4) {
        self.position = pos
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let col0 = try container.decode(simd_float4.self, forKey: .column0)
        let col1 = try container.decode(simd_float4.self, forKey: .column1)
        let col2 = try container.decode(simd_float4.self, forKey: .column2)
        let col3 = try container.decode(simd_float4.self, forKey: .column3)
        position = simd_float4x4(col0, col1, col2, col3)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position.columns.0, forKey: .column0)
        try container.encode(position.columns.1, forKey: .column1)
        try container.encode(position.columns.2, forKey: .column2)
        try container.encode(position.columns.3, forKey: .column3)
        
    }
    
    enum CodingKeys: String, CodingKey {
        case column0
        case column1
        case column2
        case column3
    }
    
}



/// The Repetition Class: Defined by a buffer, all frames, the compared animation and positions.
class Repetition : Encodable, Decodable {
    
    var buffer: [[QuatfContainer]] = [[]]
    var frames: [[QuatfContainer]] = [[]]
    var animation: [[QuatfContainer]] = [[]]
    var position: [simd_float3] = []
    var fullposition: [simd_float3] = []
    var states: [Bool] = []
    
    // Method to find the best fit for a given pose in the buffer.
    func findBestFit(pose: [QuatfContainer]) -> [QuatfContainer] {
        var bestFit: [QuatfContainer] = []
        var bestScore: Float = 0.0
        for frame in buffer {
            let arr = zip(frame, pose)
            var i = 0;
            var overall: Float = 0.0
            for (left, right) in arr{
                let percent = dot(left.quaternion, right.quaternion)
                overall += percent
                i += 1
            }
            overall = overall / Float(i)
            if overall > bestScore {
                bestScore = overall
                bestFit = frame
            }
        }
        return bestFit
    }
}

/// The Excercise Class, a simple Object that has multiple repetitions and the name
class Excercise {
    var name: String = ""
    var repetitions: [Repetition] = []
    var count: Int = 0
    var sets: Int = 0
    
    init(name: String,count: Int, sets: Int) {
        self.count = count
        self.name = name
        self.sets = sets
    }
}


/// Extension for the URL Class, makes it easier to get the filesize and creation date directly from the URL.
extension URL {
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }
    
    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }
    
    var fileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
}

/// Delegate Protocol to start and cancel.
protocol SavingViewControllerDelegate
{
    func startTrainingDelegate(sets: Int, reps: Int)
    func cancelTrainingDelegate()
}

/// Delegate protocol to implement the closeResult() method.
protocol ResultViewControllerDelegate
{
    func closeResult()
}

/// Settings Extension, updates the TrackingModelVisibility Boolean.
/// If the UserDefault has more keys, more settings would get displayed
/// This extension is used to register the SettingsBundle and update the
/// trackingModelVisibility if the settings were changed.
extension ViewController {
    
    func registerSettingsBundle(){
        let appDefaults = [String:AnyObject]()
        UserDefaults.standard.register(defaults: appDefaults)
    }
    
    @objc func defaultsChanged(){
        if UserDefaults.standard.bool(forKey: "tracking_model_visibility") {
            self.trackingModelVisibility = true
            
        }
        else {
            self.trackingModelVisibility = false
        }
    }
    
}


/// NOT IN USE: ViewController Extension to handle all ARSCNViewDelegate Events.
extension ViewController : ARSCNViewDelegate {
    
    /// NOT IN USE: Method that calculates the angle between the leg and back.
    /// Used as proof of concept
    func getAnglesOfBody(skeleton: ARSkeleton3D){
        // Get all necessar
        let upLeg = skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "left_upLeg_joint"))
        let leg = skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "left_leg_joint"))
        let spine7 = skeleton.modelTransform(for: ARSkeleton.JointName(rawValue:"spine_7_joint"))
        
        let matrix1 = SCNNode()
            matrix1.transform = SCNMatrix4(upLeg!)
        let matrix2 = SCNNode()
            matrix2.transform = SCNMatrix4(spine7!)
        let matrix3 = SCNNode()
            matrix3.transform = SCNMatrix4(leg!)
        
        let legPosition = matrix3.position
        let spine7Position = matrix2.position
        //Compute the angle made by leg joint and spine7 joint
        //from the hip_joint (root node of the skeleton)
        let angle = calculateAngleBetweenBones(bone1: legPosition, bone2: spine7Position)
        print("angle : ", angle * 180.0 / Float.pi)
        
        //Update the geometry of the feedback node
        arcNode?.removeFromParentNode()
        createArc(angle: CGFloat(angle))
        arcNode?.position = matrix1.position
        arcNode?.transform = SCNMatrix4Mult(arcNode!.transform, SCNMatrix4MakeRotation(Float(Double.pi), 0, 1, 0))
        ARSCNView.scene.rootNode.addChildNode(arcNode!)
        
    }
    
    /// Helper Method to calculate the Angle between two given bones
    func calculateAngleBetweenBones(bone1: SCNVector3, bone2:SCNVector3) -> Float{
        let cosinus = (dotProduct(left: bone1, right: bone2) / getVectorLength(vec: bone1) / getVectorLength(vec: bone2))
        let angle = acos(cosinus)
        return angle
    }
    
    /// Creates a arc
    func createArc(angle: CGFloat){
        // create bezier path
        let path = UIBezierPath()
            path.move(to: CGPoint.zero)
            path.addArc(withCenter: CGPoint.zero, radius: 0.5, startAngle: 0, endAngle: angle, clockwise: true)
            path.flatness = 0
            path.close()
        // create shape and add material
        let shape = SCNShape(path: path, extrusionDepth: 0.01)
        let mat = SCNMaterial()
            mat.diffuse.contents = UIColor.orange
            shape.materials = [mat]
        // create node, scale it and set its opacity
        self.arcNode = SCNNode(geometry: shape)
            arcNode?.scale = SCNVector3(0.3,0.3,0.01)
            arcNode?.opacity = 0.5
    }
    
    /// Helper: Computes the dot product between two SCNVector3 vectors
    func dotProduct(left: SCNVector3, right: SCNVector3) -> Float {
        return left.x * right.x + left.y * right.y + left.z * right.z
    }
    /// Helper: Computes the dot product between two SCNVector3 vectors
    func getVectorLength(vec: SCNVector3) -> Float {
        return sqrt(pow(vec.x, 2) + pow(vec.y, 2) + pow(vec.z, 2))
    }
}



