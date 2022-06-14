//
//  ProgressTutorialController.swift
//  ARSports
//
//  Created by Frederic on 30/04/2020.
//  Copyright © 2020 Frederic. All rights reserved.
//


import Foundation
import ARKit
import SceneKit
import Speech
import RealityKit

/// The ViewController for the Progress Tutorial Slider 
class ProgressTutorialController : UIViewController {

    @IBOutlet weak var ScrollView: UIScrollView!
    @IBOutlet weak var PageControl: UIPageControl!
    var slides:[Slide] = [];
    var section: Int = 0;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ScrollView.delegate = self
        slides = createSlides()
        setupSlideScrollView(slides: slides)
        
        PageControl.numberOfPages = slides.count
        PageControl.currentPage = 0
        view.bringSubviewToFront(PageControl)
    }
    
    @objc func ClosePopup(sender:UIButton!) {
       print("Button Clicked")
        dismiss(animated: true) {
            
        }
    }
    
    /// Opens the Progress Tracker at the end of the tutorial
    @objc func OpenProgressTracking(sender:UIButton!) {
        
        dismiss(animated: true) {
            let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first

            if var topController = keyWindow?.rootViewController {
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                let navView = storyBoard.instantiateViewController(withIdentifier: "ProgressView") as! UINavigationController
                let progressView = navView.viewControllers[0] as! ProgressController
                    progressView.selectedArea = self.section
                    topController.present(navView, animated: true, completion: nil)
            }
        }
    }
    
    /// Function to open a little popup displaying options
    @objc func showSectionPopup(_ sender: UIButton) {
        let items = ["Rücken", "Linke Schulter", "Rechte Schulter"]
        let controller = ArrayChoiceTableViewController(items) { (name) in
            print("\(name) selected")
            self.section = items.firstIndex(of: name)!
            sender.setTitle(name, for: .normal)
        }
            controller.modalPresentationStyle = .popover
            controller.preferredContentSize = CGSize(width: 200, height: 150)
        let presentationController = controller.presentationController as! UIPopoverPresentationController
            presentationController.sourceView = sender
            presentationController.sourceRect = sender.bounds
            presentationController.permittedArrowDirections = [.down, .up]
        self.present(controller, animated: true)
    }
    
    /// Creates the Tutorial Slides and returns an Array with them.
    func createSlides() -> [Slide] {

        let slide1:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
            slide1.ImageView.image = UIImage(named: "004-fitness")
            slide1.Headline.text = "Progress Tracker"
            slide1.Description.text = "Willkommen zum Progress Tracker. Auf den nächsten Seiten gibt es eine Kurzanleitung wie Sie einen Progress aufnehmen können."
        
        let slide2:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
            slide2.ImageView.image = UIImage(named: "001-stretching")
            slide2.Headline.text = "Auswahl des getrackten Bereiches"
            slide2.Description.text = "Bitte wählen Sie aus der unteren Liste den Bereich an der getrackt werden soll."
            slide2.SelectionContainer.isHidden = false
            slide2.SelectionBtn.addTarget(self, action: #selector(showSectionPopup), for: UIControl.Event.touchUpInside)
        
        let slide3:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
            slide3.ImageView.image = UIImage(named: "doubletap")
            slide3.Headline.text = "Aufnahme festhalten"
            slide3.Description.text = "Sobald Sie Ihre Position erreicht haben, Double Tappen Sie den oben angezeigten Apple Pencil, um die Aufnahme festzuhalten."
        
        let slide4:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
            slide4.ImageView.image = UIImage(named: "004-fitness")
            slide4.Headline.text = "Los geht's!"
            slide4.Description.text = "Bitte klicken sie auf Start um die Messung zu beginnen."
            slide4.ControlContainer.isHidden = false
            slide4.CancelBtn.addTarget(self, action: #selector(ClosePopup), for: UIControl.Event.touchUpInside)
            slide4.StartBtn.addTarget(self, action: #selector(OpenProgressTracking), for: UIControl.Event.touchUpInside)
        
        return [slide1, slide2, slide3, slide4]
    }
    
    /// init the slide scroll view
    func setupSlideScrollView(slides : [Slide]) {
        ScrollView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        ScrollView.contentSize = CGSize(width: view.frame.width * CGFloat(slides.count), height: view.frame.height)
        ScrollView.isPagingEnabled = true
        
        for i in 0 ..< slides.count {
            slides[i].frame = CGRect(x: view.frame.width * CGFloat(i), y: 0, width: view.frame.width, height: view.frame.height)
            ScrollView.addSubview(slides[i])
        }
    }
    
}

/// Extension to catch the scroll event to change the current page.
extension ProgressTutorialController : UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = round(ScrollView.contentOffset.x/view.frame.width)
        PageControl.currentPage = Int(pageIndex)
        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {

        setupSlideScrollView(slides: slides)
    }
}
