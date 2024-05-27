@usableFromInline @MainActor internal struct Subscriber {
  private weak var state: SubscriberState?
  
  let key: SubscriberKey
  
  init(_ state: SubscriberState) {
    self.state = state
    self.key = SubscriberKey(token: state.token)
  }
  
  var subscribing: Set<AspectKey> {
    get { state?.subscribing ?? [] }
    nonmutating set { state?.subscribing = newValue }
  }
  
  var unsubscribe: ((Set<AspectKey>) -> Void)? {
    get { state?.unsubscribe }
    nonmutating set { state?.unsubscribe = newValue }
  }
}
