# Indexing

When supporting iOS 18 and other coordinated releases, SwiftData supports indexes to help speed up queries. This has a small performance cost for writing, so if data is read rarely and updated frequently (such as logging), indexes may be a bad choice.

Indexes can be on single properties, like this:

```swift
@Model class Article {
    #Index<Article>([\.type], [\.author])

    var type: String
    var author: String
    var publishDate: Date

    init(type: String, author: String, publishDate: Date) {
        self.type = type
        self.author = author
        self.publishDate = publishDate
    }
}
```

Alternatively, you can mix single properties and groups of properties when you know they are often used together:

```swift
#Index<Article>([\.type], [\.type, \.author])
```
