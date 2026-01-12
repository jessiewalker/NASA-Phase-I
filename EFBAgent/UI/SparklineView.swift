//
//  SparklineView.swift
//  EFB Agent
//
//  Tiny real-time sparkline chart component
//

import SwiftUI

struct SparklineView: View {
    let values: [Double]
    let label: String
    let valueText: String
    let color: Color
    
    init(values: [Double], label: String, valueText: String, color: Color = .blue) {
        self.values = values
        self.label = label
        self.valueText = valueText
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 32)
                
                // Sparkline path
                SparklinePath(values: values, color: color)
                    .frame(height: 32)
                    .padding(.horizontal, 4)
            }
            
            Text(valueText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}

struct SparklinePath: View {
    let values: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !values.isEmpty else {
                    // Draw faint placeholder line for empty data
                    path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                    return
                }
                
                let count = values.count
                guard count > 0 else { return }
                
                // Calculate min/max for scaling
                let (minVal, maxVal) = calculateMinMax()
                let range = maxVal - minVal
                let scaleY: CGFloat = range > 0.001 ? CGFloat(range) : 1.0
                
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = count > 1 ? width / CGFloat(count - 1) : 0
                
                // Draw path
                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) * stepX
                    // Invert Y (0 = top, max = bottom) and add padding
                    let normalizedY = range > 0.001 ? (value - minVal) / scaleY : 0.5
                    let y = height - (normalizedY * (height - 4) + 2)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
    
    private func calculateMinMax() -> (Double, Double) {
        guard !values.isEmpty else { return (0, 1) }
        
        // Check if all values are constant
        let first = values[0]
        let allEqual = values.allSatisfy { abs($0 - first) < 0.001 }
        if allEqual {
            // For constant values, show flat line at middle
            let val = first
            return (max(0, val - 0.1), val + 0.1)
        }
        
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = maxVal - minVal
        
        // Ensure minimum range for visibility
        if range < 0.001 {
            let center = (minVal + maxVal) / 2
            return (center - 0.05, center + 0.05)
        }
        
        return (minVal, maxVal)
    }
}

