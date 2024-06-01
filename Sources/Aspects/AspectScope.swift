import SwiftUI

public struct AspectScope<Content: View>: View {
  private let inheritance: Inheritance
  private var overrides: [OverrideKey: any OverrideProtocol]
  private var observers: [Observer]
  private let content: Content
  
  public init<ID: Hashable>(id: ID = DefaultScopeID(), @ViewBuilder content: () -> Content) {
    let id = ScopeID(id)
    self.inheritance = .environment(id: id)
    self.overrides = [:]
    self.observers = []
    self.content = content()
  }
  
  public init(
    inheriting context: AspectViewContext,
    @ViewBuilder content: () -> Content
  ) {
    let store = context._store
    self.inheritance = .context(store: store)
    self.overrides = store.scopedOverrides
    self.observers = store.scopedObservers
    self.content = content()
  }
  
  public var body: some View {
    switch inheritance {
    case .environment(let id):
      InheritedEnvironment(
        id: id,
        content: content,
        overrides: overrides,
        observers: observers
      )
      
    case .context(let store):
      InheritedContext(
        content: content,
        store: store,
        overrides: overrides,
        observers: observers
      )
    }
  }
  
  public func scopedObserve(_ onUpdate: @escaping @MainActor @Sendable (Snapshot) -> Void) -> Self {
    mutating(self) { $0.observers.append(Observer(onUpdate: onUpdate)) }
  }
  
  public func scopedOverride<Node: Aspect>(_ aspect: Node, with value: @escaping @MainActor @Sendable (Node) -> Node.Produced) -> Self {
    mutating(self) { $0.overrides[OverrideKey(aspect)] = Override(isScoped: true, getValue: value) }
  }
  
  public func scopedOverride<Node: Aspect>(_ aspectType: Node.Type, with value: @escaping @MainActor @Sendable (Node) -> Node.Produced) -> Self {
    mutating(self) { $0.overrides[OverrideKey(aspectType)] = Override(isScoped: true, getValue: value) }
  }
}

private extension AspectScope {
  enum Inheritance {
    case environment(id: ScopeID)
    case context(store: StoreContext)
  }
  
  struct InheritedEnvironment: View {
    
    @MainActor final class State: ObservableObject {
      let token = ScopeKey.Token()
    }
    
    let id: ScopeID
    let content: Content
    let overrides: [OverrideKey: any OverrideProtocol]
    let observers: [Observer]
    
    @StateObject private var state = State()
    
    @Environment(\.store) private var environmentStore
    
    var body: some View {
      content.environment(
        \.store,
         environmentStore?.scoped(
          scopeKey: ScopeKey(token: state.token),
          scopeID: id,
          observers: observers,
          overrides: overrides
         )
      )
    }
  }
  
  struct InheritedContext: View {
    let content: Content
    let store: StoreContext
    let overrides: [OverrideKey: any OverrideProtocol]
    let observers: [Observer]
    
    var body: some View {
      content.environment(
        \.store,
         store.inherited(
          scopedObservers: observers,
          scopedOverrides: overrides
         )
      )
    }
  }
}
