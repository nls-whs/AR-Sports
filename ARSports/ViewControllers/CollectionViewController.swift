//
//  CollectionViewController.swift
//  ARSports
//
//  Created by Frederic on 23/11/2019.
//  Copyright © 2019 Frederic. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import RealityKit

/// CollectionViewController, the ViewController that manages the CollectionView that displays all excercises in sections.
class CollectionViewController : UICollectionViewController {
    
    @IBOutlet var trainingCollection: UICollectionView!
    var animations: [NSManagedObject] = []
    var expert: [NSManagedObject] = []
    var normal: [NSManagedObject] = []
    var beginner: [NSManagedObject] = []
    private let itemsPerRow: CGFloat = 3
    private let sectionInsets = UIEdgeInsets(top: 50.0,
                                             left: 20.0,
                                             bottom: 50.0,
                                             right: 20.0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchData()
    }
    /// configure the number of sections
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }
    
    /// returns the amount of elements in the sections
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return beginner.count
        case 1:
            return normal.count
        case 2:
            return expert.count
        default:
            return animations.count
        }
        
    }
    /// Create the cell for the table, update Name, Image and category.
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var animation: NSManagedObject
        switch indexPath.section {
        case 0:
            animation = beginner[indexPath.row]
        case 1:
            animation = normal[indexPath.row]
        case 2:
            animation = expert[indexPath.row]
        default:
            animation = animations[indexPath.row]
        }
        let title = animation.value(forKey: "title") as? String
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectioncell", for: indexPath) as! ThumbnailCell
            cell.name?.text = title
            cell.updateImage()
        return cell
    }
    /// Display sections
    override func collectionView(_ collectionView: UICollectionView,
                                 viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
        // 1
        switch kind {
        // 2
        case UICollectionView.elementKindSectionHeader:
            // 3
            guard
                let headerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: "\(CollectionHeader.self)",
                    for: indexPath) as? CollectionHeader
                else {
                    fatalError("Invalid view type")
            }
            
            let section = indexPath.section
            switch (section) {
            case 1:
                headerView.label.text = "Normal"
            case 2:
                headerView.label.text = "Expert"
            default:
                headerView.label.text = "Beginner"
                
            }
            return headerView
        default:
            // 4
            assert(false, "Invalid element type")
        }
    }
    
    /// The prepare function, gets triggered for example when the user clicked on a element in the list and want to navigate now
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //When clicking on a element
        if let sender = sender as? UICollectionViewCell {
            let indexPath = self.trainingCollection.indexPath(for: sender)
            // get the ViewController from the segue (NavigationLink in Storyboard)
            let vc = (segue.destination as! ViewController)
            var animation: NSManagedObject
            // access the correct array to get the clicked element
            switch indexPath!.section {
            case 0:
                animation = beginner[indexPath!.item]
            case 1:
                animation = normal[indexPath!.item]
            case 2:
                animation = expert[indexPath!.item]
            default:
                animation = animations[indexPath!.item]
            }
            //start the training mode
            let data = (animation.value(forKey: Animation.Keys.frames.rawValue))
            //get the animation: Here it is a Collections of Array of Rotations (for each bone)
            let setBack: Array<[QuatfContainer]> = try! JSONDecoder().decode(Array<[QuatfContainer]>.self, from: data! as! Data)
                vc.animation = setBack
            // Get the json for keyframes and rootpositions
            let keyframes = (animation.value(forKey: "keyframes"))
            // Get the root bone positions
            let rootpositions = (animation.value(forKey: "bodyposition"))
            // Decode the json into the Array<sim_float3> for bodyposition and Set<Int> for keyframes
            let bodypositions = try! JSONDecoder().decode(Array<simd_float3>.self, from: rootpositions! as! Data)
            let keys: Set<Int> = try! JSONDecoder().decode(Set<Int>.self, from: keyframes! as! Data)
            // Update the keyframes and body position
                vc.keyframes = keys
                vc.AnimationBodyPositions = bodypositions
            // get the name and update the ViewController
            let name = (animation.value(forKey: "title")) as? String
                vc.animationName = name!
            // get amount of sets and update the ViewController
            let sets = (animation.value(forKey: "sets")) as? Int
                vc.sets = sets ?? 3
            // get amount of repetition and update the ViewController
            let reps = (animation.value(forKey: "reps")) as? Int
                vc.reps = reps ?? 10
            // get description and update the ViewController
            let desc = (animation.value(forKey: "desc")) as? String
                vc.desc = desc ?? ""
            // get boneweights and update the ViewController
            let boneWeights = (animation.value(forKey: "weights"))
            if boneWeights != nil {
                let weights = try! JSONDecoder().decode(Dictionary<String, Float>.self, from: boneWeights! as! Data)
                    vc.weights = weights
            }
            // Switch to training mode
            vc.training = true
        }
    }
    
    /// Funtion to fetch the data from the database
    func fetchData(){
        /// 1 get the current AppDelegate
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        /// 2 Animation Core is the Base Table of the Application
        let fetchRequest =
            NSFetchRequest<NSManagedObject>(entityName: "AnimationCore")
        
        /// 3 get the objects from AnimationCore and same them in animations
        do {
            animations = try managedContext.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        /// 4 Put the animation in the right section
        for ani in animations {
            
            /// filter out excercises without keyframes
            let keyframes = (ani.value(forKey: "keyframes"))
            let keys: Set<Int> = try! JSONDecoder().decode(Set<Int>.self, from: keyframes! as! Data)
            if(keys.count == 0){ continue }
            
            switch ((ani.value(forKey: "section")) as? String) {
            case "Beginner":
                self.beginner.append(ani)
            case "Normal":
                self.normal.append(ani)
            case "Expert":
                self.expert.append(ani)
            default:
                self.beginner.append(ani)
                
            }
        }
    }
}

