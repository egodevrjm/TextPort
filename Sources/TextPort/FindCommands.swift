import AppKit

enum FindCommand {
    case showFind
    case showReplace
    case next
    case previous
    case replace
    case replaceAndFind
    case replaceAll
    case useSelectionForFind

    var actionTag: Int {
        switch self {
        case .showFind: 1
        case .next: 2
        case .previous: 3
        case .replaceAll: 4
        case .replace: 5
        case .replaceAndFind: 6
        case .useSelectionForFind: 7
        case .showReplace: 12
        }
    }
}

@MainActor
enum FindCommands {
    static func perform(_ command: FindCommand) {
        let menuItem = NSMenuItem()
        menuItem.tag = command.actionTag
        NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: menuItem)
    }
}
