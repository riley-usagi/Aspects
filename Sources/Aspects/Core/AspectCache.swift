internal protocol AspectCacheProtocol {
  associatedtype Node: Aspect
  
  var aspect: Node { get set }
  var value: Node.Produced { get set }
}

internal struct AspectCache<Node: Aspect>: AspectCacheProtocol, CustomStringConvertible {
  var aspect: Node
  var value: Node.Produced
  
  var description: String {
    "\(value)"
  }
}
