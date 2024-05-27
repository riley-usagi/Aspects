public extension Aspect where Produced: Equatable {
  
  var changes: ModifiedAspect<Self, ChangesModifier<Produced>> {
    modifier(ChangesModifier())
  }
}

public struct ChangesModifier<Produced: Equatable>: AspectModifier {
  
  public typealias Base = Produced
  public typealias Produced = Produced
  
  public struct Key: Hashable {}
  
  public var key: Key { Key() }
  
  public func producer(aspect: some Aspect<Base>) -> AspectProducer<Produced> {
    AspectProducer { context in
      context.transaction { $0.watch(aspect) }
    } shouldUpdate: { oldValue, newValue in
      oldValue != newValue
    }
  }
}
