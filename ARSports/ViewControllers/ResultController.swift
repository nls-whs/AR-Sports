//
//  ResultController.swift
//  ARSports
//
//  Created by Frederic on 14/01/2020.
//  Copyright © 2020 Frederic. All rights reserved.
//

import Foundation
import UIKit
import QuickLook
import ARKit
import SceneKit
import CoreData
// Use a PieChart from the Charts Library by Daniel Cohen Gindi & Philipp Jahoda : https://github.com/danielgindi/Charts
import Charts

/// The ViewController of the Result Screen.
/// Includes functions to setup and prepare the result screen. 
class ResultController: UIViewController {
    
    @IBOutlet weak var slider: UISlider!
    @IBOutlet var repStepper: UIStepper!
    @IBOutlet var valueLabel: UILabel!
    @IBOutlet var sceneView: SCNView!
    @IBOutlet var chart: PieChartView!
    @IBOutlet var segmentControl: UISegmentedControl!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var successRate: UILabel!
    @IBOutlet weak var percentPerRep: UIStackView!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var resultText: UILabel!
    @IBOutlet weak var saveBtn: UIButton!
    @IBOutlet weak var exportBarBtn: UIBarButtonItem!
    
    var root: SCNNode?
    var cameraNode: SCNNode?
    var boneNames: [String] = []
    var keys: [[QuatfContainer]] = []
    var skeleton: SCNNode?
    var keyframes: Set<Int> = Set<Int>()
    var delegate: ResultViewControllerDelegate?
    var lastExcercise: Excercise?
    var currentFrame: Int = 0
    var currentRepetition: Int = 0
    var overallPercentage: Float = 0.0
    var overallCount: Float = 0.0
    var overallFits: Float = 0.0
    /// Monitor Mode
    var monitor: Bool = false
    var createdAt: Date?
    var animationKeyframe: [CAKeyframeAnimation] = []
    
    
    var worstBoneName: String = ""
    var worstBonePercentage: Float = 1.0
    var worstBoneAngle: Float = 1.0
    
    
    @IBOutlet var closeBtn: UIButton!
    /// The important bones
    let relevantBones: Array = [1,2,3,4,7,8,9,12,13,14,15,16,17,18,19,20,21,22,47,48,49,50,51,52,53,63,64,65,66]
    /// Area List, connects bone and BoneArea in a Dictionary
    var areaList: [String: Int] = [
        "spine_1_joint": 0,
        "spine_2_joint": 0,
        "spine_3_joint": 0,
        "spine_4_joint": 0,
        "spine_5_joint": 0,
        "spine_6_joint": 0,
        "spine_7_joint": 0,
        "left_upLeg_joint": 1,
        "left_leg_joint": 1,
        "left_foot_joint": 1,
        "right_upLeg_joint": 2,
        "right_leg_joint": 2,
        "right_foot_joint": 2,
        "left_shoulder_1_joint": 3,
        "left_arm_joint": 3,
        "left_forearm_joint": 3,
        "left_hand_joint": 3,
        "right_shoulder_1_joint": 4,
        "right_arm_joint": 4,
        "right_forearm_joint": 4,
        "right_hand_joint": 4
    ]
    /// the BoneAreas Enum, to identify the bones location
    enum BoneAreas: Int {
        case Back = 0
        case LeftLeg = 1
        case RightLeg = 2
        case LeftArm = 3
        case RightArm = 4
    }
    
    // gets called when the tab switched, toggles the visibility of elements in the view.
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        switch segmentControl.selectedSegmentIndex
        {
        case 0:
            valueLabel.isHidden = false
            slider?.isHidden = true
            successRate.text = "Erfolgsrate: " + (overallPercentage).description + "%"
            progressBar.isHidden = false
            percentPerRep.isHidden = true
            videoView.isHidden = false
            resultText.isHidden = false
            
        case 1:
            valueLabel.isHidden = false
            progressBar.isHidden = true
            successRate.text = "Erfolgsrate pro Wiederholung: "
            slider.isHidden = false
            percentPerRep.isHidden = false
            videoView.isHidden = true
            resultText.isHidden = true
            
        default:
            break
        }
    }
    
    /// gets called when the stepper was changed and a new repetition needs to be loaded.
    @IBAction func stepperValueChanged(_ sender: UIStepper) {
        valueLabel.text = (Int(sender.value) + 1).description
        currentRepetition = abs(Int(sender.value))
        let firstIndex = lastExcercise?.repetitions[currentRepetition].frames.firstIndex(where: { (x) -> Bool in
            x.count > 0
        }) ?? 0
        /// TODO: check if frame exists.
        updateFrame(frame: (lastExcercise?.repetitions[currentRepetition].frames[firstIndex])!)
        slider?.value = Float(firstIndex)
        slider.maximumValue = (Float(((lastExcercise?.repetitions[currentRepetition].animation.count)! - 1)))
        updateChart()
    }
    
    /// updates the current frame that was selected on the time slider
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        currentFrame = Int(sender.value)
        print(sender.value)
        /*if !(lastExcercise?.repetitions[currentRepetition].states[currentFrame])!{
         print("STATE FALSE")
         }
         */
        // TODO: out of array Crashes sometimes
        updateFrame(frame: (lastExcercise?.repetitions[currentRepetition].animation[currentFrame])!)
    }
    
    /// Save Button was pressed method, should save the excercise and dismiss the popup.
    @IBAction func saveBtnClicked(_ sender: Any) {
        saveExcercise();
        delegate?.closeResult()
        dismiss(animated: true, completion: nil)
    }
    
    /// View just appeared, initialise everything.
    override func viewDidLoad() {
        boneNames = ARSkeletonDefinition.defaultBody3D.jointNames
        /// play video
        playVideo()
        if(monitor){
            saveBtn.isHidden = true
        }
        /// Configure the chart.
        var dataEntries: [PieChartDataEntry] = []
            chart.delegate = self
        let stateCount = (lastExcercise?.repetitions[1].states.count)!
        var success = 0.0
        var fail = 0.0
        for (i, state) in (lastExcercise?.repetitions[1].states.enumerated())!{
            if state {
                success += (Double(100 / stateCount))
            } else {
                fail += (Double(100 / stateCount))
            }
        }
        
        let successEntry = PieChartDataEntry(value: success)
        let failEntry = PieChartDataEntry(value: fail)
            dataEntries.append(successEntry)
            dataEntries.append(failEntry)
        let chartDataSet = PieChartDataSet(entries: dataEntries)
            chartDataSet.colors = [NSUIColor].init(arrayLiteral:#colorLiteral(red: 0.2493869228, green: 0.7803921569, blue: 0.480382319, alpha: 0.8826199384),#colorLiteral(red: 1, green: 0.190380104, blue: 0.2108749623, alpha: 0.88))
        let chartData = PieChartData(dataSet: chartDataSet)
            chart.data = chartData
        /// Slider Initialize
        let count = (lastExcercise?.repetitions[0].frames.count)!
            slider.maximumValue = (Float(((lastExcercise?.repetitions[0].animation.count)! - 1)))
            slider.minimumValue = 1
        //Slider.markPositions = markarray
        
        /// Stepper Init
        //TODO: Why is it crashing on -1
        repStepper.maximumValue = Double(((lastExcercise!.repetitions.count) - 1 ))
        repStepper.autorepeat = true
        repStepper.wraps = true
        
        /// 1:Load the robot model
        guard let urlPath = Bundle.main.url(forResource: "robot", withExtension: "usdz") else {
            return
        }
        let scene = try! SCNScene(url: urlPath, options: [.checkConsistency: true])
        
        let robot = scene.rootNode.childNode(withName: "biped_robot_ace", recursively: true)
        
        skeleton = robot?.childNode(withName: "biped_robot_ace_skeleton", recursively: true)
        
        root = skeleton?.childNode(withName: "root", recursively: true)
        //robot.scale = Vector(10,10,10)
        /// 2: Add camera node
        self.cameraNode = SCNNode()
        self.cameraNode!.camera = SCNCamera()
        /// 3: Place camera
        self.cameraNode!.position = SCNVector3(x: 0, y: 0, z: 3)
        /// 4: Set camera on scene
        scene.rootNode.addChildNode(cameraNode!)
        /// 5: Adding light to scene
        let lightNode = SCNNode()
            lightNode.light = SCNLight()
            lightNode.light?.type = .omni
            lightNode.position = SCNVector3(x: 0, y: 10, z: 35)
        scene.rootNode.addChildNode(lightNode)
        /// 6: Creating and adding ambient light to scene
        let ambientLightNode = SCNNode()
            ambientLightNode.light = SCNLight()
            ambientLightNode.light?.type = .ambient
            ambientLightNode.light?.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        /// Allow user to manipulate camera
        sceneView.allowsCameraControl = true

        /// Show FPS logs and timming
        sceneView.showsStatistics = true
        
        /// Set background color
        sceneView.backgroundColor = UIColor.lightGray
        
        /// Users can translate the picture with touch gestures
        sceneView.cameraControlConfiguration.allowsTranslation = false
        
        /// Set scene settings
        sceneView.scene = scene
        /// Now calculate the Statistics
        calculateStatistics()
    }
    
    /// Close Button was pressed, delegate the close Result event, dismiss the window.
    @IBAction func closeBtnClicked(_ sender: Any) {
        delegate?.closeResult()
        dismiss(animated: true, completion: nil)
    }
    
    /// Method to simply calculate basic statistics
    func calculateStatistics(){
        /// Calculate how well the patient did the excercise
        for rep in lastExcercise!.repetitions {
            for (i,state) in rep.states.enumerated(){
                if state {
                    /// state == 1 => key was perfectly executed
                    self.overallFits += 1.0
                }else{
                    /// Figure out what bone was the most off
                    /// 1. get keyframe that was off
                    /// 2. get bone that was the most off
                    /// 3. count that bone
                    let missedframe = rep.frames[i] // frames only have the actual frame of the keyframe saved.
                    let worstBoneText = getWorstBone(frame: missedframe, keyframe: i)
                    resultText.text = resultText.text! + worstBoneText
                }
                self.overallCount += 1.0
            }
        }
        
        /// WIP: Calculate a tip for the user, so they know what they need to work on.
        var analyseTip: String;
        var bonearea: Int = areaList[worstBoneName] ?? -1
        switch bonearea {
        case BoneAreas.Back.rawValue:
            analyseTip = "Achten Sie darauf den Rücken gerade zu halten. "
            break;
        case BoneAreas.LeftLeg.rawValue:
            analyseTip = "Achten Sie auf ihre Haltung des linken Beins und Knies."
            break;
        case BoneAreas.RightLeg.rawValue:
            analyseTip = "Achten Sie auf ihre Haltung des rechten Beins und Knies."
            break;
        case BoneAreas.LeftArm.rawValue:
            analyseTip = "Achten Sie auf die Haltung des linken Arms"
            break;
        case BoneAreas.RightArm.rawValue:
            analyseTip = "Achten Sie auf die Haltung des rechten Arms"
            break;
        default:
            analyseTip = resultText.text!
            break;
        }
        resultText.text = analyseTip;
        
        /// calculate the overall percentage, how well the workout was.
        /// since  100% is hardly reachable, we might need to fix the percentage later to round upwards.
        self.overallPercentage = (self.overallFits / self.overallCount) * 100
        print("Overall Percentage \(overallPercentage * 100)")
        
        /// update the progressbar, showing how good the user performed.
        progressBar.progress = (overallPercentage / 100)
        /// add the percentage text.
        successRate.text = successRate.text! + overallPercentage.debugDescription + "%"
    }
    
    /// Method to play the video that was just recorded.
    func playVideo(){
        let documentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var fileURL: URL = documentDirURL.appendingPathComponent(lastExcercise!.name).appendingPathComponent("exercise").appendingPathExtension("mov")
        
        if monitor{
            /// Get the created date and look for the saved video
            /// Saved Videos are currently stored in the Saved folder and their name has the following scheme
            /// excerciseName_createdAtTimeFormatted.mov
            let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd-MM-yyyy-HH:mm:ss"
            let dateInFormat = dateFormatter.string(from: createdAt!)
            let SavedFolderURL: URL = documentDirURL.appendingPathComponent("Saved")
                fileURL = SavedFolderURL.appendingPathComponent("\(lastExcercise!.name)" + "_" + "\(dateInFormat)").appendingPathExtension("mov")
        }
        print(fileURL)
        let vp = VideoPlayer()
        vp.playLargerVideo(videoURL: fileURL)
        videoView.addSubview(vp.view)
    }
    
    
    /// Method to determine the worst performing bone.
    /// Basically, checks the given rotations of the frame with the optimal rotations, and saves the least accurate one.
    /// Important: Only check tracked bones, interpolated bones can always vary, so they are excluded in this calculation.
    func getWorstBone(frame: [QuatfContainer], keyframe: Int) -> String{
        if (frame.count == 0 || keys.count == 0){
            return ""
        }
        var worstpercentage: Float = 1.0
        var worstInt = 0
        var i = 0
        for (left, right) in zip(frame, keys[keyframe]) {
            let percent = dot(left.quaternion, right.quaternion)
            if worstpercentage > percent{
                worstInt = i
                worstpercentage = percent
            }
            i += 1
        }
        /// update the worstBoneName and the percentage.
        if(worstpercentage < self.worstBonePercentage){
            self.worstBoneName = boneNames[relevantBones[worstInt]]
            self.worstBonePercentage = worstpercentage
            
        }
        /// return a combined string.
        return "\n \(boneNames[relevantBones[worstInt]]) with \(worstpercentage)"
        
    }
    
    /// helper functionto convert radian to degree.
    func rad2deg(angle: Float) -> Float{
        return angle * 180 / .pi
    }
    
    /// update the chart, gets called when the repition was changed in the details tab.
    /// basically the same code that was called in the initial viewdidload method.
    func updateChart(){
        var dataEntries: [PieChartDataEntry] = []
        let stateCount = (lastExcercise?.repetitions[currentRepetition].states.count)!
        var success = 0.0
        var fail = 0.0
        for (i, state) in (lastExcercise?.repetitions[currentRepetition].states.enumerated())!{
            if state {
                success += (Double(100 / stateCount))
            } else {
                fail += (Double(100 / stateCount))
            }
        }
        //TODO: Store frames in data container
        let successEntry = PieChartDataEntry(value: success)
        let failEntry = PieChartDataEntry(value: fail)
            dataEntries.append(successEntry)
            dataEntries.append(failEntry)
        
        let chartDataSet = PieChartDataSet(entries: dataEntries, label: "Success Rate of Repetition")
            chartDataSet.colors = [NSUIColor].init(arrayLiteral:#colorLiteral(red: 0.2493869228, green: 0.7803921569, blue: 0.480382319, alpha: 0.8826199384),#colorLiteral(red: 1, green: 0.190380104, blue: 0.2108749623, alpha: 0.88))
        let chartData = PieChartData(dataSet: chartDataSet)
            chart.data = chartData
            chart.notifyDataSetChanged()
    }
    
    /// Method to export and save the last Excercise to the Saved Folder
    func saveExcercise(){
        /// Saved Folder:
        let documentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let tempUrl: URL = documentDirURL.appendingPathComponent(lastExcercise!.name).appendingPathComponent("exercise").appendingPathExtension("mov")
        let SavedFolderURL: URL = documentDirURL.appendingPathComponent("Saved")
        
        if !FileManager.default.fileExists(atPath: SavedFolderURL.absoluteString) {
            do {
                try FileManager.default.createDirectory(atPath: SavedFolderURL.relativePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription);
            }
        }
        
        /// Get the current date
        let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd-MM-yyyy-HH:mm:ss"
        let timestamp = Date()
        let dateInFormat = dateFormatter.string(from: timestamp)
        let FileUrl: URL = SavedFolderURL.appendingPathComponent("\(lastExcercise!.name)" + "_" + "\(dateInFormat)").appendingPathExtension("mov")
        /// rename the temp file to the actual name + datetime
        do{
            try FileManager.default.copyItem(at: tempUrl, to: FileUrl)
        } catch let error as NSError{
            print("Renaming file went wrong: \(error)")
        }
        
        saveToDatabase(name: lastExcercise!.name, createdAt: timestamp)
        
    }
    
    /// Save the current animation to the SavedExcercise  database.
    func saveToDatabase(name: String, createdAt: Date) {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        /// 1: gets the current context
        let managedContext =
            appDelegate.persistentContainer.viewContext
        /// 2: gets the table
        let entity =
            NSEntityDescription.entity(forEntityName: "SavedExcercise",
                                       in: managedContext)!
        
        let ani = NSManagedObject(entity: entity,
                                  insertInto: managedContext)
        
        /// Title
        ani.setValue(name, forKeyPath: "exTitle")
        
        /// createdAt date
        ani.setValue(createdAt, forKeyPath: "createdAt")
        
        /// how many sets
        ani.setValue(lastExcercise?.sets, forKeyPath: "exSets")
        
        /// how many repetitions
        ani.setValue(lastExcercise?.count, forKeyPath: "exReps")
        
        /// Save Frames
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(lastExcercise?.repetitions){
            ani.setValue(encoded, forKey: "exrepetitions")
        }
        
        // 4
        do {
            try managedContext.save()
            
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    /// Export Button Event
    @IBAction func expBtnClicked(_ sender: Any) {
        
        exportToJSON(sender)
    }
    
    /// function to export the current Excercise as a json
    func exportToJSON(_ sender: Any){
        let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
        var jsonObject : [String:Any] = [:]
        if let encoded = try? encoder.encode(lastExcercise!.repetitions.first!.animation){
            let positions = try! encoder.encode(lastExcercise!.repetitions.first!.fullposition)
            var usedBones: [String] = []
            for i in relevantBones{
                usedBones.append(boneNames[i])
            }
            let jsonArray = try! JSONSerialization.jsonObject(with: encoded, options:[])
            
            jsonObject = [
                "title": lastExcercise?.name,
                "sets": lastExcercise?.sets ??  0,
                "reps": lastExcercise?.count ??  0,
                "fps": 60,
                "boneNames": usedBones,
                "rotations": jsonArray,
            ]
            
            /// Save data to file
            let fileName = "export"
            let DocumentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            
            let fileURL = DocumentDirURL.appendingPathComponent(fileName).appendingPathExtension("json")
            print("FilePath: \(fileURL.path)")
                        
            do {
                let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
                try data.write(to: fileURL, options: [])
                self.dismiss(animated: true, completion: { () -> Void in
                    
                    let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
                    let activityController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    activityController.popoverPresentationController?.barButtonItem = (sender as! UIBarButtonItem)
                    
                    if var topController = keyWindow?.rootViewController {
                        while let presentedViewController = topController.presentedViewController {
                            topController = presentedViewController
                        }
                        topController.present(activityController, animated: true)
                    }
                })
            } catch {
                print(error)
            }
        }
    }
    
    /// The updateFrame method, gets a frame that needs to get displayed, and modifies the loaded 3D Skeleton to display the given data.
    /// gets each bone rotation from the frame data (a rotation array actually) and update the childNodes of the 3D Skeleton
    func updateFrame(frame: [QuatfContainer]){
        var i = 0
        for joint in frame{
            let name = boneNames[relevantBones[i]]
            root?.childNode(withName: "\(name)", recursively: true)?.simdOrientation = joint.quaternion
            i += 1
        }
        
        /// Update the position of the skeleton to the saved position (from the fullposition array)
        if(currentFrame <= ((lastExcercise?.repetitions[currentRepetition].fullposition.count)! - 1)){
            root?.simdPosition = (lastExcercise?.repetitions[currentRepetition].fullposition[currentFrame])!
        }
        
        /// Fix Camera: use the X Value and the Z Value (+3 for better visibility), ignore Y completely so the skeleton is always at the same height.
        self.cameraNode!.position = SCNVector3(x: (root?.position.x)!, y: 0, z: 3 + (root?.position.z)!)
    }
}

/// MARK: - ChartViewDelegate
/// Not really used at the moment, but here you could react if the user selects the chart
extension ResultController: ChartViewDelegate
{
    public func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight)
    {
        let fr = entry.data
        print("chartValueSelected : x = \(fr.debugDescription)")
    }
    
    public func chartValueNothingSelected(_ chartView: ChartViewBase)
    {
        print("chartValueNothingSelected")
    }
}
