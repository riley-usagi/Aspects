public protocol Refreshable where Self: Aspect {
  @MainActor func refresh(context: CurrentContext) async -> Produced
}
