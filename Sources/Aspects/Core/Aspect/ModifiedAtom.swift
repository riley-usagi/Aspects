public struct ModifiedAspect<Node: Aspect, Modifier: AspectModifier>: Aspect where Node.Produced == Modifier.Base {
  
  public typealias Produced = Modifier.Produced
  
  public struct Key: Hashable {
    private let aspectKey: Node.Key
    private let modifierKey: Modifier.Key
    
    fileprivate init(
      aspectKey: Node.Key,
      modifierKey: Modifier.Key
    ) {
      self.aspectKey = aspectKey
      self.modifierKey = modifierKey
    }
  }
  
  private let aspect: Node
  private let modifier: Modifier
  
  internal init(aspect: Node, modifier: Modifier) {
    self.aspect = aspect
    self.modifier = modifier
  }
  
  public var key: Key {
    Key(aspectKey: aspect.key, modifierKey: modifier.key)
  }
  
  
  public var producer: AspectProducer<Produced> {
    modifier.producer(aspect: aspect)
  }
}

extension ModifiedAspect: AsyncAspect where Node: AsyncAspect, Modifier: AsyncAspectModifier {
  public var refreshProducer: AspectRefreshProducer<Produced> {
    modifier.refreshProducer(aspect: aspect)
  }
}

extension ModifiedAspect: Scoped where Node: Scoped {
  public var scopeID: Node.ScopeID {
    aspect.scopeID
  }
}
