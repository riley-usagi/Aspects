public struct Snapshot: CustomStringConvertible {
  internal let graph: Graph
  internal let caches: [AspectKey: any AspectCacheProtocol]
  internal let subscriptions: [AspectKey: [SubscriberKey: Subscription]]
  
  internal init(
    graph: Graph,
    caches: [AspectKey: any AspectCacheProtocol],
    subscriptions: [AspectKey: [SubscriberKey: Subscription]]
  ) {
    self.graph = graph
    self.caches = caches
    self.subscriptions = subscriptions
  }
  
  /// A textual representation of this snapshot.
  public var description: String {
        """
        Snapshot
        - graph: \(graph)
        - caches: \(caches)
        """
  }
  
  @MainActor public func lookup<Node: Aspect>(_ aspect: Node) -> Node.Produced? {
    let key = AspectKey(aspect, scopeKey: nil)
    let cache = caches[key] as? AspectCache<Node>
    return cache?.value
  }
  
  public func graphDescription() -> String {
    guard !caches.keys.isEmpty else {
      return "digraph {}"
    }
    
    var statements = Set<String>()
    
    for key in caches.keys {
      statements.insert(key.description.quoted)
      
      if let children = graph.children[key] {
        for child in children {
          statements.insert("\(key.description.quoted) -> \(child.description.quoted)")
        }
      }
      
      if let subscriptions = subscriptions[key]?.values {
        for subscription in subscriptions {
          let label = "line:\(subscription.location.line)".quoted
          statements.insert("\(subscription.location.fileID.quoted) [style=filled]")
          statements.insert("\(key.description.quoted) -> \(subscription.location.fileID.quoted) [label=\(label)]")
        }
      }
    }
    
    return """
            digraph {
              node [shape=box]
              \(statements.sorted().joined(separator: "\n  "))
            }
            """
  }
}

private extension String {
  var quoted: String {
    "\"\(self)\""
  }
}
