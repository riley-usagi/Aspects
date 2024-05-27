public protocol Resettable where Self: Aspect {
  @MainActor func reset(context: CurrentContext)
}
