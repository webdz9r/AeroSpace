public struct StickyCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .sticky,
        help: sticky_help_generated,
        flags: [
            "--window-id": windowIdSubArgParser(),
        ],
        posArgs: [ArgParser(\.toggle, parseStickyToggleEnum)],
    )

    public var toggle: ToggleEnum = .toggle
}

func parseStickyCmdArgs(_ args: StrArrSlice) -> ParsedCmd<StickyCmdArgs> {
    parseSpecificCmdArgs(StickyCmdArgs(rawArgs: args), args)
}

// Unlike 'parseToggleEnum', 'toggle' is accepted as an explicit argument too
func parseStickyToggleEnum(i: PosArgParserInput) -> ParsedCliArgs<ToggleEnum> {
    switch i.arg {
        case "on": .succ(.on, advanceBy: 1)
        case "off": .succ(.off, advanceBy: 1)
        case "toggle": .succ(.toggle, advanceBy: 1)
        default: .fail("Can't parse '\(i.arg)'. Possible values: on|off|toggle", advanceBy: 1)
    }
}
