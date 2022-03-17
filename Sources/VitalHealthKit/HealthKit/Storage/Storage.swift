func store(entities: [EntityToStore], anchorStorage: AnchorStorage, dateStorage: DateStorage) {
  for entity in entities {
    switch entity {
      case .anchor(let string, let anchor):
        anchorStorage.set(anchor, forKey: string)
      case .date(let date):
        dateStorage.set(date)
    }
  }
}
