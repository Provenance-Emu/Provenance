# Class inheritance

When supporting iOS 26 and other coordinated releases (macOS 26, etc), SwiftData supports class inheritance for models.

**Important:** This is not a common feature; only add model subclassing if it actually has a benefit. Alternatives such as protocols are often simpler and better.

This works the same as regular class inheritance in Swift, however, child classes must be explicitly marked `@available` for a 26 release or later, e.g. iOS 26. This is required even if iOS 26 is set as the minimum deployment target.

For example:

```swift
@Model class Article {
    var type: String

    init(type: String) {
        self.type = type
    }
}

@available(iOS 26, *)
@Model class Tutorial: Article {
    var difficulty: Int

    init(difficulty: Int) {
        self.difficulty = difficulty
        super.init(type: "Tutorial")
    }
}

@available(iOS 26, *)
@Model class News: Article {
    var topic: String

    init(topic: String) {
        self.topic = topic
        super.init(type: "News")
    }
}
```

Notice how both the parent and child classes must use the `@Model` macro.

**Important:** When using a 26 release or later as minimum deployment target, we must still mark subclassed models with `@available`. However, we do *not* need to do the same with code using that model, because Xcode can match the deployment target and the model availability.

When providing the schemas as part of model container creation, make sure to list both the parent class and its child classes – SwiftData is *not* able to infer the connection by itself.

If you create a relationship to a model that has subclasses, the relationship might contain the parent class or any of its subclasses.

For example, the `articles` array here might contain `Article`, `Tutorial`, or `News` instances:

```swift
@Model class Magazine {
    @Relationship(deleteRule: .cascade) var articles: [Article]

    init(articles: [Article]) {
        self.articles = articles
    }
}
```

If only one subclass is supported, it should be written specifically. If several subclasses but not all should be in the relationship, you might have no choice but to add another level of subclasses: BaseClass -> Subclass -> Subsubclass. However, this is not a good idea – deep subclassing is generally frowned upon, and will increase complexity in migrations.


## Filtering with subclasses

One important benefit of model subclassing is that we can use `@Query` to look for specific subclasses, *or* to look for the base class, which will automatically return all child classes too.

For example, we could load only tutorials like this:

```swift
@Query private var tutorials: [Tutorial]
```

Or load *all* articles, including tutorials, like this:

```swift
@Query private var articles: [Article]
```

If you want to load specific child classes but not the parent class, use `is` with the `#Predicate` macro to perform filtering:

```swift
@Query(filter: #Predicate<Article> {
    $0 is Tutorial || $0 is News
}) private var tutorialsAndNews: [Article]
```

**Important:** The type of the resulting array elements is `Article`, the parent class, so typecasting must be used to access child-class properties and methods.

It's possible to do typecasting inside predicates to filter based on child-class properties. For example, this looks for easier tutorials and general news to create a list of articles suitable for the front page:

```swift
@Query(filter: #Predicate<Article> { article in
    if let tutorial = article as? Tutorial {
        tutorial.difficulty < 3
    } else if let news = article as? News {
        news.topic == "General"
    } else {
        false
    }
}) private var frontPageArticles: [Article]
```

When working with the resulting data, regular Swift typecasting using `as` works fine.
