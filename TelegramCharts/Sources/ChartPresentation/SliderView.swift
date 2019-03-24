//
//  SliderView.swift
//  TelegramCharts
//
//  Created by Sergey Zapuhlyak on 3/16/19.
//  Copyright © 2019 @zsergey. All rights reserved.
//

import UIKit

enum SliderDirection {
    case left
    case right
    case center
    case none
    case finished
}

class SliderView: UIView, Reusable {
    
    var onChangeRange: ((IndexRange, CGFloat) ->())?
    var onBeganTouch: ((SliderDirection) ->())?
    var onEndTouch: ((SliderDirection) ->())?
    var currentRange = IndexRange(start: CGFloat(0.0), end: CGFloat(0.0))

    var chartModels: [ChartModel]? {
        didSet {
            countPoints = chartModels?.map { $0.data.count }.max() ?? 0
            setNeedsLayout()
        }
    }
    
    var colorScheme: ColorSchemeProtocol = DayScheme() {
        didSet {
            setNeedsLayout()
        }
    }
    
    var sliderWidth: CGFloat = 0

    private var startX: CGFloat = 0 {
        didSet {
            calcCurrentRange()
            setNeedsLayout()
        }
    }
    
    private var tapStartX: CGFloat = 0

    private var tapSliderWidth: CGFloat = 0

    private let tapSize: CGFloat = 34
    
    private var minValueSliderWidth: CGFloat = 0
    
    private var countPoints: Int = 0

    private var indexGap: CGFloat = 0.0

    private let mainLayer: CALayer = CALayer()
    
    private let thumbWidth: CGFloat = 11

    private let arrowWidth: CGFloat = 6

    private let arrowHeight: CGFloat = 1
    
    private let arrowCornerRadius: CGFloat = 0.25

    private let thumbCornerRadius: CGFloat = 1

    private let arrowAngle: CGFloat = 60

    private let trailingSpace: CGFloat = 16

    private let leadingSpace: CGFloat = 16
    
    private var sliderDirection: SliderDirection = .finished
    
    private var leftBackground: CAShapeLayer?

    private var rightBackground: CAShapeLayer?

    private var leftThumb: CAShapeLayer?
    
    private var rightThumb: CAShapeLayer?

    private var topLine: CAShapeLayer?
    
    private var bottomLine: CAShapeLayer?

    private var arrow1: CAShapeLayer?
    
    private var arrow2: CAShapeLayer?

    private var arrow3: CAShapeLayer?
    
    private var arrow4: CAShapeLayer?

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
    
    private func setupView() {
        layer.addSublayer(mainLayer)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
    }
    
    override func layoutSubviews() {
        self.backgroundColor = .clear
        self.calcProperties()
        self.drawSlider()
    }
    
    private func calcProperties() {
        minValueSliderWidth = 2 * thumbWidth + 2 * tapSize
        indexGap = (self.frame.size.width - trailingSpace - leadingSpace) / (CGFloat(countPoints) - 1)
        if sliderWidth == 0 {
            setSliderWidth(to: minValueSliderWidth)
        }
    }
    
    @objc private func handlePan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            tapStartX = startX
            tapSliderWidth = sliderWidth
            let point = recognizer.location(in: self)
            detectSliderTap(from: point)
            onBeganTouch?(sliderDirection)
        case .changed:
            let translation = recognizer.translation(in: self)
            switch sliderDirection {
            case .center: processCenter(translation)
            case .left: processLeft(translation)
            case .right: processRight(translation)
            default: break
            }
        case .ended:
            onEndTouch?(.finished)
        default: break
        }
    }
    
    private func processCenter(_ translation: CGPoint) {
        let minValue: CGFloat = 0
        let maxValue = self.frame.size.width - sliderWidth - trailingSpace - leadingSpace
        var value = tapStartX + translation.x
        if value < minValue {
            value = minValue
        } else if value > maxValue {
            value = maxValue
        }
        startX = value
    }
    
    private func processLeft(_ translation: CGPoint) {
        let minValueX: CGFloat = 0
        var valueX = tapStartX + translation.x
        var valueWidth = tapSliderWidth - translation.x
        if valueX < minValueX {
            valueX = minValueX
            let translationx = valueX - tapStartX
            valueWidth = tapSliderWidth - translationx
        }
        if valueWidth < minValueSliderWidth {
            valueWidth = minValueSliderWidth
            let translationx = tapSliderWidth - valueWidth
            valueX = tapStartX + translationx
        }
        startX = valueX
        setSliderWidth(to: valueWidth)
    }

    private func processRight(_ translation: CGPoint) {
        let maxValueSliderWidth = self.frame.size.width - trailingSpace - leadingSpace - tapStartX
        var valueWidth = tapSliderWidth + translation.x
        if valueWidth < minValueSliderWidth {
            valueWidth = minValueSliderWidth
        } else if valueWidth > maxValueSliderWidth {
            valueWidth = maxValueSliderWidth
        }
        setSliderWidth(to: valueWidth)
    }

    private func detectSliderTap(from point: CGPoint) {
        sliderDirection = .none
        let halfTapSize = tapSize / 2
        let x = startX + trailingSpace
        if point.x >= x - halfTapSize,
            point.x <= x + thumbWidth + halfTapSize {
            sliderDirection = .left
        } else if point.x >= x + sliderWidth - thumbWidth - halfTapSize,
            point.x <= x + sliderWidth + halfTapSize {
            sliderDirection = .right
        } else if point.x > x + thumbWidth + halfTapSize,
            point.x < x + sliderWidth - thumbWidth - halfTapSize {
            sliderDirection = .center
        }
    }
    
    private func calcCurrentRange() {
        guard indexGap != 0 else {
            return
        }
        let startIndex = startX / indexGap
        let endIndex = (startX + sliderWidth) / indexGap + 1
        currentRange.start = startIndex
        currentRange.end = endIndex
        onChangeRange?(currentRange, sliderWidth)
    }
    
    private func drawSlider() {
        CATransaction.setDisableActions(true)
        drawBackgrounds()
        drawThumbs()
        drawLines()
        drawArrows()
    }
    
    private func drawThumbs() {
        // Left Thumb.
        let color = colorScheme.slider.thumb
        var rect = CGRect(x: startX + trailingSpace, y: -1, width: thumbWidth, height: self.frame.size.height + 2)
        var corners: UIRectCorner = [.topLeft, .bottomLeft]
        if let leftThumb = leftThumb {
            let path = createRectPath(rect: rect, byRoundingCorners: corners, cornerRadius: thumbCornerRadius)
            leftThumb.path = path.cgPath
            leftThumb.changeColor(to: color, keyPath: "fillColor",
                                  animationDuration: UIView.animationDuration)
        } else {
            let leftThumb = drawRect(rect: rect, byRoundingCorners: corners, fillColor: color, cornerRadius: thumbCornerRadius)
            self.leftThumb = leftThumb
        }

        // Right Thumb.
        corners = [.topRight, .bottomRight]
        rect = CGRect(x: startX + trailingSpace + sliderWidth - thumbWidth, y: -1, width: thumbWidth, height: self.frame.size.height + 2)
        if let rightThumb = rightThumb {
            let path = createRectPath(rect: rect, byRoundingCorners: corners, cornerRadius: thumbCornerRadius)
            rightThumb.path = path.cgPath
            rightThumb.changeColor(to: color, keyPath: "fillColor",
                                   animationDuration: UIView.animationDuration)
        } else {
            let rightThumb = drawRect(rect: rect, byRoundingCorners: corners, fillColor: color, cornerRadius: thumbCornerRadius)
            self.rightThumb = rightThumb
        }
    }
    
    private func drawLines() {
        let height = self.frame.size.height
        let x = startX + trailingSpace + thumbWidth
        
        // Top Line.
        let lineWidth = sliderWidth - 1 - 2 * thumbWidth
        var rect = CGRect(x: x + 0.5, y: -0.5, width: lineWidth, height: 1)
        let color = colorScheme.slider.thumb
        if let topLine = topLine {
            let path = createRectPath(rect: rect)
            topLine.path = path.cgPath
            topLine.changeColor(to: color, keyPath: "strokeColor",
                                animationDuration: UIView.animationDuration)
        } else {
            let topLine = drawRect(rect: rect, strokeColor: color, lineWidth: 1.0)
            self.topLine = topLine
        }
        
        // Bottom Line.
        rect = CGRect(x: x + 0.5, y: height - 0.5, width: lineWidth, height: 1)
        if let bottomLine = bottomLine {
            let path = createRectPath(rect: rect)
            bottomLine.path = path.cgPath
            bottomLine.changeColor(to: color, keyPath: "strokeColor",
                                   animationDuration: UIView.animationDuration)
        } else {
            let bottomLine = drawRect(rect: rect, strokeColor: color, lineWidth: 1.0)
            self.bottomLine = bottomLine
        }
    }
    
    private func drawBackgrounds() {
        let height = self.frame.size.height
        let width = self.frame.size.width - leadingSpace
        let x = startX + trailingSpace
        
        // Left background.
        var rect = CGRect(x: trailingSpace, y: 1, width: 0, height: height - 2) // .zero
        if x > 0 {
            rect = CGRect(x: trailingSpace, y: 1, width: startX, height: height - 2)
        }
        if let leftBackground = leftBackground {
            let path = createRectPath(rect: rect)
            leftBackground.path = path.cgPath
            leftBackground.changeColor(to: colorScheme.slider.background, keyPath: "fillColor",
                                       animationDuration: UIView.animationDuration)

        } else {
            let leftBackground = drawRect(rect: rect, fillColor: colorScheme.slider.background)
            self.leftBackground = leftBackground
        }
        
        // Right background.
        rect = CGRect(x: width, y: 1, width: 0, height: height - 2) // .zero
        if x + sliderWidth < width {
            let x = x + sliderWidth
            rect = CGRect(x: x, y: 1, width: width - x, height: height - 2)
        }
        if let rightBackground = rightBackground {
            let path = createRectPath(rect: rect)
            rightBackground.path = path.cgPath
            rightBackground.changeColor(to: colorScheme.slider.background, keyPath: "fillColor",
                                        animationDuration: UIView.animationDuration)
        } else {
            let rightBackground = drawRect(rect: rect, fillColor: colorScheme.slider.background)
            self.rightBackground = rightBackground
        }
    }
    
    func createRectPath(rect: CGRect, byRoundingCorners corners: UIRectCorner = [], cornerRadius: CGFloat = 0.0) -> UIBezierPath {
        let cornerRadii = CGSize(width: cornerRadius, height: cornerRadius)
        if corners == [] {
            let path = UIBezierPath(rect: rect)
            return path
        } else {
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: cornerRadii)
            return path
        }
    }
    
    @discardableResult
    private func drawRect(rect: CGRect, byRoundingCorners corners: UIRectCorner = [],
                          strokeColor: UIColor = UIColor.clear, fillColor: UIColor = UIColor.clear,
                          lineWidth: CGFloat = 2.0, cornerRadius: CGFloat = 0.0) -> CAShapeLayer {
        let path = createRectPath(rect: rect, byRoundingCorners: corners, cornerRadius: cornerRadius)
        let rect = CAShapeLayer()
        rect.path = path.cgPath
        rect.strokeColor = strokeColor.cgColor
        rect.fillColor = fillColor.cgColor
        rect.lineWidth = lineWidth
        mainLayer.addSublayer(rect)
        return rect
    }
    
    private func createLinePath(from point1: CGPoint, to point2: CGPoint) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: point1)
        path.addLine(to: point2)
        return path
    }
    
    private func drawLine(from point1: CGPoint, to point2: CGPoint,
                          color: UIColor, lineWidth: CGFloat = 2.0) -> CAShapeLayer {
        let pathLine = createLinePath(from: point1, to: point2)
        
        let line = CAShapeLayer()
        line.path = pathLine.cgPath
        line.strokeColor = color.cgColor
        line.fillColor = UIColor.clear.cgColor
        line.lineWidth = lineWidth
        mainLayer.addSublayer(line)
        return line
    }
    
    private func drawArrows() {
        let height = self.frame.size.height
        let point1 = CGPoint(x: startX + trailingSpace + thumbWidth / 2, y: height / 2)
        let point2 = CGPoint(x: startX + trailingSpace + sliderWidth - thumbWidth / 2, y: height / 2)
        drawArrow(at: point1, left: true)
        drawArrow(at: point2, left: false)
    }
    
    private func drawArrow(at point: CGPoint, left: Bool) {
        let corners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]

        let lineWidth: CGFloat = 0.75
        let rect = CGRect(x: 0, y: 0, width: arrowWidth, height: arrowHeight)
        
        // Bottom arrow.
        var bottomArrow = left ? arrow1 : arrow2
        if bottomArrow == nil {
            let line = drawRect(rect: rect, byRoundingCorners: corners,
                                strokeColor: colorScheme.slider.arrow,
                                fillColor: colorScheme.slider.arrow,
                                lineWidth: lineWidth, cornerRadius: arrowCornerRadius)
            if left {
                self.arrow1 = line
            } else {
                self.arrow2 = line
            }
            bottomArrow = line
        }
        
        var radians = left ? arrowAngle.radians : (180 - arrowAngle).radians
        let deltaX: CGFloat = left ? 1.25 : -1.25 - lineWidth
        var transform = CATransform3DMakeTranslation(point.x - deltaX,
                                                     point.y - arrowHeight / 4, 0)
        transform = CATransform3DRotate(transform, radians, 0.0, 0.0, 1.0)
        CATransaction.setDisableActions(true)
        bottomArrow!.transform = transform

        // Top arrow.
        var topArrow = left ? arrow3 : arrow4
        if topArrow == nil {
            let line2 = drawRect(rect: rect, byRoundingCorners: corners,
                                 strokeColor: colorScheme.slider.arrow,
                                 fillColor: colorScheme.slider.arrow,
                                 lineWidth: lineWidth)
            if left {
                self.arrow3 = line2
            } else {
                self.arrow4 = line2
            }
            topArrow = line2
        }

        radians = left ? (360 - arrowAngle).radians : (180 + arrowAngle).radians
        var transform2 = CATransform3DMakeTranslation(point.x - lineWidth - deltaX,
                                                      point.y - arrowHeight / 4, 0)
        transform2 = CATransform3DRotate(transform2, radians, 0.0, 0.0, 1.0)
        topArrow!.transform = transform2
    }
    
    private func setSliderWidth(to value: CGFloat) {
        sliderWidth = value
        calcCurrentRange()
        setNeedsLayout()
    }
    
    func prepareForReuse() {
        chartModels = nil
        sliderDirection = .finished
        sliderWidth = 0
        currentRange = IndexRange(start: CGFloat(0.0), end: CGFloat(0.0))
    }

}
