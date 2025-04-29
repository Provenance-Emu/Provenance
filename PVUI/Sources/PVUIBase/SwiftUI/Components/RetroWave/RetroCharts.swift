//
//  RetroCharts.swift
//  PVUIBase
//
//  Created by Joseph Mattiello on 4/27/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI

/// RetroCharts provides RetroWave-styled chart components for data visualization
public struct RetroCharts {
    
    /// A RetroWave-styled bar chart
    public struct BarChart: View {
        /// The data values to display
        let values: [Double]
        
        /// The labels for each bar
        let labels: [String]
        
        /// Optional maximum value for scaling (defaults to the maximum value in the data)
        let maxValue: Double?
        
        /// Optional title for the chart
        let title: String?
        
        /// Optional animation duration
        let animationDuration: Double
        
        /// Whether to show the grid background
        let showGrid: Bool
        
        @State private var animatedValues: [Double] = []
        
        /// Initialize a new RetroWave bar chart
        /// - Parameters:
        ///   - values: The data values to display
        ///   - labels: The labels for each bar
        ///   - maxValue: Optional maximum value for scaling
        ///   - title: Optional title for the chart
        ///   - animationDuration: Animation duration in seconds (default: 1.0)
        ///   - showGrid: Whether to show the grid background (default: true)
        public init(values: [Double], labels: [String], maxValue: Double? = nil, title: String? = nil, animationDuration: Double = 1.0, showGrid: Bool = true) {
            self.values = values
            self.labels = labels
            self.maxValue = maxValue
            self.title = title
            self.animationDuration = animationDuration
            self.showGrid = showGrid
            
            // Initialize animated values to zero
            self._animatedValues = State(initialValue: Array(repeating: 0, count: values.count))
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Title if provided
                if let title = title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.retroPink)
                }
                
                // Chart container
                ZStack {
                    // Grid background
                    if showGrid {
                        RetroTheme.RetroGridView()
                            .opacity(0.2)
                    }
                    
                    // Chart content
                    VStack {
                        // Bars
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(0..<animatedValues.count, id: \.self) { index in
                                VStack(spacing: 4) {
                                    // Bar value
                                    Text(String(format: "%.0f", values[index]))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    
                                    // Bar
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.retroBlue, .retroPurple, .retroPink]),
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                        .frame(height: getBarHeight(for: animatedValues[index]))
                                        .frame(width: 24)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                        )
                                        .shadow(color: .retroPink.opacity(0.5), radius: 4, x: 0, y: 0)
                                    
                                    // Bar label
                                    Text(labels[index])
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(width: 60)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    }
                }
                .frame(height: 200)
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(10)
            }
            .onAppear {
                withAnimation(.easeOut(duration: animationDuration)) {
                    animatedValues = values
                }
            }
            .onChange(of: values) { newValues in
                withAnimation(.easeOut(duration: animationDuration)) {
                    animatedValues = newValues
                }
            }
        }
        
        /// Calculate the height for a bar based on its value
        /// - Parameter value: The value to calculate height for
        /// - Returns: The height in points
        private func getBarHeight(for value: Double) -> CGFloat {
            let max = maxValue ?? values.max() ?? 1.0
            let ratio = value / max
            return CGFloat(ratio) * 150.0
        }
    }
    
    /// A RetroWave-styled pie chart
    public struct PieChart: View {
        /// The data values to display
        let values: [Double]
        
        /// The labels for each segment
        let labels: [String]
        
        /// The colors for each segment (defaults to RetroWave colors)
        let colors: [Color]
        
        /// Optional title for the chart
        let title: String?
        
        /// Optional animation duration
        let animationDuration: Double
        
        @State private var animatedPercentages: [Double] = []
        @State private var selectedSegment: Int? = nil
        
        /// Initialize a new RetroWave pie chart
        /// - Parameters:
        ///   - values: The data values to display
        ///   - labels: The labels for each segment
        ///   - colors: The colors for each segment (defaults to RetroWave colors)
        ///   - title: Optional title for the chart
        ///   - animationDuration: Animation duration in seconds (default: 1.0)
        public init(values: [Double], labels: [String], colors: [Color]? = nil, title: String? = nil, animationDuration: Double = 1.0) {
            self.values = values
            self.labels = labels
            self.title = title
            self.animationDuration = animationDuration
            
            // Use provided colors or default RetroWave colors
            if let colors = colors, colors.count >= values.count {
                self.colors = colors
            } else {
                let retroColors: [Color] = [.retroPink, .retroPurple, .retroBlue, 
                                           Color(red: 0.2, green: 0.8, blue: 0.8),
                                           Color(red: 0.8, green: 0.2, blue: 0.8)]
                
                // Create enough colors by cycling through the RetroWave colors
                var generatedColors: [Color] = []
                for i in 0..<values.count {
                    generatedColors.append(retroColors[i % retroColors.count])
                }
                self.colors = generatedColors
            }
            
            // Initialize animated percentages to zero
            self._animatedPercentages = State(initialValue: Array(repeating: 0, count: values.count))
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Title if provided
                if let title = title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.retroPink)
                }
                
                // Chart container
                ZStack {
                    // Chart content
                    HStack(spacing: 20) {
                        // Pie chart
                        ZStack {
                            ForEach(0..<animatedPercentages.count, id: \.self) { index in
                                PieSegment(
                                    startAngle: startAngle(for: index),
                                    endAngle: endAngle(for: index),
                                    color: colors[index],
                                    selected: selectedSegment == index
                                )
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        selectedSegment = selectedSegment == index ? nil : index
                                    }
                                }
                            }
                            
                            // Center circle
                            Circle()
                                .fill(Color.retroBlack)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                            
                            // Total value in center
                            Text(String(format: "%.0f", values.reduce(0, +)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 150, height: 150)
                        .padding()
                        
                        // Legend
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<values.count, id: \.self) { index in
                                HStack(spacing: 8) {
                                    // Color indicator
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(colors[index])
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2)
                                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                        )
                                    
                                    // Label and value
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(labels[index])
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        
                                        Text("\(Int(values[index])) (\(Int(percentages()[index] * 100))%)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(selectedSegment == index ? Color.retroBlack.opacity(0.5) : Color.clear)
                                .cornerRadius(4)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        selectedSegment = selectedSegment == index ? nil : index
                                    }
                                }
                            }
                        }
                        .padding(.trailing)
                    }
                }
                .padding()
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(10)
            }
            .onAppear {
                withAnimation(.easeOut(duration: animationDuration)) {
                    animatedPercentages = percentages()
                }
            }
            .onChange(of: values) { _ in
                withAnimation(.easeOut(duration: animationDuration)) {
                    animatedPercentages = percentages()
                }
            }
        }
        
        /// Calculate the percentages for each value
        /// - Returns: Array of percentages (0.0-1.0)
        private func percentages() -> [Double] {
            let total = values.reduce(0, +)
            return values.map { $0 / total }
        }
        
        /// Calculate the start angle for a segment
        /// - Parameter index: The segment index
        /// - Returns: The start angle in degrees
        private func startAngle(for index: Int) -> Double {
            let priorSegments = animatedPercentages.prefix(index)
            let priorPercent = priorSegments.reduce(0, +)
            return priorPercent * 360
        }
        
        /// Calculate the end angle for a segment
        /// - Parameter index: The segment index
        /// - Returns: The end angle in degrees
        private func endAngle(for index: Int) -> Double {
            startAngle(for: index) + (animatedPercentages[index] * 360)
        }
    }
    
    /// A single segment of the pie chart
    struct PieSegment: View {
        let startAngle: Double
        let endAngle: Double
        let color: Color
        let selected: Bool
        
        var body: some View {
            GeometryReader { geometry in
                Path { path in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let radius = min(geometry.size.width, geometry.size.height) / 2
                    let start = startAngle - 90 // Adjust to start from top
                    let end = endAngle - 90
                    
                    path.move(to: center)
                    path.addArc(center: center, radius: radius,
                                startAngle: .degrees(start),
                                endAngle: .degrees(end),
                                clockwise: false)
                    path.closeSubpath()
                }
                .fill(color)
                .overlay(
                    Path { path in
                        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        let radius = min(geometry.size.width, geometry.size.height) / 2
                        let start = startAngle - 90
                        let end = endAngle - 90
                        
                        path.move(to: center)
                        path.addArc(center: center, radius: radius,
                                    startAngle: .degrees(start),
                                    endAngle: .degrees(end),
                                    clockwise: false)
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .scaleEffect(selected ? 1.05 : 1.0)
                .shadow(color: selected ? color.opacity(0.8) : color.opacity(0.3), radius: selected ? 10 : 5)
            }
        }
    }
    
    /// A RetroWave-styled line chart
    public struct LineChart: View {
        /// The data points to display
        let dataPoints: [Double]
        
        /// The labels for the x-axis
        let xLabels: [String]
        
        /// Optional maximum value for y-axis (defaults to the maximum value in the data)
        let maxValue: Double?
        
        /// Optional minimum value for y-axis (defaults to 0 or the minimum value in the data if negative)
        let minValue: Double?
        
        /// Optional title for the chart
        let title: String?
        
        /// Optional animation duration
        let animationDuration: Double
        
        /// Whether to show the grid background
        let showGrid: Bool
        
        /// Whether to fill the area under the line
        let fillArea: Bool
        
        @State private var animatedPoints: [Double] = []
        
        /// Initialize a new RetroWave line chart
        /// - Parameters:
        ///   - dataPoints: The data points to display
        ///   - xLabels: The labels for the x-axis
        ///   - maxValue: Optional maximum value for y-axis
        ///   - minValue: Optional minimum value for y-axis
        ///   - title: Optional title for the chart
        ///   - animationDuration: Animation duration in seconds (default: 1.0)
        ///   - showGrid: Whether to show the grid background (default: true)
        ///   - fillArea: Whether to fill the area under the line (default: true)
        public init(dataPoints: [Double], xLabels: [String], maxValue: Double? = nil, minValue: Double? = nil, title: String? = nil, animationDuration: Double = 1.0, showGrid: Bool = true, fillArea: Bool = true) {
            self.dataPoints = dataPoints
            self.xLabels = xLabels
            self.maxValue = maxValue
            self.minValue = minValue
            self.title = title
            self.animationDuration = animationDuration
            self.showGrid = showGrid
            self.fillArea = fillArea
            
            // Initialize animated points to minimum value
            let min = minValue ?? (dataPoints.min() ?? 0)
            self._animatedPoints = State(initialValue: Array(repeating: min, count: dataPoints.count))
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Title if provided
                if let title = title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.retroPink)
                }
                
                // Chart container
                ZStack {
                    // Grid background
                    if showGrid {
                        RetroTheme.RetroGridView()
                            .opacity(0.2)
                    }
                    
                    // Y-axis labels
                    VStack(alignment: .leading) {
                        Text(String(format: "%.0f", yAxisMax))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        if yAxisMin != 0 {
                            Text(String(format: "%.0f", yAxisMin))
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("0")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Chart content
                    VStack {
                        // Line chart
                        GeometryReader { geometry in
                            ZStack {
                                // Fill area under the line
                                if fillArea {
                                    fillPath(in: geometry)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.retroPink.opacity(0.7), .retroPurple.opacity(0.1)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                                
                                // Line
                                linePath(in: geometry)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                                    )
                                    .shadow(color: .retroPink.opacity(0.5), radius: 4, x: 0, y: 0)
                                
                                // Data points
                                ForEach(0..<animatedPoints.count, id: \.self) { index in
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                        .position(
                                            x: xPosition(for: index, in: geometry),
                                            y: yPosition(for: animatedPoints[index], in: geometry)
                                        )
                                        .shadow(color: .retroPink.opacity(0.8), radius: 2, x: 0, y: 0)
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 20)
                        
                        // X-axis labels
                        HStack(spacing: 0) {
                            ForEach(0..<xLabels.count, id: \.self) { index in
                                Text(xLabels[index])
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                }
                .frame(height: 200)
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(10)
            }
            .onAppear {
                withAnimation(.easeOut(duration: animationDuration)) {
                    animatedPoints = dataPoints
                }
            }
            .onChange(of: dataPoints) { newDataPoints in
                withAnimation(.easeOut(duration: animationDuration)) {
                    animatedPoints = newDataPoints
                }
            }
        }
        
        /// The maximum value for the y-axis
        private var yAxisMax: Double {
            maxValue ?? (dataPoints.max() ?? 1.0)
        }
        
        /// The minimum value for the y-axis
        private var yAxisMin: Double {
            minValue ?? min(0, dataPoints.min() ?? 0)
        }
        
        /// Calculate the x-position for a data point
        /// - Parameters:
        ///   - index: The index of the data point
        ///   - geometry: The geometry proxy
        /// - Returns: The x-position in points
        private func xPosition(for index: Int, in geometry: GeometryProxy) -> CGFloat {
            let width = geometry.size.width
            let count = CGFloat(animatedPoints.count - 1)
            return CGFloat(index) * (width / count)
        }
        
        /// Calculate the y-position for a data point
        /// - Parameters:
        ///   - value: The value of the data point
        ///   - geometry: The geometry proxy
        /// - Returns: The y-position in points
        private func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
            let height = geometry.size.height
            let range = yAxisMax - yAxisMin
            let normalizedValue = (value - yAxisMin) / range
            return height - (CGFloat(normalizedValue) * height)
        }
        
        /// Create a path for the line
        /// - Parameter geometry: The geometry proxy
        /// - Returns: The path
        private func linePath(in geometry: GeometryProxy) -> Path {
            Path { path in
                guard animatedPoints.count > 1 else { return }
                
                let start = CGPoint(
                    x: xPosition(for: 0, in: geometry),
                    y: yPosition(for: animatedPoints[0], in: geometry)
                )
                
                path.move(to: start)
                
                for index in 1..<animatedPoints.count {
                    let point = CGPoint(
                        x: xPosition(for: index, in: geometry),
                        y: yPosition(for: animatedPoints[index], in: geometry)
                    )
                    path.addLine(to: point)
                }
            }
        }
        
        /// Create a path for the fill area under the line
        /// - Parameter geometry: The geometry proxy
        /// - Returns: The path
        private func fillPath(in geometry: GeometryProxy) -> Path {
            Path { path in
                guard animatedPoints.count > 1 else { return }
                
                let start = CGPoint(
                    x: xPosition(for: 0, in: geometry),
                    y: yPosition(for: animatedPoints[0], in: geometry)
                )
                
                path.move(to: start)
                
                for index in 1..<animatedPoints.count {
                    let point = CGPoint(
                        x: xPosition(for: index, in: geometry),
                        y: yPosition(for: animatedPoints[index], in: geometry)
                    )
                    path.addLine(to: point)
                }
                
                // Complete the path to create a closed shape for filling
                let lastIndex = animatedPoints.count - 1
                path.addLine(to: CGPoint(
                    x: xPosition(for: lastIndex, in: geometry),
                    y: geometry.size.height
                ))
                path.addLine(to: CGPoint(
                    x: xPosition(for: 0, in: geometry),
                    y: geometry.size.height
                ))
                path.closeSubpath()
            }
        }
    }
}

/// Preview provider for RetroCharts
struct RetroCharts_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                RetroCharts.BarChart(
                    values: [42, 78, 31, 65, 99],
                    labels: ["ROMs", "Saves", "BIOS", "Battery", "Screenshots"],
                    title: "File Counts"
                )
                
                RetroCharts.PieChart(
                    values: [42, 78, 31, 65],
                    labels: ["ROMs", "Saves", "BIOS", "Battery"],
                    title: "Storage Distribution"
                )
                
                RetroCharts.LineChart(
                    dataPoints: [10, 45, 30, 80, 65, 90, 40],
                    xLabels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                    title: "Sync Activity"
                )
            }
            .padding()
            .background(Color.retroDarkBlue.edgesIgnoringSafeArea(.all))
        }
    }
}
