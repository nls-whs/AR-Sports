//
//  ExStarterVC.swift
//  ARSports
//
//  ExStartVC, short for ExcerciseStartViewController,
//  is the ViewController that displays a clicked excercise when the user starts the training
//  It displays a basic overview of the excercise and plays the video.
//  Created by Frederic on 05/01/2020.
//  Copyright © 2020 Frederic. All rights reserved.
//

import Foundation
import UIKit
/// ExStarterVC Class, a ViewController that displays a excercise.
class ExStarterVC : UIViewController {
    @IBOutlet public var MainView: UIView!
    @IBOutlet public var VideoView: UIView!
    @IBOutlet public var TitleLabel: UILabel!
    @IBOutlet public var SetsTextfield: UITextField!
    @IBOutlet var DescriptionBox: UITextView!
    
    @IBOutlet public var RepetitionTextfield: UITextField!
    
    var titleText : String!
    var repetitions : Int!
    var sets : Int!
    var desc: String!
    var video : URL!
    var delegate: SavingViewControllerDelegate?

    /// Prepares the view
    override func viewDidLoad() {
        super.viewDidLoad()
        TitleLabel.text = titleText
        RepetitionTextfield.text = repetitions.description
        DescriptionBox.text = desc
        SetsTextfield.text = sets.description
        let vp = VideoPlayer()
            vp.playLargerVideo(videoURL: video)
        VideoView.addSubview(vp.view)
    }
    
    /// Method to navigate to the Trainings Screen and start the excercise.
    @IBAction func start(_ sender: Any) {
        delegate?.startTrainingDelegate(sets: Int(SetsTextfield.text!)!, reps: Int(RepetitionTextfield.text!)!)
        dismiss(animated: true, completion: nil)
    }
    /// Method to dismiss the current window
    @IBAction func cancel(_ sender: Any) {
        delegate?.cancelTrainingDelegate()
        dismiss(animated: true, completion: nil)
    }
}
