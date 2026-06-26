import AppKit
import Common

struct ControlTowerCommand: Command {
    let args: ControlTowerCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        ControlTowerPanel.shared.toggle()
        return .succ
    }
}
