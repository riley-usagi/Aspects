@preconcurrency import Combine

@MainActor public struct AspectTestContext: AspectWatchableContext {
  private let location: SourceLocation
  
  @usableFromInline internal let _state = State()
  
  
  public init(fileID: String = #fileID, line: UInt = #line) {
    location = SourceLocation(fileID: fileID, line: line)
  }
  
  @inlinable public var onUpdate: (() -> Void)? {
    get { _state.onUpdate }
    nonmutating set { _state.onUpdate = newValue }
  }
  
  @inlinable @discardableResult public func waitForUpdate(timeout duration: Double? = nil) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
      let updates = _state.makeUpdateStream()
      
      group.addTask { @MainActor in
        for await _ in updates {
          return true
        }
        return false
      }
      
      if let duration {
        group.addTask {
          try? await Task.sleep(seconds: duration)
          return false
        }
      }
      
      for await didUpdate in group {
        group.cancelAll()
        return didUpdate
      }
      
      return false
    }
  }
  
  @inlinable @discardableResult public func wait<Node: Aspect>(
    for aspect: Node,
    timeout duration: Double? = nil,
    until predicate: @escaping (Node.Produced) -> Bool
  ) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
      @MainActor
      func check() -> Bool {
        guard let value = lookup(aspect) else {
          return false
        }
        
        return predicate(value)
      }
      
      let updates = _state.makeUpdateStream()
      
      group.addTask { @MainActor in
        guard !check() else {
          return false
        }
        
        for await _ in updates {
          if check() {
            return true
          }
        }
        
        return false
      }
      
      if let duration {
        group.addTask {
          try? await Task.sleep(seconds: duration)
          return false
        }
      }
      
      for await didUpdate in group {
        group.cancelAll()
        return didUpdate
      }
      
      return false
    }
  }
  
  @inlinable public func read<Node: Aspect>(_ aspect: Node) -> Node.Produced {
    _store.read(aspect)
  }
  
  @inlinable public func set<Node: StateAspect>(_ value: Node.Produced, for aspect: Node) {
    _store.set(value, for: aspect)
  }
  
  @inlinable public func modify<Node: StateAspect>(_ aspect: Node, body: (inout Node.Produced) -> Void) {
    _store.modify(aspect, body: body)
  }
  
  @inlinable @_disfavoredOverload @discardableResult public func refresh<Node: AsyncAspect>(_ aspect: Node) async -> Node.Produced {
    await _store.refresh(aspect)
  }
  
  @inlinable @discardableResult public func refresh<Node: Refreshable>(_ aspect: Node) async -> Node.Produced {
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
    _store.watch(
      aspect,
      subscriber: _subscriber,
      subscription: _subscription
    )
  }
  
  @inlinable
  public func lookup<Node: Aspect>(_ aspect: Node) -> Node.Produced? {
    _store.lookup(aspect)
  }
  
  @inlinable
  public func unwatch(_ aspect: some Aspect) {
    _store.unwatch(aspect, subscriber: _subscriber)
  }
  
  @inlinable
  public func override<Node: Aspect>(_ aspect: Node, with value: @escaping @MainActor @Sendable (Node) -> Node.Produced) {
    _state.overrides[OverrideKey(aspect)] = Override(isScoped: false, getValue: value)
  }
  
  @inlinable
  public func override<Node: Aspect>(_ aspectType: Node.Type, with value: @escaping @MainActor @Sendable (Node) -> Node.Produced) {
    _state.overrides[OverrideKey(aspectType)] = Override(isScoped: false, getValue: value)
  }
}

internal extension AspectTestContext {
  @usableFromInline
  @MainActor
  final class State {
    @usableFromInline
    let store = AspectStore()
    let token = ScopeKey.Token()
    let subscriberState = SubscriberState()
    
    @usableFromInline
    var overrides = [OverrideKey: any OverrideProtocol]()
    
    @usableFromInline
    var onUpdate: (() -> Void)?
    
    private let notifier = PassthroughSubject<Void, Never>()
    
    @usableFromInline
    func makeUpdateStream() -> AsyncStream<Void> {
      AsyncStream { continuation in
        let cancellable = notifier.sink(
          receiveCompletion: { _ in
            continuation.finish()
          },
          receiveValue: {
            continuation.yield()
          }
        )
        
        continuation.onTermination = { termination in
          if case .cancelled = termination {
            cancellable.cancel()
          }
        }
      }
    }
    
    @usableFromInline
    func update() {
      onUpdate?()
      notifier.send()
    }
  }
  
  @usableFromInline
  var _store: StoreContext {
    StoreContext(
      store: _state.store,
      scopeKey: ScopeKey(token: _state.token),
      inheritedScopeKeys: [:],
      observers: [],
      scopedObservers: [],
      overrides: _state.overrides,
      scopedOverrides: [:]
    )
  }
  
  @usableFromInline
  var _subscriber: Subscriber {
    Subscriber(_state.subscriberState)
  }
  
  @usableFromInline
  var _subscription: Subscription {
    Subscription(location: location) { [weak _state] in
      _state?.update()
    }
  }
}
