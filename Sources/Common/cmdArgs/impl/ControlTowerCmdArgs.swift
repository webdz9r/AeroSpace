public struct ControlTowerCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .controlTower,
        help: control_tower_help_generated,
        flags: [:],
        posArgs: [],
    )
}
