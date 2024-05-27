public struct UpdateEffect: AspectEffect {
    private let action: () -> Void

    public init(perform action: @escaping () -> Void) {
        self.action = action
    }

    /// A lifecycle event that is triggered when the aspect is updated.
    public func updated(context: Context) {
        action()
    }
}
