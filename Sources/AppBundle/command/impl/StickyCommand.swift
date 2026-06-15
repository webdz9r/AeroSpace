import AppKit
import Common

struct StickyCommand: Command {
    let args: StickyCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !window.isSticky
        }
        window.isSticky = newState
        // Sticky is scoped to floating windows so they don't disrupt the tiling tree.
        // See: https://github.com/nikitabobko/AeroSpace/issues/2
        if newState && !window.isFloating {
            window.bindAsFloatingWindow(to: target.workspace)
        }
        window.markAsMostRecentChild()
        return .succ
    }
}
