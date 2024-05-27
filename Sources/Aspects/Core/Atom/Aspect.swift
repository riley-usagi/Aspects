public protocol Aspect<Produced> {
  associatedtype Key: Hashable
  associatedtype Produced
  associatedtype Effect: AspectEffect = EmptyEffect
  
  typealias Context         = AspectTransactionContext
  typealias CurrentContext  = AspectCurrentContext
  
  var key: Key { get }
  
  @MainActor func effect(context: CurrentContext) -> Effect
  
  /// Deprecated. use `Aspect.effect(context:)` instead.
  @MainActor func updated(newValue: Produced, oldValue: Produced, context: CurrentContext)
  
  var producer: AspectProducer<Produced> { get }
}

public extension Aspect {
  @MainActor func effect(context: CurrentContext) -> Effect where Effect == EmptyEffect {
    EmptyEffect()
  }
  
  func updated(newValue: Produced, oldValue: Produced, context: CurrentContext) {}
}

public extension Aspect where Self == Key {
  var key: Self { self }
}
