//
//  MonitorListViewController.swift
//  ARSports
//
//  Created by Frederic on 02/05/2020.
//  Copyright © 2020 Frederic. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import ModelIO
import ARKit

/// ViewController for the Monitor View
class MonitorListViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, ResultViewControllerDelegate {
        
    @IBOutlet weak var headline: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var timeSpan: UILabel!
    @IBOutlet weak var amountOfExcercises: UILabel!
    let formatter = DateFormatter()
    var excerciseList: [NSManagedObject] = []
    var animationCoreList: [NSManagedObject] = []
    let relevantBones: Array = [1,2,3,4,7,8,9,12,13,14,15,16,17,18,19,20,21,22,47,48,49,50,51,52,53,63,64,65,66]

    func closeResult() {
        
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return excerciseList.count
    }
    
    /// gets all data neccessary for the result modal and displays it.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        
        let excercise = excerciseList[(excerciseList.count - 1) - indexPath.row]
        let title = excercise.value(forKey: "exTitle") as? String
        let sets = excercise.value(forKey: "exSets") as? Int
        let reps = excercise.value(forKey: "exReps") as? Int
        let data = excercise.value(forKey: "exrepetitions")
        let repetitions: [Repetition] = try! JSONDecoder().decode([Repetition].self, from: data! as! Data)
        let createdAt: Date = ((excercise.value(forKey: "createdAt") as? Date)!)


        let givenExcercise = Excercise(name: title!, count: reps ?? 0, sets: sets ?? 0 )
            givenExcercise.repetitions = repetitions
        
        //start the monitor mode
        showResultModal(excercise: givenExcercise, createdAt: createdAt )
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let excercise = excerciseList[(excerciseList.count - 1) - indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell",
                                          for: indexPath) as! SavedExcerciseCell
            cell.CreatedAt.text = self.formatter.string(from:((excercise.value(forKey: "createdAt") as? Date)!))
            cell.ExcerciseName.text = excercise.value(forKey: "exTitle") as? String
        return cell
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.formatter.dateStyle = .long
        fetchData()
        setupView()
        tableView.delegate = self
    }
    
    /// Shows how many excercises were saved and calculates the days since the first one
    func setupView(){
        self.amountOfExcercises.text = "\(excerciseList.count)"
        timeSpan.text = "\((excerciseList.first!.value(forKey: "createdAt") as? Date)!.daysBetween(date: Date())) day/s"
        
    }
    
    /// fetches the data from coredata.
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
            NSFetchRequest<NSManagedObject>(entityName: "SavedExcercise")
        
        let aniCoreRequest =
        NSFetchRequest<NSManagedObject>(entityName: "AnimationCore")
        
        //3
        do {
            excerciseList = try managedContext.fetch(fetchRequest)
            animationCoreList = try managedContext.fetch(aniCoreRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        
    }
    
    /// function to show the result modal, updates its required vars and play a result sound for the user.
    func showResultModal(excercise: Excercise, createdAt: Date) {
        let popvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ResultModalVC") as! ResultController
            popvc.lastExcercise = excercise
            popvc.monitor = true
            popvc.createdAt = createdAt
            popvc.delegate = self
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        
        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.present(popvc, animated: true)
        }
    }
}

