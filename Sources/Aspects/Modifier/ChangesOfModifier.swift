public extension Aspect {
  
  func changes<T: Equatable>(
    of keyPath: KeyPath<Produced, T>
  ) -> ModifiedAspect<Self, ChangesOfModifier<Produced, T>> {
    modifier(ChangesOfModifier(keyPath: keyPath))
  }
}

public struct ChangesOfModifier<Base, Produced: Equatable>: AspectModifier {
  
  public typealias Base = Base
  
  public typealias Produced = Produced
  
  public struct Key: Hashable {
    private let keyPath: KeyPath<Base, Produced>
    
    fileprivate init(keyPath: KeyPath<Base, Produced>) {
      self.keyPath = keyPath
    }
  }
  
  private let keyPath: KeyPath<Base, Produced>
  
  internal init(keyPath: KeyPath<Base, Produced>) {
    self.keyPath = keyPath
  }
  
  public var key: Key {
    Key(keyPath: keyPath)
  }
  
  public func producer(aspect: some Aspect<Base>) -> AspectProducer<Produced> {
    AspectProducer { context in
      let value = context.transaction { $0.watch(aspect) }
      return value[keyPath: keyPath]
    } shouldUpdate: { oldValue, newValue in
      oldValue != newValue
    }
  }
}
