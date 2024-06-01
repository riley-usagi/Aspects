@MainActor internal struct AspectProducerContext<Value> {
  private let store: StoreContext
  private let transaction: Transaction
  private let update: @MainActor (Value) -> Void
  
  init(
    store: StoreContext,
    transaction: Transaction,
    update: @escaping @MainActor (Value) -> Void
  ) {
    self.store = store
    self.transaction = transaction
    self.update = update
  }
  
  var isTerminated: Bool {
    transaction.isTerminated
  }
  
  var onTermination: (@MainActor () -> Void)? {
    get { transaction.onTermination }
    nonmutating set { transaction.onTermination = newValue }
  }
  
  func update(with value: Value) {
    update(value)
  }
  
  func transaction<T>(_ body: @MainActor (AspectTransactionContext) -> T) -> T {
    transaction.begin()
    let context = AspectTransactionContext(store: store, transaction: transaction)
    defer { transaction.commit() }
    return body(context)
  }
  
  func transaction<T>(_ body: @MainActor (AspectTransactionContext) async throws -> T) async rethrows -> T {
    transaction.begin()
    let context = AspectTransactionContext(store: store, transaction: transaction)
    defer { transaction.commit() }
    return try await body(context)
  }
}
