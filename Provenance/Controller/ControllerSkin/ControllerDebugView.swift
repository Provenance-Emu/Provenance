//
//  ControllerDebugView.swift
//  DeltaCore
//
//  Created by Riley Testut on 12/20/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import Foundation

internal class ControllerDebugView: UIView
{
    var items: [ControllerSkin.Item]? {
        didSet {
            self.updateItems()
        }
    }
    
    private var itemViews = [ItemView]()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.backgroundColor = UIColor.clear
        self.isUserInteractionEnabled = false
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        for view in self.itemViews
        {
            var frame = view.item.extendedFrame
            frame.origin.x *= self.bounds.width
            frame.origin.y *= self.bounds.height
            frame.size.width *= self.bounds.width
            frame.size.height *= self.bounds.height
            
            view.frame = frame
        }
    }
    
    private func updateItems()
    {
        self.itemViews.forEach { $0.removeFromSuperview() }
        
        var itemViews = [ItemView]()
        
        for item in (self.items ?? [])
        {
            let itemView = ItemView(item: item)
            self.addSubview(itemView)
            
            itemViews.append(itemView)
        }
        
        self.itemViews = itemViews
        
        self.setNeedsLayout()
    }
}

private class ItemView: UIView
{
    let item: ControllerSkin.Item
    
    private let label: UILabel
    
    init(item: ControllerSkin.Item)
    {
        self.item = item
        
        self.label = UILabel()
        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.label.textColor = UIColor.white
        self.label.font = UIFont.boldSystemFont(ofSize: 16)
        
        var text = ""
        
        for input in item.inputs.allInputs
        {
            if text.isEmpty
            {
                text = input.stringValue
            }
            else
            {
                text = text + "," + input.stringValue
            }
        }
        
        self.label.text = text
        
        self.label.sizeToFit()
        
        super.init(frame: CGRect.zero)
        
        self.addSubview(self.label)
        
        self.label.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        self.backgroundColor = UIColor.red.withAlphaComponent(0.75)
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError()
    }
}
