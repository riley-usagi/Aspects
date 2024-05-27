@MainActor public protocol AspectEffect {
  
  typealias Context = AspectCurrentContext
  
  func initialized(context: Context)
  
  func updated(context: Context)
  
  func released(context: Context)
}

public extension AspectEffect {
  func initialized(context: Context) {}
  func updated(context: Context) {}
  func released(context: Context) {}
}
