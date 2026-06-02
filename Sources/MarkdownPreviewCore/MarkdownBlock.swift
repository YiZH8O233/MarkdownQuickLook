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

public struct MarkdownPieChart: Equatable {
    public struct Slice: Equatable {
        public let label: String
        public let value: Double

        public init(label: String, value: Double) {
            self.label = label
            self.value = value
        }
    }

    public let title: String
    public let showData: Bool
    public let slices: [Slice]

    public init(title: String, showData: Bool, slices: [Slice]) {
        self.title = title
        self.showData = showData
        self.slices = slices
    }
}

public struct MarkdownQuadrantChart: Equatable {
    public struct Point: Equatable {
        public let label: String
        public let x: Double
        public let y: Double

        public init(label: String, x: Double, y: Double) {
            self.label = label
            self.x = x
            self.y = y
        }
    }

    public let title: String
    public let xAxisStart: String
    public let xAxisEnd: String
    public let yAxisStart: String
    public let yAxisEnd: String
    public let quadrants: [String]
    public let points: [Point]

    public init(
        title: String,
        xAxisStart: String,
        xAxisEnd: String,
        yAxisStart: String,
        yAxisEnd: String,
        quadrants: [String],
        points: [Point]
    ) {
        self.title = title
        self.xAxisStart = xAxisStart
        self.xAxisEnd = xAxisEnd
        self.yAxisStart = yAxisStart
        self.yAxisEnd = yAxisEnd
        self.quadrants = quadrants
        self.points = points
    }
}

public struct MarkdownTimeline: Equatable {
    public struct Period: Equatable {
        public let label: String
        public let events: [String]

        public init(label: String, events: [String]) {
            self.label = label
            self.events = events
        }
    }

    public let title: String
    public let periods: [Period]

    public init(title: String, periods: [Period]) {
        self.title = title
        self.periods = periods
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
    case pieChart(MarkdownPieChart)
    case quadrantChart(MarkdownQuadrantChart)
    case timeline(MarkdownTimeline)
}
