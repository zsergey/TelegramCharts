//
//  ViewController.swift
//  TelegramCharts
//
//  Created by Sergey Zapuhlyak on 3/11/19.
//  Copyright © 2019 Sergey Zapuhlyak. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var lineChart: LineChart!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dataEntries = generateEntries()
        lineChart.dataEntries = dataEntries
    }
    
    private func generateEntries() -> [ChartModel] {
        var result: [ChartModel] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"

        if let data = DataChartModelFactory.fetchCharts() {
            // пока заполним первым массивом.
            let firstChart = data[4]
            
            var xlabel = ""
            var ylabels = [String]()
            for (label, type) in firstChart.types {
                if type == .x {
                    xlabel = label
                } else {
                    ylabels.append(label)
                }
            }
            
            for ylabel in ylabels {
                if let dataX = firstChart.data[xlabel],
                    let dataY = firstChart.data[ylabel],
                    let name = firstChart.names[ylabel],
                    let color = firstChart.colors[ylabel] {

                    var pointModels: [PointModel] = []
                    let count = min(dataX.count, dataY.count)
                    for index in 0..<count {
                        if let date = dataX[index] as? Date,
                            let value = dataY[index] as? Int {
                            let pointModel = PointModel(value: value, label: formatter.string(from: date))
                            pointModels.append(pointModel)
                        }
                    }
                    
                    let chartModel = ChartModel.init(name: name, color: color, data: pointModels)
                    result.append(chartModel)
                }
            }
        }
        
        return result
    }

}

