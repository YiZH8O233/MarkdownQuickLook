import AppKit

public struct MarkdownRenderTheme: @unchecked Sendable {
    public let backgroundColor: NSColor
    public let primaryTextColor: NSColor
    public let secondaryTextColor: NSColor
    public let heading1TextColor: NSColor
    public let heading2TextColor: NSColor
    public let heading3TextColor: NSColor
    public let boldTextColor: NSColor
    public let quoteAccentColor: NSColor
    public let tableHeaderBackgroundColor: NSColor
    public let codeBackgroundColor: NSColor
    public let highlightBackgroundColor: NSColor
    public let ruleColor: NSColor
    public let subtleRuleColor: NSColor
    public let chartColor: NSColor

    public init(
        backgroundColor: NSColor,
        primaryTextColor: NSColor,
        secondaryTextColor: NSColor,
        heading1TextColor: NSColor,
        heading2TextColor: NSColor,
        heading3TextColor: NSColor,
        boldTextColor: NSColor,
        quoteAccentColor: NSColor,
        tableHeaderBackgroundColor: NSColor,
        codeBackgroundColor: NSColor,
        highlightBackgroundColor: NSColor,
        ruleColor: NSColor,
        subtleRuleColor: NSColor,
        chartColor: NSColor
    ) {
        self.backgroundColor = backgroundColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.heading1TextColor = heading1TextColor
        self.heading2TextColor = heading2TextColor
        self.heading3TextColor = heading3TextColor
        self.boldTextColor = boldTextColor
        self.quoteAccentColor = quoteAccentColor
        self.tableHeaderBackgroundColor = tableHeaderBackgroundColor
        self.codeBackgroundColor = codeBackgroundColor
        self.highlightBackgroundColor = highlightBackgroundColor
        self.ruleColor = ruleColor
        self.subtleRuleColor = subtleRuleColor
        self.chartColor = chartColor
    }

    public static let academicInkBlue = MarkdownRenderTheme(
        backgroundColor: dynamicColor(light: 0xF7F7F2, dark: 0x1F2020),
        primaryTextColor: dynamicColor(light: 0x2C2C2A, dark: 0xEFEFEB),
        secondaryTextColor: dynamicColor(light: 0x888780, dark: 0xA3A39C),
        heading1TextColor: dynamicColor(light: 0x0C447C, dark: 0x8DB7E3),
        heading2TextColor: dynamicColor(light: 0x185FA5, dark: 0x99C5F0),
        heading3TextColor: dynamicColor(light: 0x185FA5, dark: 0x99C5F0),
        boldTextColor: dynamicColor(light: 0x185FA5, dark: 0x9DC8F3),
        quoteAccentColor: dynamicColor(light: 0x378ADD, dark: 0x79B5EF),
        tableHeaderBackgroundColor: dynamicColor(light: 0xF1F4F6, dark: 0x282B2E),
        codeBackgroundColor: dynamicColor(light: 0xF1F4F6, dark: 0x282B2E),
        highlightBackgroundColor: dynamicColor(light: 0xE5F2FF, dark: 0x173A56),
        ruleColor: dynamicColor(light: 0xD8D8D2, dark: 0x484A4A),
        subtleRuleColor: dynamicColor(light: 0xDCE5EC, dark: 0x33414D),
        chartColor: dynamicColor(light: 0x0C447C, dark: 0x8DB7E3)
    )
}

private func dynamicColor(light: UInt32, dark: UInt32) -> NSColor {
    NSColor(name: nil) { appearance in
        let match = appearance.bestMatch(from: [
            .darkAqua,
            .aqua,
            .accessibilityHighContrastDarkAqua,
            .accessibilityHighContrastAqua
        ])
        let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
        return rgbColor(isDark ? dark : light)
    }
}

private func rgbColor(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}
