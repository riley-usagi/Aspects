import SwiftUI

public extension Aspect {
  
  func animation(_ animation: Animation? = .default) -> ModifiedAspect<Self, AnimationModifier<Produced>> {
    modifier(AnimationModifier(animation: animation))
  }
}

public struct AnimationModifier<Produced>: AspectModifier {
  
  public typealias Base = Produced
  
  public typealias Produced = Produced
  
  public struct Key: Hashable {
    private let animation: Animation?
    
    fileprivate init(animation: Animation?) {
      self.animation = animation
    }
  }
  
  private let animation: Animation?
  
  internal init(animation: Animation?) {
    self.animation = animation
  }
  
  public var key: Key {
    Key(animation: animation)
  }
  
  public func producer(aspect: some Aspect<Base>) -> AspectProducer<Produced> {
    AspectProducer { context in
      context.transaction { $0.watch(aspect) }
    } performUpdate: { update in
      withAnimation(animation, update)
    }
  }
}
