import Foundation

struct LiquidProgressMetrics {
    let progress: Double
    let totalWidth: CGFloat

    private var clampedProgress: Double {
        max(0, min(1, progress))
    }

    var horizontalInset: CGFloat {
        1
    }

    var verticalInset: CGFloat {
        1
    }

    var grooveHeight: CGFloat {
        max(4, LayoutRules.liquidProgressHeight - verticalInset * 2)
    }

    var rawFillWidth: CGFloat {
        let availableWidth = max(0, totalWidth - horizontalInset * 2)
        return availableWidth * clampedProgress
    }

    var minimumVisibleFillWidth: CGFloat {
        grooveHeight
    }

    var visibleFillWidth: CGFloat {
        guard rawFillWidth > 0 else {
            return 0
        }

        return max(rawFillWidth, minimumVisibleFillWidth)
    }
}
