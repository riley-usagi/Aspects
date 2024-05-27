@MainActor internal protocol AspectStateProtocol: AnyObject {
  associatedtype Effect: AspectEffect
  
  var effect: Effect { get }
  var transaction: Transaction? { get set }
}

internal final class AspectState<Effect: AspectEffect>: AspectStateProtocol {
  let effect: Effect
  var transaction: Transaction?
  
  init(effect: Effect) {
    self.effect = effect
  }
}
