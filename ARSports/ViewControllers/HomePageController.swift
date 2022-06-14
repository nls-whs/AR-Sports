//
//  HomePageController.swift
//  ARSports
//
//  Created by Frederic on 03/03/2020.
//  Copyright © 2020 Frederic. All rights reserved.
//
import UIKit
import Foundation

/// ViewController for the HomePage
class HomePageController: UIViewController {
    @IBOutlet weak var QuickstartView: UIView!
    @IBOutlet weak var StartWorkoutBtn: UIButton!
    
    override func viewDidAppear(_ animated: Bool) {
          let QSTapped = UITapGestureRecognizer(target: self, action:  #selector (self.QuickStartTouched(sender:)))
        QuickstartView.addGestureRecognizer(QSTapped)
    }
    /// Mockup for Quickstart, move to the trainings screen.
    @objc func QuickStartTouched(sender: UITapGestureRecognizer){
        tabBarController?.selectedIndex = 1
    }
    /// Switch tabs
    @IBAction func StartWorkoutPressed(_ sender: Any) {
        tabBarController?.selectedIndex = 1
    }
}


