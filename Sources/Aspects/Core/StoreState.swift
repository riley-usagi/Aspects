internal struct StoreState {
  var caches = [AspectKey: any AspectCacheProtocol]()
  var states = [AspectKey: any AspectStateProtocol]()
  var subscriptions = [AspectKey: [SubscriberKey: Subscription]]()
}
