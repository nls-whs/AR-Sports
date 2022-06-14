//
//  CollectionViewController.swift
//  ARSports
//
//  Created by Frederic on 22/11/2019.
//  Copyright © 2019 Frederic. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import ARKit
import RealityKit

/// Controller Class for the Setup Screen: Contains actions for switching to the recording view or the excercise editing view.
class TableViewController : UITableViewController {
    
    @IBOutlet var addBtn: UIBarButtonItem!
    @IBOutlet weak var dataTable: UITableView!
    var animations: [NSManagedObject] = []
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Setup"
        
        //fetch data from the CoreData Database
        fetchData()
        
    }
    
    ///Method gets called when the view is preparing to switch to another view.
    ///Here we have two possible scenarios, if the so called segue (thats a navigation link between pages in the storyboard)
    ///is named "newAnimation" the user wants to record a new animation, so he pressed on the plus symbol, we will
    ///navigate to the recording screen, otherwise a user selected a excercise and we will navigate to the PreviewController.
    ///There the user can setup the excercise and change settings. 
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //Clicked on the plus
        if segue.identifier == "newAnimation"{
            let vc = (segue.destination as! ViewController)
                vc.newPose = true;
            return
        }
        
        //Clicked on a row
        //As of right now opens the Previewer that can add keyframes
        if let indexPath = dataTable.indexPathForSelectedRow{
            let preview = segue.destination as! PreviewController
            
            let animation = animations[indexPath.row]
            //start the training mode
            let data = (animation.value(forKey: Animation.Keys.frames.rawValue))
            let setBack: Array<[QuatfContainer]> = try! JSONDecoder().decode(Array<[QuatfContainer]>.self, from: data! as! Data)
                preview.animation = setBack
            
            let bodydata = (animation.value(forKey: "bodyposition"))
            let body: [simd_float3] = try! JSONDecoder().decode([simd_float3].self, from: bodydata! as! Data)
                preview.bodyposition = body
            
            let keyframes = (animation.value(forKey: "keyframes"))
            let keys: Set<Int> = try! JSONDecoder().decode(Set<Int>.self, from: keyframes! as! Data)
                preview.keyframes = keys
            
            let name = (animation.value(forKey: "title")) as? String
                preview.animationName = name!
            
            let sets = (animation.value(forKey: "sets")) as? Int
                preview.sets = sets ?? 3
            
            let reps = (animation.value(forKey: "reps")) as? Int
                preview.reps = reps ?? 10
            
            let desc = (animation.value(forKey: "desc")) as? String
                preview.desc = desc ?? ""
            
            let section = (animation.value(forKey: "section")) as? String
                preview.section = section ?? "None"
            
            let boneWeights = (animation.value(forKey: "weights"))
            if boneWeights != nil {
                let weights = try! JSONDecoder().decode(Dictionary<String, Float>.self, from: boneWeights! as! Data)
                preview.weights = weights
            }
        }
    }
    /// Returns the count of objects in the table
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        return animations.count
    }
    /// Prepares a cell for the table/list
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath)
        -> UITableViewCell {
            
            let animation = animations[indexPath.row]
            let cell =
                dataTable.dequeueReusableCell(withIdentifier: "cell",
                                              for: indexPath)
            cell.textLabel?.text = animation.value(forKey: "title") as? String
            return cell
    }
    
    /// Function that handles the deletion of a excercise (Delete via swipe gesture)
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let name = (animations[indexPath.row].value(forKey: "title") as? String)!
            //Delete Database Stuff
            deleteDBEntry(name: name)
            //Delete local video
            deleteLocally(name: name)
            //Delete UI Stuff
            animations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            print(indexPath)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
    
    
    /// Function that get called when the + symbol is clicked.
    /// Prepares the recording view
    @IBAction func AddAnimation(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "New Name",
                                      message: "Add a new name",
                                      preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Save", style: .default) {
            [unowned self] action in
            
            guard let textField = alert.textFields?.first,
                let nameToSave = textField.text else {
                    return
            }
            
            self.save(name: nameToSave)
            self.dataTable.reloadData()
            let destinationVC = ViewController()
                destinationVC.newPose = true
                destinationVC.performSegue(withIdentifier: "ExToAR", sender: self)
            
        }
        
        let cancelAction = UIAlertAction(title: "Cancel",
                                         style: .cancel)
        
        alert.addTextField()
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    /// Helper function to delete a local file
    func deleteLocally(name: String){
        let documentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folderURL: URL = documentDirURL.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: folderURL.path) {
                //delete file
                try FileManager.default.removeItem(at: folderURL)
            }
        }catch {
            print("Could not clear temp folder: \(error)")
        }
    }
    /// Delete the db entry of the given name
    func deleteDBEntry(name: String) {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        // 1
        let managedContext =
            appDelegate.persistentContainer.viewContext
        // 2
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AnimationCore")
        
        let predicate = NSPredicate(format: "title == %@", name)
        
        fetchRequest.predicate = predicate
        do{
            let result = try managedContext.fetch(fetchRequest)
            
            print(result.count)
            
            if result.count > 0{
                for object in result {
                    print(object)
                    managedContext.delete(object as! NSManagedObject)
                    try managedContext.save()
                }
            }
        }catch{
            print("Could not delete. \(error)")
        }
    }
    
    /// Saves the title
    func save(name: String) {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        // 1
        let managedContext =
            appDelegate.persistentContainer.viewContext
        // 2
        let entity =
            NSEntityDescription.entity(forEntityName: "AnimationCore",
                                       in: managedContext)!
        
        let ani = NSManagedObject(entity: entity,
                                  insertInto: managedContext)
        
        // 3
        ani.setValue(name, forKeyPath: "title")
        
        // 4
        do {
            try managedContext.save()
            animations.append(ani)
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    /// fetches all animations from the database
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
            NSFetchRequest<NSManagedObject>(entityName: "AnimationCore")
        
        //3
        do {
            animations = try managedContext.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
    
    
}


