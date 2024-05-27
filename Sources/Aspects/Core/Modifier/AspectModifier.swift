public extension Aspect {
  func modifier<T: AspectModifier>(_ modifier: T) -> ModifiedAspect<Self, T> {
    ModifiedAspect(aspect: self, modifier: modifier)
  }
}

public protocol AspectModifier {
  associatedtype Key: Hashable
  
  associatedtype Base
  
  associatedtype Produced
  
  var key: Key { get }
  
  func producer(aspect: some Aspect<Base>) -> AspectProducer<Produced>
}
