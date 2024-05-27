import SwiftUI

@MainActor public struct AspectViewContext: AspectWatchableContext {
  @usableFromInline
  internal let _store: StoreContext
  @usableFromInline
  internal let _subscriber: Subscriber
  @usableFromInline
  internal let _subscription: Subscription
  
  internal init(
    store: StoreContext,
    subscriber: Subscriber,
    subscription: Subscription
  ) {
    _store = store
    _subscriber = subscriber
    _subscription = subscription
  }
  
  @inlinable
  public func read<Node: Aspect>(_ aspect: Node) -> Node.Produced {
    _store.read(aspect)
  }
  
  @inlinable
  public func set<Node: StateAspect>(_ value: Node.Produced, for aspect: Node) {
    _store.set(value, for: aspect)
  }
  @inlinable
  public func modify<Node: StateAspect>(_ aspect: Node, body: (inout Node.Produced) -> Void) {
    _store.modify(aspect, body: body)
  }
  
  @inlinable
  @_disfavoredOverload
  @discardableResult
  public func refresh<Node: AsyncAspect>(_ aspect: Node) async -> Node.Produced {
    await _store.refresh(aspect)
  }
  
  @inlinable
  @discardableResult
  public func refresh<Node: Refreshable>(_ aspect: Node) async -> Node.Produced {
    await _store.refresh(aspect)
  }
  
  @inlinable
  @_disfavoredOverload
  public func reset<Node: Aspect>(_ aspect: Node) {
    _store.reset(aspect)
  }
  
  @inlinable
  public func reset<Node: Resettable>(_ aspect: Node) {
    _store.reset(aspect)
  }
  
  @discardableResult
  @inlinable
  public func watch<Node: Aspect>(_ aspect: Node) -> Node.Produced {
    _store.watch(
      aspect,
      subscriber: _subscriber,
      subscription: _subscription
    )
  }
  
  @inlinable
  public func binding<Node: StateAspect>(_ aspect: Node) -> Binding<Node.Produced> {
    Binding(
      get: { watch(aspect) },
      set: { set($0, for: aspect) }
    )
  }
  
  @inlinable
  public func snapshot() -> Snapshot {
    _store.snapshot()
  }
  
  @inlinable
  public func restore(_ snapshot: Snapshot) {
    _store.restore(snapshot)
  }
}
