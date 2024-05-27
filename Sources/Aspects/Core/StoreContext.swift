@usableFromInline @MainActor internal struct StoreContext {
  private let store: AspectStore
  private let scopeKey: ScopeKey
  private let inheritedScopeKeys: [ScopeID: ScopeKey]
  private let observers: [Observer]
  private let overrides: [OverrideKey: any OverrideProtocol]
  
  let scopedObservers: [Observer]
  let scopedOverrides: [OverrideKey: any OverrideProtocol]
  
  init(
    store: AspectStore,
    scopeKey: ScopeKey,
    inheritedScopeKeys: [ScopeID: ScopeKey],
    observers: [Observer],
    scopedObservers: [Observer],
    overrides: [OverrideKey: any OverrideProtocol],
    scopedOverrides: [OverrideKey: any OverrideProtocol]
  ) {
    self.store = store
    self.scopeKey = scopeKey
    self.inheritedScopeKeys = inheritedScopeKeys
    self.observers = observers
    self.scopedObservers = scopedObservers
    self.overrides = overrides
    self.scopedOverrides = scopedOverrides
  }
  
  func inherited(
    scopedObservers: [Observer],
    scopedOverrides: [OverrideKey: any OverrideProtocol]
  ) -> StoreContext {
    StoreContext(
      store: store,
      scopeKey: scopeKey,
      inheritedScopeKeys: inheritedScopeKeys,
      observers: observers,
      scopedObservers: scopedObservers,
      overrides: overrides,
      scopedOverrides: scopedOverrides
    )
  }
  
  func scoped(
    scopeKey: ScopeKey,
    scopeID: ScopeID,
    observers: [Observer],
    overrides: [OverrideKey: any OverrideProtocol]
  ) -> StoreContext {
    StoreContext(
      store: store,
      scopeKey: scopeKey,
      inheritedScopeKeys: mutating(inheritedScopeKeys) { $0[scopeID] = scopeKey },
      observers: self.observers,
      scopedObservers: observers,
      overrides: self.overrides,
      scopedOverrides: overrides
    )
  }
  
  @usableFromInline
  func read<Node: Aspect>(_ aspect: Node) -> Node.Produced {
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    
    if let cache = lookupCache(of: aspect, for: key) {
      return cache.value
    }
    else {
      let value = initialize(of: aspect, for: key, override: override)
      checkAndRelease(for: key)
      return value
    }
  }
  
  @usableFromInline
  func set<Node: StateAspect>(_ value: Node.Produced, for aspect: Node) {
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    
    if let cache = lookupCache(of: aspect, for: key) {
      update(aspect: aspect, for: key, oldValue: cache.value, newValue: value)
    }
  }
  
  @usableFromInline
  func modify<Node: StateAspect>(_ aspect: Node, body: (inout Node.Produced) -> Void) {
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    
    if let cache = lookupCache(of: aspect, for: key) {
      let newValue = mutating(cache.value, body)
      update(aspect: aspect, for: key, oldValue: cache.value, newValue: newValue)
    }
  }
  
  @usableFromInline
  func watch<Node: Aspect>(_ aspect: Node, in transaction: Transaction) -> Node.Produced {
    guard !transaction.isTerminated else {
      return read(aspect)
    }
    
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    let cache = lookupCache(of: aspect, for: key)
    let value = cache?.value ?? initialize(of: aspect, for: key, override: override)
    
    // Add an `Edge` from the upstream to downstream.
    store.graph.dependencies[transaction.key, default: []].insert(key)
    store.graph.children[key, default: []].insert(transaction.key)
    
    return value
  }
  
  @usableFromInline
  func watch<Node: Aspect>(
    _ aspect: Node,
    subscriber: Subscriber,
    subscription: Subscription
  ) -> Node.Produced {
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    let cache = lookupCache(of: aspect, for: key)
    let value = cache?.value ?? initialize(of: aspect, for: key, override: override)
    let isNewSubscription = subscriber.subscribing.insert(key).inserted
    
    if isNewSubscription {
      store.state.subscriptions[key, default: [:]][subscriber.key] = subscription
      subscriber.unsubscribe = { keys in
        unsubscribe(keys, for: subscriber.key)
      }
      notifyUpdateToObservers()
    }
    
    return value
  }
  
  @usableFromInline
  @_disfavoredOverload
  func refresh<Node: AsyncAspect>(_ aspect: Node) async -> Node.Produced {
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    let context = prepareForTransaction(of: aspect, for: key)
    let value: Node.Produced
    
    if let override {
      value = override.getValue(aspect)
    }
    else {
      value = await aspect.refreshProducer.getValue(context)
    }
    
    await aspect.refreshProducer.refreshValue(value, context)
    
    guard let cache = lookupCache(of: aspect, for: key) else {
      checkAndRelease(for: key)
      return value
    }
    
    // Notify update unless it's cancelled or terminated by other operations.
    if !Task.isCancelled && !context.isTerminated {
      update(aspect: aspect, for: key, oldValue: cache.value, newValue: value)
    }
    
    return value
  }
  
  @usableFromInline
  func refresh<Node: Refreshable>(_ aspect: Node) async -> Node.Produced {
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    let state = getState(of: aspect, for: key)
    let context = AspectCurrentContext(store: self)
    
    // Detach the dependencies once to delay updating the downstream until
    // this aspect's value refresh is complete.
    let dependencies = detachDependencies(for: key)
    let value = await aspect.refresh(context: context)
    
    // Restore dependencies when the refresh is completed.
    attachDependencies(dependencies, for: key)
    
    guard let transaction = state.transaction, let cache = lookupCache(of: aspect, for: key) else {
      checkAndRelease(for: key)
      return value
    }
    
    // Notify update unless it's cancelled or terminated by other operations.
    if !Task.isCancelled && !transaction.isTerminated {
      update(aspect: aspect, for: key, oldValue: cache.value, newValue: value)
    }
    
    return value
  }
  
  @usableFromInline
  @_disfavoredOverload
  func reset<Node: Aspect>(_ aspect: Node) {
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    
    if let cache = lookupCache(of: aspect, for: key) {
      let newValue = getValue(of: aspect, for: key, override: override)
      update(aspect: aspect, for: key, oldValue: cache.value, newValue: newValue)
    }
  }
  
  @usableFromInline
  func reset<Node: Resettable>(_ aspect: Node) {
    let context = AspectCurrentContext(store: self)
    aspect.reset(context: context)
  }
  
  @usableFromInline
  func lookup<Node: Aspect>(_ aspect: Node) -> Node.Produced? {
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    let cache = lookupCache(of: aspect, for: key)
    
    return cache?.value
  }
  
  @usableFromInline
  func unwatch(_ aspect: some Aspect, subscriber: Subscriber) {
    let override = lookupOverride(of: aspect)
    let scopeKey = lookupScopeKey(of: aspect, override: override)
    let key = AspectKey(aspect, scopeKey: scopeKey)
    
    subscriber.subscribing.remove(key)
    unsubscribe([key], for: subscriber.key)
  }
  
  @usableFromInline
  func snapshot() -> Snapshot {
    Snapshot(
      graph: store.graph,
      caches: store.state.caches,
      subscriptions: store.state.subscriptions
    )
  }
  
  @usableFromInline
  func restore(_ snapshot: Snapshot) {
    let keys = snapshot.caches.keys
    var disusedDependencies = [AspectKey: Set<AspectKey>]()
    
    for key in keys {
      let oldDependencies = store.graph.dependencies[key]
      let newDependencies = snapshot.graph.dependencies[key]
      
      // Update aspect values and the graph.
      store.state.caches[key] = snapshot.caches[key]
      store.graph.dependencies[key] = newDependencies
      store.graph.children[key] = snapshot.graph.children[key]
      disusedDependencies[key] = oldDependencies?.subtracting(newDependencies ?? [])
    }
    
    for key in keys {
      // Release if the aspect is no longer used.
      checkAndRelease(for: key)
      
      // Release dependencies that are no longer dependent.
      if let dependencies = disusedDependencies[key] {
        for dependency in dependencies {
          store.graph.children[dependency]?.remove(key)
          checkAndRelease(for: dependency)
        }
      }
      
      // Notify updates only for the subscriptions of restored aspects.
      if let subscriptions = store.state.subscriptions[key] {
        for subscription in subscriptions.values {
          subscription.update()
        }
      }
    }
    
    notifyUpdateToObservers()
  }
}

private extension StoreContext {
  func initialize<Node: Aspect>(
    of aspect: Node,
    for key: AspectKey,
    override: Override<Node>?
  ) -> Node.Produced {
    let value = getValue(of: aspect, for: key, override: override)
    let state = getState(of: aspect, for: key)
    
    store.state.caches[key] = AspectCache(aspect: aspect, value: value)
    
    let context = AspectCurrentContext(store: self)
    state.effect.initialized(context: context)
    
    return value
  }
  
  func update<Node: Aspect>(
    aspect: Node,
    for key: AspectKey,
    oldValue: Node.Produced,
    newValue: Node.Produced
  ) {
    store.state.caches[key] = AspectCache(aspect: aspect, value: newValue)
    
    // Check whether if the dependent aspects should be updated transitively.
    guard aspect.producer.shouldUpdate(oldValue, newValue) else {
      return
    }
    
    // Perform side effects first.
    let state = getState(of: aspect, for: key)
    let context = AspectCurrentContext(store: self)
    aspect.updated(newValue: newValue, oldValue: oldValue, context: context)
    state.effect.updated(context: context)
    
    // Calculate topological order for updating downstream efficiently.
    let (edges, redundantDependencies) = store.topologicalSorted(key: key)
    var skippedDependencies = Set<AspectKey>()
    
    // Updates the given aspect.
    func update(for key: AspectKey, cache: some AspectCacheProtocol) {
      let override = lookupOverride(of: cache.aspect)
      let newValue = getValue(of: cache.aspect, for: key, override: override)
      
      store.state.caches[key] = AspectCache(aspect: cache.aspect, value: newValue)
      
      // Check whether if the dependent aspects should be updated transitively.
      guard cache.aspect.producer.shouldUpdate(cache.value, newValue) else {
        // Record the aspect to avoid downstream from being update.
        skippedDependencies.insert(key)
        return
      }
      
      // Perform side effects before updating downstream.
      let state = getState(of: cache.aspect, for: key)
      cache.aspect.updated(newValue: newValue, oldValue: cache.value, context: context)
      state.effect.updated(context: context)
    }
    
    // Performs update of the given aspect with the dependency's context.
    func performUpdate(for key: AspectKey, cache: some AspectCacheProtocol, dependency: some Aspect) {
      dependency.producer.performUpdate {
        update(for: key, cache: cache)
      }
    }
    
    // Performs update of the given subscription with the dependency's context.
    func performUpdate(subscription: Subscription, dependency: some Aspect) {
      dependency.producer.performUpdate(subscription.update)
    }
    
    func validEdge(_ edge: Edge) -> Edge? {
      // Do not transitively update aspects that have dependency recorded not to update downstream.
      guard skippedDependencies.contains(edge.from) else {
        return edge
      }
      
      // If the topological sorting has marked the vertex as a redundant, the update still performed.
      guard let fromKey = redundantDependencies[edge.to]?.first(where: { !skippedDependencies.contains($0) }) else {
        return nil
      }
      
      // Convert edge's `from`, which represents a dependency aspect, to a non-skipped one to
      // change the update transaction context (e.g. animation).
      return Edge(from: fromKey, to: edge.to)
    }
    
    // Perform transitive update for dependent aspects ahead of notifying updates to subscriptions.
    for edge in edges {
      switch edge.to {
      case .aspect(let key):
        guard let edge = validEdge(edge) else {
          // Record the aspect to avoid downstream from being update.
          skippedDependencies.insert(key)
          continue
        }
        
        let cache = store.state.caches[key]
        let dependencyCache = store.state.caches[edge.from]
        
        if let cache, let dependencyCache {
          performUpdate(for: key, cache: cache, dependency: dependencyCache.aspect)
        }
        
      case .subscriber(let key):
        guard let edge = validEdge(edge) else {
          continue
        }
        
        let subscription = store.state.subscriptions[edge.from]?[key]
        let dependencyCache = store.state.caches[edge.from]
        
        if let subscription, let dependencyCache {
          performUpdate(subscription: subscription, dependency: dependencyCache.aspect)
        }
      }
    }
    
    // Notify the observers after all updates are completed.
    notifyUpdateToObservers()
  }
  
  func release(for key: AspectKey) {
    let dependencies = store.graph.dependencies.removeValue(forKey: key)
    let state = store.state.states.removeValue(forKey: key)
    
    store.graph.children.removeValue(forKey: key)
    store.state.caches.removeValue(forKey: key)
    store.state.subscriptions.removeValue(forKey: key)
    
    if let dependencies {
      for dependency in dependencies {
        store.graph.children[dependency]?.remove(key)
        checkAndRelease(for: dependency)
      }
    }
    
    state?.transaction?.terminate()
    
    let context = AspectCurrentContext(store: self)
    state?.effect.released(context: context)
  }
  
  func checkAndRelease(for key: AspectKey) {
    // The condition under which an aspect may be released are as follows:
    //     1. It's not marked as `KeepAlive`, is marked as `Scoped`, or is scoped by override.
    //     2. It has no downstream aspects.
    //     3. It has no subscriptions from views.
    lazy var shouldKeepAlive = !key.isScoped && store.state.caches[key].map { $0.aspect is any KeepAlive } ?? false
    lazy var isChildrenEmpty = store.graph.children[key]?.isEmpty ?? true
    lazy var isSubscriptionEmpty = store.state.subscriptions[key]?.isEmpty ?? true
    lazy var shouldRelease = !shouldKeepAlive && isChildrenEmpty && isSubscriptionEmpty
    
    guard shouldRelease else {
      return
    }
    
    release(for: key)
  }
  
  func detachDependencies(for key: AspectKey) -> Set<AspectKey> {
    // Remove current dependencies.
    let dependencies = store.graph.dependencies.removeValue(forKey: key) ?? []
    
    // Detatch the aspect from its children.
    for dependency in dependencies {
      store.graph.children[dependency]?.remove(key)
    }
    
    return dependencies
  }
  
  func attachDependencies(_ dependencies: Set<AspectKey>, for key: AspectKey) {
    // Set dependencies.
    store.graph.dependencies[key] = dependencies
    
    // Attach the aspect to its children.
    for dependency in dependencies {
      store.graph.children[dependency]?.insert(key)
    }
  }
  
  func unsubscribe<Keys: Sequence<AspectKey>>(_ keys: Keys, for subscriberKey: SubscriberKey) {
    for key in keys {
      store.state.subscriptions[key]?.removeValue(forKey: subscriberKey)
      checkAndRelease(for: key)
    }
    
    notifyUpdateToObservers()
  }
  
  func prepareForTransaction<Node: Aspect>(
    of aspect: Node,
    for key: AspectKey
  ) -> AspectProducerContext<Node.Produced> {
    let transaction = Transaction(key: key) {
      let oldDependencies = detachDependencies(for: key)
      
      return {
        let dependencies = store.graph.dependencies[key] ?? []
        let disusedDependencies = oldDependencies.subtracting(dependencies)
        
        // Release disused dependencies if no longer used.
        for dependency in disusedDependencies {
          checkAndRelease(for: dependency)
        }
      }
    }
    
    let state = getState(of: aspect, for: key)
    // Terminate the ongoing transaction first.
    state.transaction?.terminate()
    // Register the transaction state so it can be terminated from anywhere.
    state.transaction = transaction
    
    return AspectProducerContext(store: self, transaction: transaction) { newValue in
      if let cache = lookupCache(of: aspect, for: key) {
        update(aspect: aspect, for: key, oldValue: cache.value, newValue: newValue)
      }
    }
  }
  
  func getValue<Node: Aspect>(
    of aspect: Node,
    for key: AspectKey,
    override: Override<Node>?
  ) -> Node.Produced {
    let context = prepareForTransaction(of: aspect, for: key)
    let value: Node.Produced
    
    if let override {
      value = override.getValue(aspect)
    }
    else {
      value = aspect.producer.getValue(context)
    }
    
    aspect.producer.manageValue(value, context)
    return value
  }
  
  func getState<Node: Aspect>(of aspect: Node, for key: AspectKey) -> AspectState<Node.Effect> {
    if let state = lookupState(of: aspect, for: key) {
      return state
    }
    
    let context = AspectCurrentContext(store: self)
    let effect = aspect.effect(context: context)
    let state = AspectState(effect: effect)
    store.state.states[key] = state
    return state
  }
  
  func lookupState<Node: Aspect>(of aspect: Node, for key: AspectKey) -> AspectState<Node.Effect>? {
    guard let baseState = store.state.states[key] else {
      return nil
    }
    
    guard let state = baseState as? AspectState<Node.Effect> else {
      assertionFailure(
                """
                [Aspects]
                The type of the given aspect's value and the state did not match.
                There might be duplicate keys, make sure that the keys for all aspect types are unique.
                
                Aspect: \(Node.self)
                Key: \(type(of: aspect.key))
                Detected: \(type(of: baseState))
                Expected: AspectState<\(Node.Effect.self)>
                """
      )
      
      // Release the invalid registration as a fallback.
      release(for: key)
      return nil
    }
    
    return state
  }
  
  func lookupCache<Node: Aspect>(of aspect: Node, for key: AspectKey) -> AspectCache<Node>? {
    guard let baseCache = store.state.caches[key] else {
      return nil
    }
    
    guard let cache = baseCache as? AspectCache<Node> else {
      assertionFailure(
                """
                [Aspects]
                The type of the given aspect's value and the cache did not match.
                There might be duplicate keys, make sure that the keys for all aspect types are unique.
                
                Aspect: \(Node.self)
                Key: \(type(of: aspect.key))
                Detected: \(type(of: baseCache))
                Expected: AspectCache<\(Node.self)>
                """
      )
      
      // Release the invalid registration as a fallback.
      release(for: key)
      return nil
    }
    
    return cache
  }
  
  func lookupOverride<Node: Aspect>(of aspect: Node) -> Override<Node>? {
    lazy var overrideKey = OverrideKey(aspect)
    lazy var typeOverrideKey = OverrideKey(Node.self)
    
    // OPTIMIZE: Desirable to reduce the number of dictionary lookups which is currently 4 times.
    let baseScopedOverride = scopedOverrides[overrideKey] ?? scopedOverrides[typeOverrideKey]
    let baseOverride = baseScopedOverride ?? overrides[overrideKey] ?? overrides[typeOverrideKey]
    
    guard let baseOverride else {
      return nil
    }
    
    guard let override = baseOverride as? Override<Node> else {
      assertionFailure(
                """
                [Aspects]
                Detected an illegal override.
                There might be duplicate keys or logic failure.
                Detected: \(type(of: baseOverride))
                Expected: Override<\(Node.self)>
                """
      )
      
      return nil
    }
    
    return override
  }
  
  func lookupScopeKey<Node: Aspect>(of aspect: Node, override: Override<Node>?) -> ScopeKey? {
    if override?.isScoped ?? false {
      return scopeKey
    }
    else if let aspect = aspect as? any Scoped {
      let scopeID = ScopeID(aspect.scopeID)
      return inheritedScopeKeys[scopeID]
    }
    else {
      return nil
    }
  }
  
  func notifyUpdateToObservers() {
    guard !observers.isEmpty || !scopedObservers.isEmpty else {
      return
    }
    
    let snapshot = snapshot()
    
    for observer in observers + scopedObservers {
      observer.onUpdate(snapshot)
    }
  }
}
