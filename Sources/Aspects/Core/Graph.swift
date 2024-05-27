internal struct Graph: Equatable {
  var dependencies = [AspectKey: Set<AspectKey>]()
  var children = [AspectKey: Set<AspectKey>]()
}
