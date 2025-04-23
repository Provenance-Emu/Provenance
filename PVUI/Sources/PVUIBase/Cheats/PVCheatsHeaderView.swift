//
//  PVCheatsHeaderView.swift
//  Provenance
//

#if canImport(UIKit)
import UIKit
#endif

final class PVCheatsHeaderView: UICollectionReusableView {
    @IBOutlet var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        applyRetroWaveStyle()
    }
    
    func applyRetroWaveStyle() {
        // Apply retrowave styling to the header
        backgroundColor = .clear
        
        // Style the label with retrowave theme
        label?.applyRetroWaveTextStyle(color: .retroBlue, fontSize: 18, weight: .bold)
        
        // Add a subtle bottom border
        let borderLayer = CALayer()
        borderLayer.frame = CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
        borderLayer.backgroundColor = UIColor.retroPink.withAlphaComponent(0.5).cgColor
        layer.addSublayer(borderLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure the retrowave styling is applied after layout changes
        applyRetroWaveStyle()
    }
}
