//
//  Dot.swift
//  ARSports
//
//  Created by Frederic on 03/01/2020.
//  Copyright © 2020 Frederic. All rights reserved.
//
// Dot with border, which you can control completely in Storyboard

import UIKit

///Dot Class to display a dot on the screen.
@IBDesignable
class Dot:UIView
{
    @IBInspectable var mainColor: UIColor = UIColor.blue
        {
        didSet { print("mainColor was set here") }
    }
    @IBInspectable var ringColor: UIColor = UIColor.orange
        {
        didSet { print("bColor was set here") }
    }
    @IBInspectable var ringThickness: CGFloat = 4
        {
        didSet { print("ringThickness was set here") }
    }
    
    @IBInspectable var isSelected: Bool = true
    
    override func draw(_ rect: CGRect)
    {
        let dotPath = UIBezierPath(ovalIn:rect)
        let shapeLayer = CAShapeLayer()
            shapeLayer.path = dotPath.cgPath
            shapeLayer.fillColor = mainColor.cgColor
            layer.addSublayer(shapeLayer)
        
        if (isSelected) { drawRingFittingInsideView(rect: rect) }
    }
    
    internal func drawRingFittingInsideView(rect: CGRect)->()
    {
        let hw:CGFloat = ringThickness/2
        let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: hw,dy: hw) )
        
        let shapeLayer = CAShapeLayer()
            shapeLayer.path = circlePath.cgPath
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.strokeColor = ringColor.cgColor
            shapeLayer.lineWidth = ringThickness
            layer.addSublayer(shapeLayer)
    }
}
