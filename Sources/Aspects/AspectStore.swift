@MainActor public final class AspectStore {
  internal var graph = Graph()
  internal var state = StoreState()
  
  nonisolated public init() {}
}
