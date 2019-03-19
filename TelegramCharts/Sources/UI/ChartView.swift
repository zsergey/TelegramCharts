//
//  ChartView.swift
//  TelegramCharts
//
//  Created by Sergey Zapuhlyak on 3/11/19.
//  Copyright © 2019 @zsergey. All rights reserved.
//

import UIKit

class ChartView: UIView {
    
    var chartModels: [ChartModel]? { didSet { setNeedsLayout() } }

    var range: IndexRange = (0, 0) { didSet { setNeedsLayout() } }
    
    var drawingStyle: DrawingStyleProtocol = StandardDrawingStyle() { didSet { setNeedsLayout() } }

    var colorScheme: ColorSchemeProtocol = DayScheme() { didSet { setNeedsLayout() } }
    
    var isPreviewMode: Bool = false { didSet { setNeedsLayout() } }

    var lineGap: CGFloat = 60.0
    
    var topSpace: CGFloat = 40.0
    
    var bottomSpace: CGFloat = 40.0
    
    var topHorizontalLine: CGFloat = 95.0 / 100.0
    
    var animateDots: Bool = false

    var showDots: Bool = false

    var innerRadius: CGFloat = 6

    var outerRadius: CGFloat = 10
    
    private var minValue: CGFloat = 0
    
    private var maxValue: CGFloat = 0 { didSet { setNeedsLayout() } }

    private var targetMaxValue: CGFloat = 0

    private var deltaToTargetValue: CGFloat = 0
    
    private var timeAnimation: Int = 0
    
    private var maxTimeAnimation: Int = 30 // 0.5 sec
    
    private var countPoints: Int = 0

    private let animationDuration: CFTimeInterval = 0.5
    
    private let dataLayer: CALayer = CALayer()
    
    private let mainLayer: CALayer = CALayer()
    
    private let gridLayer: CALayer = CALayer()
    
    private var dataPoints: [[CGPoint]]?

    private var chartLines: [CAShapeLayer]?

    private var gridLines: [ValueLayer]?

    private var gridLinesToRemove: [ValueLayer]?

    private var valueLayer0: ValueLayer?

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    convenience init() {
        self.init(frame: CGRect.zero)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    func update() {
        if timeAnimation < maxTimeAnimation {
            // Ease-in-out function from
            // https://math.stackexchange.com/questions/121720/ease-in-out-function
            var prevy: CGFloat = 0
            for time in 0..<maxTimeAnimation {
                let x = CGFloat(time) / CGFloat(maxTimeAnimation - 1)
                let y = (x * x) / (x * x + (1.0 - x) * (1.0 - x))
                
                let toAddValue = deltaToTargetValue * (y - prevy)
                prevy = y
                
                if time == timeAnimation {
                    maxValue = maxValue + toAddValue
                }
            }
            timeAnimation += 1
        }
    }
    
    private func setMaxValue(_ newMaxValue: CGFloat, animated: Bool = false) {
        if animated {
            guard newMaxValue != targetMaxValue else {
                return
            }
            targetMaxValue = newMaxValue
            drawHorizontalLines()
            deltaToTargetValue = newMaxValue - maxValue
            timeAnimation = 0
        } else {
            maxValue = newMaxValue
            drawHorizontalLines()
        }
    }
    
    private func setupView() {
        mainLayer.addSublayer(dataLayer)
        layer.addSublayer(gridLayer)
        layer.addSublayer(mainLayer)
        clipsToBounds = true
    }
    
    override func layoutSubviews() {
        backgroundColor = colorScheme.background
        guard let chartModels = chartModels else {
            return
        }
        calcProperties()
        
        let width = CGFloat(countPoints) * lineGap
        let height = self.frame.size.height
        mainLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        dataLayer.frame = CGRect(x: 0, y: topSpace, width: mainLayer.frame.width,
                                 height: mainLayer.frame.height - topSpace - bottomSpace)
        
        dataPoints = [[CGPoint]]()
        for index in 0..<chartModels.count {
            let points = convertDataEntriesToPoints(entries: chartModels[index].data)
            dataPoints?.append(points)
        }
        
        gridLayer.frame = CGRect(x: 0, y: topSpace, width: self.frame.width,
                                 height: mainLayer.frame.height - topSpace - bottomSpace)
        
        // clean()
        // if showDots { drawDots() }
        drawCharts()
        // drawLables()
    }
    
    private func calcProperties() {
        let animateMaxValue = maxValue == 0 ? false : true
        if isPreviewMode {
            topSpace = 0.0
            bottomSpace = 0.0
            topHorizontalLine = 110.0 / 100.0
            
            countPoints = chartModels?.map { $0.data.count }.max() ?? 0
            lineGap = self.frame.size.width / (CGFloat(countPoints) - 1)
            let max: CGFloat = chartModels?.map { chartModel in
                if chartModel.isHidden {
                    return 0
                } else {
                    return CGFloat(chartModel.data.max()?.value ?? 0)
                }}.compactMap { $0 }.max() ?? 0
            setMaxValue(max, animated: animateMaxValue)
        } else {
            topSpace = 40.0
            bottomSpace = 40.0
            topHorizontalLine = 95.0 / 100.0
            lineGap = self.frame.size.width / (range.end - range.start - 1)
            if let chartModels = chartModels {
                var max: CGFloat = 0
                for chartModel in chartModels {
                    if chartModel.isHidden { continue }
                    for i in 0..<chartModel.data.count {
                        let x = (CGFloat(i) - range.start) * lineGap
                        if x >= 0, x <= self.frame.size.width {
                            let value = CGFloat(chartModel.data[i].value)
                            if value > max {
                                max = value
                            }
                        }
                    }
                }
                setMaxValue(max, animated: animateMaxValue)
            }
        }
    }
    
    private func calcHeight(for value: Int, with minMaxGap: CGFloat) -> CGFloat {
        if value == 0 {
            return dataLayer.frame.height
        }
        if Int(minMaxGap) == 0 {
            return -dataLayer.frame.height
        }
        return dataLayer.frame.height * (1 - ((CGFloat(value) - CGFloat(minValue)) / minMaxGap))
    }
    
    private func calcLineValue(for value: CGFloat, with minMaxGap: CGFloat) -> Int {
        return Int((1 - value) * minMaxGap) + Int(minValue)
    }
    
    private func convertDataEntriesToPoints(entries: [PointModel]) -> [CGPoint] {
        var result: [CGPoint] = []
        let minMaxGap = CGFloat(maxValue - minValue) * topHorizontalLine
        let startFrom: CGFloat = 0 // isPreviewMode ? 0 : 20 // TODO: + 40
        
        for i in 0..<entries.count {
            let height = calcHeight(for: entries[i].value, with: minMaxGap)
            let point = CGPoint(x: CGFloat(i) * lineGap + startFrom, y: height)
            result.append(point)
        }
        return result
    }
    
    private func drawCharts() {
        guard let dataPoints = dataPoints, dataPoints.count > 0,
            let chartModels = chartModels else {
            return
        }
        
        let isUpdating = chartLines != nil
        var newChartLines = isUpdating ? nil : [CAShapeLayer]()
        
        for index in 0..<chartModels.count {
            let chartModel = chartModels[index]
            
            let lineLayer = isUpdating ? chartLines![index] : CAShapeLayer()
            
            var points = dataPoints[index]
            if !isPreviewMode {
                for i in 0..<points.count {
                    points[i] = CGPoint(x: (CGFloat(i) - range.start) * lineGap, y: points[i].y)
                }
            }
            
            if let path = drawingStyle.createPath(dataPoints: points) {
                if isUpdating {
                    lineLayer.path = path.cgPath
                    if chartModel.opacity != lineLayer.opacity {
                        let toValue: Float = chartModel.isHidden ? 0 : 1
                        let fromValue: Float = lineLayer.isHidden ? 0 : 1
                        lineLayer.changeOpacity(from: fromValue, to: toValue,
                                                animationDuration: animationDuration)
                    }
                    
                } else {
                    lineLayer.path = path.cgPath
                    lineLayer.strokeColor = chartModel.color.cgColor
                    lineLayer.fillColor = UIColor.clear.cgColor
                    lineLayer.lineWidth = isPreviewMode ? 1.0 : 2.0
                    dataLayer.addSublayer(lineLayer)
                    newChartLines!.append(lineLayer)
                }
            }
        }
        
        if !isUpdating {
            chartLines = newChartLines
        }
    }
        
    private func drawLables() {
        guard let chartModels = chartModels, chartModels.count > 0, !isPreviewMode else {
            return
        }
        var points: [PointModel]?
        _ = chartModels.map {
            if $0.data.count > points?.count ?? 0 { points = $0.data }
        }
        if var points = points {
            // TODO: здесь учесть видимый участок графика
            /* if !isPreviewMode {
                points = Array(points[range])
            }*/

            let startFrom: CGFloat = 0 // isPreviewMode ? 0 : 20 // TODO: + 40
            for i in 0..<points.count {
                let textLayer = CATextLayer()
                textLayer.frame = CGRect(x: CGFloat(i) * lineGap - lineGap / 2 + startFrom,
                                         y: mainLayer.frame.size.height - bottomSpace / 2 - 8,
                                         width: lineGap,
                                         height: 16)
                textLayer.foregroundColor = colorScheme.text.cgColor
                textLayer.backgroundColor = UIColor.clear.cgColor
                textLayer.alignmentMode = .center
                textLayer.contentsScale = UIScreen.main.scale
                textLayer.font = CTFontCreateWithName(UIFont.systemFont(ofSize: 0).fontName as CFString, 0, nil)
                textLayer.fontSize = 11
                textLayer.string = points[i].label
                mainLayer.addSublayer(textLayer)
            }
        }
    }
    
    private func drawHorizontalLines() {
        guard let _ = chartModels, !isPreviewMode else {
            return
        }
        
        let minMaxGap = CGFloat(maxValue - minValue) * topHorizontalLine
        let newMinMaxGap = CGFloat(targetMaxValue - minValue) * topHorizontalLine
        
        let heightGrid: CGFloat = 30
        let widthGrid: CGFloat = self.frame.size.width
        let isUpdating = self.gridLines != nil
        var newGridLines = [ValueLayer]()
        var newGridLinesToRemove = [ValueLayer]()

        _ = gridLinesToRemove?.map { $0.removeFromSuperlayer() }
        
        let gridValues: [CGFloat] = [0, 0.2, 0.4, 0.6, 0.8, 1]
        for index in 0..<gridValues.count {
            let value = gridValues[index]
            
            let lineValue = calcLineValue(for: value, with: minMaxGap)
            let newLineValue = calcLineValue(for: value, with: newMinMaxGap)
            
            let valueLayer = isUpdating ? gridLines![index] : nil
            let newValueLayer = ValueLayer()

            // Animate new layer.
            let fromNewHeight = calcHeight(for: newLineValue, with: minMaxGap)
            let fromNewFrame = CGRect(x: 0, y: fromNewHeight, width: frame.size.width, height: heightGrid)
            let toNewHeight = calcHeight(for: newLineValue, with: newMinMaxGap) + heightGrid / 2
            let toNewPoint = CGPoint(x: widthGrid / 2, y: toNewHeight)
            newValueLayer.lineColor = colorScheme.grid
            newValueLayer.textColor = colorScheme.text
            gridLayer.addSublayer(newValueLayer)
            newGridLines.append(newValueLayer)
            
            // Animate old layer.
            if let valueLayer = valueLayer {
                let toHeight = calcHeight(for: lineValue, with: newMinMaxGap) + heightGrid / 2
                let toPoint = CGPoint(x: widthGrid / 2, y: toHeight)
                let duration = value == 1 ? 0 : animationDuration
                CATransaction.setDisableActions(true)
                valueLayer.moveTo(point: toPoint, animationDuration: duration)
                valueLayer.changeOpacity(from: 1, to: 0, animationDuration: duration)
                newGridLinesToRemove.append(valueLayer)
            }
            
            if isUpdating {
                newValueLayer.lineValue = newLineValue
                let duration: CFTimeInterval = value == 1 ? 0 : animationDuration
                newValueLayer.opacity = 0
                newValueLayer.frame = fromNewFrame
                newValueLayer.moveTo(point: toNewPoint, animationDuration: duration)
                newValueLayer.changeOpacity(from: 0, to: 1, animationDuration: duration)
            } else {
                newValueLayer.lineValue = lineValue
                newValueLayer.opacity = 1
                let height = calcHeight(for: lineValue, with: minMaxGap)
                let rect = CGRect(x: 0, y: height, width: frame.size.width, height: heightGrid)
                newValueLayer.frame = rect
            }
        }
        
        gridLines = newGridLines
        gridLinesToRemove = newGridLinesToRemove
    }
    
    private func clean() {
        // TODO: удалить если ненужно
        /*mainLayer.sublayers?.forEach {
            if $0 is CATextLayer || $0 is DotCALayer{
                $0.removeFromSuperlayer()
            }
        }
        dataLayer.sublayers?.forEach { $0.removeFromSuperlayer() }*/
        gridLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    private func drawDots() {
        guard let dataPoints = dataPoints, dataPoints.count > 0, !isPreviewMode,
            let chartModels = chartModels else {
            return
        }
        
        for index in 0..<chartModels.count {
            let chartModel = chartModels[index]
            // if chartModel.isHidden { continue }
            
            var dotLayers: [DotLayer] = []
            var points = dataPoints[index]
            // TODO: здесь учесть видимый участок графика
            /* if !isPreviewMode {
                points = Array(points[range])
            }*/
            for i in 0..<points.count {
                let dataPoint = points[i]
                let xValue = CGFloat(i) * lineGap - outerRadius / 2
                let yValue = dataPoint.y + bottomSpace - outerRadius / 2
                let dotLayer = DotLayer()
                dotLayer.dotInnerColor = colorScheme.background
                dotLayer.innerRadius = innerRadius
                dotLayer.backgroundColor = chartModel.color.cgColor
                dotLayer.cornerRadius = outerRadius / 2
                dotLayer.frame = CGRect(x: xValue, y: yValue, width: outerRadius, height: outerRadius)
                dotLayers.append(dotLayer)
                
                mainLayer.addSublayer(dotLayer)
                
                if animateDots {
                    let anim = CABasicAnimation(keyPath: "opacity")
                    anim.duration = 1.0
                    anim.fromValue = 0
                    anim.toValue = 1
                    dotLayer.add(anim, forKey: "opacity")
                }
            }
        }
    }
    
}
