//
//  ProgressOverviewController.swift
//  ARSports
//
//  Created by Frederic on 01/05/2020.
//  Copyright © 2020 Frederic. All rights reserved.
//

import Foundation
import UIKit
import CoreData

/// ViewController of the Progress Overview Popup
class ProgressOverviewController : UIViewController,UITableViewDelegate,UITableViewDataSource {
    
    @IBOutlet weak var headline: UILabel!
    @IBOutlet weak var timeSpan: UILabel!
    @IBOutlet weak var currentPercent: UILabel!
    @IBOutlet weak var progressTable: UITableView!
    let formatter = DateFormatter()
    var progressList: [NSManagedObject] = []
    var goal: Float = 0.0
    var section: Int = 0;
    var selectedSection: String = "Rücken"
    enum Area: Int {
        case Back = 0
        case LeftArm = 1
        case RightArm = 2
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    /// Init the view
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.formatter.dateStyle = .medium
        //Connect to Database
        fetchData()
        setupView()
        progressTable.delegate = self
    }
    
    /// Initialize goals and headlines
    /// Since this is a prototype, goals are hardcoded and should be later variable to edit
    func setupView(){
        switch section {
        case Area.Back.rawValue:
            headline.text = "Übersicht: Rücken"
            selectedSection = "back"
            goal = 90.0
        case Area.LeftArm.rawValue:
            headline.text = "Übersicht: Linke Schulter"
            selectedSection = "lShoulder"
            goal = 180.0
        case Area.RightArm.rawValue:
            headline.text = "Übersicht: Rechte Schulter"
            selectedSection = "rShoulder"
            goal = 180.0
        default:
            goal = 90.0
            headline.text = "Übersicht: Rücken"
            selectedSection = "back"
        }

        timeSpan.text = "\((progressList.first!.value(forKey: "createdAt") as? Date)!.daysBetween(date: Date())) day/s"
        let angle = rad2deg(angle: progressList.last!.value(forKey: selectedSection) as! Float)
        let dist = goal - (abs(angle - goal))
        currentPercent.text = "\((100.0 / goal) * dist)%"
    }
    /// fetches the data from coredata
    func fetchData(){
        //1
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        //2
        let fetchRequest =
            NSFetchRequest<NSManagedObject>(entityName: "ProgressTable")
        
        //3
        do {
            progressList = try managedContext.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let progress = progressList[(progressList.count - 1) - indexPath.row]
        let cell =
            progressTable.dequeueReusableCell(withIdentifier: "cell",
                                              for: indexPath) as! ProgressCell
        
        
        cell.CreatedAt.text = self.formatter.string(from:((progress.value(forKey: "createdAt") as? Date)!))
        
        switch section {
        case Area.Back.rawValue:
            cell.Angle.text = "\(rad2deg(angle: (progress.value(forKey: "back") as? Float)!).description)º"
        case Area.LeftArm.rawValue:
            cell.Angle.text = "\(rad2deg(angle:(progress.value(forKey: "lShoulder") as? Float)!).description)º"
        case Area.RightArm.rawValue:
            cell.Angle.text = "\(rad2deg(angle:(progress.value(forKey: "rShoulder") as? Float)!).description)º"
        default:
            cell.Angle.text = "\(rad2deg(angle:(progress.value(forKey: "back") as? Float)!).description)º"
        }
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return progressList.count
    }
    
    /// helper functionto convert radian to degree.
   func rad2deg(angle: Float) -> Float{
           return angle * 180 / .pi
       }
    
}

/// Extension for the date to calculate the days between to dates.
extension Date {

    func daysBetween(date: Date) -> Int {
        return Date.daysBetween(start: self, end: date)
    }

    static func daysBetween(start: Date, end: Date) -> Int {
        let calendar = Calendar.current

        // Replace the hour (time) of both dates with 00:00
        let date1 = calendar.startOfDay(for: start)
        let date2 = calendar.startOfDay(for: end)

        let a = calendar.dateComponents([.day], from: date1, to: date2)
        return a.value(for: .day)!
    }
}
