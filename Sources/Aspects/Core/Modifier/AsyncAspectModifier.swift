public protocol AsyncAspectModifier: AspectModifier {
  func refreshProducer(aspect: some AsyncAspect<Base>) -> AspectRefreshProducer<Produced>
}
