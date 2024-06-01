public protocol AsyncAspect<Produced>: Aspect {
  var refreshProducer: AspectRefreshProducer<Produced> { get }
}
