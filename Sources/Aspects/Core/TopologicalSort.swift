internal enum Vertex: Hashable {
  case aspect(key: AspectKey)
  case subscriber(key: SubscriberKey)
}

internal struct Edge: Hashable {
  let from: AspectKey
  let to: Vertex
}

internal extension AspectStore {
  
  func topologicalSorted(key: AspectKey) -> (
    edges: ReversedCollection<ContiguousArray<Edge>>,
    redundantDependencies: [Vertex: ContiguousArray<AspectKey>]
  ) {
    var trace = Set<Vertex>()
    var edges = ContiguousArray<Edge>()
    var redundantDependencies = [Vertex: ContiguousArray<AspectKey>]()
    
    func traverse(key: AspectKey, isRedundant: Bool) {
      if let children = graph.children[key] {
        for child in children {
          traverse(key: child, from: key, isRedundant: isRedundant)
        }
      }
      
      if let subscriptions = state.subscriptions[key] {
        for subscriberKey in subscriptions.keys {
          traverse(key: subscriberKey, from: key, isRedundant: isRedundant)
        }
      }
    }
    
    func traverse(key: AspectKey, from fromKey: AspectKey, isRedundant: Bool) {
      let vertex = Vertex.aspect(key: key)
      let isRedundant = isRedundant || trace.contains(vertex)
      
      trace.insert(vertex)
      
      // Do not stop traversing downstream even when edges are already traced
      // to analyze the redundant edges later.
      traverse(key: key, isRedundant: isRedundant)
      
      if isRedundant {
        redundantDependencies[vertex, default: []].append(fromKey)
      }
      else {
        let edge = Edge(from: fromKey, to: vertex)
        edges.append(edge)
      }
    }
    
    func traverse(key: SubscriberKey, from fromKey: AspectKey, isRedundant: Bool) {
      let vertex = Vertex.subscriber(key: key)
      let isRedundant = isRedundant || trace.contains(vertex)
      
      trace.insert(vertex)
      
      if isRedundant {
        redundantDependencies[vertex, default: []].append(fromKey)
      }
      else {
        let edge = Edge(from: fromKey, to: vertex)
        edges.append(edge)
      }
    }
    
    traverse(key: key, isRedundant: false)
    
    return (edges: edges.reversed(), redundantDependencies: redundantDependencies)
  }
}
