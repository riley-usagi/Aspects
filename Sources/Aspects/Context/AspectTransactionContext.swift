@MainActor public struct AspectTransactionContext: AspectWatchableContext {
  @usableFromInline
  internal let _store: StoreContext
  @usableFromInline
  internal let _transaction: Transaction
  
  internal init(
    store: StoreContext,
    transaction: Transaction
  ) {
    self._store = store
    self._transaction = transaction
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
  
  @inlinable
  @discardableResult
  public func watch<Node: Aspect>(_ aspect: Node) -> Node.Produced {
    _store.watch(aspect, in: _transaction)
  }
}
