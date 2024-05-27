import SwiftUI

public struct AspectRoot<Content: View>: View {
  private var storeHost: StoreHost
  private var overrides = [OverrideKey: any OverrideProtocol]()
  private var observers = [Observer]()
  private let content: Content
  
  
  public init(@ViewBuilder content: () -> Content) {
    self.storeHost = .tree
    self.content = content()
  }
  
  
  public init(
    storesIn store: AspectStore,
    @ViewBuilder content: () -> Content
  ) {
    self.storeHost = .unmanaged(store: store)
    self.content = content()
  }
  
  
  public var body: some View {
    switch storeHost {
    case .tree:
      TreeManaged(
        content: content,
        overrides: overrides,
        observers: observers
      )
      
    case .unmanaged(let store):
      Unmanaged(
        content: content,
        store: store,
        overrides: overrides,
        observers: observers
      )
    }
  }
  
  public func observe(_ onUpdate: @escaping @MainActor @Sendable (Snapshot) -> Void) -> Self {
    mutating(self) { $0.observers.append(Observer(onUpdate: onUpdate)) }
  }
  
  public func override<Node: Aspect>(_ aspect: Node, with value: @escaping @MainActor @Sendable (Node) -> Node.Produced) -> Self {
    mutating(self) { $0.overrides[OverrideKey(aspect)] = Override(isScoped: false, getValue: value) }
  }
  
  public func override<Node: Aspect>(_ aspectType: Node.Type, with value: @escaping @MainActor @Sendable (Node) -> Node.Produced) -> Self {
    mutating(self) { $0.overrides[OverrideKey(aspectType)] = Override(isScoped: false, getValue: value) }
  }
}

private extension AspectRoot {
  enum StoreHost {
    case tree
    case unmanaged(store: AspectStore)
  }
  
  struct TreeManaged: View {
    @MainActor final class State: ObservableObject {
      let store = AspectStore()
      let token = ScopeKey.Token()
    }
    
    let content: Content
    let overrides: [OverrideKey: any OverrideProtocol]
    let observers: [Observer]
    
    @StateObject private var state = State()
    
    var body: some View {
      content.environment(
        \.store,
         StoreContext(
          store: state.store,
          scopeKey: ScopeKey(token: state.token),
          inheritedScopeKeys: [:],
          observers: observers,
          scopedObservers: [],
          overrides: overrides,
          scopedOverrides: [:]
         )
      )
    }
  }
  
  struct Unmanaged: View {
    @MainActor final class State: ObservableObject {
      let token = ScopeKey.Token()
    }
    
    let content: Content
    let store: AspectStore
    let overrides: [OverrideKey: any OverrideProtocol]
    let observers: [Observer]
    
    @StateObject private var state = State()
    
    var body: some View {
      content.environment(
        \.store,
         StoreContext(
          store: store,
          scopeKey: ScopeKey(token: state.token),
          inheritedScopeKeys: [:],
          observers: observers,
          scopedObservers: [],
          overrides: overrides,
          scopedOverrides: [:]
         )
      )
    }
  }
}
