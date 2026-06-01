import Foundation

public struct MarkdownTable: Equatable {
    public enum Alignment: Equatable {
        case left
        case center
        case right
    }

    public let headers: [String]
    public let alignments: [Alignment]
    public let rows: [[String]]

    public init(
        headers: [String],
        alignments: [Alignment]? = nil,
        rows: [[String]]
    ) {
        self.headers = headers
        self.alignments = alignments ?? Array(repeating: .left, count: headers.count)
        self.rows = rows
    }
}

public struct MarkdownXYChart: Equatable {
    public struct Series: Equatable {
        public enum Kind: Equatable {
            case bar
            case line
        }

        public let kind: Kind
        public let values: [Double]

        public init(kind: Kind, values: [Double]) {
            self.kind = kind
            self.values = values
        }
    }

    public let title: String
    public let xAxisLabels: [String]
    public let yAxisLabel: String
    public let yAxisRange: ClosedRange<Double>
    public let series: [Series]

    public init(
        title: String,
        xAxisLabels: [String],
        yAxisLabel: String,
        yAxisRange: ClosedRange<Double>,
        series: [Series]
    ) {
        self.title = title
        self.xAxisLabels = xAxisLabels
        self.yAxisLabel = yAxisLabel
        self.yAxisRange = yAxisRange
        self.series = series
    }
}

public enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case blockquote(String)
    case unorderedList([String])
    case orderedList([String])
    case image(alt: String, path: String)
    case codeBlock(language: String?, code: String)
    case thematicBreak
    case table(MarkdownTable)
    case xyChart(MarkdownXYChart)
}
