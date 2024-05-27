final class SubscriberState {
  let token = SubscriberKey.Token()
  var subscribing = Set<AspectKey>()
  var unsubscribe: ((Set<AspectKey>) -> Void)?
  
  init() {}
  
  deinit {
    unsubscribe?(subscribing)
  }
}
